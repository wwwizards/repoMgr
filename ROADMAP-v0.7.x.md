# repoMgr Roadmap v0.7.x
> **Generated: 260915** | **Source:** repoMgr reporting + architecture review
> **Target script version:** v0.6.4.7
> **Targeted Repos For Cleanup:** LogicWizards-core: as identified by `REPORT-260914-all-backup-recovery.txt`
> ***Last updated:** 260918 BY: Copilot::repoMgr.WIZ-00.TOOLS
> — See [README.md](README.md), [CHANGELOG.md](CHANGELOG.md), [repoMgr.ps1](repoMgr.ps1), [repoMgr.sanity.Tests.ps1](repoMgr.sanity.Tests.ps1), [repoMgr.smoke.Tests.ps1](repoMgr.smoke.Tests.ps1), and [repoMgr.unit.Tests.ps1](repoMgr.unit.Tests.ps1) for current context.

---
## Validation-first gate (prerequisite before refactoring)

- [x] Refresh the `psst` test baseline to match the current repoMgr functionality.
- [x] Confirm the current CLI contract and defaults in [repoMgr.ps1](repoMgr.ps1).
- [x] Review the current behavior in [README.md](README.md) and [CHANGELOG.md](CHANGELOG.md) before changing architecture.
- [x] Lock the refactor scope to a validated baseline, not an inferred one.
- [x] Verify the forced-recovery fixture path for detached HEAD, orphaned files, and same-remote collisions against disposable temp repos only.

---
## Current initiative summary

The immediate workstream is validation-first refactoring:

1. Refresh the test coverage for the current repoMgr behavior.
2. Use that refreshed baseline to guide the architecture cleanup.
3. Prioritize safety, purity, and testability over feature expansion.
4. Treat the current script as the operational baseline while we isolate refactor work into a smaller, cleaner pipeline.
5. Preserve the active recovery/discovery and triage operations that are currently being used to stabilize a compromised repo environment.
6. Validate against disposable temp repos only; do not recurse the live monorepo during the test run.

### Recovery/discovery and triage impact
This project is being used as a live forensic and recovery-support tool, not only as a repo-management script. The refactor priorities therefore must keep all of the following behaviors stable while the larger recovery work continues:

- topology snapshots for collision and drift mapping
- remote-collision detection across nested repos and submodules
- detached-HEAD and divergence risk reporting
- DR branches as a safe checkpoint/recovery path
- dry-run-safe reporting, especially when the team is diagnosing a corrupted repo state
- structured JSON artifacts that support downstream triage, handoff analysis, and ETL-style recovery planning

### Verified baseline (260918)
The validation-first baseline is now confirmed on disposable temp repos only:

- 22 fixture-based tests pass, split across `psst sanity` (9), `psst unit` (9), and `psst smoke` (4).
- Tiered runtime is ~312s total (141s / 63s / 108s). A combined `psst repoMgr` run passes 22/22 in 582s, but per-test cost roughly doubles, so the tiered invocation is preferred and stays clear of the 600s terminal-bridge ceiling.
- The suite includes a forced-recovery scenario covering detached HEAD, orphaned files, and shared remote collisions.
- The recovery path verifies the script creates DR branches, creates an archival branch for detached HEAD, and then restores the repo to the good branch instead of leaving it on `HEAD`.
- Five flag-contract tests pin the CLI surface to `BACKLOG-v0.6.3.md-RepoMgr-OnePage.png`, which is the authoritative spec.

### Live baseline evidence (260914)
The most recent baseline run confirms the operational reality:
**SEE:** [REPORT-260914-all-backup-recovery.txt](REPORT-260914-all-backup-recovery.txt) 

- `repoMgr.ps1 -all -backup -recovery` was executed in DRYRUN mode.
- The root repo was active on `DEV` with 79 pending changes (3 staged, 76 untracked).
- The `.AI-TRAINING` repo was already on `RepoMgr-DR-260901` with 68 pending changes.
- The repo is generating repeated `repoMgr-logs` and `topology-*.json` artifacts as part of the ongoing discovery and recovery workflow.

> **APORIA:** This is not a generic cleanup task. It is the live recovery system which is currently in use for an ongoing recovery effort for LogicWizards-core repo.
>  
**The Goal** is to refactor for clarity and safety while preserving the current forensic and triage value already produced by the tool.

---
## Prioritized refactor plan for `repoMgr.ps1`

This plan assumes the current script remains the baseline while we refactor for safety, maintainability, and validation clarity.

### [x] Priority 1 — Fix the script’s architecture boundary
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

### [x] Priority 2 — Remove `Invoke-Expression`
This is the highest-risk reliability issue in the script.

#### Status
Shipped in v0.6.4.2. The Git execution path has a structured, argument-safe helper and the project includes a regression guard to ensure shell-string evaluation does not return.

