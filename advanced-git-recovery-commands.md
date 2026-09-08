Yes. For what you’re doing, I’d make the cheatsheet **Git forensics/recovery-first**, not just day-to-day Git.

As of **September 7, 2026**, the latest Git source release is **2.55.0**, released June 29, 2026. The commands below are aligned to the current Git documentation. ([Git][1])

# Git 2.55 — Repo Forensics, Recovery & Branch Archaeology Cheatsheet
## TL;DR SUMMARY

### The four recovery commands worth memorizing

**If I had to reduce this entire sheet to four commands:**

 1. `git log --all --graph --decorate --oneline` - **What's still reachable?**
 1. `git reflog --date=iso` - **Where did HEAD used to point?**
 1. `git fsck --full --no-reflogs --unreachable` - **What's still physically in the object database but no longer referenced?**
 1. `git branch rescue/<name> <SHA>` - **Protect the thing you found before doing anything else.**

**And for missing files, add a fifth:**
 
 5. `git log --all --full-history --diff-filter=D --name-status` - **What files were deleted, and when?**

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

## Git 5-Min Review  
  
Git offers various commands to interact with repositories, and understanding their purposes is crucial for effective version control. Below is a detailed comparison:
### 1. `git show`  
  
- **Purpose:** Display detailed information about a specific commit, branch, or object.  
- **Primary Use Case:** Inspect commits including changes, metadata like author and date, and commit messages.  
- **Common Syntax:**  
  
```bash
git show <long-or-short-commit-hash>
git show HEAD
git show branch-name
```
- **Example:**  `git show abc123`

This shows the commit `abc123` with the patch, commit message, author, and date.
- **Notes:**    
  - Mostly used for checking changes without switching branches.    
  - Can also be used to see details about tags and other Git objects.  
  
### 2. `git branch`  
  
- **Purpose:** Manage and display branches in a repository.  
- **Primary Use Case:** Create, delete, list branches, or check which branch you are on.  
- **Common Usage:**   
    >    ```bash
    >    git branch                  # List all local branches
    >    git branch -r               # List remote branches
    >    git branch new-feature      # Create a new branch
    >    git branch -d old-feature   # Delete a branch
    >    ```
    > #### Example: `git branch main develop feature/login`
    > Here's a breakdown of what it does and some important clarifications.
    > ##### What `git branch` REALLY Does  
    >   
    > - The `git branch` command is used to **list, create, or delete branches** in a Git repository.  
    > - The usual syntax for creating new branches is: ` git branch <branch-name>`
    > You can also specify multiple branch names after `git branch` to create them all at once: `git branch branch1 branch2 branch3`
    > ###### Interpretation of Example Command  
    >   
    > The example command will **create three new branches** in your local repository: 
    > ```
    >1. `main` – this will create a branch named `main` starting from your current HEAD. If `main` already exists, Git will show an error.    
    > 2. `develop` – creates a branch named `develop` starting from the current commit.    
    > 3. `feature/login` – creates a branch named `feature/login`, also from the current commit.    
    > ```  
    > ###### Important Notes:  
    > - Branches are **not automatically switched to - when created**. Your current branch remains the same. 
    >   - To switch to a branch, you would use `git checkout <branch-name>` or `git switch > <branch-name>` - as detaild in next section  
    > - If `main` already exists (as is typical in most repositories), running this command may produce an error for that branch, while the other branches are created >    successfully.  
    > - Using a slash `/` in branch names (like `feature/login`) is fully supported in Git and considered a convention for grouping feature branches.  
    >   
    > ###### A Practical Example  
    > Suppose you are currently on branch `master` (or any branch), running: ` git branch main develop feature/login`
    > - `main` is attempted to be created from your current commit.  
    > - `develop` is attempted to be created from your current commit.  
    > - `feature/login` is attempted to be created from your current commit.  
    > - You remain on your original branch.  
    >   
    > To switch and work on the `develop` branch, use: ` git checkout develop` -or- `git switch develop` - these are essentially the same: the former is considered *"legacy"*  and the later *"modern"*...
    > ###### Summary  
    > The command: `git branch main develop feature/login` **creates three new branches locally** starting from your current commit, but it **does not switch** to any of them.     After creating a branch we MUST then switch to any of these branches to start working on them...
    > 
    >  - `git branch` does **NOT** switch branches by default.    
    >  - It’s mainly for branch management rather than exploring commits.  
  
