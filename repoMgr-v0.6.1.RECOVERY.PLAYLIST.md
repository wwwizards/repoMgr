# RECOVERY‑PLAYLIST  
> **Generated: 2026-09-01** | **Source:** `repoMgr -stats` + `repoMgr -risk` output
> **Repos in scope:** `.AI-TRAINING`, `Agile-Wizard`
> ***Last updated:** 2026-09-05 by Win11-Copilot  
> — based on `REPORT-260901-00-LogicWizards.txt` "flight recorder" outputs previous run
### Attack Plan (v0.6.1)

This version assumes our current `repoMgr.ps1` (0.6.1) with all MODs in CHANGELOG.md.

> #### **Based Upon CHANGELOG** (tail excerpt)
> ##### **260903 - 0.6.0 -**  multiple improvements and new features added.
> * **(ADD)** - Added dry-run support for create-drBranches: prints planned actions without executing them.
> * **(BUG)** - fixed: now restores the pointer to the original branch after creating DR branch.
> * **(ADD)** - new functions for repository topology and risk analysis.
>      * **(NEW)** - FUNCTION: Get-RemoteCollisions - Detects remote URL collisions (multiple dirs → same remote) among > submodules and nested Git repositories.
>      * **(NEW)** - FUNCTION: Write-TopologySnapshot - Captures the current topology of all repositories, including roles, > branches, and remotes.
>      * **(NEW)** - FUNCTION: Write-RiskReport - Generates a risk analysis report for all repositories, including remote > collisions.
>      * **(NEW)** - MVx-FUNCTION: analyze-fileOverlap - Detects overlapping file changes between two branches by comparing the > last modification dates of each file.
> * **(ADD)** - dry-run support for create-drBranches and ensured original branch is restored after DR branch creation.
> * **(MOD)** - -all now includes -topology and -collisions as well.
> * **(MOD)** - DR branch creation now requires -Force to execute, otherwise it will be skipped in dry-run mode.
> * **(MOD)** - Updated help information to reflect new features and changes.
> * **(MOD)** - Improved error handling and logging for all operations.
> * **(MOD)** - General code cleanup and refactoring for better maintainability and improved UX.
> * **(MOD)** - Updated repository analysis functions to include additional metrics and improved reporting.
> * **(MOD)** - Enhanced logging for repository backup and recovery operations - improved visibility into success and failure > events
> * **(MOD)** - Improved handling of nested Git repositories and submodules for all operations - enhanced detection and > management of nested structures
> * **(MOD)** - Agent-friendly improvements for better integration with CI/CD pipelines & AI-assisted workflows.
> 
> ##### **260904 - 0.6.1 -**  minor UX improvements and tweaks.

---
## **REMEDIATION PLAN** (Sept 5th, 2026 @ 11AM)
### AKA: "Labor Day Marathon - The Final Stretch" 
  
We’ve built a seriously solid monorepo “flight recorder” here — there’s enough signal to get back on the rails without guessing.

> `-all now includes -topology and -collisions as well.`  
> `Agent-friendly improvements for better integration with CI/CD pipelines & AI-assisted workflows.`

assuming our (project specific) [Config File](repoMgr.config.psd1) is defined as
```
@{
#--------------------------------------------------------------------------#>
# FILE: repoMgr.config.psd1 - REPO MGR CONFIGURATION
#--------------------------------------------------------------------------#>
    root      = "C:\PROJECTS\LogicWizards\"
    safedest  = "C:\Users\User\OneDrive - Logic Wizards\Backups\RepoMgr-v6.1"
    lookback  = "45 days ago"
    drBranch  = "RepoMgr-DR-260905"
}

```

***From what we've already wired into the v0.6.x toolkit:***
- Our “critical path recovery playlist” can almost completely lean on the tools that we already have...
- Using a phased remediation plan - the critical path is now hermetic - as above / so below:

---

### **PHASE-1**. Baseline the current state (drift + topology)

Run these from the monorepo root:

