<#--------------------------------------------------------------------------
#  SCRIPT: repoMgr.ps1 — LogicWizards Monorepo Multi‑Tool Manager
#--------------------------------------------------------------------------
# PURPOSE:
#   Manages various tasks within a monorepo, including backups, statistics,
#   disaster‑recovery branches, detached‑HEAD risk analysis, and reintegration
#   scaffolding for nested repositories.
#
# ABSTRACT:
#   Provides a comprehensive set of tools for managing a monorepo, including:
#     - Full backup + safe‑copy
#     - Repo drift statistics and bounded history traversal
#     - DR branch creation (per‑repo, optionally dirty‑only)
#     - Nested repo detection and reintegration scaffold
#     - Detached‑HEAD analysis with:
#         * bounded traversal (configurable lookback)
#         * divergence checks vs primary branch
#         * stale‑commit detection
#         * destructive‑commit classification
#         * per‑repo risk scoring
#     - Root + Agile‑Wizard awareness for stricter thresholds
#
# REQUIRES:
#   - Git
#   - PowerShell 7+
#   - A monorepo root or submodule checkout
#
# CREATED: 260828 BY: Joe Negron (LogicWizards.NYC)
# UPDATED: 260830 BY: JN
# UPDATED: 260830 BY: Copilot (v0.4.x risk + drift enhancements)
# COMPANY: LogicWizards.NYC <LogicWizards.NYC>
# VERSION: 0.4.0
# LICENSE: MIT
#
# USAGE:
#   .\repoMgr.ps1 -backup -stats -recovery -reintegration -risk -dirtyonly -dryrun -help -all
#
# OPTIONS:
#   -backup        # Performs a backup of the repository (root) and safe‑copies it.
#   -stats         # Displays drift statistics + bounded history for all repos.
#   -recovery      # Creates DR branches for repositories (legacy alias: -dr).
#   -reintegration # Handles reintegration scaffold for nested repositories.
#   -risk          # Analyzes detached‑HEAD risk across repos (root + Agile‑Wizard aware).
#   -dirtyonly     # Operates only on dirty repositories (for DR branch creation).
#   -dryrun        # Simulates actions without making any changes (exec wrapper).
#   -help          # Displays this help message.
#   -all           # Executes backup + stats + recovery + reintegration (no risk by default).
#
# CHANGELOG:
#   260827 - 0.2.0 - Initial port from previous BASH version.
#   260828 - 0.3.x - Added -risk option for analyzing detached HEAD state (per‑repo).
#   260830 - 0.3.2 - Updated version and ensured -risk option is documented.
#   260830 - 0.4.0 - Added:
#                    * bounded traversal via config $lookback (with override)
#                    * automatic JSON output to repoMgr‑logs
#                    * archival‑branch detection for detached HEAD
#                    * DR‑branch creation (existing, now risk‑aware)
#                    * divergence checks vs primary branch (main/master)
#                    * stale‑commit detection
#                    * destructive‑commit classification
#                    * risk scoring with severity buckets
#                    * root + Agile‑Wizard repo role awareness
#--------------------------------------------------------------------------#>

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
$cfgPath = Join-Path $PSScriptRoot "repoMgr.config.psd1"
$cfg = Import-PowerShellDataFile $cfgPath

