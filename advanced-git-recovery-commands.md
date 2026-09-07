Yes. For what you’re doing, I’d make the cheatsheet **Git forensics/recovery-first**, not just day-to-day Git.

As of **September 7, 2026**, the latest Git source release is **2.55.0**, released June 29, 2026. The commands below are aligned to the current Git documentation. ([Git][1])

# Git 2.55 — Repo Forensics, Recovery & Branch Archaeology Cheatsheet
## TL;DR SUMMARY

### The four recovery commands worth memorizing

If I had to reduce this entire sheet to four:

```bash
git log --all --graph --decorate --oneline
```

**What's still reachable?**

```bash
git reflog --date=iso
```

**Where did HEAD used to point?**

```bash
git fsck --full --no-reflogs --unreachable
```

**What's still physically in the object database but no longer referenced?**

```bash
git branch rescue/<name> <SHA>
```

**Protect the thing you found before doing anything else.**

And for missing files, add a fifth:

```bash
git log --all --full-history --diff-filter=D --name-status
```

**What files were deleted, and when?**

---

### A particularly useful workflow for a missing-file(s) situation

Say you're convinced `repoMgr.ps1` or an earlier supporting file existed somewhere but isn't on the current branch.

1. **Find all history touching it:**
`git log --all --full-history --follow --name-status -- repoMgr.ps1`

2. **Find deletion commits:** 
`git log --all --full-history --diff-filter=D --name-status -- repoMgr.ps1`

3. **Inspect an older copy:**  → `git show <SHA>:repoMgr.ps1`
4. **Find branches containing that SHA:**  → `git branch -a --contains <SHA>`
5. **If none do, inspect reflog:**  → `git reflog show --all --date=iso`
6. **Then unreachable objects:**  → `git fsck --full --no-reflogs --unreachable`
7. **Once you find the right SHA:**  → `git branch rescue/repoMgr-found <SHA>`
8. **Now it's anchored and you can safely compare:**
   - `git diff main...rescue/repoMgr-found`
9.  **or restore just the file:**  → `git restore --source=<SHA> -- repoMgr.ps1`

---
- **HERE's the recovery model I usualy build around:** 
  - **discover → diagnose → document → design/deep-dive → do/deliver** (restore/cherry-pick), 
  - **DON'T** go switching & resetting branches while you're still investigating. ([Git][11])

---

## DISCOVER
### 1. RULE #1: DISCOVER before you DO (anything)

When you suspect missing files, deleted branches, detached-HEAD commits, or lost work, **do not start with `reset`, `clean`, `gc`, `prune`, or branch deletion**.

1. **Run this first:**
    ```shell
    git --version
    git status --short --branch
    git branch --show-current
    git rev-parse --show-toplevel
    git rev-parse --short HEAD
    git show -s --decorate --format=fuller HEAD
    git branch -avv
    git worktree list
    git remote -v
    ```

2. **THEN IF:** `git branch --show-current`
   - prints nothing, you're probably in **detached HEAD** state.
3. **Confirm with:** `git symbolic-ref -q --short HEAD`
   - No output / nonzero exit means a detached HEAD.

---

### 2. `git -C` — extremely useful for repo analysis

This is a **global Git option**:

```bash
git -C <repo-path> <command>
```

It means:

> Run the Git command as though the current directory were `<repo-path>`.

So you don't need:

```bash
cd /some/repo
git status
cd ..
```

Use:

```bash
git -C /some/repo status
```

Git officially supports multiple `-C` arguments as well; subsequent relative paths are resolved from the preceding `-C`. ([Git][2])

Examples:

```bash
git -C ~/repos/myapp status
git -C ~/repos/myapp branch -avv
git -C ~/repos/myapp log --all --graph --decorate --oneline
git -C ~/repos/myapp reflog --date=iso
git -C ~/repos/myapp fsck --full
```

This is particularly valuable for a repo-manager/forensic script because you can inspect repositories without changing the process's working directory.

---

### 3. `git -C` vs `git switch -C` vs `git switch -c`

These are ALL completely different directives - ONE which deserves EXTREME CAUTION.

| Command                    | Meaning                          | Recovery safety |
| -------------------------- | -------------------------------- | --------------- |
| `git -C /repo status`      | Run Git inside `/repo`           | SAFE            |
| `git switch -c rescue SHA` | Create new branch at SHA         | SAFE            |
| `git switch -C rescue SHA` | Force-create/reset branch at SHA | CAUTION         |
| `git branch rescue SHA`    | Create pointer without switching | VERY SAFE       |

Current `switch` syntax is:

```bash
git switch <branch>
git switch --detach <commit>
git switch -c <new-branch> [<start-point>]
git switch -C <new-branch> [<start-point>]
```

`-c` creates a new branch. `-C` does the same **but resets the branch if it already exists**. ([Git][3])

For recovery, prefer: `git branch rescue-20260907 <SHA>`

or: `git switch -c rescue-20260907 <SHA>`

rather than: `git switch -C rescue-20260907 <SHA>`

---

## DIAGNOSE
### 4. Get the complete visible branch/ref picture

- **Local branches:**  → `git branch`
- **Verbose:**  → `git branch -vv`
- **Local + remote:**  → `git branch -a`
- **Verbose local + remote:**  → `git branch -avv`
- **Remote only:**  → `git branch -r`
- **Current branch:**  → `git branch --show-current`

- **Get branches sorted by latest commit:**  → `git for-each-ref --sort=-committerdate --format='%(committerdate:iso8601) %(objectname:short) %(refname:short)' refs/heads refs/remotes
    `

- **All refs:** → `git show-ref`
- **All branch history:**
    ```bash
    git log --all --graph --decorate --oneline --date-order
    ```
    - A particularly useful forensic version (for bash & pwsh):
    ```bash
    git log --all --graph --decorate --pretty=format:'%h %ad %d %s [%an] --date=iso 
    ```

---

### 5. Find which branches contain a mystery commit

Given the short-hash: → `a1b2c3d`  → find local branches containing it:

```bash
git branch --contains a1b2c3d
```
Variants: 
- **Local + Remote:** → `git branch -a --contains a1b2c3d`
- **Remote only:** → `git branch -r --contains a1b2c3d`
- Find branches pointing **exactly** at it:  → `git branch -a --points-at a1b2c3d`
> 
> **NOTE:** Git defines `--contains` as branches whose histories include that commit ([Git][4]) BUT: Theres ONE HUMONGOUS limitation:
> 
> **A commit does not record "I was created on branch X."**
> 
> Branches are movable pointers. We MUST infer historical branch association through:
> 
> ```bash
> git branch --contains
> git reflog
> git log --graph
> git merge-base
> ```

---

### 6. Detached HEAD — inspect it safely

Explicitly inspect a commit without touching a branch:

```bash
git switch --detach <SHA>
```

Example: → `git switch --detach a1b2c3d`

- **That is a normal supported workflow for examining old commits.** ([Git][5])
   - If you discover something valuable while detached, **anchor it immediately**:

```bash
git branch rescue-detached HEAD
```

That way we remain detached, but the commit is now protected by a branch ref. 
 → **or:** you can create the branch and switch:  → `git switch -c rescue-detached`
 →  → **or:** From an arbitrary old SHA:  → `git switch -c rescue-detached a1b2c3d`

---

### 7. Jump back to the previous branch/commit

Modern Git:  → `git switch -`

This is equivalent to:  → `git switch @{-1}`
 - Git also supports: `@{-2}` & `@{-3}`... 
   - meaning previous locations visited through `switch`/`checkout`. ([Git][3])
     - We can inspect them without switching with :
          ```bash
          git show @{-1}
          git show @{-2}
          ```

---

## DESIGN
### 8. Reflog — probably your most important recovery command

Normal commit history tells you:

> What commits are reachable now?

Reflog tells you:

> Where did HEAD and refs point before?
- **Start here:**  → `git reflog`
- **Even Better:**  → `git reflog --date=iso`
- **Show ALL reflogs:**  → `git reflog show --all --date=iso`
- **EVEN More Detailed:**  → `git reflog --date=iso --pretty='%h %gd %cd %gs'`

You'll see things like:

```text
7a5c123 HEAD@{0} switch: moving from feature-x to main
4c391ab HEAD@{1} commit: added recovery logic
1bfa822 HEAD@{2} checkout: moving from main to 1bfa822
```
you can then 
- **Inspect:**  → `git show HEAD@{1}` → **or:**  → `git show 4c391ab`
- **Recover:**  → `git branch rescue-reflog 4c391ab`
- **Then:**  → `git switch rescue-reflog`

> :exclamation: **IMPORTANT NOTES - FOR PROCRASTINATORS:** :exclamation: 
> Reflogs specifically record previous ref values & HEAD branch-switch activity. Current Git defaults generally expire reachable reflog entries after 90 days and unreachable entries after 30 days unless configuration changes those values...  **so: recovery work should be done sooner rather than later.** ([Git][6])

---

### 9. Find commits made in detached HEAD that were "lost"

Suppose you:

```bash
git switch --detach oldSHA
```

then:

```bash
git commit
git commit
git switch main
```

