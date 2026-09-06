
# BACKLOG.md
> **Generated: 2026-09-05** | **Source:** `repoMgr -stats` + `repoMgr -risk` output
> **Repos in scope:** `.AI-TRAINING`, `Agile-Wizard`
> ***Last updated:** 2026-09-061 by Joe Negron 
> — based on `repoMgr -stats` / `-risk` output provided by Joe.*

---
### CHANGELOG: 260905 - 0.6.2 — Patch release (remote normalization, collision detection, risk fixes)

**Summary**  
This patch closes several gaps discovered during the recovery playlist run: remote URL normalization for collision detection, more robust collision reporting for `.gitmodules` and nested repos, safer divergence checks when HEAD is detached, and consistent DRYRUN behavior for risk/archival operations. It also adds small UX/logging improvements and non‑destructive guards so the toolkit can be run repeatedly during triage without accidental mutations.

**Notable fixes and changes**
- **(FIX) Normalize remote URLs** — Added `Normalize-RemoteUrl` to strip trailing `.git`, normalize host/path case, and handle both HTTP(S) and SSH forms (e.g., `git@host:User/Repo` → `ssh://host/user/repo`). This prevents false negatives when comparing remotes.  
- **(FIX) Submodule collision detection** — `.gitmodules` URLs are now normalized before grouping so `ai-labs` vs `ai-labs.git` no longer appear as different remotes.  
- **(FIX) Nested repo collision detection** — `Get-RemoteCollisions` now normalizes `git remote get-url origin` output and uses the normalized value as the collision key; collisions are logged as machine-readable `REMOTE-COLLISION` events.  
- **(FIX) Divergence calculation when HEAD is detached** — `Analyze-AllRepoRisk` now chooses a safe compare ref (`HEAD` when detached, otherwise the current branch) before running `git rev-list --left-right --count`, avoiding misleading or failing divergence output.  
- **(FIX) Dry‑run / Force semantics hardened** — `Write-RiskReport` and `Create-ArchivalBranchIfDetached` respect the DRYRUN/`-Force` flags consistently; by default the report run is non‑mutating and prints a clear DRYRUN banner. Detached‑HEAD archival branch creation is gated by `-Force` unless explicitly allowed.  
- **(MOD) Topology snapshot improvements** — `Write-TopologySnapshot` includes `OriginUrl` (raw) and the snapshot artifact is written to `repoMgr-logs/topology-<timestamp>.json` for agent/CI consumption. Remote values are normalized where useful.  
- **(UX) Clearer logging and non‑destructive defaults** — Added DRYRUN banners, skip messages for existing DR branches, and quieter messages for idempotent operations so repeated triage runs are less noisy.  
- **(TEST) Small defensive checks** — Guarded `get-repoList` to include `$root` when it is itself a repo; added checks for missing remotes and empty git outputs to avoid noisy exceptions during scans.

**Why this matters (short)**  
Normalizing remotes and tightening the risk/dry‑run logic removes false positives and accidental mutations during triage. That keeps the recovery playlist repeatable and safe while you run `-stats`, `-topology`, `-collisions`, and `-risk` repeatedly to build case files for reintegration.

**Suggested changelog entry text (copy/paste)**

```
##     260905 - 0.6.2 - Patch release

* (FIX) Normalize-RemoteUrl: strip trailing .git, normalize host/path case, support HTTP(S) and SSH forms.
* (FIX) Get-RemoteCollisions: normalize .gitmodules and nested repo remotes before grouping; log REMOTE-COLLISION events.
* (FIX) Analyze-AllRepoRisk: safe divergence compare ref when HEAD is detached; avoid misleading rev-list errors.
* (FIX) Dry-run/Force semantics: Write-RiskReport and Create-ArchivalBranchIfDetached respect DRYRUN and -Force consistently.
* (MOD) Write-TopologySnapshot: include OriginUrl and write topology JSON to repoMgr-logs/topology-<timestamp>.json.
* (UX) Improved logging: DRYRUN banners, idempotent DR branch guards, quieter repeated-run output.
* (TEST) Defensive checks: include $root in get-repoList when it is a repo; guard missing remote outputs.
```

If you want, I can:
- produce a **git patch** (diff) that applies these exact function edits to `repoMgr.ps1`, or  
- generate the **single-line changelog snippet** formatted for your `CHANGELOG.md` and append it to the file, or  
- run a quick **sanity checklist** against the current repo outputs you attached (verify `ai-labs` / `.AI-TRAINING` remotes normalize to the same canonical URL and show up as collisions).

Which of those would you like next — patch diff, changelog append, or the sanity check?---

---

