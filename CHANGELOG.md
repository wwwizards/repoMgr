
# CHANGELOG:

![alt text](BACKLOG-v0.6.3.md-RepoMgr-OnePage.png)
---
##     **260827 - 0.2.0** - Initial port from previous BASH version.

---
##     **260828 - 0.3.x** - Added -risk option for analyzing detached HEAD state (single‑repo).

---
##     **260830 - 0.3.2** - Updated version and ensured -risk option is documented.

---
##     **260830 - 0.4.0** - Added:
* bounded traversal via config $lookback (with override)
* automatic JSON output to repoMgr‑logs
* archival‑branch detection for detached HEAD
* DR‑branch creation (existing, now risk‑aware)
* divergence checks vs primary branch (main/master)
* stale‑commit detection
* destructive‑commit classification
* risk scoring with severity buckets
* root + Agile‑Wizard repo role awareness

---
##     **260830 - 0.5.0** - refactored from v0.4 for speed & efficiency on deep & wide repo-traversals:
* Smart Divergence (merge‑base bounded traversal)
* Forensic Mode (metadata‑only, JSON output)
* Archival branch detection for detached HEAD
* DR branch creation retained
* Divergence checks vs primary branch (main/master)
* Stale‑commit detection
* Destructive‑commit classification (crude but useful)
* Risk scoring with role‑sensitive thresholds (Root vs Agile‑Wizard vs Standard)
* Root + Agile‑Wizard sensitivity hooks for future tuning

---
##     **260831 - 0.5.1** - Fixed CFG-INFO invalid variable name (renamed to $cfgInfo) causing a
script-wide ParseException, and moved the INIT log call to after the
log function definition to fix call-before-definition order.

---
##     **260901 - 0.5.2** - Fixed three bugs:
* **(BUG)** fixed: $root shell-tokenizer quirk: -root='path' passes literal
           '-root=C:\path' string; added sanitization + guard + user warning.
* **(BUG)** fixed: Get-ChildItem -Directory cascade failure was caused entirely
           by the poisoned $root value above — no independent fix needed.
* **(DESIGN)** get-repoList never checked $root itself for .git; it only
           recursed into subdirs. Added self-check so -root targeting a
           single leaf repo (e.g. .AI-TRAINING) works correctly.

---
##     **260901 - 0.5.3** - Added Show-PendingChanges helper: replaces flat one-liner
      with Format-Table view. Parses XY porcelain codes into
      Action/Scope/File columns. Summary count header included.
      -Grouped switch available for large dirty repos.

---
##     **260901 - 0.5.4** - Fixed three post-table bugs surfaced by -all -dryrun run:
* **(BUG)** fixed: Nested detection false-positive: parent dir scan re-flagged
        $root as nested. Added Resolve-Path equality guard.
* **(BUG)** fixed: Reintegration double-path: Join-Path $root $repo.Name
        doubled the leaf dir name. Now uses $repo.FullName + root guard.
* **(UX)**  Silent empty history: git log returning nothing left a blank
        line. Now prints "(no commits in window)" fallback.
* **(PATCH)**  Updated create-drBranches to guard against re-creating an existing DR branch.

---
##     **260903 - 0.6.0** -  multiple improvements and new features added.
* **(ADD)** Added dry-run support for create-drBranches: prints planned actions without executing them.
* **(BUG)** fixed: now restores the pointer to the original branch after creating DR branch.
* **(ADD)** new functions for repository topology and risk analysis.
     * (NEW) FUNCTION: Get-RemoteCollisions - Detects remote URL collisions (multiple dirs → same remote) among submodules and nested Git repositories.
     * (NEW) FUNCTION: Write-TopologySnapshot - Captures the current topology of all repositories, including roles, branches, and remotes.
     * (NEW) FUNCTION: Write-RiskReport - Generates a risk analysis report for all repositories, including remote collisions.
     * (NEW) MVx-FUNCTION: analyze-fileOverlap - Detects overlapping file changes between two branches by comparing the last modification dates of each file.
* **(ADD)** dry-run support for create-drBranches and ensured original branch is restored after DR branch creation.
* **(MOD)** -all now includes -topology and -collisions as well.
* **(MOD)** DR branch creation now requires -Force to execute, otherwise it will be skipped in dry-run mode.
* **(MOD)** Updated help information to reflect new features and changes.
* **(MOD)** Improved error handling and logging for all operations.
* **(MOD)** General code cleanup and refactoring for better maintainability and improved UX.
* **(MOD)** Updated repository analysis functions to include additional metrics and improved reporting.
* **(MOD)** Enhanced logging for repository backup and recovery operations - improved visibility into success and failure events
* **(MOD)** Improved handling of nested Git repositories and submodules for all operations - enhanced detection and management of nested structures
* **(MOD)** Agent-friendly improvements for better integration with CI/CD pipelines & AI-assisted workflows.

---
##     **260904 - 0.6.1** -  minor UX improvements and tweaks.

---
##     **260905 - 0.6.2** - Patch release

* **(FIX)** Normalize-RemoteUrl: strip trailing .git, normalize host/path case, support HTTP(S) and SSH forms.
* **(FIX)** Get-RemoteCollisions: normalize .gitmodules and nested repo remotes before grouping; log REMOTE-COLLISION events.
* **(FIX)** Analyze-AllRepoRisk: safe divergence compare ref when HEAD is detached; avoid misleading rev-list errors.
* **(FIX)** Dry-run/Force semantics: Write-RiskReport and Create-ArchivalBranchIfDetached respect DRYRUN and -Force consistently.
* **(MOD)** Write-TopologySnapshot: include OriginUrl and write topology JSON to repoMgr-logs/topology-<timestamp>.json.
* **(UX)** Improved logging: DRYRUN banners, idempotent DR branch guards, quieter repeated-run output.
* **(TEST)** Defensive checks: include $root in get-repoList when it is a repo; guard missing remote outputs.
---