### 3. `git switch`  
  
- **Purpose:** Switch between branches or create a new branch and switch to it in one step.  
- **Primary Use Case:** Change the current working branch.  
- **Common Syntax:**  
  
```bash
git switch branch-name       # Switch to an existing branch
git switch -c new-branch     # Create and switch to a new branch
```
- **Example:**  `git switch develop`
  - **Notes:**    
    - Because git checkout performs multiple roles, it can be confusing or risky for new users.
      - Mistaken usage could overwrite changes unintentionally.
    - `git switch` was introduced as the more *"modern"* and simpler alternative to `git checkout` for switching branches.    
      - It does **NOT** show commit details; its focus is only on changing working branches.  
  
### Summary Comparison Table  
  
| Command        | Purpose                          | Main Use                   | Affects Working Directory?  |  
|----------------|----------------------------------|----------------------------|-----------------------------|  
| `git show`     | Inspect commits or objects       | View changes, metadata     | No                          |  
| `git branch`   | Manage branches                  | List/create/delete branches| No                          |  
| `git switch`   | Switch or create branches        | Change current branch      | Yes                         |  
  
  
### Key Takeaways  
- Use **`git show`** to inspect commits without switching branches.    
- Use **`git branch`** to manage or list branches.  
- Use **`git switch`** to move between branches or create new ones.    
  
This understanding helps you navigate and manage your Git workflow efficiently.


Source(s):  
[^1^]: https://stackoverflow.com/questions/57265785/whats-the-difference-between-git-switch-and-git-checkout-branch  
[^2^]: https://stackoverflow.com/questions/10002239/difference-between-git-checkout-track-origin-branch-and-git-checkout-b-branch  
[^3^]: https://learn.microsoft.com/en-us/visualstudio/version-control/git-browse-repository?view=visualstudio  
[^4^]: https://git-scm.com/docs/git-switch

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

| Command                    | Meaning                          | Recovery safety                   |
|----------------------------|----------------------------------|-----------------------------------|
| `git -C /repo status`      | Run Git inside `/repo`           | SAFE                              |
| `git switch -c rescue SHA` | Create new branch at SHA         | SAFE                              |
| `git switch -C rescue SHA` | Force-create/reset branch at SHA | :exclamation:CAUTION:exclamation: |
| `git branch rescue SHA`    | Create pointer without switching | VERY SAFE                         |

Current `switch` syntax is:

```bash
git switch <branch>
git switch --detach <commit>
git switch -c <new-branch> [<start-point>]
git switch -C <new-branch> [<start-point>]
```

> **:exclamation:CAUTION - DON'T LEARN THIS THE HARD WAY  :exclamation:** 
> - Lower-Case `-c` creates a new branch; 
> - Upper-Case `-C` does the same **!!! BUT IT RESETS THE BRANCH IF IT ALREADY EXISTS !!!**. ([Git][3])

**For recovery, prefer:** `git branch rescue-20260907 <SHA>` **or:** `git switch -c rescue-20260907 <SHA>` **rather than:** `git switch -C rescue-20260907 <SHA>`

---

## DIAGNOSE
---
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
- **Detailed & Decorated**  → `git reflog --date=iso --decorate`
- **Decorated locals-ONLY**  → ` git reflog --date=iso --decorate-refs=refs/heads --pretty=oneline`
- **FULL Formatted w/COLOR:**  → ` git reflog -n 20 --pretty=format:"%C(#FFA500)%h %Creset %C(blue)%cd %Creset %C(green) %gs %<(110,trunc)" --date=iso`

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
  
and you can alwats cross reference with things like `git show-ref` AND `git branch -aav` to shed more light on your discover & recover efforts...

> **:exclamation: IMPORTANT NOTES - FOR PROCRASTINATORS: :exclamation:**  
> - **YES: Reflogs are your friend.** They are specifically designed to record previous ref-pointer values as well as HEAD & branch-switch activity... 
>   - **BUT:** Current Git defaults generally expire reachable reflog entries after 90 days and unreachable entries after 30 days unless configuration changes those values...  **.: recovery work should be done sooner rather than later!** ([Git][6])

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

- **First:**  → `git reflog --date=iso` to find the detached commits.

- **Then:**  → `git show <SHA>`
- **Protect them:**  → `git branch rescue-detached <SHA>`
- **or:**  → `git switch -c rescue-detached <SHA>`
---