$root      = $cfg.root
$safedest  = $cfg.safedest
$lookback  = $cfg.lookback       # e.g. "120 days ago" or "2026-01-01"
$drBranch  = $cfg.drBranch       # e.g. "DR-260830"

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
# DESCRIPTION:
#   Logs actions performed by the script, including dry runs and actual executions.
#
# PARAMETERS:
#   [string]$action - The action being logged (e.g., "DRYRUN", "EXEC", "NESTED", "BACKUP", "RISK").
#   [string]$path   - The path associated with the action (repo path, root, etc.).
#   [string]$result - The result or message to log (command, summary, etc.).
#
# RETURNS:
#   None. Appends a JSON entry to the per‑run log file.
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
# --- FUNCTION: exec - DRYRUN wrapper ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Executes a command, respecting the -dryrun mode. All invocations are logged.
#
# PARAMETERS:
#   [string]$cmd  - The command to execute.
#   [string]$path - The path associated with the command (repo path).
#
# RETURNS:
#   The output of the executed command (unless in dryrun mode).
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
# DESCRIPTION:
#   Creates a full backup of the root directory and copies it to a safe destination.
#
# PARAMETERS:
#   None.
#
# RETURNS:
#   None. Produces a zip archive and safe‑copies it to $safedest.
#------------------------------------------------------------------------------#>
function archive-safecopy {
    banner "Creating full backup"
    if ($dryrun) {
        Write-Host "[DRYRUN] Would zip $root to $zipPath"
        Write-Host "[DRYRUN] Would copy to $safedest"
        log "BACKUP-DRYRUN" $root "Zip: $zipPath -> $safedest"
        return
    }

    # Ensure the safe destination directory exists
    if (-not (Test-Path $safedest)) {
        New-Item -ItemType Directory -Path $safedest -Force | Out-Null
    }

    # Create the backup archive and copy it to the safe destination.
    Compress-Archive -Path $root -DestinationPath $zipPath -Force
    Copy-Item $zipPath $safedest -Force
    log "BACKUP" $root "Backup created: $zipPath -> $safedest"
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: get-repoList - Repo discovery ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Scans the root directory for Git repositories (monorepo + submodules).
#
# PARAMETERS:
#   None.
#
# RETURNS:
#   A list of directories containing Git repositories (objects from Get-ChildItem).
#------------------------------------------------------------------------------#>
function get-repoList {
    banner "Scanning for Git repositories"
    $repos = Get-ChildItem -Path $root -Recurse -Directory -Force |
        Where-Object { Test-Path (Join-Path $_.FullName ".git") }
    return $repos
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Get-RepoRole - Classifies repo role (root, Agile‑Wizard, other) ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Determines the "role" of a repo within the monorepo:
#     - "root"         : The configured monorepo root ($root).
#     - "agile-wizard" : A repo whose leaf name matches "Agile-Wizard" or ".Agile-Wizard".
#     - "submodule"    : Any other repo under the root.
#
# PARAMETERS:
#   [string]$repoPath - The path to the Git repository.
#
# RETURNS:
#   A string role: "root", "agile-wizard", or "submodule".
#------------------------------------------------------------------------------#>
function Get-RepoRole {
    param([string]$repoPath)

    if ([IO.Path]::GetFullPath($repoPath) -eq [IO.Path]::GetFullPath($root)) {
        return "root"
    }

    $leaf = Split-Path $repoPath -Leaf
    if ($leaf -match 'Agile-Wizard') {
        return "agile-wizard"
    }

    return "submodule"
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Get-GoodBranch - Determines the primary branch of a Git repo ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Determines the primary branch of a Git repository, typically 'main' or 'master'.
#   This is used as the "good" branch for divergence and risk analysis.
#
# PARAMETERS:
#   [string]$repoPath - The path to the Git repository.
#
# RETURNS:
#   The name of the primary branch ('main' or 'master').
#   Defaults to 'main' if neither is found (with a warning).
#
# USAGE:
#   $goodBranch = Get-GoodBranch -repoPath "C:\path\to\repo"
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
# DESCRIPTION:
#   Detects nested Git repositories within the root directory (submodules, accidental nests).
#
# PARAMETERS:
#   None.
#
# RETURNS:
#   A list of nested Git repositories within the root directory.
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
# --- FUNCTION: get-repoHistory - Repo history (bounded traversal) ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Retrieves commit history for a given repo path, bounded by the configured
#   $lookback period. This is the "bounded traversal" mechanism for drift stats.
#
# PARAMETERS:
#   [string]$path - The path to the Git repository.
#
# RETURNS:
#   The commit history in a formatted graph via Git commands.
#------------------------------------------------------------------------------#>
function get-repoHistory($path) {
    git -C $path log --graph --oneline --decorate --all --since=$lookback `
        --pretty=format:"%C(auto)%h %C(blue)%ad%C(reset) %C(yellow)%d%C(reset) %s" `
        --date=iso
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: write-repoStats - Repo drift report ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Creates a report of current status & bounded commit history of all repos.
#   This surfaces:
#     - current branch
#     - pending changes (dirty vs clean)
#     - history since $lookback (bounded traversal)
#
# PARAMETERS:
#   None.
#
# RETURNS:
#   None. Writes to console; underlying git calls can be redirected if needed.
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
# DESCRIPTION:
#   Creates DR branches for all repositories, optionally only for dirty ones.
#   Uses the configured $drBranch name and pushes to origin.
#
# PARAMETERS:
#   None.
#
# RETURNS:
#   None. Generates DR branches via Git commands (or simulates in dryrun).
#------------------------------------------------------------------------------#>
function create-drBranches {
    banner "Creating DR branches ($drBranch)"

    $repos = get-repoList

    foreach ($repo in $repos) {
        $path   = $repo.FullName
        $status = git -C $path status --short

        if ($dirtyonly -and -not $status) {
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
# DESCRIPTION:
#   Provides a scaffold for reintegrating a nested repository into the monorepo.
#   This is intentionally non‑automated because destructive operations may be
#   required (removing nested .git, cherry‑picking, etc.).
#
# PARAMETERS:
#   [string]$nestedPath - The path to the nested Git repository
#                         (default: "$root\.AI-TRAINING").
#
# RETURNS:
#   None. Prints manual steps and ancestry for human review.
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
# --- FUNCTION: Create-ArchivalBranchIfDetached - Detached HEAD archival ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Creates an archival branch if repo is in a detached HEAD state.
#   This ensures that the detached commit chain is anchored to a named branch
#   before any recovery or reintegration work is attempted.
#
# PARAMETERS:
#   [string]$repoPath - Path to Git repo to check for detached HEAD.
#
# RETURNS:
#   None. Creates a branch "recovered-<shortHash>" if HEAD is detached.
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
# --- FUNCTION: Analyze-DetachedHeadCommits - Legacy detached chain analyzer ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Analyzes commits in a detached HEAD state and compares them against a
#   specified good branch. This is a more "raw" analyzer, kept for manual use.
#
# PARAMETERS:
#   [string]$goodBranch - Branch to compare against (default = "main").
#   [string]$lookback   - Time period to look back for commits (default = "120 days ago").
#   [switch]$FullScan   - If set, analyzes entire commit history regardless of lookback.
#
# RETURNS:
#   None. Outputs analysis results to console and writes a JSON file.
#------------------------------------------------------------------------------#>
function Analyze-DetachedHeadCommits {
    param(
        [string]$goodBranch = "main",
        [string]$lookback   = "120 days ago",
        [switch]$FullScan
    )

    Write-Host "`n=== Analyzing Detached HEAD Commit Chain ===" -ForegroundColor Cyan

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
        if (-not $files) { continue }

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

    Write-Host "`n=== Summary Table ===" -ForegroundColor Cyan
    $results | Format-Table Commit, File, GoodTimestamp, DetachedTimestamp -AutoSize

    $jsonPath = "detached-analysis-$((Get-Date).ToString('yyyyMMdd-HHmmss')).json"
    $results | ConvertTo-Json -Depth 5 | Out-File $jsonPath

    Write-Host "`nJSON written to: $jsonPath" -ForegroundColor Green

    return $results
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Analyze-RepoRisk - Detached HEAD risk analysis (bounded + scored) ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Analyzes the risk associated with a detached HEAD in a Git repo, with:
#     - bounded traversal using config $lookback (or override)
#     - divergence checks vs primary branch (main/master)
#     - stale‑commit detection
#     - destructive‑commit classification (based on deletions)
#     - per‑repo risk scoring (NONE/LOW/MEDIUM/HIGH/CRITICAL)
#     - role‑aware thresholds (root vs Agile‑Wizard vs submodule)
#
# PARAMETERS:
#   [string]$repoPath        - Path to the Git repository to analyze.
#   [string]$OverrideLookback - Optional override for lookback (e.g. "30 days ago").
#
# RETURNS:
#   [PSCustomObject[]] results per file/commit, plus JSON summary written to repoMgr‑logs.
#
# USAGE:
#   Analyze-RepoRisk -repoPath "C:\path\to\repo"
#   Analyze-RepoRisk -repoPath "C:\path\to\repo" -OverrideLookback "30 days ago"
#------------------------------------------------------------------------------#>
function Analyze-RepoRisk {
    param(
        [string]$repoPath,
        [string]$OverrideLookback
    )

    $effectiveLookback = if ($OverrideLookback) { $OverrideLookback } else { $lookback }

    banner "Risk Analysis for $repoPath"

    $branch = git -C $repoPath rev-parse --abbrev-ref HEAD 2>$null

    if ($branch -ne "HEAD") {
        Write-Host "Repo is not in detached HEAD state. Skipping risk analysis."
        log "RISK-SKIP" $repoPath "HEAD is on branch '$branch'"
        return
    }

    $role       = Get-RepoRole -repoPath $repoPath
    $goodBranch = Get-GoodBranch -repoPath $repoPath

    Write-Host "Repo role       : $role"
    Write-Host "Good branch     : $goodBranch"

    $detached = git -C $repoPath rev-parse HEAD
    Write-Host "Detached HEAD at: $detached"

    Create-ArchivalBranchIfDetached -repoPath $repoPath

    Write-Host "Bounded scan — commits since $effectiveLookback"
    $commitList = git -C $repoPath rev-list --since="$effectiveLookback" $detached

    Write-Host "Commits to analyze: $($commitList.Count)"

    # Divergence checks vs goodBranch
    $aheadCount  = git -C $repoPath rev-list --count "$goodBranch..$detached"
    $behindCount = git -C $repoPath rev-list --count "$detached..$goodBranch"

    Write-Host "Divergence vs $goodBranch: detached ahead=$aheadCount, detached behind=$behindCount"

    $results = @()

    foreach ($commit in $commitList) {
        $files = git -C $repoPath diff --name-only $goodBranch $commit
        if (-not $files) { continue }

        foreach ($file in $files) {
            $goodDate = git -C $repoPath log -1 --pretty=format:"%ad" --date=iso $goodBranch -- $file
            $badDate  = git -C $repoPath log -1 --pretty=format:"%ad" --date=iso $commit -- $file
            $diffStat = git -C $repoPath diff --stat $goodBranch $commit -- $file

            # crude destructive metric: any "deletions(-)" in diffStat
            $isDestructive = $false
            $deletionCount = 0

            if ($diffStat) {
                foreach ($line in $diffStat -split "`n") {
                    if ($line -match '(\d+)\s+deletions\(-\)') {
                        $isDestructive = $true
                        $deletionCount += [int]($Matches[1])
                    }
                }
            }

            # classify destructive severity per file
            $destructiveSeverity =
                if ($deletionCount -ge 100) { "HEAVY" }
                elseif ($deletionCount -ge 20) { "MODERATE" }
                elseif ($deletionCount -gt 0) { "MINOR" }
                else { "NONE" }

            $results += [PSCustomObject]@{
                RepoPath          = $repoPath
                Commit            = $commit
                File              = $file
                GoodBranch        = $goodBranch
                GoodTimestamp     = $goodDate
                DetachedTimestamp = $badDate
                DiffStat          = $diffStat
                IsDestructive     = [bool]$isDestructive
                DeletionCount     = $deletionCount
                DestructiveLevel  = $destructiveSeverity
            }
        }
    }

    # Stale‑commit detection: last detached commit date vs effectiveLookback
    $lastDetachedDateRaw = git -C $repoPath log -1 --pretty=format:"%ad" --date=iso $detached
    $lastDetachedDate    = [datetime]::Parse($lastDetachedDateRaw)
    $lookbackAnchor      = (Get-Date $effectiveLookback)

    $isStale = $lastDetachedDate -lt $lookbackAnchor

    Write-Host "`nStale check: last detached commit at $lastDetachedDateRaw; stale=$isStale"

    # Simple risk scoring per repo (role‑aware thresholds)
    $destructiveCount = ($results | Where-Object { $_.IsDestructive }).Count
    $totalFiles       = $results.Count

    # base score from destructive files and divergence
    $baseScore = ($destructiveCount * 2) + ($aheadCount * 1) + ($behindCount * 1)
    if ($isStale) { $baseScore += 10 }

    # role‑based adjustment: root and Agile‑Wizard are more sensitive
    switch ($role) {
        "root"         { $baseScore += 10 }
        "agile-wizard" { $baseScore += 5 }
        default        { $baseScore += 0 }
    }

    # clamp to 0‑100
    if ($baseScore -lt 0)   { $baseScore = 0 }
    if ($baseScore -gt 100) { $baseScore = 100 }

    $riskLevel =
        if ($baseScore -ge 80) { "CRITICAL" }
        elseif ($baseScore -ge 50) { "HIGH" }
        elseif ($baseScore -ge 20) { "MEDIUM" }
        elseif ($baseScore -gt 0)  { "LOW" }
        else { "NONE" }

    Write-Host "`nRisk level for $repoPath: $riskLevel (score=$baseScore, destructive files: $destructiveCount / $totalFiles)" -ForegroundColor Yellow

    Write-Host "`n=== Summary Table ===" -ForegroundColor Cyan
    $results | Format-Table Commit, File, GoodTimestamp, DetachedTimestamp, IsDestructive, DestructiveLevel -AutoSize

    # JSON summary + per‑file details
    $summary = [ordered]@{
        RepoPath       = $repoPath
        Role           = $role
        GoodBranch     = $goodBranch
        DetachedHead   = $detached
        EffectiveLookback = $effectiveLookback
        AheadCount     = $aheadCount
        BehindCount    = $behindCount
        IsStale        = $isStale
        RiskScore      = $baseScore
        RiskLevel      = $riskLevel
        DestructiveFiles = $destructiveCount
        TotalFiles     = $totalFiles
        AnalysisTime   = (Get-Date).ToString("o")
        Results        = $results
    }

    $jsonPath = Join-Path $logDir ("detached-analysis-{0}-{1}.json" -f `
        (Split-Path $repoPath -Leaf), (Get-Date).ToString('yyyyMMdd-HHmmss'))

    $summary | ConvertTo-Json -Depth 6 | Out-File $jsonPath
    Write-Host "`nJSON written to: $jsonPath" -ForegroundColor Green

    log "RISK" $repoPath "RiskLevel=$riskLevel Score=$baseScore Stale=$isStale"

    return $results
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: show-help - Help ---
#------------------------------------------------------------------------------#>
# DESCRIPTION:
#   Displays the help information for the script, including all flags.
#
# PARAMETERS:
#   None.
#------------------------------------------------------------------------------#>
function show-help {
    banner "repoMgr.ps1 — Flags"
    Write-Host "-backup         : Full backup + safe-copy"
    Write-Host "-stats          : Repo drift report (bounded history via config lookback)"
    Write-Host "-recovery       : Create DR branches (legacy alias: -dr)"
    Write-Host "-dirtyonly      : Only branch repos with pending changes"
    Write-Host "-reintegration  : Reintegration scaffold for nested repos"
    Write-Host "-risk           : Detached-HEAD risk analysis (bounded, scored, role-aware)"
    Write-Host "-dryrun         : No changes, only simulate (exec wrapper)"
    Write-Host "-all            : Run backup + stats + recovery + reintegration"
}

#------------------------------------------------------------------------------#>
# --- MAIN ---
#------------------------------------------------------------------------------#>
if ($help) { show-help; exit }

# --- EXECUTE ALL TASKS IF THE -all FLAG IS SET (risk is opt-in) ---
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

if ($risk) {
    banner "Running detached-HEAD risk analysis across repos"
    $repos = get-repoList

    foreach ($repo in $repos) {
        $path = $repo.FullName
        Analyze-RepoRisk -repoPath $path
    }
}

# --- DEFAULT CASE: Show help if no actionable flags are provided ---
if (-not ($backup -or $stats -or $recovery -or $reintegration -or $risk -or $dryrun -or $all)) {
    show-help
}