>ok i think PHASES 1,2,3 are complete with the v0.6.2 MODS - and it can be a lot more streamlined, lot cleaner & no harm to adding `-risk` to `-all` and removing `-collisions` in v0.7 when we get there.... so we can get to PHASE-4.1 (`-all -dryrun`) with a single command
>
>does this change anything we may want to tweak for the rest of phase-4  
> 
```
--------------------------------------------------------------------------------------------
   INVOCATION: .\repoMgr.ps1 -risk     <-- Timestamp: 260905-194403
--------------------------------------------------------------------------------------------
 - Configuration: -- Root: C:\PROJECTS\LogicWizards,
    --> SafeDest: C:\Users\User\OneDrive - Logic Wizards\Backups\RepoMgr-v6.1,
    --  Lookback: 45 days ago,
    --  DR Branch: RepoMgr-DR-260905
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
  === Risk Analysis (Option-D: Smart Divergence + Forensic Mode) ===
--------------------------------------------------------------------------------------------
  (DRYRUN: no mutations will occur)

--------------------------------------------------------------------------------------------
  === Scanning for Git repositories ===
--------------------------------------------------------------------------------------------
  ✓ C:\PROJECTS\LogicWizards  [root is a repo]

--------------------------------------------------------------------------------------------
  === Detecting remote collisions ===
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
  === Scanning for Git repositories ===
--------------------------------------------------------------------------------------------
  ✓ C:\PROJECTS\LogicWizards  [root is a repo]
⚠ Remote collision [Repo] — https://github.com/wwwizards/ai-labs ← C:\PROJECTS\LogicWizards\.AI-TRAINING, C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\ai-labs
⚠ Remote collision [Repo] — https://github.com/logicwizards/core ← C:\PROJECTS\LogicWizards, C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\Agile-Wizard

--------------------------------------------------------------------------------------------
  === Scanning for Git repositories ===
--------------------------------------------------------------------------------------------
  ✓ C:\PROJECTS\LogicWizards  [root is a repo]

Repo: C:\PROJECTS\LogicWizards
  Role          : Root
  CurrentBranch : master
  GoodBranch    : master
  DetachedHead  : False
  Dirty         : True
  Divergence    : 0     0
  Collision     : https://github.com/logicwizards/core

Repo: C:\PROJECTS\LogicWizards\.AI-TRAINING
  Role          : Standard
  CurrentBranch : RepoMgr-DR-260901
  GoodBranch    : main
  DetachedHead  : False
  Dirty         : True
  Divergence    : 0     0
  Collision     : https://github.com/wwwizards/ai-labs

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\Agile-Wizard
  Role          : Agile-Wizard
  CurrentBranch : master
  GoodBranch    : master
  DetachedHead  : False
  Dirty         : True
  Divergence    : 0     0
  Collision     : https://github.com/logicwizards/core

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\ai-labs
  Role          : Standard
  CurrentBranch : main
  GoodBranch    : main
  DetachedHead  : False
  Dirty         : False
  Divergence    : 0     0
  Collision     : https://github.com/wwwizards/ai-labs

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\gitlogs
  Role          : Standard
  CurrentBranch : main
  GoodBranch    : main
  DetachedHead  : False
  Dirty         : False
  Divergence    : 0     0

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\ipscan
  Role          : Standard
  CurrentBranch : main
  GoodBranch    : main
  DetachedHead  : False
  Dirty         : False
  Divergence    : 0     0

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\pickaxe
  Role          : Standard
  CurrentBranch : main
  GoodBranch    : main
  DetachedHead  : False
  Dirty         : False
  Divergence    : 0     0

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\redactor
  Role          : Standard
  CurrentBranch : main
  GoodBranch    : main
  DetachedHead  : False
  Dirty         : False
  Divergence    : 0     0

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\tools\a2m8-toolkit
  Role          : Standard
  CurrentBranch : master
  GoodBranch    : master
  DetachedHead  : False
  Dirty         : False
  Divergence    : 0     0

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\tools\modules\clipd
  Role          : Standard
  CurrentBranch : main
  GoodBranch    : main
  DetachedHead  : False
  Dirty         : False
  Divergence    : 0     0

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\tools\modules\psst
  Role          : Standard
  CurrentBranch : main
  GoodBranch    : main
  DetachedHead  : False
  Dirty         : False
  Divergence    : 0     0

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\tools\modules\psstel
  Role          : Standard
  CurrentBranch : main
  GoodBranch    : main
  DetachedHead  : False
  Dirty         : False
  Divergence    : 0     0

Repo: C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\SIDE-PROJECTS\vsCode\ai-labs-toolkit
  Role          : Standard
  CurrentBranch : HEAD
  GoodBranch    : main
  DetachedHead  : True
  Dirty         : True
  Divergence    : 4     0
```
---

#TODO: UPDATE FROM HERE DOWN 
## 🔴 Broken / At-Risk Repos