> **Repo drift + topology:**
> ```
> .\repoMgr.ps1 -stats
> .\repoMgr.ps1 -topology
> ```
> - **What this gives you:**
>   - **Drift:** `Show-PendingChanges` grouped by `Action/Scope/File` per repo.  
>   - **Topology:** `topology-<timestamp>.json` with `Path/Role/Branch/GoodBranch/OriginUrl` for every repo.
>
> > **THEN:** We can use the topology JSON as the “truth table” for any AI agent or CI job that needs to understand which dirs are authoritative vs which are sub-modules & side-projects.

---

### **PHASE-2**. Identify structural hazards (collisions + nested repos)

- **Remote collisions only:**
  - `.\repoMgr.ps1 -collisions`
- **Full structural picture:**
  - `.\repoMgr.ps1 -topology -collisions`
- **Why this matters:**
  - `Get-RemoteCollisions` already turns “two dirs → same remote” into machine-readable events and logs them as `REMOTE-COLLISION`.  
  - Combined with `detect-nestedRepos`, this is your map of “where we can accidentally overwrite or double-push.”

Use this to decide which repos need immediate human intervention (e.g., consolidating remotes, clarifying which path is canonical).

---

### **PHASE-3**. Detached HEAD + divergence triage (Option‑D)

You’ve got two layers:

- **Lightweight sweep across all repos:**
  - `.\repoMgr.ps1 -risk`
  - This calls `Write-RiskReport` → `Analyze-AllRepoRisk`, logging per-repo `Role/CurrentBranch/GoodBranch/DetachedHead/Dirty/Divergence`.
- **Deep forensic on a single repo:**
  - `Analyze-RepoRisk -repoPath <path>`
  - Bounded by `merge-base` and `lookback`, with per-file `IsStale/IsDestructive/IsDivergent` and a role-sensitive risk score.

> `Risk level for ${repoPath}: HIGH/MEDIUM/LOW/NONE`  
> `Role-sensitive numeric score… Root vs Agile-Wizard vs Standard.`

Playlist-wise:

1. Run `-risk` from the monorepo root.
2. Sort the `RISK` log entries by:
   - `DetachedHead = true`
   - `Role = Root` or `Agile-Wizard`
   - Non‑null `Divergence`
3. For each high-risk repo, run `Analyze-RepoRisk` directly and stash the JSON as a case file.

---

### **PHASE-4**. Recovery points before mutation (SafeCopy + DR branches)

You already default to DRYRUN unless `-Force`:

> `In v0.6.0, -all now defaults to DRYRUN mode unless -Force is explicitly set.`

Suggested pattern:

- **Dry-run rehearsal:**
  - `.\repoMgr.ps1 -all -dryrun`
- **If the dry-run output looks sane:**
  - `.\repoMgr.ps1 -backup -stats -topology -collisions`
  - Only then consider:
    - `.\repoMgr.ps1 -recovery -dirtyonly -Force`
- **Guardrails you already have:**
  - DR branches skip if they already exist.
  - Original branch pointer is restored after DR branch creation.

This gives you a reproducible “pre-mutation snapshot” before any reintegration or filter‑repo surgery.

---

### **PHASE-5**. Reintegration & “unscramble the omelette” work

- **Scaffold only (no auto-destruction):**
  - `.\repoMgr.ps1 -reintegration`
  - `reintegrate-nestedRepo` prints manual steps: inspect ancestry, cherry-pick into DR, remove nested `.git`, re-add folder.
- **Use the topology JSON + collisions log:**
  - Decide which nested repos should be folded into the monorepo vs kept as submodules.
  - Feed those artifacts to an AI agent that:
    - Proposes cherry-pick sets.
    - Flags conflicting histories.
    - Generates human-readable reintegration plans per repo.

---

### PUTTING IT ALL TOGETHER: 
#### A concrete “playlist” you can run today

From `C:\PROJECTS\LogicWizards`:

1. **Dry-run everything:**

   ```pwsh
   .\repoMgr.ps1 -all
   ```

   (No `-Force` → DRYRUN only.)

2. **Capture focused artifacts:**

   ```pwsh
   .\repoMgr.ps1 -stats
   .\repoMgr.ps1 -topology
   .\repoMgr.ps1 -collisions
   .\repoMgr.ps1 -risk
   ```

