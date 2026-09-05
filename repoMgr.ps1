#!/usr/bin/env pwsh
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
# VERSION:  0.6.x - Added new features and improvements: dry-run is now default for all operations.
# LICENSE:  AGPL-3.0 <https://www.gnu.org/licenses/agpl-3.0.html> 
#               ~ FEE: $00 = for academic and non-commercial use. (requires attribution)
#               ~ FEE: $20 = for individual commercial DEV use (requires separate licensing & registration).
#               ~ FEE: $99 = for commercial use (requires separate licensing & registration - bulk pricing is available).
# NOTES:  Ensure that the configuration file is correctly set up to avoid unexpected behavior.
# USAGE:
#     .\repoMgr.ps1 -backup -stats -topology -recovery -reintegration -risk -dirtyonly -dryrun -help -all 
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
#     -topology         # Captures the current topology of all repositories (roles, branches, remotes).

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
#     260901 - 0.5.2 - Fixed three bugs:
#                * (BUG) fixed: $root shell-tokenizer quirk: -root='path' passes literal
#                           '-root=C:\path' string; added sanitization + guard + user warning.
#                * (BUG) fixed: Get-ChildItem -Directory cascade failure was caused entirely
#                           by the poisoned $root value above — no independent fix needed.
#                * (DESIGN) get-repoList never checked $root itself for .git; it only
#                           recursed into subdirs. Added self-check so -root targeting a
#                           single leaf repo (e.g. .AI-TRAINING) works correctly.
#     260901 - 0.5.3 - Added Show-PendingChanges helper: replaces flat one-liner
#                      with Format-Table view. Parses XY porcelain codes into
#                      Action/Scope/File columns. Summary count header included.
#                      -Grouped switch available for large dirty repos.
#     260901 - 0.5.4 - Fixed three post-table bugs surfaced by -all -dryrun run:
#                * (BUG) fixed: Nested detection false-positive: parent dir scan re-flagged
#                        $root as nested. Added Resolve-Path equality guard.
#                * (BUG) fixed: Reintegration double-path: Join-Path $root $repo.Name
#                        doubled the leaf dir name. Now uses $repo.FullName + root guard.
#                * (UX)  Silent empty history: git log returning nothing left a blank
#                        line. Now prints "(no commits in window)" fallback.
#                * (PATCH)  Updated create-drBranches to guard against re-creating an existing DR branch.
#     260903 - 0.6.0 -  multiple improvements and new features added.
#                * (ADD) Added dry-run support for create-drBranches: prints planned actions without executing them.
#                * (BUG) fixed: now restores the pointer to the original branch after creating DR branch.
#                * (ADD) new functions for repository topology and risk analysis.
#                     * (NEW) FUNCTION: Get-RemoteCollisions - Detects remote URL collisions (multiple dirs → same remote) among submodules and nested Git repositories.
#                     * (NEW) FUNCTION: Write-TopologySnapshot - Captures the current topology of all repositories, including roles, branches, and remotes.
#                     * (NEW) FUNCTION: Write-RiskReport - Generates a risk analysis report for all repositories, including remote collisions.
#                     * (NEW) MVx-FUNCTION: analyze-fileOverlap - Detects overlapping file changes between two branches by comparing the last modification dates of each file.
#                * (ADD) dry-run support for create-drBranches and ensured original branch is restored after DR branch creation.
#                * (MOD) -all now includes -topology and -collisions as well.
#                * (MOD) DR branch creation now requires -Force to execute, otherwise it will be skipped in dry-run mode.
#                * (MOD) Updated help information to reflect new features and changes.
#                * (MOD) Improved error handling and logging for all operations.
#                * (MOD) General code cleanup and refactoring for better maintainability and improved UX.
#                * (MOD) Updated repository analysis functions to include additional metrics and improved reporting.
#                * (MOD) Enhanced logging for repository backup and recovery operations - improved visibility into success and failure events
#                * (MOD) Improved handling of nested Git repositories and submodules for all operations - enhanced detection and management of nested structures
#                * (MOD) Agent-friendly improvements for better integration with CI/CD pipelines & AI-assisted workflows.
#     260904 - 0.6.1 -  minor UX improvements and tweaks.
#--------------------------------------------------------------------------#>

