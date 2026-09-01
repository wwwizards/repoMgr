<#--------------------------------------------------------------------------
#  SCRIPT: repoMgr.ps1 — LogicWizards Monorepo Multi‑Tool Manager
#--------------------------------------------------------------------------
# PURPOSE:  Manages various tasks within a monorepo, including backups, statistics,
#           risk analysis, and reintegration for a multi‑repo / monorepo layout.
# ABSTRACT: Provides a comprehensive set of tools for managing a monorepo, including:
#           - Backup (SafeCopy)
#           - Repo drift statistics
#           - DR branch creation
#           - Nested repo reintegration scaffold
#           - Detached HEAD risk analysis (Option‑D: Smart Divergence + Forensic Mode)
# REQUIRES: Git, PowerShell 7+, and a repo or submodule checkout.
# CREATED:  260828 BY: Joe Negron (LogicWizards.NYC)
# UPDATED:  260831 BY: Copilot (Fix: invalid $CFG-INFO variable name / function-call-before-definition order / v0.5.1)
# COMPANY:  LogicWizards.NYC <LogicWizards.NYC>
# VERSION:  0.5.1
# LICENSE:  AGPL-3.0 <https://www.gnu.org/licenses/agpl-3.0.html> 
#               ~ FEE: $00 = for academic and non-commercial use. (requires attribution)
#               ~ FEE: $20 = for individual commercial DEV use (requires separate licensing & registration).
#               ~ FEE: $99 = for commercial use (requires separate licensing & registration - bulk pricing is available).
# NOTES:  Ensure that the configuration file is correctly set up to avoid unexpected behavior.
# USAGE:
#     .\repoMgr.ps1 -backup -stats -recovery -reintegration -risk -dirtyonly -dryrun -help -all
# OPTIONS:
#     -backup           # Performs a backup of the repository (SafeCopy ZIP + copy to safedest).
#     -stats            # Displays drift statistics about all discovered repositories.
#     -recovery         # Creates DR branches for repositories (optionally only dirty ones).
#     -reintegration    # Handles reintegration scaffold tasks for nested repositories.
#     -risk             # Analyzes detached HEAD risk across repos (Option‑D: Smart Divergence + Forensic Mode).
#     -dirtyonly        # Operates only on dirty repositories (for DR branch creation).
#     -dryrun           # Simulates actions without making any changes (logged as DRYRUN).
#     -help             # Displays this help message.
#     -all              # Executes backup + stats + recovery + reintegration (not risk, by design).
# CHANGELOG:
#     260827 - 0.2.0 - Initial port from previous BASH version.
#     260828 - 0.3.x - Added -risk option for analyzing detached HEAD state (single‑repo).
#     260830 - 0.3.2 - Updated version and ensured -risk option is documented.
#     260830 - 0.4.0 - Added:
#                * bounded traversal via config $lookback (with override)
#                * automatic JSON output to repoMgr‑logs
#                * archival‑branch detection for detached HEAD
#                * DR‑branch creation (existing, now risk‑aware)
#                * divergence checks vs primary branch (main/master)
#                * stale‑commit detection
#                * destructive‑commit classification
#                * risk scoring with severity buckets
#                * root + Agile‑Wizard repo role awareness
#     260830 - 0.5.0 - refactored from v0.4 for speed & efficiency on deep & wide repo-traversals:
#                  * Smart Divergence (merge‑base bounded traversal)
#                  * Forensic Mode (metadata‑only, JSON output)
#                  * Archival branch detection for detached HEAD
#                  * DR branch creation retained
#                  * Divergence checks vs primary branch (main/master)
#                  * Stale‑commit detection
#                  * Destructive‑commit classification (crude but useful)
#                  * Risk scoring with role‑sensitive thresholds (Root vs Agile‑Wizard vs Standard)
#                  * Root + Agile‑Wizard sensitivity hooks for future tuning
#     260831 - 0.5.1 - Fixed $CFG-INFO invalid variable name (renamed to $cfgInfo) causing a
#                script-wide ParseException, and moved the INIT log call to after the
#                log function definition to fix call-before-definition order.
#--------------------------------------------------------------------------#>

