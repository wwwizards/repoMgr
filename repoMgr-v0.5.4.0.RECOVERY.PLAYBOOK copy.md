# **RECOVERY‑PLAYBOOK**  
> **Generated: 2026-09-01** | **Source:** `repoMgr -stats` + `repoMgr -risk` output
> **Repos in scope:** `.AI-TRAINING`, `Agile-Wizard`
> ***Last updated:** 2026-09-01 by Copilot Tasks 
> — based on `repoMgr -stats` / `-risk` output provided by Joe.*
## *LogicWizards Monorepo Recovery Playbook — v0.5.4 Ops Edition*  
*(Updated for repoMgr.ps1 v0.5.4 — including DR‑branch guards, nested‑repo fixes, tokenizer patch, Show‑PendingChanges, and root‑repo self‑check)*

---


# 🧭 Phase 1 — Assessment (Triage)

## **1. Run bounded drift stats**
```powershell
repoMgr.ps1 -stats
```

Use this to identify:

- Detached HEAD repos  
- Dirty working trees  
- Divergent branches  
- Repos with large untracked explosions  
- Repos with deleted or modified core documents  
- Repos with stale commit windows (no commits in lookback)

## **2. Build the Broken Repo List**
Record each repo showing anomalies:

- Root (master)  
- `.AI-TRAINING`  
- `SOLUTIONS/DevOps/Agile-Wizard`  
- `SIDE-PROJECTS/ai-labs`  
- `SIDE-PROJECTS/ai-labs-toolkit`  
- Any nested `.HANDOFF` or `.AI-TRAINING` clones  
- Any repo containing detached-analysis artifacts  
- Any repo containing repoMgr-logs inside tracked tree  
- Any repo with submodule pointer drift  

Add these to **BACKLOG.md** under “Broken Repos”.

---

# 🛡 Phase 2 — Archival Preservation (Detached HEAD Only)

For each repo showing **detached HEAD**:

```powershell
repoMgr.ps1 -risk
```

This triggers:

```
Create-ArchivalBranchIfDetached
→ recovered-<hash>
```

This safely preserves the broken state.

## If repo is *not* detached:
Manually create archival branch:

```powershell
git -C <path> branch recovered-$(git -C <path> rev-parse --short HEAD)
```

Add archival branch info to BACKLOG.md.

---

# 🧰 Phase 3 — DR Branch Creation (Dirty Repos)

For repos with pending changes:

```powershell
repoMgr.ps1 -recovery -dirtyonly
```

This creates:

```
DR-YYMMDD
```

## v0.5.4 Guard:
If DR branch already exists, repoMgr prints:

```
ℹ DR branch '<name>' already exists — skipping.
```

This prevents accidental re-creation and makes `-all` idempotent.

Add DR branch info to BACKLOG.md.

---

# 🔄 Phase 4 — Reset to Known‑Good State (Safe Baseline)

After DR + archival branches exist:

```powershell
git -C <path> checkout main   # or master for root
git -C <path> reset --hard origin/main
```

This restores a clean baseline.

## **Important:**  
Do **NOT** hard reset until:

- DR branch is validated  
- Archival branch exists (if detached)  
- Untracked explosion is reviewed  
- Deleted files are inspected  

---

# 🧩 Phase 5 — Selective Reintegration (Safe Merge Strategy)

## Use the reintegration scaffold:

```powershell
repoMgr.ps1 -reintegration
```

Then reintegrate changes **safely**:

### **Option A — Cherry‑pick only verified commits**
```powershell
git -C <path> cherry-pick <commit>
```

Use the Option‑D JSON to identify:

- Non‑stale commits  
- Non‑destructive commits  
- Divergent but safe commits  

### **Option B — Merge DR branch (only if safe)**
```powershell
git -C <path> merge <DR-branch>
```

Resolve conflicts guided by:

- Show‑PendingChanges  
- Option‑D risk JSON  
- Deleted vs modified vs untracked classification  

### **Option C — Discard unsafe changes**
Move unwanted untracked files into:

```
QUARANTINE/
```

Commit only what belongs in repo.

---

# 🔍 Phase 6 — Verification (Post‑Recovery)

Run:

```powershell
repoMgr.ps1 -stats
```

