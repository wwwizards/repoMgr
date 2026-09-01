<#--------------------------------------------------------------------------
#  SCRIPT: repoMgr.ps1 — LogicWizards Monorepo Multi‑Tool Manager
#--------------------------------------------------------------------------
# PURPOSE:  Manages various tasks within a monorepo, including backups, statistics, and reintegration.
# ABSTRACT: Provides a comprehensive set of tools for managing a monorepo, including backup, statistics, and reintegration functionalities.
# REQUIRES: Git, PowerShell 7+, and a repo or submodule checkout.
# CREATED: 260828 BY: Joe Negron (LogicWizards.NYC)
# UPDATED: 260828 BY: Copilot
# COMPANY: LogicWizards.NYC <LogicWizards.NYC>
# VERSION: 0.3.1
# LICENSE: MIT
# USAGE: 
#     .\repoMgr.ps1 -backup -stats -recovery -reintegration -dirtyonly -dryrun -help -all
# OPTIONS: 
#     -backup           # Performs a backup of the repository.
#     -stats            # Displays statistics about the repository.
#     -recovery         # Creates DR branches for repositories.
#     -reintegration    # Handles reintegration tasks within the repository.
#     -dirtyonly        # Operates only on dirty repositories.
#     -dryrun           # Simulates actions without making any changes.
#     -help             # Displays this help message.
#     -all              # Executes all available tasks.
#     -risk             # Analyzes the risk of detached HEAD state in the repository.
#
#------------------------------------------------------------------------------#>

param(
    [switch]$backup,
    [switch]$stats,
    [Alias('dr')]
    [switch]$recovery,
    [switch]$dirtyonly,
    [switch]$reintegration,
    [switch]$risk,  
    [switch]$dryrun,
    [switch]$help,
    [switch]$all     
)

#------------------------------------------------------------------------------#>
# -- Load external config - Imports configuration from repoMgr.config.psd1 --
#------------------------------------------------------------------------------#>
# DESCRIPTION: Loads configuration and sets up initial variables.
# RETURNS: None. Initializes vars for the script based on the configuration file.
# -----------------------------------------------------------------------------#>
$cfgPath = Join-Path $PSScriptRoot "repoMgr.config.psd1"
$cfg = Import-PowerShellDataFile $cfgPath

$root      = $cfg.root
$safedest  = $cfg.safedest
$lookback  = $cfg.lookback
$drBranch  = $cfg.drBranch

$timestamp = (Get-Date).ToString("yyMMdd-HHmmss")
$zipPath   = "$root\$timestamp-SafeCopy-backup.zip"
$logDir    = "$root\repoMgr-logs"
$logFile   = "$logDir\repoMgr-$timestamp.json"

# --- Ensure log directory exists ---
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

#------------------------------------------------------------------------------#>
# --- FUNCTION: log - Logging helper ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Logs actions performed by the script, including dry runs and actual executions.
# PARAMETERS:
#     [string]$action - The action being logged (e.g., "DRYRUN", "EXEC", "NESTED", "BACKUP").
#     [string]$path   - The path associated with the action.
#     [string]$result - The result or message to log.
# RETURNS: None. Logs the specified action to the log file.
#------------------------------------------------------------------------------#>
function log {
    param([string]$action, [string]$path, [string]$result)
    $entry = [ordered]@{
        timestamp = (Get-Date).ToString("o")
        action    = $action
        path      = $path
        result    = $result
    }
    $json = ($entry | ConvertTo-Json -Depth 5)
    Add-Content -Path $logFile -Value $json
}