param(
    [string]$root,              # Override the root directory for repository operations
    [string]$safedest,          # Override the safe destination for backups
    [string]$lookback,          # Override the lookback period for repository analysis
    [string]$drBranch,          # Override the name of the disaster recovery branch
    [switch]$backup,            # Perform a backup of the repository
    [switch]$stats,             # Display repository statistics
    [Alias('dr')]               # deprecated alias for back-compat w/prev versions 
    [switch]$recovery,          # Perform a disaster recovery operation (alias: dr)
    [switch]$dirtyonly,         # Operate only on dirty repositories
    [switch]$reintegration,     # Perform reintegration of changes
    [switch]$risk,              # Analyze risk for the repository
    [switch]$dryrun,            # Perform a dry run without making changes
    [switch]$help,              # Display help information
    [switch]$all                # Apply the operation to all repositories
)

#------------------------------------------------------------------------------#>
# -- Load external config - Imports configuration from repoMgr.config.psd1 --
# This loads the configuration file for the repository manager script.
# The configuration file should (at minimum) define the following keys:
#     root      - The root directory for repository operations  (override arg: -root)
#     safedest  - The safe destination for backups              (override arg: -safedest)
#     lookback  - The lookback period for repository analysis   (override arg: -lookback)
#     drBranch  - The name of the disaster recovery branch      (override arg: -drBranch)
# Defaults in file are for lazy loading and can be overridden by providing the 
# corresponding override params when invoking the script.
#------------------------------------------------------------------------------#>
#
$cfgPath = Join-Path $PSScriptRoot "repoMgr.config.psd1"
# Gracefully handle missing configuration file
if (!(Test-Path $cfgPath)) {
    Write-Warning " -Configuration file not found at path: $cfgPath - using default values instead."
} else {
    $cfg = Import-PowerShellDataFile $cfgPath
}
# --- Determine effective configuration values based on overrides and defaults ---
$root =  ($root) ? $root : ((!$cfg.root) ? "." : $cfg.root) # the root-dir for repository operations, (default = "." if not specified in config or override.)
$safedest = ($safedest) ? $safedest : (!$cfg.safedest) ? "." : $cfg.safedest  # the safe-dir for backups, (default = "." if not specified in config or override.)
$lookback = ($lookback) ? $lookback : (!$cfg.lookback) ? "2 weeks ago" : $cfg.lookback  # the lookback period for repo-analysis, (default = "2 weeks ago" if not specified in config or override.)
$drBranch = ($drBranch) ? $drBranch : (!$cfg.drBranch) ? "DR-YYMMDD" : $cfg.drBranch  # Determine the name of the disaster recovery branch, (default = "DR-YYMMDD" if not specified in config or override.)
# --- Generate timestamp and define paths for backup and logging ---
$timestamp = (Get-Date).ToString("yyMMdd-HHmmss")
$zipPath   = "$root\$timestamp-SafeCopy-backup.zip"
$logDir    = "$root\repoMgr-logs"
$logFile   = "$logDir\repoMgr-$timestamp.json"
# --- Ensure log directory exists ---
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

