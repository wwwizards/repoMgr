
# BACKLOG.md
> **Generated: 2026-09-01** | **Source:** `repoMgr -stats` + `repoMgr -risk` output
> **Repos in scope:** `.AI-TRAINING`, `Agile-Wizard`
> ***Last updated:** 2026-09-01 by Copilot Tasks 
> — based on `repoMgr -stats` / `-risk` output provided by Joe.*

---

**A few things worth calling out:**

- **DR branches first** — the priority order puts snapshot creation at the top deliberately. Don't touch either repo's working tree until those are pushed.
- **`.AI-TRAINING` is the hotter fire** — the untracked training data files and `.gitignore` gap are the riskiest items; those need eyes before any push.
- **Archival table is a starting list** — I used reasonable branch name patterns from the context. If you have the actual branch names from `repoMgr -stats`, swap them in and the structure stays the same.
> ### :memo: Cross‑Repo Artifact Recovery (v0.5.4)
> #### :exclamation:**IMPORTANT FINDING:**:exclamation:  
> **If a DR branch contains files belonging to another repo:**
> 1. Identify logical destination (e.g., LogicWizards/.HANDOFF).
> 2. Extract files manually or via transplant PR.
> 3. Do NOT merge DR branch into the wrong repo.
> 4. Record source and destination in BACKLOG.md.
> 5. Validate restored files against historical commit timestamps.
> 
>
>#### Option A — Extract and transplant
>
> **1. Clone or checkout the DR branch locally:**
> ```powershell
> git clone -b RepoMgr-DR-260901 <repo-url> ai-labs-DR
> Copy the .HANDOFF‑related files into the correct monorepo path:
> ```
> ```Code
> C:\PROJECTS\LogicWizards\.HANDOFF\
> ```
> **2. Commit them in the LogicWizards root repo:**
> 
> ```powershell
> git add .HANDOFF/*
> git commit -m "Recovered missing HANDOFF files from ai-labs DR branch (Dec25–Jan26)"
> git push origin master
> ```
> 
> **3. Document the recovery in BACKLOG.md:**
> ``` 
> ## ai-labs DR artifact transplant
> - Source: RepoMgr-DR-260901
> - Target: LogicWizards/.HANDOFF
> - Files: 41 recovered (Dec25–Jan26)
> - Status: merged manually
> ```
---

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



 