3. **Per high‑risk repo (from `RISK` logs):**

   ```pwsh
   Analyze-RepoRisk -repoPath 'C:\PROJECTS\LogicWizards\.AI-TRAINING'
   Analyze-RepoRisk -repoPath 'C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\Agile-Wizard'
   ```

4. **Only after you’re comfortable with the JSON + logs:**

   ```pwsh
   .\repoMgr.ps1 -backup
   .\repoMgr.ps1 -recovery -dirtyonly -Force
   ```
5. **Consider what to DIY and what to delegate before actual reintegration**
   ```   
   .\repoMgr.ps1 -reintegration
   ```

If you want, we can take one of the `RISK` JSONs or that early report you mentioned and walk through a single repo end‑to‑end—detached HEAD, DR branch, and a concrete reintegration plan.

---
## APPENDIX - Final Analysis 
You’re not hallucinating the submodules—but you’re also not missing a gaping hole.

### Quick verdict

|                         Area | Coverage in 0.6.x                             | Real gap today?                |
|-----------------------------:|:----------------------------------------------|:-------------------------------|
|             **Nested repos** | `get-repoList` + `detect-nestedRepos`         | ✅  **Covered**                 |
|   **Submodules (structure)** | `.gitmodules` + `Get-RemoteCollisions`        | ⚠️ **Mostly covered**          |
| **Submodules (state/drift)** | Per‑repo stats via `get-repoList`             | ⚠️ **Light gap, not critical** |
|       **Detached HEAD risk** | `Analyze-AllRepoRisk` + `Analyze-RepoRisk`    | ✅  **Covered**                 |
|                **DR safety** | DRYRUN default, `-Force` gate, branch restore | ✅  **Covered**                 |


---

### ⚠️ Submodule analysis: what you already have

From the script:

- **Submodule URL collisions:**

  > “Detects remote URL collisions among submodules and nested Git repositories.”  
  > `Get-RemoteCollisions` reads `.gitmodules` and also walks nested repos, logging `REMOTE-COLLISION` with `Type/Url/Paths`.

- **Submodules as repos:**

  `get-repoList` walks the tree and treats any dir with `.git` as a repo—submodules included—so:

  - They show up in **drift** (`Show-PendingChanges`).
  - They show up in **topology** (`Write-TopologySnapshot`).
  - They’re included in **risk** (`Analyze-AllRepoRisk`).

So structurally and risk‑wise, submodules are already in scope.

---

### ⚠️ What’s *not* there yet (but can safely wait)

The only “submodule‑specific” things you don’t do yet:

- **Superproject ↔ submodule SHA drift:**

  You don’t currently:

  - Compare `git submodule status` vs committed SHA in the superproject.
  - Flag “superproject points at SHA X, working tree is SHA Y”.

- **Policy around DR branches in submodules:**

  You treat all repos equally; there’s no:

  - “Don’t create DR branches in vendor/third‑party submodules.”
  - “Only DR branch first‑party repos.”

These are *nice‑to‑have governance knobs*, not immediate safety issues—especially with DRYRUN default and `-Force` gating.

---

### Is your current playlist enough for “Labor Day Marathon”?

> ✅ **Yes** — for getting back on critical path without moving the goalposts:

- You already:
  - Baseline drift and topology.
  - Detect remote collisions (including submodules).
  - Sweep detached HEAD + divergence.
  - Create DR branches only under explicit `-Force`, with branch restore and idempotent guards.
  - Keep everything DRYRUN by default.

Given that, your deferrals are reasonable:

- **Static analyzer / AST / semantic audit / v0.6.2**  
  All of those are *hardening passes*, not “we might lose data tomorrow” fixes.

---

### If you want one tiny, non‑goalpost tweak later

When you’re ready for a v0.6.2:

- Add a `Get-SubmoduleStatus` helper that:

  - Runs `git submodule status` in the root.
  - Emits JSON with:
    - `Path`, `Url`, `RecordedSHA`, `WorkingSHA`, `IsDirty`.
  - Logs as `SUBMODULE-STATUS` alongside `TOPOLOGY` and `RISK`.

That would close the last “submodule‑specific” gap without changing your current recovery playlist at all.

For now: your plan is coherent, risk‑aware, and doesn’t need more knobs before you run it.