### 10. Find unreachable / dangling commits

- **If reflog isn't enough:**  → `git fsck --full`
- **More useful for archaeology:**  → `git fsck --full --unreachable`
- **And particularly:**  → `git fsck --full --no-reflogs --unreachable`
  >**Q:  Why `--no-reflogs`?** 
  > > **A:** Normally `fsck` treats reflog entries as roots, meaning commits referenced only through reflogs aren't considered unreachable.`--no-reflogs` lets you expose commits that aren't reachable from a normal branch/tag/ref. ([Git][7])

  - **Let's take a look at some example output:**
    > ```text
    > unreachable commit 4c391ab...
    > unreachable tree   ee8291...
    > unreachable blob   83ab922...
    > ```
**NOW We Can:**
- **Inspect a commit:** → `git show 4c391ab`
- **Inspect its tree:** → `git ls-tree -r 4c391ab`
- **Protect it:** → `git branch rescue-fsck 4c391ab`

---

### 11. Last-resort lost-found

- **Git can write dangling objects into:** → `.git/lost-found/`
  - **with:** → `git fsck --full --lost-found`
    - **Git places dangling commits under:** → `.git/lost-found/commit/`
    - **and other recovered objects under:** → `.git/lost-found/other/`
This is explicitly supported by `git fsck`. ([Git][7])

I would run ordinary `fsck` first and only use `--lost-found` when you actually need it.

> NOTES for Windows users:
> On Windows, there is no direct fsck command like in Linux/Unix, but the closest equivalents for checking and repairing file systems are:
>
> **1. chkdsk (Classic Tool)**
> chkdsk is the built-in Windows utility for checking and repairing NTFS/FAT file systems.
>
> - **Example:** Check and repair drive D: `chkdsk D: /f /r /x`
>   - ***where:*** 
>     - `/f` – Fix errors on the disk
>     - `/r` – Locate bad sectors and recover readable information
>     - `/x` – Force dismount before checking
> 
> 
> **2. PowerShell Native Equivalent — Repair-Volume**
> Starting with Windows Server 2012 and Windows 8, PowerShell introduced Repair-Volume, which is essentially the modern replacement for chkdsk.
>
> - **Examples:**
>   - Scan only (no changes): `PowershellRepair-Volume -DriveLetter D -Scan`
>   - Spot fix (quick repair without full offline scan): `PowershellRepair-Volume -DriveLetter D -SpotFix`
>   - Offline full repair (requires dismount): `PowershellRepair-Volume -DriveLetter D -OfflineScanAndFix`
> 
> **3. For Linux File Systems (ext2/3/4) on Windows**
> 
>  If you need a true fsck for ext partitions (e.g., from Linux or Android SD cards), Windows cannot natively run fsck. BUT: you have two main options:
>   1. WSL (Windows Subsystem for Linux) — Install Ubuntu/Debian in WSL and run:Bashsudo fsck /dev/sdXn
>   2. Third-party tools like DiskGenius or Ext2Fsd to mount and repair ext partitions.
> 
> ✅ **Recommendations:**
> - For NTFS/FAT → Use Repair-Volume in PowerShell (modern) or chkdsk (classic).
> - For ext → Use WSL or boot into Linux.


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

First anchor it: `git branch rescue/abc1234 abc1234`

Then Inspect: 
```
    git log --graph --decorate --oneline rescue/abc1234
    git show --stat rescue/abc1234
    git diff main...rescue/abc1234
```

Then either: `git switch rescue/abc1234` or: `git switch main; git cherry-pick abc1234` -- just be careful...

---
## DELIVERABLE
### 31. My recommended "repo forensic sweep"

This is the shell agnostic sequence I'd use on one of your questionable repos:

```bash

function gitfor(){
# --------------------------------------------------------------------------------
# FUNCTION: gitfor - lightweight forensic analyzer for git repos
# --------------------------------------------------------------------------------
# ABSTRACT: This function should work in almost any modern OS-agnostic shell. 
#           Tested on: pwsh/bash/zsh - you may need to tweak it for your OS.
#  CREATED: 200531   BY: Joe Negron <LogicWizards.NYC>
#  UPDATED: 260907
#  VERSION: v0.6.3
#  LICENSE: MIT
#    USAGE: cd <dirname>; gitfor
# SEE-ALSO: inspired by gitsweep, git-sweep & gitalyzer
# --------------------------------------------------------------------------------

    date
    pwd
    echo ''
    git config --global pager.branch false
    git config --global pager.diff false
    git config --global pager.show false
    git config --global pager.log false
    git config --global pager.reflog false
    git config --global pager.status false
    git config --global log.decorate short

    echo '# --------------------------------------------------------------------------'
    echo '# PHASE 1 - Identify repository/state'
    echo '# --------------------------------------------------------------------------'
    git --version
    echo " - status:    $(git status --short --branch)"
    echo " -    top:    $(git rev-parse --show-toplevel)"
    echo " -   head:    $(git rev-parse --short HEAD)"
    echo " - branch:    $(git branch --show-current)"
    echo " - fuller:"
    git show -s --decorate --format=fuller HEAD

    echo '# --------------------------------------------------------------------------'
    echo '# PHASE 2 - Inventory refs'
    echo '# --------------------------------------------------------------------------'
    echo " - branches:  "
    git branch -avv 
    echo " - worktree:  $(git worktree list)"
    echo " - show-ref: "
    git show-ref

    echo '# --------------------------------------------------------------------------'
    echo '# PHASE 3 - Visualize reachable history'
    echo '# --------------------------------------------------------------------------'
    git log --all --graph --pretty=format:"%C(#FFA500)%h%Creset %C(blue)%ad%Creset %<(110,trunc)%s" --date=iso --since="30 days ago"
    echo ''

    echo '# --------------------------------------------------------------------------'
    echo '# PHASE 4 - Showing reflogs'
    echo '# --------------------------------------------------------------------------'
    git reflog --date=iso  --decorate-refs=*

    echo '# --------------------------------------------------------------------------'
    echo '# PHASE 5 - Showing unreachable - git fsck --full --no-reflogs --unreachable'
    echo '# --------------------------------------------------------------------------'
    git fsck --full --no-reflogs --unreachable

    echo '# --------------------------------------------------------------------------'
    echo '# PHASE 6 - Find deleted files'
    echo '# --------------------------------------------------------------------------'
    git log --all --full-history --diff-filter=D --name-status

    echo '# --------------------------------------------------------------------------'
    echo '# PHASE 7 - Find unpushed/local-only commits'
    echo '# --------------------------------------------------------------------------'
    git for-each-ref --format="%(refname:short)" refs/heads/ > tmp.txt;  cat tmp.txt | git log --stdin --not --remotes --graph --color=always --pretty=format:"%C(auto)%C(#FFA500)%h%Creset %C(#666666)(t:%<(7,trunc)%t p:%<(7,trunc)%p) %C(blue)%ad%Creset %C(#666666)(%cr) %Creset%n%C(cyan) memo >> %Creset%<(110,trunc)%C(yellow)%s%C(auto)%n" --name-status;rm tmp.txt

    # === reset paging to before we started ===
    git config --global --unset pager.branch
    git config --global --unset pager.diff
    git config --global --unset pager.show
    git config --global --unset pager.log
    git config --global --unset pager.reflog
    git config --global --unset pager.status
    git config --global --unset log.decorate short
}

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

during the initial forensic sweep. Some of those can erase or move exactly the evidence you're trying to recover.
- `git fsck`, by contrast, is designed to inspect connectivity and identify unreachable/dangling objects. ([Git][7])

---

[1]: https://git-scm.com/ "Git"
[2]: https://git-scm.com/docs/git/2.50.0.html   "Git - git Documentation"
[3]: https://git-scm.com/docs/git-switch        "Git - git-switch Documentation"
[4]: https://git-scm.com/docs/git-branch        "Git - git-branch Documentation"
[5]: https://git-scm.com/docs/git-switch        "Git - git-switch Documentation"
[6]: https://git-scm.com/docs/git-reflog.html   "Git - git-reflog Documentation"
[7]: https://git-scm.com/docs/git-fsck          "Git - git-fsck Documentation"
[8]: https://git-scm.com/docs/git-log           "Git - git-log Documentation"
[9]: https://git-scm.com/docs/git-restore       "Git - git-restore Documentation"
[10]: https://git-scm.com/docs/git-cherry-pick  "Git - git-cherry-pick Documentation"
[11]: https://git-scm.com/docs/git-restore.html "Git - git-restore Documentation"
