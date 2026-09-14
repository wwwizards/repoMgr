# ROADMAP.md
> **Generated: 260914** | **Source:** `repoMgr -stats` + `repoMgr -risk` output
> **Repos in scope:** `.AI-TRAINING`, `Agile-Wizard`
> ***Last updated:** 260914 BY: MAI-Code-1.1-Flash 
> — based on `repoMgr -stats` / `-risk` output provided by Joe.*

I’ve got the review scoped; I’m turning it into a concrete, prioritized refactor plan with the highest-value changes first and no code edits yet.

## Prioritized refactor plan for `repoMgr.ps1`

This is the version I’d recommend if the goal is to improve safety, maintainability, and testability without changing the external behavior too drastically.

### Priority 1 — Fix the script’s architecture boundary
This is the biggest improvement by far.

#### Problem
The script mixes:
- configuration resolution
- repo discovery
- Git execution
- reporting
- mutation
- console UI
- logging

in one shared global state model.

#### Recommendation
Split the script into four explicit phases:

1. Load config
2. Discover repos
3. Analyze repos
4. Execute mutation actions

A clean shape would look like:

- `Get-RepoManagerConfig`
- `Get-RepoInventory`
- `Get-RepoAnalysis`
- `Invoke-RepoMutation`

#### Why it matters
- Easier to test each phase independently
- Easier to reason about dry-run behavior
- Easier to audit side effects
- Less risk of accidental global pollution

---

### Priority 2 — Remove `Invoke-Expression`
This is the highest-risk reliability issue in the script.

#### Problem
The helper `exec` uses `Invoke-Expression` at `repoMgr.ps1:196-220`. This is brittle for quoting, escaping, and security.

#### Recommendation
Use command invocation patterns like:

- `& git ...` with argument arrays
- `Start-Process` for explicit command/arg usage
- or a small wrapper that builds the invocation safely

#### Why it matters
- Prevents shell tokenization bugs
- Reduces argument injection risk
- Makes dry-run logging deterministic

---

### Priority 3 — Make repo discovery a single-pass pipeline
#### Problem
The script repeatedly scans the repo tree in multiple functions, and repo metadata is recomputed on demand.

#### Recommendation
Create a single repo inventory object once per run, such as:

- repo path
- role
- branch
- good branch
- remote URL
- dirty state
- detached head state

Then pass this to analysis and mutation functions.

#### Why it matters
- Consistent results across the run
- Less redundant Git work
- Better performance on large monorepos

---

### Priority 4 — Separate reporting output from logic
#### Problem
Many functions both compute values and directly print to the console. That makes them hard to validate.

#### Recommendation
Adopt a pattern like:

- analysis function returns PSCustomObject
- display function renders it
- log function writes a JSON event

#### Example approach
- `Get-RepoRiskReport` returns objects
- `Write-RepoRiskReport` handles formatting
- `log` records the structured result

#### Why it matters
- Cleaner test assertions
- Easier AI-agent handoff
- Fewer side effects

---

### Priority 5 — Add explicit validation of CLI combinations
#### Problem
The script supports many option combinations, but mode semantics are implicit and easy to misuse.

#### Recommendation
Add upfront validation for:

- `-all` vs `-backup`
- `-recovery` vs `-Force`
- `-reintegration` with `-dryrun`
- `-collisions` and `-risk` overlap
- missing or invalid `-lookback`
- missing path and config values

#### Why it matters
- Fewer accidental destructive runs
- Clear UX
- Easier to inspect in CI

---

### Priority 6 — Make dry-run and mutation explicit per action
#### Problem
There is a single global `$dryrun` and a global `$Force`, but not every action is equally safe.

#### Recommendation
Define action-level policy:

- `Write-Report` = always allowed
- `archive-safecopy` = default safe
- `create-drBranches` = dry-run by default; require `-Force`
- `reintegrate-nestedRepo` = require explicit confirmation or `-Force`
- `Write-RiskReport` = reporting only

#### Why it matters
- Cleaner safety model
- Better audit trail
- Reduced chances of destructive behavior being mistaken for “safe”

---

### Priority 7 — Consolidate thresholds and rules into config
#### Problem
Risk scoring thresholds and repo-role logic are embedded in code.

#### Recommendation
Put them in config or settings, e.g.:

- risk score limits
- repo-role matchers
- lookback defaults
- DR branch naming template
- allowed role names

#### Why it matters
- More operational flexibility
- Easier tuning and experimentation
- Less code churn for business-rule changes

---

### Priority 8 — Improve error handling and no-output handling
#### Problem
Several Git calls depend on the absence of output being interpreted as a valid status.

#### Recommendation
Add structured handling for:
- repo not found
- no commits in lookback window
- branch not found
- detached HEAD with no upstream
- remote missing

Treat these as explicit states, not “just nothing happened.”

#### Why it matters
- Eliminates noisy false assumptions
- Better logs
- Easier debugging

---

### Priority 9 — Separate UI behavior from automation mode
#### Problem
Banner/spinner/cursor manipulation at `repoMgr.ps1:122-158` is quite interactive.

#### Recommendation
Wrap UI features behind an “interactive mode” gate, for example:

- interactive console output only when running in a human TTY
- structured output to console/log when not interactive

#### Why it matters
- Better adaptation for CI/automation
- Avoids odd terminal behavior
- Cleaner compatibility with VS Code terminals and automation jobs

---

### Priority 10 — Standardize output contract
#### Problem
The script produces a mix of:
- banner text
- structured JSON logs
- formatted tables
- warnings
- status lines

#### Recommendation
Define a consistent contract:

- Human-readable console output for interactive users
- JSON artifacts for machine-readable logs
- return objects for programmatic callers

#### Why it matters
- Easier downstream consumption
- Better for AI workflows and scripting

---

## Recommended order of implementation

If I were doing this in a disciplined refactor, I’d do it in this order:

1. Introduce config object and explicit function inputs
2. Replace `Invoke-Expression`
3. Cache repo discovery once
4. Split analysis from rendering
5. Add validation of flag combinations
6. Harden dry-run/Force semantics
7. Refactor logging into structured output
8. Add CI-oriented tests around the analysis pipeline
9. Tune UI behavior for noninteractive mode

---

## My “must-fix before v1” shortlist
If this were a production-facing script, I would mark these as the non-negotiables:

- remove `Invoke-Expression`
- centralize config and repo inventory
- separate analysis from side effects
- validate CLI combinations
- make dry-run and Force semantics explicit and consistent

These are the changes most likely to reduce real-world failure risk.

---

## Summary
The script is already strong in features, but the main weakness is architectural: it is too much “one big script with global state.” The next upgrade should focus on separating concerns and tightening operational safety, not adding more commands.

If you want, I can take the next step and draft a concrete refactor blueprint in pseudo-code for the main functions without editing the actual script.