| Repo | Risk Level | Primary Issue | Last Known Good State |
|---|---|---|---|
| `.AI-TRAINING` | HIGH | Drift detected; branch divergence from main | Unknown — requires forensic review |
| `Agile-Wizard` | MEDIUM-HIGH | Pending uncommitted changes; stale branches present | Pre-drift baseline unclear |

### `.AI-TRAINING` — Detailed Status
- **Branch drift:** HEAD has diverged from `origin/main`; merge conflicts likely
- **Uncommitted changes:** Untracked training data files flagged by `-stats`
- **Risk flags:** Potential data contamination in working tree; `.gitignore` coverage gaps suspected
- **Action required:** Do NOT push until forensic review complete (see Forensic Tasks below)

### `Agile-Wizard` — Detailed Status
- **Branch drift:** Feature branches behind `main` by unknown commit delta
- **Pending changes:** Staged and unstaged changes present; last commit message unclear
- **Risk flags:** Possible double-entry of sprint artifacts; branch naming inconsistency detected
- **Action required:** Stash or commit pending changes before any merge operations

---

## 🟡 Pending Cleanup Actions (260901~>5AM)

- [x] **`.AI-TRAINING`** — Run ` .\repoMgr.ps1 -stats -root 'C:\PROJECTS\LogicWizards\.AI-TRAINING' -lookback '7 days ago'` </br>&nbsp; - for an enhanced - `git status --porcelain` and capture full output for review
- [x] **`.AI-TRAINING`** — Audit `.gitignore` for untracked training data leakage
- [ ] **`.AI-TRAINING`** — Resolve HEAD divergence: rebase or hard reset after forensic sign-off
- [ ] **`Agile-Wizard`** — Stash or commit all pending staged/unstaged changes
- [ ] **`Agile-Wizard`** — Reconcile sprint artifact duplication across branches
- [ ] **Both repos** — Re-run `repoMgr -stats` after cleanup to confirm drift cleared
- [ ] **Both repos** — Update `README.md` files to reflect current branch strategy

---

## 🗄️ Archival Branches

> Branches identified as stale, abandoned, or superseded. Candidates for archival or deletion after review.

| Repo | Branch Name | Status | Recommended Action |
|---|---|---|---|
| `.AI-TRAINING` | `feature/old-training-set` | Stale — no commits in 90+ days | Archive to tag, then delete |
| `.AI-TRAINING` | `experiment/v1-model` | Superseded by newer experiment | Delete after confirming no unique work |
| `Agile-Wizard` | `hotfix/sprint-3-patch` | Merged but not deleted | Delete (already merged) |
| `Agile-Wizard` | `wip/backlog-restructure` | Abandoned WIP | Review with Joe, archive or close |

**Archive procedure:**
```bash
# Tag before deleting
git tag archive/<branch-name> <branch-name>
git push origin archive/<branch-name>
git push origin --delete <branch-name>
```

---

## 🆘 DR (Disaster Recovery) Branches

> Branches created or needed for recovery purposes. Treat as protected until recovery is confirmed complete.

| Repo           | DR Branch                | Purpose                                                 | Status                    |
|----------------|--------------------------|---------------------------------------------------------|---------------------------|
| `.AI-TRAINING` | `dr/pre-drift-snapshot`  | Preserve last-known-good state before drift correction  | **CREATE — not yet made** |
| `.AI-TRAINING` | `dr/working-tree-backup` | Capture current (drifted) working tree for forensic use | **CREATE — not yet made** |
| `Agile-Wizard` | `dr/pre-cleanup-state`   | Snapshot before stash/commit cleanup runs               | **CREATE — not yet made** |

**Create DR branches before any recovery work:**
```bash
git checkout -b dr/pre-drift-snapshot
git push origin dr/pre-drift-snapshot
```

---

## 🔬 Follow-Up Forensic Tasks

- [ ] **`.AI-TRAINING`** — Diff `HEAD` vs `origin/main` and document all diverged commits
- [ ] **`.AI-TRAINING`** — Identify and log all untracked files flagged by `-stats`; determine if any contain sensitive training data
- [ ] **`.AI-TRAINING`** — Check commit history for any force-pushes or rebases that may have rewritten shared history
- [ ] **`Agile-Wizard`** — Review last 10 commits for accidental inclusion of non-sprint content
- [ ] **`Agile-Wizard`** — Verify branch protection rules are active on `main`
- [ ] **Both repos** — Confirm `repoMgr` risk thresholds are calibrated correctly (false positive check)
- [ ] **Both repos** — Schedule a post-recovery `repoMgr -risk` run and document results as new baseline

---

## 📋 Backlog Priority Order

1. Create all DR branches (protect state before touching anything)
2. Forensic review of `.AI-TRAINING` drift
3. Stash/commit pending `Agile-Wizard` changes
4. Run cleanup actions (in order listed above)
5. Archive/delete stale branches
6. Post-recovery `-stats` and `-risk` validation
7. Update READMEs and close this backlog



 