> **CARRY-FORWARD (updated 260918, v0.6.4.6):** 16 hot-path call sites were migrated to `Invoke-GitSafe`, including the inventory builder, `Get-GoodBranch`, `get-repoHistory`, and `Show-PendingChanges`. **20 direct `git -C` call sites remain** in the recovery, reintegration, and detached-HEAD forensics paths. Important framing correction: these are *not* a security hole — PowerShell passes those arguments natively, so there is no shell-string evaluation. The remaining migration is a consistency and testability concern, and should be done opportunistically rather than as a big-bang change. The regression guard still only greps for the literal string `Invoke-Expression`.

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

### [x] Priority 3 — Make repo discovery a single-pass pipeline
#### Status
Shipped in v0.6.4.3. Repo discovery builds one inventory object per run and reuses it across the reporting and risk-analysis pipeline.

> **CLOSED (260918, v0.6.4.6):** the field-level duplication is resolved. `Get-RepoMetadata` returns branch/remote/role/dirty state from the inventory, and `Get-RepoRiskReport` / `Analyze-AllRepoRisk` now consume it instead of re-shelling. A duplicated `rev-parse` in `Analyze-AllRepoRisk` was also removed. **Measured result: suite runtime 965s -> 312s (3.1x), and the `-all` forensic test alone 140.07s -> 14.72s (9.5x)** — confirming redundant git process spawns were the dominant cost.
>
> **Still open:** identical tests cost roughly 2x more in a combined `psst repoMgr` session than in split tier runs. Fixture accumulation is the leading hypothesis; profile this before P5 adds combinatorial tests.

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

### [x] Priority 4 — Separate reporting output from logic
#### Status
Shipped in v0.6.4.4. `Get-RepoRiskReport` computes and `Write-RepoRiskReport` renders, with a regression pinning the data/render boundary. The spinner is quarantined: `Show-Spinner` runs its scriptblock in a separate runspace, which drops state, so analysis runs inline (see the note at ~L1128).

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
#### Status
This is the **next active milestone**. Partially pre-solved by v0.6.4.5, which defined the `-collisions` alone/combined contract and bound `-backupdest`/`-dr`. Open design questions are listed below and must be answered before coding.

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

#### Design decisions (ANSWERED 260918, REVISED 260919 — do not re-ask)

> **PROVENANCE (260919, from the author):** the `-all` suppression of `-backup` was **never a design decision**. It was a quick-and-dirty workaround for a *timing* problem — backing up and safecopying to the cloud could outlast the run window. It is not a technical conflict. The workaround was then canonized as spec when the one-page infographic was generated by feeding the source code to an LLM, and `show-help` was written to match the infographic, which cemented it. Treat it as removable debt, not a contract.

1. **Warn, do not throw** (revised from the 260918 `throw` decision). `-all -backup` emits a warning naming the exact remedy and continues. This keeps existing tests valid, since a warning does not fail a run. Reserve `throw` for genuinely contradictory pairs — `-Force -dryrun` is the real example, because both cannot be honored at once.
2. **Nonzero exit codes approved** for true validation failures, including updating the smoke assertion that currently expects `0`.
3. **No new `-recovery` guard.** Recovery is destructive, which is exactly why it only executes under `-Force`; dry-run-by-default already *is* the guard. The original pseudo-code was a no-op.
4. **`-lookback` validation deferred** as non-critical.
5. **Long-term:** once the runtime problem is fixed, `-all` and `-backup` should simply compose and the warning should be deleted. There is no reason a read-only deep dive and a file copy cannot both run.

#### Deferred candidate — asynchronous backup with progress polling

> **Origin:** proposed by the author on 260919 as *"production hardening done anytime before v1.x, or maybe a hybrid approach after we finish the mini viability experiment (MVx)."* Not scheduled. Recorded here so it is not re-discovered.

The root cause of the `-all` / `-backup` suppression is duration, not conflict. If the backup no longer blocks the run, the flags compose for free. The proposed shape: start the safecopy as a background job at the *beginning* of the run, poll it between reporting phases, and only surface a progress indicator if it is still running once the report is rendered.

```powershell
while ($true) {
    $last = Receive-Job -Keep -Job $backupJob | Select-Object -Last 1
    if ($backupJob.State -ne 'Running') { break }
    Write-Progress -Activity 'Background Task Running' -Status $last.Message -PercentComplete $percent
}
```

**HARD CONSTRAINT — do not design around a closure.** A background job runs in a *separate runspace* and does **not** inherit dot-sourced state. Any scriptblock that reads `$script:`/`$global:` config, helper functions, or the resolved inventory will fail or silently see `$null`. This codebase has already been bitten by exactly this (see the `Show-Spinner` note at `repoMgr.ps1` L1128). The job must therefore invoke a **self-contained script with explicit parameters** — full paths, destination, and lookback passed in as arguments — not a closure over run state.

Open questions to settle before scheduling:
- How does a still-running backup interact with the exit code contract from decision 2?
- Does `Write-Progress` degrade acceptably in noninteractive/automation mode? This overlaps **Priority 9**.
- Failure semantics: does a failed background backup fail the run, or warn?

#### Why it matters

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

