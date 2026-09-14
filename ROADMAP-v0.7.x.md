# repoMgr Roadmap v0.7.x
> **Generated: 260914** | **Source:** repoMgr reporting + architecture review
> **Target script version:** 0.6.4.x (next refactor baseline)
> **Targeted Repos For Cleanup:** LogicWizards-core: as identified by `REPORT-260914-all-backup-recovery.txt`
> ***Last updated:** 260914 BY: MAI-Code-1.1-Flash
> — See [README.md](README.md), [CHANGELOG.md](CHANGELOG.md), [repoMgr.ps1](repoMgr.ps1), [repoMgr.sanity.Tests.ps1](repoMgr.sanity.Tests.ps1), [repoMgr.smoke.Tests.ps1](repoMgr.smoke.Tests.ps1), and [repoMgr.unit.Tests.ps1](repoMgr.unit.Tests.ps1) for current context.

---
## Validation-first gate (prerequisite before refactoring)

- [ ] Refresh the `psst` test baseline to match the current repoMgr functionality.
- [ ] Confirm the current CLI contract and defaults in [repoMgr.ps1](repoMgr.ps1).
- [ ] Review the current behavior in [README.md](README.md) and [CHANGELOG.md](CHANGELOG.md) before changing architecture.
- [ ] Lock the refactor scope to a validated baseline, not an inferred one.

---
## Current initiative summary

The immediate workstream is validation-first refactoring:

1. Refresh the test coverage for the current repoMgr behavior.
2. Use that refreshed baseline to guide the architecture cleanup.
3. Prioritize safety, purity, and testability over feature expansion.
4. Treat the current script as the operational baseline while we isolate refactor work into a smaller, cleaner pipeline.
5. Preserve the active recovery/discovery and triage operations that are currently being used to stabilize a compromised repo environment.

### Recovery/discovery and triage impact
This project is being used as a live forensic and recovery-support tool, not only as a repo-management script. The refactor priorities therefore must keep all of the following behaviors stable while the larger recovery work continues:

- topology snapshots for collision and drift mapping
- remote-collision detection across nested repos and submodules
- detached-HEAD and divergence risk reporting
- DR branches as a safe checkpoint/recovery path
- dry-run-safe reporting, especially when the team is diagnosing a corrupted repo state
- structured JSON artifacts that support downstream triage, handoff analysis, and ETL-style recovery planning

### Live baseline evidence (260914)
The most recent baseline run confirms the operational reality:

- `repoMgr.ps1 -all -backup -recovery` was executed in DRYRUN mode.
- The root repo was active on `DEV` with 79 pending changes (3 staged, 76 untracked).
- The `.AI-TRAINING` repo was already on `RepoMgr-DR-260901` with 68 pending changes.
- The repo is generating repeated `repoMgr-logs` and `topology-*.json` artifacts as part of the ongoing discovery and recovery workflow.

This is not a generic cleanup task. It is the live recovery system in use. The goal is to refactor for clarity and safety while preserving the current forensic and triage value already produced by the tool.

---
## Prioritized refactor plan for `repoMgr.ps1`

This plan assumes the current script remains the baseline while we refactor for safety, maintainability, and validation clarity.

### [ ] Priority 1 — Fix the script’s architecture boundary
This is the biggest improvement by far.

#### Problem
The script mixes configuration loading, repo discovery, Git execution, reporting, mutation, console UI, and logging in one shared global-state model.

#### Recommendation
Split the script into explicit phases:

1. Load config
2. Discover repos
3. Analyze repos
4. Execute mutation actions

Pseudo-code example:

```powershell
function Get-RepoManagerConfig {
    param([string]$Root, [hashtable]$Overrides)

    $cfg = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'repoMgr.config.psd1')
    return [pscustomobject]@{
        Root     = if ($Overrides.Root) { $Overrides.Root } else { $cfg.root }
        Safedest = if ($Overrides.Safedest) { $Overrides.Safedest } else { $cfg.safedest }
        Lookback = if ($Overrides.Lookback) { $Overrides.Lookback } else { $cfg.lookback }
        DrBranch = if ($Overrides.DrBranch) { $Overrides.DrBranch } else { $cfg.drBranch }
        DryRun   = (-not $Overrides.Force)
        Force    = [bool]$Overrides.Force
    }
}
```