#------------------------------------------------------------------------------#>
# --- Banner helper - Displays a banner message ---
#------------------------------------------------------------------------------#>
function banner($msg) {
    Write-Host "`n=== $msg ===" -ForegroundColor Cyan
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: exec - DRYRUN wrapper ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Executes a command, respecting the dry run mode.
# PARAMETERS:
#     [string]$cmd  - The command to execute.
#     [string]$path - The path associated with the command.
# RETURNS: The output of the executed command.
#------------------------------------------------------------------------------#>
function exec {
    param([string]$cmd, [string]$path)

    if ($dryrun) {
        Write-Host "[DRYRUN] Would execute: $cmd"
        log "DRYRUN" $path $cmd
        return
    }

    Write-Host $cmd
    $out = Invoke-Expression $cmd
    log "EXEC" $path $cmd
    return $out
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Get-GoodBranch - Determines the primary branch of a Git repo ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Determines the primary branch of a Git repository, typically 'main' or 'master'.
# PARAMETERS:
#     [string]$repoPath - The path to the Git repository.
# RETURNS: The name of the primary branch ('main' or 'master'). 
#     - Defaults to 'main' if neither is found.
#  USAGE:
#     $goodBranch = Get-GoodBranch -repoPath "C:\path\to\repo"
#------------------------------------------------------------------------------#>
function Get-GoodBranch {
    param([string]$repoPath)

    $branches = git -C $repoPath branch --format="%(refname:short)"

    if ($branches -contains "main")   { return "main" }
    elseif ($branches -contains "master") { return "master" }
    else {
        Write-Host "⚠ No 'main' or 'master' found in $repoPath, defaulting to 'main'" -ForegroundColor Yellow
        return "main"
    }
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: get-repoList - Repo discovery ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Scans the root directory for Git repositories.
# PARAMETERS: None.
# RETURNS: A list of directories containing Git repositories.
#------------------------------------------------------------------------------#>
function get-repoList {
    banner "Scanning for Git repositories"
    $repos = Get-ChildItem -Path $root -Recurse -Directory -Force |
        Where-Object { Test-Path (Join-Path $_.FullName ".git") }
    return $repos
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: detect-nestedRepos - Nested repo detection ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Detects nested Git repositories within the root directory.
# PARAMETERS: None.
# RETURNS: A list of nested Git repositories within the root directory.
#------------------------------------------------------------------------------#>
function detect-nestedRepos {
    banner "Detecting nested repos"
    $repos = get-repoList
    $nestedRepos = @()
    foreach ($repo in $repos) {
        $parent = Split-Path $repo.FullName -Parent
        if ($parent -ne $root -and (Test-Path "$parent\.git")) {
            Write-Host "⚠ Nested repo detected: $($repo.FullName)" -ForegroundColor Yellow
            log "NESTED" $repo.FullName "Nested repo detected"
            $nestedRepos += $repo
        }
    }
    return $nestedRepos
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: archive-safecopy - Backup ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Creates a full backup of the root directory and copies it to a safe destination.
# PARAMETERS: None.
# RETURNS: None.  
#------------------------------------------------------------------------------#>
function archive-safecopy {
    banner "Creating full backup"
    if ($dryrun) {
        Write-Host "[DRYRUN] Would zip $root to $zipPath"
        Write-Host "[DRYRUN] Would copy to $safedest"
        return
    }

    # Ensure the safe destination directory exists
    if (-not (Test-Path $safedest)) {
        New-Item -ItemType Directory -Path $safedest -Force | Out-Null
    }

    # Create the backup archive and copy it to the safe destination.
    Compress-Archive -Path $root -DestinationPath $zipPath -Force
    Copy-Item $zipPath $safedest -Force
    log "BACKUP" $root "Backup created and copied"
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: get-repoHistory - Repo history ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Retrieves commit history for a given repo path & lookback period.
# PARAMETERS:
#     [string]$path - The path to the Git repository.
# RETURNS: The commit history in a formatted graph via Git commands.
#------------------------------------------------------------------------------#>
function get-repoHistory($path) {
    # Retrieve the commit history for the specified repository path since the lookback period.
    git -C $path log --graph --oneline --decorate --all --since=$lookback `
        --pretty=format:"%C(auto)%h %C(blue)%ad%C(reset) %C(yellow)%d%C(reset) %s" `
        --date=iso
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: write-repoStats - Repo drift report ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Creates report of current status & commit history of all repos.
# PARAMETERS: None.
# RETURNS: None. 
#------------------------------------------------------------------------------#>
function write-repoStats {
    banner "Repo Drift Report"
    $repos = get-repoList

    foreach ($repo in $repos) {
        $path = $repo.FullName
        $branch = git -C $path rev-parse --abbrev-ref HEAD 2>$null
        $status = git -C $path status --short 2>$null

        banner "Repo: $path"
        Write-Host "Branch: $branch"
        Write-Host "Pending changes:"
        Write-Host ($status ? $status : "Clean")

        Write-Host "`nHistory since $lookback :"
        get-repoHistory $path
    }
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: create-drBranches - DR branch creation ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Creates DR branches for all repositories, optionally only for dirty ones.
# PARAMETERS: None.
# RETURNS: None. Generates DR branches for the repositories via Git commands.
#------------------------------------------------------------------------------#>
function create-drBranches {
    banner "Creating DR branches ($drBranch)"

    $repos = get-repoList

    foreach ($repo in $repos) {
        $path = $repo.FullName
        $status = git -C $path status --short

        if ($dirtyonly -and !$status) {
            Write-Host "Skipping clean repo: $path"
            continue
        }

        exec "git -C `"$path`" checkout -b $drBranch" $path
        exec "git -C `"$path`" push -u origin $drBranch" $path
    }
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: reintegrate-nestedRepo - Reintegration scaffold ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Provides a scaffold for reintegrating a nested repository into the monorepo.
#  PARAMETERS:
#     [string]$nestedPath - The path to the nested Git repository (default: "$root\.AI-TRAINING").
# RETURNS: None. DESTRUCTIVE operations may be required manually.
#------------------------------------------------------------------------------#>
function reintegrate-nestedRepo {
    param([string]$nestedPath = "$root\.AI-TRAINING")

    banner "Reintegration Scaffold for $nestedPath"

    if (!(Test-Path "$nestedPath\.git")) {
        Write-Host "No nested repo found."
        return
    }

    Write-Host "Nested repo detected. Manual steps:"
    Write-Host "1. Inspect commit ancestry"
    # Display the commit history for review before proceeding with reintegration.
    git -C $nestedPath log --graph --oneline --decorate --all

    Write-Host "`n2. Cherry-pick needed commits into DR branch"
    Write-Host "3. Remove nested .git directory"
    Write-Host "4. Add folder back to monorepo"
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Create-ArchivalBranchIfDetached - does what it says...
#------------------------------------------------------------------------------#>
# DESCRIPTION: Creates an archival branch if repo is in a detached HEAD state.
#  PARAMETERS:
#      param([string]$repoPath) - path to Git repo to check for detached HEAD.
# RETURNS: None. DESTRUCTIVE operations may be required manually.
#------------------------------------------------------------------------------#>
function Create-ArchivalBranchIfDetached {
    param([string]$repoPath)

    $branch = git -C $repoPath rev-parse --abbrev-ref HEAD

    if ($branch -eq "HEAD") {
        $hash = git -C $repoPath rev-parse HEAD
        $archival = "recovered-$($hash.Substring(0,7))"

        Write-Host "Detached HEAD detected — creating archival branch: $archival"
        # Create the archival branch pointing to the detached HEAD commit
        git -C $repoPath branch $archival $hash
    }
}


#------------------------------------------------------------------------------#>
# --- FUNCTION: Analyze-DetachedHeadCommits - 
#------------------------------------------------------------------------------#>
# DESCRIPTION: Analyzes commits in a detached HEAD state and compares them against a specified good branch.
# PARAMETERS:
#     [string]$goodBranch - The branch to compare against (default = "main").
#     [string]$lookback - The time period to look back for commits (default = "120 days ago").
#     [switch]$FullScan - If set, analyzes the entire commit history regardless of the lookback period.
# RETURNS: None. Outputs analysis results to the console.
#------------------------------------------------------------------------------#>
function Analyze-DetachedHeadCommits {
    param(
        [string]$goodBranch = "main",
        [string]$lookback = "120 days ago",
        [switch]$FullScan
    )

    Write-Host "`n=== Analyzing Detached HEAD Commit Chain ===" -ForegroundColor Cyan

    # 1. Get detached HEAD commit
    $detached = git rev-parse HEAD
    Write-Host "Detached HEAD at: $detached"
    
    # Ensure we have an archival branch for the detached HEAD
    Create-ArchivalBranchIfDetached -repoPath "."

    # 2. Build rev-list command with optional lookback limit
    if ($FullScan) {
        Write-Host "Full scan enabled — traversing entire commit chain."
        $commitList = git rev-list $detached
    }
    else {
        Write-Host "Bounded scan — commits since $lookback"
        $commitList = git rev-list --since="$lookback" $detached
    }

    Write-Host "Commits to analyze: $($commitList.Count)"

    $results = @()

    foreach ($commit in $commitList) {

        # 3. Overlapping files between commit and good branch
        $files = git diff --name-only $goodBranch $commit

        if (!$files) { continue }

        foreach ($file in $files) {

            # 4. Timestamps
            $goodDate = git log -1 --pretty=format:"%ad" --date=iso $goodBranch -- $file
            $badDate  = git log -1 --pretty=format:"%ad" --date=iso $commit -- $file

            # 5. Diff summary
            $diffStat = git diff --stat $goodBranch $commit -- $file

            $results += [PSCustomObject]@{
                Commit            = $commit
                File              = $file
                GoodBranch        = $goodBranch
                GoodTimestamp     = $goodDate
                DetachedTimestamp = $badDate
                DiffStat          = $diffStat
            }
        }
    }

    # 6. Output table
    Write-Host "`n=== Summary Table ===" -ForegroundColor Cyan
    $results | Format-Table Commit, File, GoodTimestamp, DetachedTimestamp -AutoSize

    # 7. Write JSON file
    $jsonPath = "detached-analysis-$((Get-Date).ToString('yyyyMMdd-HHmmss')).json"
    $results | ConvertTo-Json -Depth 5 | Out-File $jsonPath

    Write-Host "`nJSON written to: $jsonPath" -ForegroundColor Green

    return $results
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Analyze-RepoRisk - Risk analysis for detached HEAD state ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Analyzes the risk associated with a detached HEAD  in a Git repo.
# PARAMETERS: 
#     [string]$repoPath - The path to the Git repository to analyze.
# RETURNS: None. Logs analysis results to console & writes them to a JSON file.
# USAGE: Analyze-RepoRisk -repoPath <path_to_repo>
#------------------------------------------------------------------------------#>
function Analyze-RepoRisk {
    param([string]$repoPath)

    banner "Risk Analysis for $repoPath"

    $branch = git -C $repoPath rev-parse --abbrev-ref HEAD 2>$null

    if ($branch -ne "HEAD") {
        Write-Host "Repo is not in detached HEAD state. Skipping risk analysis."
        return
    }

    $goodBranch = Get-GoodBranch -repoPath $repoPath

    Write-Host "Good branch resolved as: $goodBranch"

    # Detached HEAD commit
    $detached = git -C $repoPath rev-parse HEAD
    Write-Host "Detached HEAD at: $detached"

    # Archival branch
    Create-ArchivalBranchIfDetached -repoPath $repoPath

    # Bounded rev-list
    Write-Host "Bounded scan — commits since $lookback"
    $commitList = git -C $repoPath rev-list --since="$lookback" $detached

    Write-Host "Commits to analyze: $($commitList.Count)"

    $results = @()

    foreach ($commit in $commitList) {
        $files = git -C $repoPath diff --name-only $goodBranch $commit
        if (!$files) { continue }

        foreach ($file in $files) {
            $goodDate = git -C $repoPath log -1 --pretty=format:"%ad" --date=iso $goodBranch -- $file
            $badDate  = git -C $repoPath log -1 --pretty=format:"%ad" --date=iso $commit -- $file
            $diffStat = git -C $repoPath diff --stat $goodBranch $commit -- $file

            # crude destructive metric: count "-" in diffStat
            $deletions = ($diffStat -split '\s+' | Where-Object { $_ -match 'deletions' }) -join ' '
            $isDestructive = $diffStat -match 'deletions'

            $results += [PSCustomObject]@{
                RepoPath          = $repoPath
                Commit            = $commit
                File              = $file
                GoodBranch        = $goodBranch
                GoodTimestamp     = $goodDate
                DetachedTimestamp = $badDate
                DiffStat          = $diffStat
                IsDestructive     = [bool]$isDestructive
            }
        }
    }

    # Simple risk scoring per repo
    $destructiveCount = ($results | Where-Object { $_.IsDestructive }).Count
    $totalFiles       = $results.Count

    $risk =
        if ($destructiveCount -gt 50) { "HIGH" }
        elseif ($destructiveCount -gt 10) { "MEDIUM" }
        elseif ($destructiveCount -gt 0) { "LOW" }
        else { "NONE" }

    Write-Host "`nRisk level for $repoPath: $risk (destructive files: $destructiveCount / $totalFiles)" -ForegroundColor Yellow

    Write-Host "`n=== Summary Table ===" -ForegroundColor Cyan
    $results | Format-Table Commit, File, GoodTimestamp, DetachedTimestamp, IsDestructive -AutoSize

    $jsonPath = Join-Path $logDir ("detached-analysis-{0}-{1}.json" -f `
        (Split-Path $repoPath -Leaf), (Get-Date).ToString('yyyyMMdd-HHmmss'))

    $results | ConvertTo-Json -Depth 5 | Out-File $jsonPath
    Write-Host "`nJSON written to: $jsonPath" -ForegroundColor Green

    return $results
}


#------------------------------------------------------------------------------#>
# --- FUNCTION: show-help - Help ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Displays the help information for the script.
# PARAMETERS: None.
#------------------------------------------------------------------------------#>
function show-help {
    banner "repoMgr.ps1 — Flags"
    Write-Host "-backup         : Full backup + safe-copy"
    Write-Host "-stats          : Repo drift report"
    Write-Host "-recovery       : Create DR branches (legacy alias: -dr)"
    Write-Host "-dirtyonly      : Only branch repos with pending changes"
    Write-Host "-reintegration  : Reintegration scaffold"
    Write-Host "-dryrun         : No changes, only simulate"
    Write-Host "-all            : Run backup + stats + recovery + reintegration"
}



#------------------------------------------------------------------------------#>
# --- MAIN ---
#------------------------------------------------------------------------------#>
if ($help) { show-help; exit }

# --- EXECUTE ALL TASKS IF THE -all FLAG IS SET ---
if ($all) {
    archive-safecopy
    write-repoStats
    detect-nestedRepos
    create-drBranches
    reintegrate-nestedRepo
    exit
}

# --- CONDITIONAL EXECUTION BASED ON FLAGS ---
if ($backup)       { archive-safecopy }
if ($stats)        { write-repoStats }
if ($recovery)     { create-drBranches }
if ($reintegration){ reintegrate-nestedRepo }

# --- DEFAULT CASE: Show help if no valid flags are provided ---
if (-not ($backup -or $stats -or $recovery -or $reintegration -or $dryrun -or $all)) {
    show-help
}