Those commits may no longer be reachable from any branch.

First:

```bash
git reflog --date=iso
```

Find the detached commits.

Then:

```bash
git show <SHA>
```

Protect them:

```bash
git branch rescue-detached <SHA>
```

or:

```bash
git switch -c rescue-detached <SHA>
```

---

### 10. Find unreachable / dangling commits

If reflog isn't enough:

```bash
git fsck --full
```

More useful for archaeology:

```bash
git fsck --full --unreachable
```

And particularly:

```bash
git fsck --full --no-reflogs --unreachable
```

Why `--no-reflogs`?

Normally `fsck` treats reflog entries as roots, meaning commits referenced only through reflogs aren't considered unreachable.

`--no-reflogs` lets you expose commits that aren't reachable from a normal branch/tag/ref. ([Git][7])

Example output:

```text
unreachable commit 4c391ab...
unreachable tree   ee8291...
unreachable blob   83ab922...
```

Inspect a commit:

```bash
git show 4c391ab
```

Inspect its tree:

```bash
git ls-tree -r 4c391ab
```

Protect it:

```bash
git branch rescue-fsck 4c391ab
```

---

### 11. Last-resort lost-found

Git can write dangling objects into:

```text
.git/lost-found/
```

with:

```bash
git fsck --full --lost-found
```

Git places dangling commits under:

```text
.git/lost-found/commit/
```

and other recovered objects under:

```text
.git/lost-found/other/
```

This is explicitly supported by `git fsck`. ([Git][7])

I would run ordinary `fsck` first and only use `--lost-found` when you actually need it.

---

### 12. Find the history of a deleted file

Known path:

```bash
git log --all -- path/to/file
```

Show statuses:

```bash
git log \
    --all \
    --full-history \
    --name-status \
    -- path/to/file
```

Only deletion commits:

```bash
git log \
    --all \
    --full-history \
    --diff-filter=D \
    --name-status \
    -- path/to/file
```

`D` means deleted. Git's current `log` supports `--diff-filter=D` for precisely this. ([Git][8])

---

### 13. Find a file that may have been renamed

Use:

```bash
git log --follow -- path/to/file
```

With patches:

```bash
git log -p --follow -- path/to/file
```

With statuses:

```bash
git log \
    --follow \
    --name-status \
    -- path/to/file
```

This can walk backward across renames.

---

### 14. Find the exact commit that deleted a file

```bash
git log \
    --all \
    --full-history \
    --diff-filter=D \
    --format='%H %ad %an %s' \
    --date=iso \
    -- path/to/file
```

Suppose that returns:

```text
abc1234 2026-06-02 ... removed obsolete recovery tool
```

The file existed immediately **before** that commit.

Therefore:

```bash
git show abc1234^:path/to/file
```

is often exactly what you want.

---

### 15. View a file from any previous commit without switching

This is one of Git's best archaeology commands:

```bash
git show <commit>:<path>
```

Examples:

```bash
git show HEAD~5:scripts/recovery.ps1
```

```bash
git show feature-old:scripts/recovery.ps1
```

```bash
git show a1b2c3d:scripts/recovery.ps1
```

No checkout. No switch. No working-tree changes.

Excellent for forensics.

---

### 16. Check whether a file existed at a commit

List entire tree:

```bash
git ls-tree -r --name-only <SHA>
```

Example:

```bash
git ls-tree -r --name-only a1b2c3d
```

Search a path directly:

```bash
git ls-tree -r a1b2c3d -- path/to/file
```

List a directory:

```bash
git ls-tree a1b2c3d:path/to/
```

---

### 17. Restore one deleted file from an old commit

Modern Git prefers `restore`:

```bash
git restore --source=<SHA> -- path/to/file
```

Example:

```bash
git restore --source=a1b2c3d -- scripts/recovery.ps1
```

From the parent of its deletion commit:

```bash
git restore --source=abc1234^ -- scripts/recovery.ps1
```

This restores the file to your working tree.

Git 2.55 documents `--source=<tree>` specifically for taking file contents from another commit, branch, or tag. ([Git][9])

To restore and stage it:

```bash
git restore \
    --source=a1b2c3d \
    --staged \
    --worktree \
    -- scripts/recovery.ps1
```

---

## DIVE DEEPER
### 18. Old syntax versus modern syntax

You'll still see the older syntax all over the web:

`git checkout <SHA> -- path/to/file`

- Yes, It STILL works... but there's a more modern equivalent: 
  - `git restore --source=<SHA> -- path/to/file`

**Similarly, the old:**  → `git checkout feature-x` ~~> **Modern:** `git switch feature-x`