#### Why it matters
- Easier to test each phase independently
- Easier to reason about dry-run behavior
- Easier to audit side effects
- Less risk of accidental global pollution

---

### [ ] Priority 2 — Remove `Invoke-Expression`
This is the highest-risk reliability issue in the script.

#### Problem
The helper `exec` relies on `Invoke-Expression`, which is brittle for quoting, escaping, and shell-tokenization edge cases.

#### Recommendation
Use argument-safe command invocation.

Pseudo-code example:

```powershell
function Invoke-GitSafe {
    param(
        [string]$RepoPath,
        [string[]]$GitArgs
    )

    $cmd = @('git') + $GitArgs
    $output = & $cmd[0] @($cmd[1..($cmd.Count - 1)]) 2>$null
    return $output
}

# example:
$raw = Invoke-GitSafe -RepoPath $repoPath -GitArgs @('-C', $repoPath, 'status', '--porcelain')
```

#### Why it matters
- Prevents shell tokenization bugs
- Reduces argument injection risk
- Makes dry-run logging deterministic

---

### [ ] Priority 3 — Make repo discovery a single-pass pipeline
#### Problem
The script repeatedly scans the repo tree in multiple functions, and repo metadata is recomputed on demand.

#### Recommendation
Create a single repo inventory object once per run and pass it through the pipeline.

Pseudo-code example:

```powershell
function Get-RepoInventory {
    param([pscustomobject]$Config)

    $repos = get-repoList
    return $repos | ForEach-Object {
        [pscustomobject]@{
            Path       = $_.FullName
            Role       = Get-RepoRole -repoPath $_.FullName
            GoodBranch = Get-GoodBranch -repoPath $_.FullName
            Current    = git -C $_.FullName branch --show-current
        }
    }
}
```

#### Why it matters
- Consistent results across the run
- Less redundant Git work
- Better performance on large monorepos

---

### [ ] Priority 4 — Separate reporting output from logic
#### Problem
Many functions both compute values and directly print to the console.

#### Recommendation
Use a pattern where analysis returns objects and the formatter renders them.

Pseudo-code example:

```powershell
function Get-RepoRiskReport {
    param([pscustomobject[]]$Repos)

    foreach ($repo in $Repos) {
        [pscustomobject]@{
            Path        = $repo.Path
            Risk        = 'LOW'
            Detached    = $true
            Divergent  = $false
            Dirty       = $true
        }
    }
}

function Write-RepoRiskReport {
    param([pscustomobject[]]$Report)
    $Report | Format-Table -AutoSize
}
```

#### Why it matters
- Cleaner test assertions
- Easier AI-agent handoff
- Fewer side effects

---

### [ ] Priority 5 — Add explicit validation of CLI combinations
#### Problem
The script supports many option combinations, but the mode semantics are implicit and easy to misuse.

#### Recommendation
Add upfront validation for combinations such as:

- `-all` vs `-backup`
- `-recovery` vs `-Force`
- `-reintegration` with `-dryrun`
- `-collisions` and `-risk` overlap
- missing or invalid `-lookback`
- missing path and config values

Pseudo-code example:

```powershell
if ($all -and $backup) {
    Write-Warning 'Ignoring -backup because -all already includes the reporting flow.'
}

if ($recovery -and -not $Force -and -not $dryrun) {
    throw 'Recovery operations require -Force or dry-run-safe semantics.'
}
```

#### Why it matters
- Fewer accidental destructive runs
- Clear UX
- Easier to inspect in CI

---

### [ ] Priority 6 — Make dry-run and mutation explicit per action
#### Problem
There is a single global `$dryrun` and `$Force`, but not every action is equally safe.

#### Recommendation
Define action-level policy.

Example policy map:

- [ ] `Write-Report` = always allowed
- [ ] `archive-safecopy` = default safe
- [ ] `create-drBranches` = dry-run by default; require `-Force`
- [ ] `reintegrate-nestedRepo` = require explicit confirmation or `-Force`
- [ ] `Write-RiskReport` = reporting only