param(
    [string]$root,              # Override the root directory for repository operations
    [string]$safedest,          # Override the safe destination for backups
    [string]$lookback,          # Override the lookback period for repository analysis
    [string]$drBranch,          # Override the name of the disaster recovery branch
    [switch]$backup,            # Perform a backup of the repository
    [switch]$topology,          # Capture the current topology of all repositories
    [switch]$collisions,        # Run remote collision detection only
    [switch]$force,             # Explicit override for destructive operations
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
# --- PATCH v0.5.2: Sanitize $root against shell tokenizer quirk ---
# When invoked as -root='C:\path', PS passes the literal string '-root=C:\path'
# as the value. Strip the prefix defensively and warn the user.
if ($root -match '^-root=(.+)$') {
    Write-Warning @"
`$root received a '-root=' prefix — this is a shell tokenizer bug.
  Got   : $root
  Fixed : $($Matches[1])
  Hint  : Use -root 'C:\path'  (space-separated), NOT -root='C:\path' (equals-sign form).
"@
    $root = $Matches[1]
}
# Normalize: strip trailing slashes so Join-Path never gets double-backslashes
$root = $root.TrimEnd('\').TrimEnd('/')

# --- Guard: validate the resolved root before anything else runs ---
if (-not (Test-Path $root)) {
    Write-Error "root path does not exist: '$root' — aborting."
    exit 1
}

# --- Generate timestamp and define paths for backup and logging ---
$timestamp = (Get-Date).ToString("yyMMdd-HHmmss")
$zipPath   = "$root\$timestamp-SafeCopy-backup.zip"
$logDir    = "$root\repoMgr-logs"
$logFile   = "$logDir\repoMgr-$timestamp.json"

# --- Ensure log directory exists ---
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

# --- Default: Use DRYRUN mode unless FORCE is explicitly specified ---
if (-not $PSBoundParameters.ToUpper().ContainsKey('FORCE')) {
    $dryrun = $true
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: banner - Displays a banner message ---
#------------------------------------------------------------------------------#>
function banner($msg) {
    write-host "`n--------------------------------------------------------------------------------------------"
    Write-Host "  === $msg ===" -ForegroundColor Cyan
    write-host "--------------------------------------------------------------------------------------------"
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
$cfgInfo  = "`n--------------------------------------------------------------------------------------------"
$cfgInfo += "`n   INVOCATION: $($MyInvocation.Line)    <-- Timestamp: $timestamp"
$cfgInfo += "`n--------------------------------------------------------------------------------------------"
$cfgInfo += "`n - Configuration: -- Root: $root, `n    --> SafeDest: $safedest, `n    --  Lookback: $lookback, `n    --  DR Branch: $drBranch"
$cfgInfo += "`n--------------------------------------------------------------------------------------------"
Write-Host $cfgInfo -ForegroundColor Darkgray
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
# RETURNS:  None.
# NOTE: v0.6.x - Now excludes the `.venv` directory from the backup.
#------------------------------------------------------------------------------#>
function archive-safecopy {
    banner "Creating full backup"

    # Always include hidden files/dirs; optionally exclude venv
    $source = Resolve-Path $root

    # Explicit venv exclusion without touching .git or submodules.
    # Recurse + Force = hidden files & directories included.
    $items = Get-ChildItem -Path $source -Recurse -Force |
             Where-Object { $_.FullName -notmatch '\\\.venv($|\\)' }

    if ($dryrun) {
        Write-Host "[DRYRUN] Would archive $($items.Count) items from $source to $zipPath"
        Write-Host "[DRYRUN] Would copy to $safedest"
        log "BACKUP-DRYRUN" $root "SafeCopy simulated (filtered venv)"
        return
    }

    if (-not (Test-Path $safedest)) {
        New-Item -ItemType Directory -Path $safedest -Force | Out-Null
    }

    # point‑in‑time (insurance) artifacts that can be restored and inspected like tar -cvz.
    Compress-Archive -Path $items.FullName -DestinationPath $zipPath -Force
    Copy-Item $zipPath $safedest -Force

    log "BACKUP" $root "Backup created at $zipPath and copied to $safedest (filtered venv)"
}


#------------------------------------------------------------------------------#>
# --- FUNCTION: analyze-fileOverlap - Detect overlapping file changes between branches ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Detects overlapping file changes between two branches by comparing the last modification dates of each file.
# PARAMETERS:
#     [string]$branchA - The first branch to compare.
#     [string]$branchB - The second branch to compare.
# RETURNS: A collection of PSCustomObjects containing the file name and the last 
#   modification dates in both branches. It produces a JSON report showing which 
#   files differ and which branch has the newer commit timestamp — perfect for 
#   additional triage before merging - but not a substitute for careful review.
#   combined with something like `git log -n 5 --follow <filename>`
#------------------------------------------------------------------------------#>
function analyze-fileOverlap {
    param([string]$branchA, [string]$branchB), 
    param ([Int16]$numCommits = 5)
    $files = git diff $branchA..$branchB --name-only
    foreach ($f in $files) { 
        banner "Showing last $numCommits commits for $f"
        $logC = git log -n $numCommits --follow $f
        banner "Analyzing file overlap for $f between branches"
        $logA = git log -n 1 --pretty=format:"%ad" --date=iso $branchA -- $f
        $logB = git log -n 1 --pretty=format:"%ad" --date=iso $branchB -- $f
        [PSCustomObject]@{File=$f; Commits=$logC; BranchA_Date=$logA; BranchB_Date=$logB}
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
    $repos = [System.Collections.Generic.List[object]]::new()

    # PATCH v0.5.2: Check $root itself first — handles case where -root targets
    # a single leaf repo (e.g. .AI-TRAINING). The old recurse-only approach
    # returned empty when the root IS the repo, not a parent of repos.
    if (Test-Path (Join-Path $root ".git")) {
        Write-Host "  ✓ $root  [root is a repo]" -ForegroundColor DarkGray
        $repos.Add((Get-Item $root))
    }

    # Then recurse into children for monorepo / multi-repo layouts.
    # Using Microsoft.PowerShell.Management\Get-ChildItem to bypass any alias
    # that strips the -Directory switch in non-default PS environments.
    $children = Microsoft.PowerShell.Management\Get-ChildItem `
        -Path $root -Recurse -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName ".git") }

    foreach ($c in $children) { $repos.Add($c) }

    if ($repos.Count -eq 0) {
        Write-Warning "No Git repositories found under: $root"
    }

    return $repos
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Get-RemoteCollisions - Detect remote collisions in Git repos ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Detects remote URL collisions among submodules and nested Git repositories.
# PARAMETERS: None.
# RETURNS: A list of collision objects with Type, Url, and Paths properties.
#------------------------------------------------------------------------------#>
function Get-RemoteCollisions {
    banner "Detecting remote collisions"

    $collisions = @()

    # 1) Submodules via .gitmodules
    $gitmodulesPath = Join-Path $root ".gitmodules"
    if (Test-Path $gitmodulesPath) {
        $entries = git -C $root config --file .gitmodules --get-regexp 'submodule\..*\.url' 2>$null
        $map = @{}

        foreach ($line in $entries) {
            $parts = $line -split '\s+', 2
            if ($parts.Count -ne 2) { continue }

            $key = $parts[0]   # submodule.<name>.url
            $url = $parts[1]

            $name = ($key -split '\.')[1]
            if (-not $map.ContainsKey($url)) { $map[$url] = @() }
            $map[$url] += $name
        }

        foreach ($url in $map.Keys) {
            if ($map[$url].Count -gt 1) {
                $collisions += [PSCustomObject]@{
                    Type  = 'Submodule'
                    Url   = $url
                    Paths = ($map[$url] -join ', ')
                }
            }
        }
    }

    # 2) Nested repos with same remote
    $repos = get-repoList
    $remoteMap = @{}

    foreach ($repo in $repos) {
        $path   = $repo.FullName
        $remote = git -C $path remote get-url origin 2>$null
        if (-not $remote) { continue }

        if (-not $remoteMap.ContainsKey($remote)) { $remoteMap[$remote] = @() }
        $remoteMap[$remote] += $path
    }

    foreach ($remote in $remoteMap.Keys) {
        if ($remoteMap[$remote].Count -gt 1) {
            $collisions += [PSCustomObject]@{
                Type  = 'Repo'
                Url   = $remote
                Paths = ($remoteMap[$remote] -join ', ')
            }
        }
    }
    if ($collisions.Count -eq 0) {
        Write-Host "  (no remote collisions detected)" -ForegroundColor DarkGray
        return
    }

    foreach ($c in $collisions) {
        Write-Host "⚠ Remote collision [$($c.Type)] — $($c.Url) ← $($c.Paths)" -ForegroundColor Yellow
        log "REMOTE-COLLISION" $root ($c | ConvertTo-Json -Depth 5)
    }

    return $collisions
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

        # PATCH v0.5.4: When -root targets a leaf repo, get-repoList returns $root
        # itself. Skip it — $root cannot be nested inside itself.
        if ((Resolve-Path $repo.FullName).Path -eq (Resolve-Path $root).Path) { continue }

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
    # PATCH v0.5.4: Check for empty window first; original silently printed nothing.
    $count = (git -C $path log --since=$lookback --oneline 2>$null | Measure-Object -Line).Lines
    if ($count -eq 0) {
        Write-Host "  (no commits in window: $lookback → now)" -ForegroundColor DarkGray
        return
    }

    git --no-pager -C $path log --graph --oneline --decorate --all --since=$lookback `
        --pretty=format:"%C(auto)%h %C(blue)%ad%C(reset) %C(yellow)%d%C(reset) %s" `
        --date=iso
}


#--------------------------------------------------------------------------
# Helper: Show-PendingChanges                                  [v0.5.2]
# Replaces the flat one-liner dump with a structured Format-Table view.
# -Grouped switch groups output by Action — useful for large dirty repos.
#--------------------------------------------------------------------------
function Show-PendingChanges {
    param(
        [string]$RepoPath,
        [switch]$Grouped          # Group output by Action type
    )

    $raw = & git -C $RepoPath status --porcelain 2>$null
    if (-not $raw) {
        Write-Host "  (clean — no pending changes)" -ForegroundColor DarkGray
        return
    }

    # Parse each porcelain 'XY filename' line into a structured object
    $entries = foreach ($line in $raw) {
        if ($line.Length -lt 3) { continue }

        $xy   = $line.Substring(0, 2)    # raw XY code e.g. ' M', 'D ', '??'
        $file = $line.Substring(3)        # everything after 'XY '

        $action = switch -Regex ($xy) {
            '^\?\?'        { 'Untracked' }
            '^!!'          { 'Ignored'   }
            '^[UA][UA]'    { 'Conflict'  }
            '^[Rr]'        { 'Renamed'   }
            '^[ ][Rr]'     { 'Renamed'   }
            '^[Cc]'        { 'Copied'    }
            '^[Aa]'        { 'Added'     }
            '^[Dd]'        { 'Deleted'   }
            '^[ ][Dd]'     { 'Deleted'   }
            '^[Mm]'        { 'Modified'  }
            '^[ ][Mm]'     { 'Modified'  }
            default        { $xy.Trim()  }
        }

        $scope = if ($action -eq 'Untracked') {
            '-'
        } elseif ($xy[0] -ne ' ') {
            'Staged'
        } else {
            'Unstaged'
        }

        [PSCustomObject]@{
            Code   = $xy
            Action = $action
            Scope  = $scope
            File   = $file
        }
    }

    # Summary counts
    $total     = @($entries).Count
    $modified  = @($entries | Where-Object Action -eq 'Modified').Count
    $deleted   = @($entries | Where-Object Action -eq 'Deleted').Count
    $untracked = @($entries | Where-Object Action -eq 'Untracked').Count
    $other     = $total - $modified - $deleted - $untracked

    Write-Host (
        "  Pending changes: $total total  " +
        "[M:$modified  D:$deleted  ?:$untracked" +
        $(if ($other -gt 0) { "  Other:$other" } else { '' }) + "]"
    ) -ForegroundColor Cyan

    if ($Grouped) {
        $entries | Sort-Object Action, File | Group-Object Action |
        ForEach-Object {
            Write-Host "`n  ── $($_.Name) ($($_.Count)) ──" -ForegroundColor DarkYellow
            $_.Group | Select-Object Code, Scope, File |
                Format-Table -AutoSize | Out-String | Write-Host
        }
    } else {
        $entries | Sort-Object Action, File |
            Select-Object Code, Action, Scope, File |
            Format-Table -AutoSize | Out-String | Write-Host
    }
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

        banner "Repo: $path"
        Write-Host "Branch: $branch"
        Show-PendingChanges -RepoPath $path -Grouped

        Write-Host "`nHistory since $lookback :"
        get-repoHistory $path
    }
    Write-TopologySnapshot
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Write-RiskReport - Risk analysis report ---                   #>
#------------------------------------------------------------------------------#>
# DESCRIPTION: Generates a risk analysis report for all repositories,          #>
#              including remote collisions.                                   #>
# NOTE:       Now a “two dirs → same remote” situation becomes a logged,      #>
#              machine-readable event instead of a surprise.                   #>
# PARAMETERS: None.                                                            #>
# RETURNS:    None.                                                            #>
#------------------------------------------------------------------------------#>
function Write-RiskReport {
    banner "Risk Analysis (Option-D: Smart Divergence + Forensic Mode)"

    # Check for remote collisions (submodules + nested repos sharing the same origin URL)
    $repos      = get-repoList
    $collisions = Get-RemoteCollisions

    # Detached HEAD + divergence + dirty status across all repos
    Analyze-AllRepoRisk
}


#------------------------------------------------------------------------------#>
# --- FUNCTION: Analyze-AllRepoRisk - Smart divergence + forensic mode        #>
#------------------------------------------------------------------------------#>
# DESCRIPTION: Performs a lightweight risk analysis across all repos:          #>
#              - Detached HEAD detection                                       #>
#              - Divergence vs good branch (main/master)                       #>
#              - Dirty working tree status                                     #>
#              - Role-aware classification (Root / Agile-Wizard / Standard)    #>
# RETURNS:    None. Prints summary and logs machine-readable entries.          #>
#------------------------------------------------------------------------------#>
function Analyze-AllRepoRisk {
    $repos = get-repoList

    foreach ($repo in $repos) {
        $path          = $repo.FullName
        $role          = Get-RepoRole -repoPath $path
        $goodBranch    = Get-GoodBranch -repoPath $path
        $currentBranch = git -C $path rev-parse --abbrev-ref HEAD 2>$null
        $headRef       = git -C $path rev-parse --abbrev-ref HEAD 2>$null
        $isDetached    = ($headRef -eq "HEAD")

        $statusShort   = git -C $path status --short 2>$null
        $isDirty       = [bool]$statusShort

        $divergence = $null
        try {
            $divergence = git -C $path rev-list --left-right --count "$goodBranch...HEAD" 2>$null
        } catch {
            $divergence = $null
        }

        $riskEntry = [ordered]@{
            Path          = $path
            Role          = $role
            CurrentBranch = $currentBranch
            GoodBranch    = $goodBranch
            DetachedHead  = $isDetached
            Dirty         = $isDirty
            Divergence    = $divergence
        }

        $riskJson = $riskEntry | ConvertTo-Json -Depth 5
        log "RISK" $path $riskJson

        Write-Host "`nRepo: $path" -ForegroundColor Cyan
        Write-Host "  Role          : $role"
        Write-Host "  CurrentBranch : $currentBranch"
        Write-Host "  GoodBranch    : $goodBranch"
        Write-Host "  DetachedHead  : $isDetached"
        Write-Host "  Dirty         : $isDirty"
        if ($divergence) {
            Write-Host "  Divergence    : $divergence"
        } else {
            Write-Host "  Divergence    : (not available)"
        }

        if ($isDetached) {
            Create-ArchivalBranchIfDetached -repoPath $path
        }
    }
}


#------------------------------------------------------------------------------#>
# --- FUNCTION: Write-TopologySnapshot - Capture repository topology snapshot  #>
#------------------------------------------------------------------------------#>
# DESCRIPTION: Captures the current topology of all repositories, including    #>
#              roles, branches, and remotes.                                   #>
# ABSTRACT:   Produces a single JSON artifact summarizing:                     #>
#              - Repo path                                                     #>
#              - Role (Root / Agile-Wizard / Standard)                         #>
#              - Current branch                                                #>
#              - Good branch (main/master)                                     #>
#              - Origin URL                                                    #>
# NOTE:       This function is automatically called at the end of              #>
#              write-repoStats, and can also be invoked via -topology.         #>
# RETURNS:    None. Writes topology JSON to repoMgr-logs.                      #>
#------------------------------------------------------------------------------#>
function Write-TopologySnapshot {
    banner "Topology Snapshot"

    $repos = get-repoList
    $snapshot = @()

    foreach ($repo in $repos) {
        $path   = $repo.FullName
        $role   = Get-RepoRole -repoPath $path
        $branch = git -C $path rev-parse --abbrev-ref HEAD 2>$null
        $good   = Get-GoodBranch -repoPath $path
        $origin = git -C $path remote get-url origin 2>$null

        $snapshot += [PSCustomObject]@{
            Path        = $path
            Role        = $role
            Branch      = $branch
            GoodBranch  = $good
            OriginUrl   = $origin
        }
    }

    # create artifact for an AI-Agent to perform the “unscramble the omelette” work.
    $json = $snapshot | ConvertTo-Json -Depth 5
    $topologyFile = Join-Path $logDir "topology-$timestamp.json"

    Set-Content -Path $topologyFile -Value $json
    Write-Host "Topology snapshot written to $topologyFile" -ForegroundColor Cyan
    log "TOPOLOGY" $root $topologyFile
}


#------------------------------------------------------------------------------#>
# --- FUNCTION: create-drBranches - DR branch creation ---                     #>
#------------------------------------------------------------------------------#>
# DESCRIPTION: Creates DR branches for all repositories, optionally only for   #>
#              dirty ones. In v0.6.0 this is now:                              #>
#              - Dry-run aware (no side effects when -dryrun is set).          #>
#              - Branch-safe: restores the original branch after DR creation.  #>
# PARAMETERS: None.                                                            #>
# RETURNS: None. Generates DR branches via Git commands.                       #>
#------------------------------------------------------------------------------#>
function create-drBranches {
    banner "Creating DR branches ($drBranch)"

    if (-not $Force) {
        Write-Host "⚠ DR branch creation requires -Force; running in DRYRUN-only mode." -ForegroundColor Yellow
        $dryrun = $true
    }

    $repos = get-repoList

    foreach ($repo in $repos) {
        $path   = $repo.FullName
        $status = git -C $path status --short

        if ($dirtyonly -and !$status) {
            Write-Host "Skipping clean repo: $path"
            continue
        }

        # PATCH v0.5.4: Guard against re-creating an existing DR branch.
        # git checkout -b hard-errors if branch already exists — makes -all non-idempotent.
        $branchExists = git -C $path branch --list $drBranch 2>$null
        if ($branchExists) {
            Write-Host "  ℹ DR branch '$drBranch' already exists in $path — skipping." -ForegroundColor DarkGray
            continue
        }

        # NEW v0.6.0: capture original branch so we can restore it.
        $originalBranch = git -C $path rev-parse --abbrev-ref HEAD 2>$null

        if ($dryrun) {
            Write-Host "[DRYRUN] Would create DR branch '$drBranch' in $path (from $originalBranch)"
            Write-Host "[DRYRUN] Would push '$drBranch' to origin and then switch back to '$originalBranch'"
            log "DR-BRANCH-DRYRUN" $path "Create '$drBranch' from '$originalBranch' and restore"
            continue
        }

        # Actual DR branch creation + push
        exec "git -C `"$path`" checkout -b $drBranch" $path
        exec "git -C `"$path`" push -u origin $drBranch" $path

        # Restore original branch pointer to avoid leaving the repo on DR.
        if ($originalBranch -and $originalBranch -ne $drBranch) {
            exec "git -C `"$path`" checkout $originalBranch" $path
        }
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
    param([string]$nestedPath = $root)    # PATCH v0.5.2: was "$root\.AI-TRAINING" — caused double-suffix

    banner "Reintegration Scaffold for $nestedPath"

    # PATCH v0.5.4: When -root IS the leaf repo, nestedPath equals $root.
    # Nothing to reintegrate — bail gracefully instead of building a phantom path.
    $resolvedNested = Resolve-Path $nestedPath -ErrorAction SilentlyContinue
    if ($resolvedNested -and $resolvedNested.Path -eq (Resolve-Path $root).Path) {
        Write-Host "  ℹ Skipping reintegration — target is the root repo itself." -ForegroundColor DarkGray
        return
    }

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
    Write-Host "-topology       : Capture the current topology of all repositories, including roles, branches, and remotes"
    Write-Host "-collisions     : Detect remote URL collisions (multiple dirs → same remote) among submodules and nested Git repositories"
    Write-Host "-dirtyonly      : Only branch repos with pending changes (for -recovery)"
    Write-Host "-reintegration  : Reintegration scaffold for nested repos"
    Write-Host "-risk           : Option-D (detached HEAD) risk analysis reporting across repos + smart divergence + forensic mode"
    Write-Host "-dryrun         : No changes, only simulate (logged as DRYRUN)"
    Write-Host "-all            : Run backup + stats + recovery + reintegration (not risk)"
}


#------------------------------------------------------------------------------#>
#  --- DISCOVERY DISPATCHER  - CONDITIONAL EXECUTION BASED ON OPTION FLAGS --- #>
#------------------------------------------------------------------------------#>

# Prevent redundant execution when the -all flag is set
if (-NOT $all) {
    if ($backup)        { archive-safecopy          } # (full backup + safe-copy) trigger 
    if ($stats)         { write-repoStats           } # drift detectionn trigger
    if ($topology)      { Write-TopologySnapshot    } # capture topology of all repos & submodules
    if ($risk)          { Write-RiskReport          } # Get-RemoteCollisions + Analyze-AllRepoRisk
}

#------------------------------------------------------------------------------#>
# ORTHOGONAL KNOBS - Variates which can be treated as statistically independent
#------------------------------------------------------------------------------#>

if (-NOT $risk -or -NOT $all) {
    if ($collisions)    { Get-RemoteCollisions      } # independent trigger 
} elseif ($risk)        { Write-RiskReport          } # never included in -ALL


#------------------------------------------------------------------------------#>
# RECOVER MODE: Only allow DR branch creation when -Force is passed
#------------------------------------------------------------------------------#>
if ($recovery) {
    if ($Force) {
        create-drBranches   # as of v0.5.x - includes DirtyRepo branching logic 
    } else {
        Write-Host "[DRYRUN] Skipping DR branch creation — requires -Force." -ForegroundColor DarkGray
        log "DRYRUN-SKIP" $root "Skipped DR branch creation (no -Force flag)"
    }
}

if ($reintegration) { reintegrate-nestedRepo    }


#------------------------------------------------------------------------------#>
# --- EXECUTE ALL TASKS IF THE -all FLAG IS SET ---                            #>
#------------------------------------------------------------------------------#>
# In v0.6.0, -all now defaults to DRYRUN mode unless -Force is explicitly set. #>
# This prevents accidental branch creation or destructive operations.          #>
#------------------------------------------------------------------------------#>
if ($all) {
    banner "Executing ALL Tasks  "

    # DEFAULT to DRYRUN unless -Force is explicitly set
    if (-not $Force) {
        Write-Host "⚠ SAFE MODE: Running in DRYRUN (no changes will be made)." -ForegroundColor Yellow
        $dryrun = $true
    } else { 
        Write-Host "⚠ FORCE MODE: Destructive operations are enabled." -ForegroundColor Red
        $dryrun = $false
    }

    # CREATE RECOVERY POINT
    archive-safecopy

    # DISCOVER/DIAGNOSE TASKS
    write-repoStats
    Write-TopologySnapshot
    Get-RemoteCollisions

    # DELIVER TASKS
    create-drBranches
    reintegrate-nestedRepo
    exit
}


#------------------------------------------------------------------------------#>
# --- DEFAULT FALLTHROUGH CASE: Show help if no valid flags are provided ---               #>
#------------------------------------------------------------------------------#>
if (-not ($backup -or $stats -or $recovery -or $reintegration -or $risk -or $dryrun -or $all -or $topology -or $collisions)) {
    show-help
}