A good mental split is:

```text
switch   -> branches / HEAD
restore  -> files
```

while `checkout` historically did both.

---

### 19. Find files deleted between an old branch and current branch

Suppose:

```text
old-release
main
```

and you want files that existed in `old-release` but were deleted by `main`:

```bash
git diff \
    --name-status \
    --diff-filter=D \
    old-release..main
```

Current HEAD:

```bash
git diff \
    --name-status \
    --diff-filter=D \
    old-release..HEAD
```

Only filenames:

```bash
git diff \
    --name-only \
    --diff-filter=D \
    old-release..HEAD
```

This is extremely useful for what you're describing.

---


### 20. Compare every file between two historical points

```bash
git diff --name-status <OLD>..<NEW>
```

Example:

```bash
git diff --name-status release-2025..main
```

Typical output:

```text
A       scripts/new.ps1
M       README.md
D       scripts/old-recovery.ps1
R100    old-name.ps1 new-name.ps1
```

Meaning:

```text
A = Added
M = Modified
D = Deleted
R = Renamed
```

Deleted only:

```bash
git diff --name-status --diff-filter=D OLD..NEW
```

Added only:

```bash
git diff --name-status --diff-filter=A OLD..NEW
```

Renamed:

```bash
git diff --name-status --diff-filter=R OLD..NEW
```

---

### 21. Search every reachable branch for a filename

On Bash/zsh:

```bash
git rev-list --objects --all | grep -i 'recovery.ps1'
```

On PowerShell:

```powershell
git rev-list --objects --all |
    Select-String -Pattern 'recovery.ps1'
```

Another useful PowerShell search:

```powershell
git log --all --full-history --name-only --pretty=format: |
    Sort-Object -Unique |
    Select-String -Pattern 'recovery'
```

Bash/zsh equivalent:

```bash
git log --all --full-history --name-only --pretty=format: |
    sort -u |
    grep -i recovery
```

---

### 22. Search history for code/content, not filename

Find commits where the number of occurrences of a literal string changed:

```bash
git log --all -S'function show-help'
```

Show patches:

```bash
git log --all -p -S'function show-help'
```

Search changes matching a regex:

```bash
git log --all -G'recovery.*branch' -p
```

This is invaluable when:

> "I don't remember what the file was called, but I remember it contained `Invoke-RepoRecovery`."

Use:

```bash
git log --all -S'Invoke-RepoRecovery' -p
```

Git calls `-S`/`-G` the pickaxe search mechanisms. ([Git][8])

---

### 23. Find commits unique to a branch

Commits in `feature-x` but not `main`:

```bash
git log main..feature-x --oneline
```

Commits in `main` but not `feature-x`:

```bash
git log feature-x..main --oneline
```

Both sides:

```bash
git log \
    --left-right \
    --graph \
    --decorate \
    --oneline \
    main...feature-x
```

Very useful for identifying orphaned feature work.

---

### 24. Find local commits that never reached a remote

Useful after forgotten branches or failed pushes:

```bash
git log --branches --not --remotes --oneline --decorate
```

A more visual version:

```bash
git log \
    --branches \
    --not --remotes \
    --graph \
    --decorate \
    --oneline
```

Those deserve attention before deleting anything.

---

## DO-ABLE
### 25. Cherry-pick recovered work

Suppose you find:

```text
abc1234
```

and want its change applied to `main`:

```bash
git switch main
```

Then:

```bash
git cherry-pick abc1234
```

Current Git describes `cherry-pick` as applying the changes introduced by existing commits and creating corresponding commits on the current branch. ([Git][10])

I often recommend:

```bash
git cherry-pick -x abc1234
```

when doing recovery work because the resulting commit message records the original SHA.

---

### 26. Cherry-pick several commits

Explicit:

```bash
git cherry-pick abc1234 def5678 999aaaa
```

Contiguous range:

```bash
git cherry-pick abc1234^..def5678
```

Inspect first:

```bash
git log --reverse --oneline abc1234^..def5678
```

Then cherry-pick.

---

### 27. Cherry-pick without automatically committing

Useful when recovering pieces of old work:

```bash
git cherry-pick --no-commit abc1234
```

or:

```bash
git cherry-pick -n abc1234
```

Inspect:

```bash
git diff --cached
```

Then decide:

```bash
git commit
```

---

### 28. Cherry-pick conflict recovery

After fixing conflicts:

```bash
git add <resolved-files>
```

Then:

```bash
git cherry-pick --continue
```

Skip commit:

```bash
git cherry-pick --skip
```

Completely abort:

```bash
git cherry-pick --abort
```