#------------------------------------------------------------------------------#>
# --- FUNCTION: banner - Displays a banner message ---
#------------------------------------------------------------------------------#>
function banner($msg) {
    Write-Host "`n=== $msg ===" -ForegroundColor Cyan
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: log - Logging helper ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Logs actions performed by the script, including dry runs and actual executions.
# PARAMETERS:
#     [string]$action - The action being logged (e.g., "DRYRUN", "EXEC", "NESTED", "BACKUP", "RISK").
#     [string]$path   - The path associated with the action.
#     [string]$result - The result or message to log.
# RETURNS: None. Logs the specified action to the log file as JSON lines.
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

# Write initial log entry
log "INIT" $root "Script started"

# write current configuration to the screen & log
$cfgInfo = " - Configuration: -- Root: $root, `n -- SafeDest: $safedest, Timestamp: $timestamp, Lookback: $lookback, DR Branch: $drBranch"
Write-Host $cfgInfo -ForegroundColor Magenta
log "CONFIG" $root $cfgInfo

#------------------------------------------------------------------------------#>
# --- FUNCTION: exec - DRYRUN wrapper ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Executes a command, respecting the dry run mode.
# PARAMETERS:
#     [string]$cmd  - The command to execute.
#     [string]$path - The path associated with the command.
# RETURNS: The output of the executed command (unless dryrun).
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
        log "BACKUP-DRYRUN" $root "SafeCopy simulated"
        return
    }

    # Ensure the safe destination directory exists
    if (-not (Test-Path $safedest)) {
        New-Item -ItemType Directory -Path $safedest -Force | Out-Null
    }

    # Create the backup archive and copy it to the safe destination.
    Compress-Archive -Path $root -DestinationPath $zipPath -Force
    Copy-Item $zipPath $safedest -Force
    log "BACKUP" $root "Backup created at $zipPath and copied to $safedest"
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
# --- FUNCTION: Get-RepoRole - Classifies repo role (Root / Agile‑Wizard / Standard) ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Determines the logical role of a repo for risk scoring sensitivity.
# PARAMETERS:
#     [string]$repoPath - The path to the Git repository.
# RETURNS: A role string: "Root", "Agile-Wizard", or "Standard".
#------------------------------------------------------------------------------#>
function Get-RepoRole {
    param([string]$repoPath)

    $leaf = Split-Path $repoPath -Leaf

    if ($repoPath -eq $root) {
        return "Root"
    }
    elseif ($leaf -match "Agile[-_ ]?Wizard") {
        return "Agile-Wizard"
    }
    else {
        return "Standard"
    }
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Get-GoodBranch - Determines the primary branch of a Git repo ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Determines the primary branch of a Git repository, typically 'main' or 'master'.
# PARAMETERS:
#     [string]$repoPath - The path to the Git repository.
# RETURNS: The name of the primary branch ('main' or 'master').
#          Defaults to 'main' if neither is found (with a warning).
#------------------------------------------------------------------------------#>
function Get-GoodBranch {
    param([string]$repoPath)

    $branches = git -C $repoPath branch --format="%(refname:short)"

    if ($branches -contains "main") {
        return "main"
    }
    elseif ($branches -contains "master") {
        return "master"
    }
    else {
        Write-Host "⚠ No 'main' or 'master' found in $repoPath, defaulting to 'main'" -ForegroundColor Yellow
        return "main"
    }
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
# --- FUNCTION: get-repoHistory - Repo history ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Retrieves commit history for a given repo path & lookback period.
# PARAMETERS:
#     [string]$path - The path to the Git repository.
# RETURNS: The commit history in a formatted graph via Git commands.
#------------------------------------------------------------------------------#>
function get-repoHistory($path) {
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
        $path   = $repo.FullName
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
# RETURNS: None. Generates DR branches via Git commands.
#------------------------------------------------------------------------------#>
function create-drBranches {
    banner "Creating DR branches ($drBranch)"

    $repos = get-repoList

    foreach ($repo in $repos) {
        $path   = $repo.FullName
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
# PARAMETERS:
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
    git -C $nestedPath log --graph --oneline --decorate --all

    Write-Host "`n2. Cherry-pick needed commits into DR branch"
    Write-Host "3. Remove nested .git directory"
    Write-Host "4. Add folder back to monorepo"
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Create-ArchivalBranchIfDetached - Detached HEAD archival branch ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Creates an archival branch if repo is in a detached HEAD state.
# PARAMETERS:
#     [string]$repoPath - Path to Git repo to check for detached HEAD.
# RETURNS: None. Creates a recovered-<shortHash> branch if needed.
#------------------------------------------------------------------------------#>
function Create-ArchivalBranchIfDetached {
    param([string]$repoPath)

    $branch = git -C $repoPath rev-parse --abbrev-ref HEAD

    if ($branch -eq "HEAD") {
        $hash     = git -C $repoPath rev-parse HEAD
        $archival = "recovered-$($hash.Substring(0,7))"

        Write-Host "Detached HEAD detected — creating archival branch: $archival"
        git -C $repoPath branch $archival $hash
        log "ARCHIVAL" $repoPath "Created archival branch $archival at $hash"
    }
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Analyze-DetachedHeadCommits - Deep scan (legacy) ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Legacy deep scan of detached HEAD commit chain vs a good branch.
#              Preserved for case‑study / forensic use, but not wired to -risk by default.
# PARAMETERS:
#     [string]$goodBranch - Branch to compare against (default = "main").
#     [string]$lookback   - Time period to look back (default = "120 days ago").
#     [switch]$FullScan   - If set, analyzes entire commit history regardless of lookback.
# RETURNS: [PSCustomObject[]] of commit/file comparison results.
#------------------------------------------------------------------------------#>
function Analyze-DetachedHeadCommits {
    param(
        [string]$goodBranch = "main",
        [string]$lookback   = "120 days ago",
        [switch]$FullScan
    )

    Write-Host "`n=== Analyzing Detached HEAD Commit Chain (Legacy Deep Scan) ===" -ForegroundColor Cyan

    $detached = git rev-parse HEAD
    Write-Host "Detached HEAD at: $detached"

    Create-ArchivalBranchIfDetached -repoPath "."

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
        $files = git diff --name-only $goodBranch $commit
        if (!$files) { continue }

        foreach ($file in $files) {
            $goodDate = git log -1 --pretty=format:"%ad" --date=iso $goodBranch -- $file
            $badDate  = git log -1 --pretty=format:"%ad" --date=iso $commit -- $file
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

    Write-Host "`n=== Summary Table (Legacy) ===" -ForegroundColor Cyan
    $results | Format-Table Commit, File, GoodTimestamp, DetachedTimestamp -AutoSize

    $jsonPath = "detached-analysis-legacy-$((Get-Date).ToString('yyyyMMdd-HHmmss')).json"
    $results | ConvertTo-Json -Depth 5 | Out-File $jsonPath

    Write-Host "`nJSON written to: $jsonPath" -ForegroundColor Green

    return $results
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Analyze-RepoRisk - Option‑D Smart Divergence + Forensic Mode ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Analyzes the risk associated with a detached HEAD in a Git repo using:
#     * Smart Divergence:
#         - merge-base between goodBranch and detached HEAD
#         - bounded traversal (since $lookback) from merge-base..detached
#     * Forensic Mode:
#         - metadata‑only (timestamps, file lists, simple diff stats)
#         - JSON output for downstream agents
#   Also performs:
#     * Archival branch creation for detached HEAD
#     * Divergence checks vs primary branch (main/master)
#     * Stale‑commit detection (detached older than good branch version)
#     * Destructive‑commit classification (presence of deletions in diffStat)
#     * Role‑sensitive risk scoring (Root vs Agile‑Wizard vs Standard)
# PARAMETERS:
#     [string]$repoPath - The path to the Git repository to analyze.
# RETURNS:
#     [PSCustomObject[]] of per‑file risk records.
#------------------------------------------------------------------------------#>
function Analyze-RepoRisk {
    param([string]$repoPath)

    banner "Risk Analysis for $repoPath"

    $branch = git -C $repoPath rev-parse --abbrev-ref HEAD 2>$null

    if ($branch -ne "HEAD") {
        Write-Host "Repo is not in detached HEAD state. Skipping risk analysis."
        log "RISK-SKIP" $repoPath "Not detached HEAD"
        return
    }

    $role       = Get-RepoRole -repoPath $repoPath
    $goodBranch = Get-GoodBranch -repoPath $repoPath

    Write-Host "Repo role       : $role"
    Write-Host "Good branch     : $goodBranch"

    $detached = git -C $repoPath rev-parse HEAD
    Write-Host "Detached HEAD at: $detached"

    Create-ArchivalBranchIfDetached -repoPath $repoPath

    # Smart Divergence: use merge-base to bound traversal
    $mergeBase = git -C $repoPath merge-base $goodBranch $detached 2>$null

    if (-not $mergeBase) {
        Write-Host "⚠ No merge-base found between $goodBranch and $detached — using detached only." -ForegroundColor Yellow
        $range = $detached
    }
    else {
        Write-Host "Merge-base between $goodBranch and detached: $mergeBase"
        $range = "$mergeBase..$detached"
    }

    Write-Host "Bounded scan — commits in range $range since $lookback"
    $commitList = git -C $repoPath rev-list --since="$lookback" $range

    Write-Host "Commits to analyze: $($commitList.Count)"

    $results = @()

    foreach ($commit in $commitList) {
        # Divergence: files that differ between goodBranch and this commit
        $files = git -C $repoPath diff --name-only $goodBranch $commit
        if (!$files) { continue }

        foreach ($file in $files) {
            # Timestamps (for stale detection)
            $goodDate = git -C $repoPath log -1 --pretty=format:"%ad" --date=iso $goodBranch -- $file
            $badDate  = git -C $repoPath log -1 --pretty=format:"%ad" --date=iso $commit -- $file

            # Simple diff stat (for destructive classification)
            $diffStat = git -C $repoPath diff --stat $goodBranch $commit -- $file

            # Stale detection: detached commit older than good branch version
            $isStale =
                if ($goodDate -and $badDate) {
                    ([DateTime]$badDate) -lt ([DateTime]$goodDate)
                }
                else {
                    $false
                }

            # Destructive classification: presence of "deletions" in diffStat
            $isDestructive = $diffStat -match "deletions"

            # Divergence classification (simple: any difference = divergent)
            $isDivergent = $true

            $results += [PSCustomObject]@{
                RepoPath          = $repoPath
                Role              = $role
                Commit            = $commit
                File              = $file
                GoodBranch        = $goodBranch
                GoodTimestamp     = $goodDate
                DetachedTimestamp = $badDate
                DiffStat          = $diffStat
                IsStale           = [bool]$isStale
                IsDestructive     = [bool]$isDestructive
                IsDivergent       = [bool]$isDivergent
            }
        }
    }

    # Aggregate risk metrics
    $destructiveCount = ($results | Where-Object { $_.IsDestructive }).Count
    $staleCount       = ($results | Where-Object { $_.IsStale }).Count
    $divergentCount   = ($results | Where-Object { $_.IsDivergent }).Count
    $totalFiles       = $results.Count

    # Role‑sensitive numeric score
    $baseScore = ($destructiveCount * 3) + ($staleCount * 2) + ($divergentCount * 1)

    switch ($role) {
        "Root" {
            # Root: more sensitive — lower thresholds
            if     ($baseScore -gt 40) { $risk = "HIGH" }
            elseif ($baseScore -gt 15) { $risk = "MEDIUM" }
            elseif ($baseScore -gt  0) { $risk = "LOW" }
            else                       { $risk = "NONE" }
        }
        "Agile-Wizard" {
            # Agile‑Wizard: medium sensitivity
            if     ($baseScore -gt 60) { $risk = "HIGH" }
            elseif ($baseScore -gt 25) { $risk = "MEDIUM" }
            elseif ($baseScore -gt  0) { $risk = "LOW" }
            else                       { $risk = "NONE" }
        }
        default {
            # Standard repos: default thresholds
            if     ($baseScore -gt 80) { $risk = "HIGH" }
            elseif ($baseScore -gt 30) { $risk = "MEDIUM" }
            elseif ($baseScore -gt  0) { $risk = "LOW" }
            else                       { $risk = "NONE" }
        }
    }

    Write-Host "`nRisk level for ${repoPath}: $risk" -ForegroundColor Yellow
    Write-Host "  Role            : $role"
    Write-Host "  Destructive     : $destructiveCount"
    Write-Host "  Stale           : $staleCount"
    Write-Host "  Divergent       : $divergentCount"
    Write-Host "  Total files     : $totalFiles"
    Write-Host "  Base score      : $baseScore"

    log "RISK" $repoPath "Role=$role; Risk=$risk; Score=$baseScore; Files=$totalFiles"

    Write-Host "`n=== Summary Table (Option‑D) ===" -ForegroundColor Cyan
    $results | Format-Table Commit, File, GoodTimestamp, DetachedTimestamp, IsStale, IsDestructive -AutoSize | Out-Host

    $jsonPath = Join-Path $logDir ("detached-analysis-{0}-{1}.json" -f `
        (Split-Path $repoPath -Leaf), (Get-Date).ToString('yyyyMMdd-HHmmss'))

    $results | ConvertTo-Json -Depth 5 | Out-File $jsonPath
    Write-Host "`nJSON written to: $jsonPath" -ForegroundColor Green

    return $results
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Analyze-AllRepoRisk - Runs Option‑D across all repos ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Iterates over all discovered repos and runs Analyze-RepoRisk on each.
#   Skips non‑detached repos automatically.
# PARAMETERS: None.
# RETURNS: None. Writes per‑repo JSON files + console tables.
#------------------------------------------------------------------------------#>
function Analyze-AllRepoRisk {
    banner "Running Option‑D Risk Analysis Across All Repos"

    $repos = get-repoList

    foreach ($repo in $repos) {
        $path = $repo.FullName
        Analyze-RepoRisk -repoPath $path
    }
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
    Write-Host "-dirtyonly      : Only branch repos with pending changes (for -recovery)"
    Write-Host "-reintegration  : Reintegration scaffold for nested repos"
    Write-Host "-risk           : Option‑D detached HEAD risk analysis across repos"
    Write-Host "-dryrun         : No changes, only simulate (logged as DRYRUN)"
    Write-Host "-all            : Run backup + stats + recovery + reintegration (not risk)"
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
if ($backup)        { archive-safecopy }
if ($stats)         { write-repoStats }
if ($recovery)      { create-drBranches }
if ($reintegration) { reintegrate-nestedRepo }
if ($risk)          { Analyze-AllRepoRisk }

# --- DEFAULT CASE: Show help if no valid flags are provided ---
if (-not ($backup -or $stats -or $recovery -or $reintegration -or $risk -or $dryrun -or $all)) {
    show-help
}
