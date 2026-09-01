You’re thinking exactly like a recovery engineer should, Joe — separating **triage** from **forensics**.  
The image you shared shows the “Step 2 — Create archival branches” snippet, and you’re right: the current workflow assumes that running `repoMgr.ps1 ‑risk` automatically preserves the broken state safely. That’s true for detached repos, but it doesn’t yet handle the **monorepo root** or the **multi‑repo coordination** you need for a full recovery.

Let’s re‑evaluate and design a **Recovery Playbook** that complements your existing script and focuses purely on getting the repos functional again.

---

## 🧭 Recovery Playbook (v0.5.1‑Ops)

### **Phase 1 — Assessment**
1. **Run bounded stats**
   ```powershell
   repoMgr.ps1 -stats
   ```
   → Identify repos with:
   - Detached HEAD  
   - Dirty working trees  
   - Divergent branches  

2. **List broken repos**
   - Root (master)  
   - Agile‑Wizard  
   - ai‑labs  
   - ai‑labs‑toolkit  
   - Any nested `.AI‑TRAINING` or `.HANDOFF` repos  

---

### **Phase 2 — Archival Preservation**
For each broken repo:
```powershell
repoMgr.ps1 -risk
```
This triggers `Create‑ArchivalBranchIfDetached`, producing:
```
recovered‑<hash>
```
✅ Preserves the broken state safely.  
⚠ If the repo is **not detached**, manually create an archival branch:
```powershell
git -C <path> branch recovered-$(git -C <path> rev-parse --short HEAD)
```

---

### **Phase 3 — Disaster‑Recovery Branches**
For repos with pending changes:
```powershell
repoMgr.ps1 -recovery -dirtyonly
```
Creates:
```
DR‑YYMMDD
```
✅ Captures current work before resets.

---

### **Phase 4 — Reset to Known‑Good State**
For each repo:
```powershell
git -C <path> checkout main   # or master for root
git -C <path> reset --hard origin/main
```
This restores the clean baseline.

---

### **Phase 5 — Selective Reintegration**
Use the scaffold:
```powershell
repoMgr.ps1 -reintegration
```
Then cherry‑pick only verified commits from:
- `recovered‑*`  
- `DR‑*`

---

### **Phase 6 — Verification**
Run:
```powershell
repoMgr.ps1 -stats
```
Confirm:
- No detached HEADs  
- No dirty repos  
- No divergence from origin  

---

### **Phase 7 — Backlog Registration**
Add a new entry to **BACKLOG.md** for each repo touched:
```
## [RepoName]
- Recovery date: 260901
- Archival branch: recovered-<hash>
- DR branch: DR-260901
- Reintegration status: pending
- Notes: [summary of issue or anomaly]
```

This ensures nothing gets lost while you focus on stabilization.

---

## 🧩 Why Item 1 Skipped the Monorepo
The earlier workflow treated the monorepo root as “clean” because it’s on `master`, not `main`.  
In v0.5.1, you can fix that by adding:
```powershell
$goodBranch = Get-GoodBranch -repoPath $root
```
inside the risk loop, so the root is analyzed and archived like any other repo.

---

## ⚙️ Immediate Next Step
Run these two commands tonight:

```powershell
repoMgr.ps1 -stats
repoMgr.ps1 -risk
```

Then send me the short list of repos that still show:
- Detached HEAD  
- Dirty working tree  
- Divergent branches  

Once we have that, I’ll help you script the **Phase 4–5 reset + reintegration sequence** so you can bring everything back online quickly and safely.