Quit sequencer but leave current state:

```bash
git cherry-pick --quit
```

These are all part of current `cherry-pick` syntax. ([Git][10])

---

### 29. Cherry-pick a merge commit

A merge has multiple parents, so Git needs the mainline:

```bash
git cherry-pick -m 1 <merge-SHA>
```

Inspect parents first:

```bash
git show --no-patch --pretty=raw <merge-SHA>
```

Don't blindly assume `-m 1`; verify which parent represents the base you want.

---

### 30. Safest way to recover a mystery commit

If you find:

```text
abc1234
```

don't immediately manipulate `main`.

First anchor it:

```bash
git branch rescue/abc1234 abc1234
```

Inspect:

```bash
git log --graph --decorate --oneline rescue/abc1234
```

```bash
git show --stat rescue/abc1234
```

```bash
git diff main...rescue/abc1234
```

Then either:

```bash
git switch rescue/abc1234
```

or:

```bash
git switch main
git cherry-pick abc1234
```

---
## DELIVERABLE
### 31. My recommended "repo forensic sweep"

This is the sequence I'd use on one of your questionable repos:

```bash
# --------------------------------------------------------------------------
# PHASE 1 - Identify repository/state
# --------------------------------------------------------------------------

git --version
git status --short --branch
git rev-parse --show-toplevel
git rev-parse --short HEAD
git branch --show-current
git show -s --decorate --format=fuller HEAD

# --------------------------------------------------------------------------
# PHASE 2 - Inventory refs
# --------------------------------------------------------------------------

git branch -avv
git worktree list
git show-ref

# --------------------------------------------------------------------------
# PHASE 3 - Visualize reachable history
# --------------------------------------------------------------------------

git log \
    --all \
    --graph \
    --decorate \
    --date=iso \
    --pretty=format:'%h %ad %d %s [%an]'

# --------------------------------------------------------------------------
# PHASE 4 - Search reflogs
# --------------------------------------------------------------------------

git reflog show \
    --all \
    --date=iso \
    --pretty='%h %gd %cd %gs'

# --------------------------------------------------------------------------
# PHASE 5 - Look for unreachable history
# --------------------------------------------------------------------------

git fsck \
    --full \
    --no-reflogs \
    --unreachable

# --------------------------------------------------------------------------
# PHASE 6 - Find deleted files
# --------------------------------------------------------------------------

git log \
    --all \
    --full-history \
    --diff-filter=D \
    --name-status

# --------------------------------------------------------------------------
# PHASE 7 - Find unpushed/local-only commits
# --------------------------------------------------------------------------

git log \
    --branches \
    --not \
    --remotes \
    --graph \
    --decorate \
    --oneline
```

That is essentially a **read-only Git archaeological survey**.

---
## DANGEROUS
### 32. Commands I would NOT run during initial recovery

Until you're sure you've found everything, avoid:

```bash
git gc
```

```bash
git prune
```

```bash
git reflog expire
```

```bash
git reset --hard
```

```bash
git clean -fd
```

```bash
git clean -fdx
```

```bash
git branch -D <branch>
```

```bash
git switch -C <branch>
```

and I would also avoid:

```bash
git fetch --prune
```

during the initial forensic sweep.

Some of those can erase or move exactly the evidence you're trying to recover.

`git fsck`, by contrast, is designed to inspect connectivity and identify unreachable/dangling objects. ([Git][7])

---

[1]: https://git-scm.com/?utm_source=chatgpt.com "Git"
[2]: https://git-scm.com/docs/git/2.50.0.html "Git - git Documentation"
[3]: https://git-scm.com/docs/git-switch "Git - git-switch Documentation"
[4]: https://git-scm.com/docs/git-branch?utm_source=chatgpt.com "Git - git-branch Documentation"
[5]: https://git-scm.com/docs/git-switch?utm_source=chatgpt.com "Git - git-switch Documentation"
[6]: https://git-scm.com/docs/git-reflog.html?utm_source=chatgpt.com "Git - git-reflog Documentation"
[7]: https://git-scm.com/docs/git-fsck?utm_source=chatgpt.com "Git - git-fsck Documentation"
[8]: https://git-scm.com/docs/git-log?utm_source=chatgpt.com "Git - git-log Documentation"
[9]: https://git-scm.com/docs/git-restore?utm_source=chatgpt.com "Git - git-restore Documentation"
[10]: https://git-scm.com/docs/git-cherry-pick?utm_source=chatgpt.com "Git - git-cherry-pick Documentation"
[11]: https://git-scm.com/docs/git-restore.html?utm_source=chatgpt.com "Git - git-restore Documentation"