Confirm:

- No detached HEADs  
- No dirty repos  
- No divergence from origin  
- No nested repo false‑positives  
- No accidental repoMgr-logs inside repos  
- Submodule pointers correct  
- Working tree clean  

If clean → mark repo as **RECOVERED** in BACKLOG.md.

---

# 📓 Phase 7 — Backlog Registration (Audit Trail)

## For each repo touched:

```
## [RepoName]
- Recovery date: 260901
- Archival branch: recovered-<hash> (if applicable)
- DR branch: DR-260901
- Reintegration status: [pending | complete]
- Notes:
  - Deleted files reviewed
  - Untracked explosion triaged
  - DR branch validated
  - Reset performed
  - Cherry-picks applied
  - Submodule pointers corrected
```

This ensures nothing gets lost and provides a full audit trail.

---

# 🧩 Why v0.5.4 Changes Matter

## **1. Root repo self-check**
`get-repoList` now checks `$root/.git` first.  
This fixes the case where `-root` targets a leaf repo like `.AI-TRAINING`.

## **2. Nested repo false-positive fix**
`Resolve-Path` guard prevents `$root` from being flagged as nested.

## **3. DR branch guard**
Prevents re-creating DR branches and breaking `-all`.

## **4. Reintegration path fix**
Prevents double-suffix path errors.

## **5. Show‑PendingChanges**
Structured table replaces flat porcelain dump:

- Action  
- Scope  
- File  
- Summary counts  
- Grouped mode  

This is essential for triage.

## **6. Tokenizer patch**
Fixes `-root='C:\path'` bug.

---

# 🧪 PR Checklist (Safe Reintegration Workflow)

Use this checklist **before merging DR or archival changes**.

---

## **PR Title**
```
[Recovery] RepoName — DR Reintegration (260901)
```

---

## **PR Sections**

## **1. DR Branch Validation**
- [ ] DR branch exists  
- [ ] DR branch contains all pending changes  
- [ ] No missing staged changes  
- [ ] No missing untracked files that belong in repo  

## **2. Archival Branch Validation (if detached)**
- [ ] recovered‑<hash> exists  
- [ ] HEAD state preserved  
- [ ] Detached chain documented  

## **3. Deleted File Review**
For each deleted file:
- [ ] Confirm intentional  
- [ ] Restore if accidental  
- [ ] Move to QUARANTINE if unclear  

## **4. Modified File Review**
For each modified file:
- [ ] Compare against origin/main  
- [ ] Check Option‑D JSON for stale/destructive flags  
- [ ] Validate correctness  

## **5. Untracked Explosion Review**
For each untracked file:
- [ ] Belongs in repo → stage  
- [ ] Does not belong → QUARANTINE  
- [ ] Generated artifact → add to `.gitignore`  

## **6. Submodule Pointer Review**
- [ ] ai-labs pointer correct  
- [ ] ai-labs-toolkit pointer correct  
- [ ] No accidental pointer drift  

## **7. Repo Hygiene**
- [ ] Remove repoMgr-logs from repo  
- [ ] Remove detached-analysis.json from repo  
- [ ] Remove SIDE-PROJECTS folders  
- [ ] Validate `.gitignore` coverage  

## **8. Reintegration Method**
Choose one:

- [ ] Cherry-pick safe commits  
- [ ] Merge DR branch  
- [ ] Partial merge + manual conflict resolution  
- [ ] Reset + selective reapply  

## **9. Final Verification**
- [ ] repoMgr.ps1 -stats shows clean  
- [ ] repoMgr.ps1 -risk shows NONE or LOW  
- [ ] Working tree clean  
- [ ] No nested repo warnings  
- [ ] No divergence from origin  

## **10. Documentation**
- [ ] BACKLOG.md updated  
- [ ] STATE.md updated (if applicable)  
- [ ] Notes added to LIGHTBULB-LOG.md (if applicable)  

---

# ✔ You now have a complete v0.5.4 Recovery Playbook + PR Checklist

If you want, I can also generate:

- A **QUARANTINE/ folder structure**  
- A **reintegration decision tree**  
- A **repoMgr v0.5.5 roadmap**  
- A **monorepo hygiene baseline**  

Just tell me what you want next.