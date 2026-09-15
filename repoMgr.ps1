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
# UPDATED:  260915 BY: SOLOMON(MAI-Code-1.1-Flash)::Copilot::repoMgr.WIZ-00.TOOLS
# COMPANY:  LogicWizards.NYC <LogicWizards.NYC>
# VERSION:  v0.6.4.0
#           SEE: CHANGELOG.md for more details
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
#--------------------------------------------------------------------------#>

param(
    [string]$root,              # Override the root directory for repository operations
    [string]$safedest,          # Override the safe destination for backups
    [string]$lookback,          # Override the lookback period for repository analysis
    [string]$drBranch,          # Override the name of the disaster recovery branch
    [switch]$backup,            # Perform a backup of the repository
    [switch]$topology,          # Capture the current topology of all repositories
    [switch]$collisions,        # Run remote collision detection only
    [switch]$Force,             # Explicit override for destructive operations
    [switch]$stats,             # Display repository statistics
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




#-----------------------------------------------------------------------------#>
# FUNCTION: Get-EffectiveConfig - Determine config values for the repoMgr script
#-----------------------------------------------------------------------------#>
# Description:
#     Determines the effective configuration values for the repository manager script,
#     taking into account command-line overrides, configuration file values, and defaults.
# Parameters:
#     -Root      : The root directory for repository operations
#     -Safedest  : The safe destination for backups
#     -Lookback  : The lookback period for repository analysis
#     -DrBranch  : The name of the disaster recovery branch
#     -Config    : The hashtable containing configuration file values
# Returns:
#     A PSCustomObject containing the effective configuration values for the repository manager script.
#-----------------------------------------------------------------------------#>
function Get-EffectiveConfig {
    param(
        [string]$Root,
        [string]$Safedest,
        [string]$Lookback,
        [string]$DrBranch,
        [hashtable]$Config
    )

    $effectiveRoot = if ($Root) { $Root } elseif ($Config -and $Config.ContainsKey('root') -and $Config.root) { $Config.root } else { '.' }
    if ($effectiveRoot -match '^-root=(.+)$') {
        Write-Warning @"
`$root received a '-root=' prefix — this is a shell tokenizer bug.
  Got   : $effectiveRoot
  Fixed : $($Matches[1])
  Hint  : Use -root 'C:\path'  (space-separated), NOT -root='C:\path' (equals-sign form).
"@
        $effectiveRoot = $Matches[1]
    }
    $effectiveRoot = $effectiveRoot.TrimEnd('\').TrimEnd('/')

    $effectiveSafedest = if ($Safedest) { $Safedest } elseif ($Config -and $Config.ContainsKey('safedest') -and $Config.safedest) { $Config.safedest } else { '.' }
    $effectiveLookback = if ($Lookback) { $Lookback } elseif ($Config -and $Config.ContainsKey('lookback') -and $Config.lookback) { $Config.lookback } else { '2 weeks ago' }
    $effectiveDrBranch = if ($DrBranch) { $DrBranch } elseif ($Config -and $Config.ContainsKey('drBranch') -and $Config.drBranch) { $Config.drBranch } else { 'DR-YYMMDD' }

    return [pscustomobject]@{
        Root      = $effectiveRoot
        Safedest  = $effectiveSafedest.TrimEnd('\').TrimEnd('/')
        Lookback  = $effectiveLookback
        DrBranch  = $effectiveDrBranch
    }
}

$config = Get-EffectiveConfig -Root $root -Safedest $safedest -Lookback $lookback -DrBranch $drBranch -Config $cfg
$root = $config.Root
$safedest = $config.Safedest
$lookback = $config.Lookback
$drBranch = $config.DrBranch

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
if (-not $PSBoundParameters.ContainsKey('force')) {
    $dryrun = $true
}


#------------------------------------------------------------------------------#>
# --- FUNCTION: Write-Banner - Displays a banner message ---
#------------------------------------------------------------------------------#>
function Write-Banner($msg) {
    write-host "`n--------------------------------------------------------------------------------------------"
    Write-Host "  === $msg  ===" -ForegroundColor Cyan
    Write-Host "      Caller: [$(Get-Caller)]" -ForegroundColor DarkGray
    write-host "--------------------------------------------------------------------------------------------"
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Show-Spinner - Display animation while a script block runs ---
#------------------------------------------------------------------------------#>
function Show-Spinner($scriptBlock) {
    $cursorTop = [Console]::CursorTop
    
    try {
        [Console]::CursorVisible = $false
        
        $counter = 0
        $frames = '|', '/', '-', '\' 
        $jobName = Start-Job -ScriptBlock $scriptBlock
    
        while($jobName.JobStateInfo.State -eq "Running") {
            $frame = $frames[$counter % $frames.Length]
            
            Write-Host "$frame" -NoNewLine
            [Console]::SetCursorPosition(0, $cursorTop)
            
            $counter += 1
            Start-Sleep -Milliseconds 125
        }
        
        # Only needed if you use a multiline frames
        Write-Host ($frames[0] -replace '[^\s+]', ' ')
    }
    finally {
        [Console]::SetCursorPosition(0, $cursorTop)
        [Console]::CursorVisible = $true
    }
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
# --- FUNCTION: exec - Safe structured command wrapper ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Executes a command without string-evaluating shell input.
# PARAMETERS:
#     [string[]]$Command - Structured command arguments.
#     [string]$Path      - The path associated with the command.
# RETURNS: The output of the executed command (unless dryrun).
#------------------------------------------------------------------------------#>
function exec {
    param(
        [Parameter(Position = 0)]
        [object[]]$Command,
        [Parameter(Position = 1)]
        [string]$Path = ''
    )

    if (-not $Command -or $Command.Count -eq 0) {
        return
    }

    $commandList = @()
    foreach ($item in $Command) {
        if ($null -eq $item) { continue }
        $commandList += [string]$item
    }

    if ($commandList.Count -eq 0) {
        return
    }

    $commandText = (($commandList | ForEach-Object {
        $value = [string]$_
        if ($value.Contains(' ') -or $value.Contains('"')) {
            '"' + ($value -replace '"', '\"') + '"'
        }
        else {
            $value
        }
    }) -join ' ')

    if ($dryrun) {
        Write-Host "[DRYRUN] Would execute: $commandText"
        log "DRYRUN" $Path $commandText
        return
    }

    $exe = $commandList[0]
    $args = @()
    if ($commandList.Count -gt 1) {
        $args = @($commandList[1..($commandList.Count - 1)])
    }

    Write-Host $commandText
    $out = & $exe @args 2>&1
    $exitCode = $LASTEXITCODE
    log "EXEC" $Path $commandText

    if ($null -ne $exitCode -and $exitCode -ne 0) {
        Write-Warning "Command failed ($exitCode): $commandText"
    }

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
    Write-Banner "Creating full backup"

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
    param(
        [string]$branchA,
        [string]$branchB,
        [int]$numCommits = 5
    )
    $files = git diff "$branchA..$branchB" --name-only
    foreach ($f in $files) { 
        Write-Banner "Showing last $numCommits commits for $f"
        $logC = git log -n $numCommits --follow "$f"
        Write-Banner "Analyzing file overlap for $f between branches"
        $logA = git log -n 1 --pretty=format:"%ad" --date=iso $branchA -- $f
        $logB = git log -n 1 --pretty=format:"%ad" --date=iso $branchB -- $f
        [PSCustomObject]@{File=$f; Commits=$logC; BranchA_Date=$logA; BranchB_Date=$logB}
    }
}

#------------------------------------------------------------------------------#>
# --- FUNCTION: Get-Caller - Retrieve the calling function from the call stack ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Retrieves the name of the function that called the current function.
# RETURNS: "<No caller - invoked directly>" if called from the top level.
#------------------------------------------------------------------------------#>
function Get-Caller {
    try {
        # Get the call stack
        $stack = Get-PSCallStack

        # If there is more than one frame, index 1 is the caller
        if ($stack.Count -gt 2) {
            return $stack[2].Command
        }
        else {
            return $stack[1].Command
        }
    }
    catch {
        Write-Error "Failed to get caller: $_"
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
    $verbose=$false
    if ($VerbosePreference -eq 'Continue') {
        $verbose=$true
        Write-Banner "Scanning for Git repositories "
    }
    
    $repos = [System.Collections.Generic.List[object]]::new()

    # PATCH v0.5.2: Check $root itself first — handles case where -root targets
    # a single leaf repo (e.g. .AI-TRAINING). The old recurse-only approach
    # returned empty when the root IS the repo, not a parent of repos.
    if (Test-Path (Join-Path $root ".git")) {
        if ($verbose) { Write-Host "  ✓ $root  [root is a repo]" -ForegroundColor DarkGray }
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
# --- FUNCTION: Normalize-RemoteUrl - Normalize Git remote URLs (NEW: v0.6.2) ---
#------------------------------------------------------------------------------#>
# FLAW: URLs like git:User/Repo and git:User/Repo.git are logically the same, 
#       but the detector treated them as different, even though Git does NOT.
# DESCRIPTION: Normalizes Git remote URLs by stripping trailing .git and
#              converting host and path to lowercase.
# PARAMETERS: 
#   - Url: The Git remote URL to normalize.
# RETURNS: The normalized Git remote URL.
#------------------------------------------------------------------------------#>
function Normalize-RemoteUrl {
    param(
        [string]$Url
    )

    if (-not $Url) { return $null }

    $normalized = $Url.Trim()

    # strip trailing .git
    if ($normalized.EndsWith('.git')) {
        $normalized = $normalized.Substring(0, $normalized.Length - 4)
    }

    # normalization candidates for host+path variants
    try {
        # URI-style: http(s)://<host>/<path>
        $uri = [Uri]$normalized
        $remotehost = $uri.Host.ToLowerInvariant()
        $path = $uri.AbsolutePath.TrimEnd('/').ToLowerInvariant()
        return "$($uri.Scheme)://$remotehost$path"
    } catch {
        # SSH-style: git@github.com:User/Repo
        if ($normalized -match 'ssh://git@([^/]+)/(.+)' -or $normalized -match 'git@([^:]+):(.+)') {
            $remotehost = $matches[1].ToLowerInvariant()
            $path = '/' + $matches[2].TrimEnd('/').ToLowerInvariant()
            return "ssh://$remotehost$path"
        }


        # fallback: lowercase everything
        return $normalized.ToLowerInvariant()
    }

}


#------------------------------------------------------------------------------#>
# --- FUNCTION: Get-RemoteCollisions - Detect remote collisions in Git repos ---
#------------------------------------------------------------------------------#>
# DESCRIPTION: Detects remote URL collisions among submodules and nested Git repositories.
# PARAMETERS: None.
# RETURNS: A list of collision objects with Type, Url, and Paths properties.
#------------------------------------------------------------------------------#>
function Get-RemoteCollisions {
    Write-Banner "Detecting Remote Collisions"

    $collisions = @()
#    Invoke-Spinner {
        # 1) Submodules via .gitmodules
        $gitmodulesPath = Join-Path $root ".gitmodules"
        if (Test-Path $gitmodulesPath) {
            $entries = git -C $root config --file .gitmodules --get-regexp 'submodule\..*\.url' 2>$null
            $map = @{}

            foreach ($line in $entries) {
                $parts = $line -split '\s+', 2
                if ($parts.Count -ne 2) { continue }

                $key = $parts[0]   # submodule.<name>.url
                $url = Normalize-RemoteUrl $parts[1] # normalized via v0.6.2 patch
    
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
            #$remote = git -C $path remote get-url origin 2>$null
            # QUICK-PATCH v0.6.2 # still uses $remote as our collision-key but run it through Normalize-RemoteUrl
            $rawRemote = git -C $path remote get-url origin 2>$null
            if (-not $rawRemote) { continue }
            $remote = Normalize-RemoteUrl $rawRemote 
            if (-not $remote) { continue }
            if (-not $remoteMap.ContainsKey($remote)) { $remoteMap[$remote] = @() }
            $remoteMap[$remote] += $path
            # PATCH-END
        }
#    }

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
        Write-Host -NoNewline " ⚠ Remote Collision ⚠ " -ForegroundColor DarkRed -backgroundColor Yellow
        Write-Host -NoNewline " [$($c.Type)]" -ForegroundColor yellow 
        Write-host -NoNewline " — $($c.Url) " -ForegroundColor Blue
        Write-host -NoNewline " ← $($c.Paths)" -ForegroundColor Yellow
        Write-Host ""
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
    Write-Banner "Detecting Nested Repos"
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
    Write-Banner "Repo Drift Report"
    $repos = get-repoList

    foreach ($repo in $repos) {
        $path   = $repo.FullName
        $branch = git -C $path rev-parse --abbrev-ref HEAD 2>$null

        Write-Banner "Repo: $path"
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
    Write-Banner "Risk Analysis (Opt-D: Smart Divergence + Forensic Mode)"
    if (-not $Force) {
        Write-Host "  (DRYRUN: No Mutations Will Occur)" -ForegroundColor DarkGray
    }

    # Check for remote collisions (submodules + nested repos sharing the same origin URL)
    $repos      = get-repoList
    $collisions = Get-RemoteCollisions

    # Detached HEAD + divergence + dirty status across all repos
    Analyze-AllRepoRisk -collisions $collisions
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
    param($collisions)
    $repos = get-repoList

    foreach ($repo in $repos) {
        # compute the easy stuff first
        $path          = $repo.FullName
        $remote        = Normalize-RemoteUrl (git -C $path remote get-url origin 2>$null)
        $role          = Get-RepoRole -repoPath $path
        $goodBranch    = Get-GoodBranch -repoPath $path
        $currentBranch = git -C $path rev-parse --abbrev-ref HEAD 2>$null
        $headRef       = git -C $path rev-parse --abbrev-ref HEAD 2>$null
        $isDetached    = ($headRef -eq "HEAD")
        $statusShort   = git -C $path status --short 2>$null
        $isDirty       = [bool]$statusShort
        
        # now we need to compute the divergence entry safely before building the PSCustomObject
        # AND safely compute the divergence before building the risk entry
        # - divergence calculation = (how far the current branch is from the good branch)
        # - if the HEAD is detached, compare against HEAD directly
        # - otherwise, compare the current branch against the last-known "good" branch   
        $divergence = $null
        try {
            # $divergence = git -C $path rev-list --left-right --count "$goodBranch...HEAD" 2>$null # it always bugs me when "$Good...HEAD" <-- just kinda sucks ;-}
            $compareRef = if ($isDetached) { "HEAD" } else { $currentBranch } ## FIX via v0.6.2 patch - when your HEAD is somewhere it shouldn't be
            $divergence = git -C $path rev-list --left-right --count "$goodBranch...$compareRef" 2>$null ## END-PATCH
        } catch {
            $divergence = $null
        }

        # compute collision entry safely before building the PSCustomObject
        $collision = $null
        if ($collisions) {
            # split the stored Paths string into an array and test for exact path equality
            $collision = $collisions |
                Where-Object { ($_.Paths -split ',\s*') -contains $path }
        }

        # create the risk entry PSCustomObject hashtable to be converted to json
        $riskEntry = [ordered]@{
            Path          = $path
            Remote        = $remote
            Collision     = $collision
            Role          = $role
            CurrentBranch = $currentBranch
            GoodBranch    = $goodBranch
            DetachedHead  = $isDetached
            Dirty         = $isDirty
            Divergence    = $divergence
        }


        $riskJson = $riskEntry | ConvertTo-Json -Depth 5
        log "RISK" $path $riskJson

        Write-Host "`n $($PSStyle.bold)-- Repo: $path $($PSStyle.BoldOff)" -ForegroundColor DarkBlue -BackgroundColor White -NoNewline; Write-Host ""
        Write-Host "    Role          : $role"
        Write-Host "    CurrentBranch : " -NoNewline 
        if ($currentBranch.ToLower() -eq "main") {
            Write-Host $currentBranch -ForegroundColor DarkGreen 
        } else {
            Write-Host $currentBranch -ForegroundColor DarkYellow
        }
        Write-Host "    GoodBranch    : $goodBranch"
        Write-Host "    DetachedHead  : " -NoNewline 
          if ($isDetached) { Write-Host "Yes" -ForegroundColor Red } 
            else { Write-Host "No" -ForegroundColor DarkGreen }
        Write-Host "    Dirty         : " -NoNewline
          if ($isDirty) { Write-Host "Yes" -ForegroundColor Red } 
            else { Write-Host "No" -ForegroundColor DarkGreen }

        if ($divergence) { Write-Host "    Divergence    : $divergence"} 
            else { Write-Host "    Divergence    : (not available)" }
        if ($riskEntry.Collision) {
            Write-Host "    Collision     : $($riskEntry.Collision.Url)" -ForegroundColor Red
        }

        if ($isDetached) {
            if (-not $Force) { return }
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
    Write-Banner "Topology Snapshot"

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
    Write-Banner "Creating DR branches ($drBranch)"

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
        $restoreBranch = if ($originalBranch -and $originalBranch -ne 'HEAD') {
            $originalBranch
        } else {
            Get-GoodBranch -repoPath $path
        }

        if ($dryrun) {
            Write-Host "[DRYRUN] Would create DR branch '$drBranch' in $path (from $restoreBranch)"
            Write-Host "[DRYRUN] Would push '$drBranch' to origin and then switch back to '$restoreBranch'"
            log "DR-BRANCH-DRYRUN" $path "Create '$drBranch' from '$restoreBranch' and restore"
            continue
        }

        # Actual DR branch creation + push
        exec -Command @('git', '-C', $path, 'checkout', '-b', $drBranch) -Path $path
        exec -Command @('git', '-C', $path, 'push', '-u', 'origin', $drBranch) -Path $path

        # Restore the repo to the original branch when possible. Detached HEADs
        # should return to the repo's good branch (usually main/master), not to HEAD.
        if ($restoreBranch -and $restoreBranch -ne $drBranch) {
            exec -Command @('git', '-C', $path, 'checkout', $restoreBranch) -Path $path
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

    Write-Banner "Reintegration Scaffold for $nestedPath"

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

        if ($dryrun) {
            Write-Host "DRYRUN: would create archival branch for detached HEAD"
            $exists = git -C $repoPath rev-parse --verify "refs/heads/$archival" 2>$null
            if ($exists) {
                Write-Host "  Archival branch already exists: $archival" -ForegroundColor DarkGray
                return
            }
            return
        }

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

    Write-Banner "Risk Analysis for $repoPath"

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
            #TODO: we should dynamically determine risk based on detatched HEAD, histories & collision detection
            # We are hard coding dirs here. WHY? This may not adapt well to changes in repository structure nor 
            # future use-cases & expansion as a generic tool. Current thresholds are also static and may not 
            # accurately reflect the actual risk.
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
    Write-Banner "repoMgr.ps1 — Flags"
    Write-Host "-all            : Deep-Dive Risk Analysis across ALL Repos & Branches - Forensic Mode"
    Write-Host "-backup         : Full backup + safe-copy according to Config-File settings"
    Write-Host "-backupdest     : Override config-file's backup destination (used with -backup)"
    Write-Host "-collisions     : Detect remote URL collisions (multiple dirs → same remote) among submodules and nested Git repositories"
    Write-Host "-dirtyonly      : Only branch repos with pending changes (for -recovery)"
    Write-Host "-drBranch       : Override config-file's DR branch-prefix (used with -recovery)"
    Write-Host "-dryrun         : (DEFAULT) No changes, only simulate (logged as DRYRUN)"
    Write-Host "-force          : Enable destructive operations (overrides -dryrun)"
    Write-Host "-lookback       : Override config-file's lookback period for analysis (e.g., 7d, 1m)"
    Write-Host "-recovery       : Create DR branches (legacy alias: -dr)"
    Write-Host "-reintegration  : Provides a scaffold for reintegrating a nested repository into your monorepo"
    Write-Host "-risk           : (DEFAULT) Option-D (detached HEAD) risk analysis reporting across repos + smart divergence + forensic mode"
    Write-Host "-stats          : (DEFAULT) Repo drift report"
    Write-Host "-topology       : (DEFAULT) Capture the current topology of all repositories, including roles, branches, and remotes"
}


#------------------------------------------------------------------------------#>
#  --- DISCOVERY DISPATCHER  -  ALWAYS EXECUTED REGARDLESS OF OPTION FLAGS --- #>
#------------------------------------------------------------------------------#>
if ($help) { show-help; exit }
Write-Banner "Executing BASE REPORTING Tasks  "
#------------------------------------------------------------------------------#>
# In v0.6+ EVERYTHING defaults to DRYRUN mode unless -Force is explicitly set. #>
# This prevents accidental branch creation or destructive operations.          #>
#------------------------------------------------------------------------------#>
if (-not $Force) {
    Write-Host "⚠ SAFE MODE: Running in DRYRUN (no changes will be made)." -ForegroundColor Yellow
    $dryrun = $true
} else { 
    Write-Host "⚠ FORCE MODE: Destructive operations are enabled." -ForegroundColor Red
    $dryrun = $false
}

# DISCOVER/DIAGNOSE TASKS 
write-repoStats         # Drift Detection
Write-TopologySnapshot  # Capture topology of all repos & submodules for handoff to AI-Agents 
Write-RiskReport        # Analyze risk across all repositories (>6.2+ NOW includes collision detection)

# ORTHOGONAL KNOBS - Variates which can be treated as statistically independent
if (($backup -or $backupdest) -and -not $all)    { archive-safecopy    } # (full backup + safe-copy) trigger 
if ($all)               { Analyze-ALLRepoRisk       }   # Deep-Dive Risk Analysis across ALL Repos & Branches - Forensic Mode
# REPAIR MODE: Default = DRYRUN unless -Force is passed (USE CAUTION: WHEN RISK IS HIGH OR COLLISIONS ARE POSSIBLE)
if ($recovery)          { create-drBranches         }   # as of v0.5.x - includes DirtyRepo branching logic 
if ($reintegration )    { reintegrate-nestedRepo    }   # Provides a scaffold for reintegrating a nested repository into the monorepo.

#-----------------------------------------------------------------------------------#>
# (CopyLeft:AGPL-v3) 2015-2026 LogicWizards <LogicWizards.NYC> - ALL Rights Reserved.
#-----------------------------------------------------------------------------------#>
