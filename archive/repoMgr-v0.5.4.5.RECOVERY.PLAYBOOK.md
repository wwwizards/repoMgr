# RECOVERY‑PLAYBOOK  
> **Generated: 2026-09-01** | **Source:** `repoMgr -stats` + `repoMgr -risk` output
> **Repos in scope:** `.AI-TRAINING`, `Agile-Wizard`
> ***Last updated:** 2026-09-01 by Copilot Tasks 
> — based on `repoMgr -stats` / `-risk` output provided by Joe.*
### Recovery playbook (v0.5.4.5 ‑ Ops-Aporiae Edition)

This version assumes our current `repoMgr.ps1` (0.5.4) with `Show‑PendingChanges`, DR branch idempotence, nested‑repo guards, and empty‑history fallback. It also bakes in the “collision” insight (two subdirs pointing at the same remote) and the PR path from `RepoMgr-DR-260901` → LogicWizards core.

> #### APORIAE
>    - **APORIA-1.1:** your (response) Option-A shows a clear (script-able) remediation plan that would be even simpler if we could just clone the branch as shown in https://github.com/wwwizards/ai-labs/tree/RepoMgr-DR-260901 but it says "This branch is 1 commit ahead of and 77 commits behind main."  within that branch there are some things that actually belong in the AI-LABS repo while the majority does not.  image - GH://wwwizards/ai-labs recovery branches evidence![alt text](image-1.png)
> 
>    - **APORIA-1.2 (SEE) the code-listing for that branch (below)** where I highlighted: green = things that should be there; red, should NOT; yellow is just one example of something that should be there but might be in the wrong dir... that partially shown README.md looks like it belongs in our .AI-TRAINING dir that is currently (and wrongly) pointing to ai-labs as the remote URL - which may identify another issue that was not clear from any repoMgr report that we have two completely different subdirs pointing to the same remote URL 
> 
> **these are significant discoveries and possibly another bugfix & feature request** - where we may need to identify collision signals as a potential risk before creating recovery branches that mix the apples & oranges and cause further confusion... hopefully I can locate the other missing files
> - **APORIA-2: I think i noticed another bug when using both dryrun & all flags at the same time**
>     - i am fairly certain that this condition may have created the additional recovery branches that I am seeing -- and on top of all that:  the script never switches back to the branch it was using before creating the new one - which can cause all kinds of other issues if the user is overworked and under-caffeinated...
>
> (image - GH://wwwizards/ai-labs recovery branch evidence drill-down)![alt text](image.png)
> TODO: rename images as per standards


---

#### Phase 1 — Assessment (Revised)

1. **Bounded drift scan (per root)**  
   ```powershell
   .\repoMgr.ps1 -stats -root 'C:\PROJECTS\LogicWizards'
   .\repoMgr.ps1 -stats -root 'C:\PROJECTS\LogicWizards\.AI-TRAINING'
   .\repoMgr.ps1 -stats -root 'C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\Agile-Wizard'
   ```
   **Goal:** identify repos with:
   - **Detached HEAD**  
   - **Dirty working trees** (see `Pending changes: …` header)  
   - **No commits in window** where you expected activity  

2. **Nested + collision signals**  
   ```powershell
   .\repoMgr.ps1 -reintegration -root 'C:\PROJECTS\LogicWizards'
   ```
   **You’re looking for:**
   - Nested repos under `.HANDOFF`, `.AI-TRAINING`, `SIDE-PROJECTS`  
   - Multiple subdirs pointing to the **same remote URL** (e.g. both `.AI-TRAINING` and `ai-labs` pointing at `wwwizards/ai-labs`)  

   > Any “two different trees, same remote” is a **collision risk** and should be treated as a recovery item before more DR branches are created.

---

#### Phase 2 — Archival preservation (per repo)

For each repo you’re about to touch:

1. **Run risk on the repo root**  
   ```powershell
   .\repoMgr.ps1 -risk -root 'C:\PROJECTS\LogicWizards\.AI-TRAINING'
   ```
   Internally this should:
   - Use `Get-GoodBranch` to pick `main` vs `master`  
   - Call `Create-ArchivalBranchIfDetached` when HEAD is detached  
   - Emit `recovered-<hash>` branches only when needed  

2. **Manual archival when not detached**  
   If HEAD is not detached but you still want a frozen snapshot:
   ```powershell
   git -C C:\PROJECTS\LogicWizards\.AI-TRAINING branch recovered-$(git -C C:\PROJECTS\LogicWizards\.AI-TRAINING rev-parse --short HEAD)
   ```

---

#### Phase 3 — DR branches (bounded, idempotent)

Use the built‑in DR creation, but **avoid mixing `-all` and `-dryrun` until you patch the behavior**:

```powershell
.\repoMgr.ps1 -recovery -dirtyonly -root 'C:\PROJECTS\LogicWizards\.AI-TRAINING'
```

**Operational rules:**

- **One DR name per session** (e.g. `RepoMgr-DR-260901`)  
- Let 0.5.4’s guard prevent re‑creating existing DR branches.  
- After DR creation, **explicitly restore the original branch** (until the script is patched):

  ```powershell
  $orig = git -C C:\PROJECTS\LogicWizards\.AI-TRAINING rev-parse --abbrev-ref @{-1}
  git -C C:\PROJECTS\LogicWizards\.AI-TRAINING checkout $orig
  ```

  Or more simply, if you know the intended branch:

  ```powershell
  git -C C:\PROJECTS\LogicWizards\.AI-TRAINING checkout main   # or master
  ```

> Future script patch: capture `git rev-parse --abbrev-ref HEAD` before DR creation and auto‑checkout it at the end of `create-drBranches`, even in `-all` mode.

---

#### Phase 4 — Collision‑aware PR plan (ai‑labs → LogicWizards core)

You’ve identified that `RepoMgr-DR-260901` in `wwwizards/ai-labs` contains:

- **Green:** files that truly belong in `ai-labs`  
- **Red:** files that belong in `C:\PROJECTS\LogicWizards\.HANDOFF` (core)  
- **Yellow:** files that belong in `.AI-TRAINING` but are sitting in the wrong dir

The safe PR pattern is:

1. **Clone and isolate the DR branch locally**
   ```powershell
   git clone https://github.com/wwwizards/ai-labs.git
   cd ai-labs
   git checkout RepoMgr-DR-260901
   ```

2. **Classify files by destination repo**

   - **Keep in ai-labs:** leave them where they are.  
   - **Move to LogicWizards root (`.HANDOFF`):**  
     - Copy them out to `C:\PROJECTS\LogicWizards\.HANDOFF` in a **separate working tree**.  
   - **Move to `.AI-TRAINING`:**  
     - Copy them into `C:\PROJECTS\LogicWizards\.AI-TRAINING` under the correct subdir (e.g. `README.md` → `.AI-TRAINING/README.md`).

3. **Create PRs per destination (no cross‑repo PR)**

   - **PR‑A (ai-labs cleanup):**
     - Remove red files from `RepoMgr-DR-260901` (or move them to a neutral archive dir inside ai-labs if you want a forensic record).
     - Keep only green/yellow that truly belong to ai-labs.
   - **PR‑B (LogicWizards root):**
     - From `C:\PROJECTS\LogicWizards`, create a branch (e.g. `HANDOFF-DR-260901`) and add the 41 `.HANDOFF` files.
   - **PR‑C (`.AI-TRAINING`):**
     - From `C:\PROJECTS\LogicWizards\.AI-TRAINING`, create a branch (e.g. `AI-TRAINING-DR-260901`) and add/move the training‑related files.

> Hypothetical “THIS‑PR” that tries to move files into a directory that doesn’t exist in ai‑labs should **not** be a single PR. Instead, treat ai‑labs as the source of truth for the DR snapshot and LogicWizards as the destination repos that receive those files via separate branches.

---

#### Phase 5 — Reset to known‑good state (per repo)

Once archival + DR + PR scaffolding are in place:

```powershell
git -C C:\PROJECTS\LogicWizards\.AI-TRAINING checkout main   # or master
git -C C:\PROJECTS\LogicWizards\.AI-TRAINING reset --hard origin/main
```

Repeat for:

- `C:\PROJECTS\LogicWizards` (core root)  
- `C:\PROJECTS\LogicWizards\SOLUTIONS\DevOps\Agile-Wizard`  
- Any other repo that had DR branches created

---

#### Phase 6 — Selective reintegration

Use the reintegration scaffold only after you’ve separated apples and oranges:

```powershell
.\repoMgr.ps1 -reintegration -root 'C:\PROJECTS\LogicWizards'
```

Then, manually:

- Cherry‑pick commits from:
  - `recovered-*` branches  
  - `RepoMgr-DR-260901` (after cleanup)  
  - `HANDOFF-DR-*` and `AI-TRAINING-DR-*` branches  
- Ensure each cherry‑pick lands in the **correct repo and directory**.

---

#### Phase 7 — Verification

Re‑run stats:

```powershell
.\repoMgr.ps1 -stats -root 'C:\PROJECTS\LogicWizards'
.\repoMgr.ps1 -stats -root 'C:\PROJECTS\LogicWizards\.AI-TRAINING'
```

Confirm:

- No detached HEADs  
- No unexpected DR branches  
- No nested repos where they shouldn’t exist  
- No subdirs sharing the same remote URL unless explicitly intended

---

### PR checklist (for this recovery episode)

You can drop this straight into `BACKLOG.md` or a `RECOVERY-PR-CHECKLIST.md`:

```markdown
## Recovery PR Checklist — RepoMgr-DR-260901

- [ ] Confirm archival branches exist for all touched repos (`recovered-*`).
- [ ] Confirm DR branches exist and are unique per repo (`RepoMgr-DR-260901`, `HANDOFF-DR-260901`, `AI-TRAINING-DR-260901`).
- [ ] Classify ai-labs DR files into:
      - [ ] Belong in ai-labs
      - [ ] Belong in LogicWizards root (.HANDOFF)
      - [ ] Belong in .AI-TRAINING
- [ ] PR-A (ai-labs): cleanup DR branch, remove/move non-ai-labs files.
- [ ] PR-B (LogicWizards root): add .HANDOFF files from DR snapshot.
- [ ] PR-C (.AI-TRAINING): add/move training files into correct dirs.
- [ ] Patch repoMgr:
      - [ ] Avoid creating DR branches when `-dryrun` is set (log only).
      - [ ] Capture original branch before DR creation and restore it after.
      - [ ] Add collision detection: warn when multiple subdirs share the same remote URL.
- [ ] Re-run `repoMgr.ps1 -stats` on all roots and confirm:
      - [ ] No detached HEADs
      - [ ] No dirty repos (unless intentionally in-progress)
      - [ ] No unexpected divergence from origin
```

If you want, next step we can tighten the collision‑detection logic into a concrete PowerShell helper that plugs into `-risk` so this whole episode becomes a first‑class “risk signal” instead of a surprise.