#### Why it matters
- Cleaner safety model
- Better audit trail
- Reduced chance of destructive behavior being mistaken for safe

---

### [ ] Priority 7 — Consolidate thresholds and rules into config
#### Problem
Risk scoring thresholds and repo-role logic are embedded in code.

#### Recommendation
Move operational thresholds into a config or settings object.

Pseudo-code example:

```powershell
$Rules = [pscustomobject]@{
    RiskHighThreshold       = 60
    RiskMediumThreshold     = 25
    LookbackDefault         = '30 days ago'
    DrBranchTemplate        = 'RepoMgr-DR-{0}'
    RoleMatchers            = @('Agile[-_ ]?Wizard', 'Root')
}
```

#### Why it matters
- More operational flexibility
- Easier tuning and experimentation
- Less code churn for business-rule changes

---

### [ ] Priority 8 — Improve error handling and no-output handling
#### Problem
Several Git calls treat the absence of output as a valid status instead of an explicit state.

#### Recommendation
Normalize explicit states like "no repo", "no commits", and "branch missing".

Pseudo-code example:

```powershell
if (-not (Test-Path (Join-Path $RepoPath '.git'))) {
    return [pscustomobject]@{ State = 'NotAGitRepo'; Path = $RepoPath }
}

$history = git -C $RepoPath log --since=$Config.Lookback --oneline 2>$null
if (-not $history) {
    return [pscustomobject]@{ State = 'NoCommitsInWindow'; Path = $RepoPath }
}
```

#### Why it matters
- Eliminates noisy false assumptions
- Better logs
- Easier debugging

---

### [ ] Priority 9 — Separate UI behavior from automation mode
#### Problem
Banner/spinner/cursor manipulation is interactive and may be fragile in automation contexts.

#### Recommendation
Wrap UI helpers behind a mode gate.

Pseudo-code example:

```powershell
if ($InteractiveMode) {
    Write-Banner 'Executing BASE REPORTING Tasks'
} else {
    Write-Host 'BASE REPORTING Tasks'
}
```

#### Why it matters
- Better adaptation for CI/automation
- Avoids odd terminal behavior
- Cleaner compatibility with VS Code terminals and automation jobs

---

### [ ] Priority 10 — Standardize output contract
#### Problem
The script produces a mix of banner text, JSON logs, formatted tables, warnings, and status lines.

#### Recommendation
Define a consistent output contract.

Pseudo-code example:

```powershell
$output = [pscustomobject]@{
    RunId     = (Get-Date).ToString('yyyyMMdd-HHmmss')
    Mode      = if ($Force) { 'EXEC' } else { 'DRYRUN' }
    Repos     = $RepoInventory.Count
    Summary   = 'Validated baseline pending refactor'
}

$output | ConvertTo-Json -Depth 5
```

#### Why it matters
- Easier downstream consumption
- Better for AI workflows and scripting
- Clear separation between interactive and machine-readable output

---
## Recommended order of implementation

1. [ ] Refresh the `psst` test baseline for current functionality
2. [ ] Introduce config object and explicit function inputs
3. [ ] Replace `Invoke-Expression`
4. [ ] Cache repo discovery once per run
5. [ ] Split analysis from rendering
6. [ ] Add validation of flag combinations
7. [ ] Harden dry-run/Force semantics
8. [ ] Refactor logging into structured output
9. [ ] Tune UI behavior for noninteractive mode

---
## Must-fix-before-v1 shortlist

- [ ] Remove `Invoke-Expression`
- [ ] Centralize config and repo inventory
- [ ] Separate analysis from side effects
- [ ] Validate CLI combinations
- [ ] Make dry-run and Force semantics explicit and consistent

---
## Summary

The current script is feature-rich and useful, but the main weakness is architectural: it is still too much of a global-state monolith. The next upgrade should focus on validation-first cleanup and separation of concerns, not on feature expansion.

The next step is not a big rewrite; it is a disciplined baseline refresh: update the test suite to the current functionality, then refactor the operational pipeline in smaller, verifiable increments.