> **PROMOTED (260919), then DEMOTED the same day by measurement.** This priority still owns the **audit-log O(n²) defect**: `log` re-reads, re-parses, and re-serializes the *entire* daily audit JSON on **every** entry, and `repoMgr-audit-<date>.json` is a per-root daily file, so the cost compounds within a run and across runs on the same day. The defect is **real in code**. It is **not** the top performance cost.
>
> **MVx evidence (260919, `REPORT-perf-MVx.json`, n=3 per level):** medians by pre-seeded entry count were 0 → 52.6s, 250 → 45.2s, 1000 → 30.8s, 2500 → 38.5s. Medians **do not climb with seed size**. Read this as *underpowered, not acquitted* — spread was 22–79%, so a few seconds of real log cost would hide inside the noise band. The correct conclusion is "not material at ≤2500 entries," and the fix is now a **correctness/tidiness** item rather than a performance item.
>
> Candidate fixes unchanged: buffer entries in memory and flush once (plus flush on error, to preserve forensic value), or switch to append-only NDJSON — noting NDJSON breaks the current JSON-array consumers and tests. Measure before and after.

> **THE ACTUAL TOP COST IS GIT SPAWN TIME.** Same MVx artifact: median total run 49.4s, of which **41.4s (~84%) was spent inside `git.exe`**. Building the throwaway fixture — one bare origin, one root repo, one nested repo, a handful of trivial files — took **78.0s** on its own. That ratio points at per-spawn process cost (plausibly on-access AV scanning of `.git`), not at any single hot function. This is consistent with v0.6.4.6's 3.1× win coming purely from *removing redundant spawns*.
>
> **Open, unmeasured:** the harness recorded `GitMs` but not `GitSpawns`, so per-spawn cost is not yet known. Next experiment must divide time by count before any optimization is chosen.

> **ROOT CAUSE FOUND (260919, spawn-cost probe, n=30 medians after warm-up):**
>
> | probe | median | isolates |
> |---|---|---|
> | `cmd /c exit` | 122.8 ms | bare process creation (control) |
> | `git --version` | 389.0 ms | git launch, zero repo I/O |
> | `git rev-parse --abbrev-ref HEAD` | 375.8 ms | git launch + `.git` read |
> | `git status --short` | 415.8 ms | git launch + worktree scan |
>
> `rev-parse` ≈ `--version`, so reading `.git` is **free**. `status` adds only ~27–40 ms, so git's real work is **~7% of a call**. The remaining **~93% is process-creation overhead**, and the `cmd` control proves it is not git-specific: a no-op process still costs 123 ms here, roughly 10× a healthy Windows box. Strongly consistent with on-access AV/Defender scanning every process launch (git.exe pays more than cmd.exe because it loads far more DLLs).
>
> **Derived spawn count:** 41.4s git time ÷ 0.389s per spawn ≈ **~106 git spawns per run**.
>
> **Environment check (260919):** Windows Defender is the **only** registered AV and **real-time protection is enabled**. Exclusion lists could not be read (requires admin). This is *consistent with* the 123 ms no-op process cost but does **not prove causation** — proving it would require toggling real-time protection, which is an elevated, security-reducing action and was deliberately not performed.
>
> **Consequences — there is no hot function to optimize:**
> 1. **In-code lever: reduce spawn *count*.** This is the only thing the script controls, and it is exactly why v0.6.4.6's inventory-first change delivered 3.1×. Combining reads (e.g. `git status --short --branch` for branch + dirty in one spawn) is worth ~389 ms each time it removes a call.
> 2. **Out-of-code lever, larger: AV exclusions.** An exclusion for the repo paths and/or `git.exe` is an **environment/security decision for the operator, not a code change** — it trades scan coverage for speed and must not be applied by tooling. If launch dropped to ~60 ms, ~106 spawns fall from ~41s to ~6s.
>
> **Do not** pursue PowerShell-side micro-optimization for performance. The measurement says it cannot pay.

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

1. [x] Refresh the `psst` test baseline for current functionality
2. [x] Introduce config object and explicit function inputs
3. [x] Replace `Invoke-Expression` *(helper shipped; 20 non-reporting call sites still unmigrated)*
4. [x] Cache repo discovery once per run *(closed in v0.6.4.6 — inventory-first metadata)*
5. [x] Split analysis from rendering
6. [ ] Add validation of flag combinations  ← **next**
7. [ ] Harden dry-run/Force semantics
8. [ ] Refactor logging into structured output
9. [ ] Tune UI behavior for noninteractive mode

---
## Must-fix-before-v1 shortlist

- [x] Remove `Invoke-Expression`
- [x] Centralize config and repo inventory
- [x] Separate analysis from side effects
- [ ] Validate CLI combinations
- [ ] Make dry-run and Force semantics explicit and consistent

---
## Summary

The current script is feature-rich and useful, but the main weakness is architectural: it is still too much of a global-state monolith. The next upgrade should focus on validation-first cleanup and separation of concerns, not on feature expansion.

The next step is not a big rewrite; it is a disciplined baseline refresh: update the test suite to the current functionality, then refactor the operational pipeline in smaller, verifiable increments.
