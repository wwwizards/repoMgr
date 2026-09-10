# repoMgr — LogicWizards Monorepo Multi‑Tool Manager
```
<#--------------------------------------------------------------------------
#  SCRIPT: repoMgr.ps1 — LogicWizards Monorepo Multi‑Tool Manager
#--------------------------------------------------------------------------
# PURPOSE:  Manages various tasks within a monorepo, including backups, statistics,
#           risk analysis, and reintegration for a multi‑repo / monorepo layout.
# ABSTRACT: Provides a comprehensive set of tools for managing a monorepo, including:
#           - Backup (SafeCopy)
#           - Repo drift statistics
#           - DR branch creation
#           - Nested repo reintegration scaffold
#           - Detached HEAD risk analysis (Option‑D: Smart Divergence + Forensic Mode)
# REQUIRES: Git, PowerShell 7+, and a repo or submodule checkout.
# CREATED:  260828 BY: Joe Negron (LogicWizards.NYC)
# UPDATED:  260910 BY: Copilot (Docs sync: README + CHANGELOG aligned to v0.6.3 behavior)
# COMPANY:  LogicWizards.NYC <LogicWizards.NYC>
# VERSION:  0.6.3 - synced to the current dispatcher, topology, collision, and risk-reporting flow
#           SEE: CHANGELOG.md for more details
# LICENSE:  AGPL-3.0 <https://www.gnu.org/licenses/agpl-3.0.html> 
#               ~ FEE: $00 = for academic and non-commercial use. (requires attribution)
#               ~ FEE: $20 = for individual commercial DEV use (requires separate licensing & registration).
#               ~ FEE: $99 = for commercial use (requires separate licensing & registration - bulk pricing is available).
# NOTES:  Ensure that the configuration file is correctly set up to avoid unexpected behavior.
# USAGE:
#     .\repoMgr.ps1 -help
#     .\repoMgr.ps1 -stats -topology -risk
#     .\repoMgr.ps1 -backup
#     .\repoMgr.ps1 -recovery -dirtyonly
#     .\repoMgr.ps1 -reintegration
#     .\repoMgr.ps1 -all
#     .\repoMgr.ps1 -Force -recovery
# OPTIONS:
#     -backup           # Performs a backup of the repository (SafeCopy ZIP + copy to safedest).
#     -stats            # Displays drift statistics about all discovered repositories.
#     -topology         # Captures the current topology of all repositories (roles, branches, remotes).
#     -risk             # Analyzes remote collisions and detached HEAD risk across repos.
#     -collisions       # Detects remote URL collisions among submodules and nested Git repos.
#     -recovery         # Creates DR branches for repositories (optionally only dirty ones).
#     -reintegration    # Handles reintegration scaffold tasks for nested repositories.
#     -dirtyonly        # Operates only on dirty repositories (for DR branch creation).
#     -dryrun           # Simulates actions without making any changes (default unless -Force is set).
#     -Force            # Enables destructive or mutating operations.
#     -help             # Displays this help message.
#     -all              # Runs the workspace-level reporting flow plus deeper repo analysis.
#--------------------------------------------------------------------------#>
```

| Related docs | Purpose |
| --- | --- |
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes for repoMgr. |
| [BACKLOG-v0.6.3.md](BACKLOG-v0.6.3.md) | Active backlog, operational notes, and dispatcher/UX rationale. |
| [advanced-git-recovery-commands.md](advanced-git-recovery-commands.md) | Git forensics, recovery, detached HEAD, and branch archaeology playbook. |

![alt text](BACKLOG-v0.6.3.md-RepoMgr-OnePage.png)

## Overview
repoMgr is a PowerShell-based monorepo workflow manager for Git repositories. It discovers nested repos, records topology, detects remote collisions, analyzes drift and detached HEAD risk, creates DR branches, and produces JSON logs for downstream AI-assisted workflows and handoff documentation.

## Version
0.6.3

## Features
- Full backup + safe-copy archive to the configured destination
- Recursive repo discovery, including the root repo when it is itself a Git checkout
- Repo drift reporting with branch status, dirty-state checks, and recent history
- Remote collision detection across nested repos and submodules
- Topology snapshot export to JSON under the repo log directory
- Risk analysis for detached HEAD and smart-divergence comparisons
- DR branch creation with dry-run safety and Force-gated execution
- Reintegration scaffold for nested repositories
- JSON logging under the repo root log folder
- Safe default mode: dry-run unless -Force is explicitly specified
- Pester-compatible validation suite

## Configuration
The script reads repoMgr.config.psd1 and uses the following values:
- root: monorepo root directory
- safedest: backup destination
- lookback: Git history window such as "30 days ago"
- drBranch: disaster-recovery branch prefix

## Usage
```powershell
.\repoMgr.ps1 -help
.\repoMgr.ps1 -stats
.\repoMgr.ps1 -topology
.\repoMgr.ps1 -risk
.\repoMgr.ps1 -collisions
.\repoMgr.ps1 -backup
.\repoMgr.ps1 -recovery -dirtyonly
.\repoMgr.ps1 -reintegration
.\repoMgr.ps1 -all
.\repoMgr.ps1 -Force -recovery
```

The default operational mode is safe: the script runs in dry-run mode unless `-Force` is supplied. This prevents accidental branch creation or destructive changes while still allowing inspection and reporting tasks to run.

## Testing
Use the project’s preferred harness:

```powershell
psst repoMgr
```

This runs the validation set for:
- repoMgr.sanity.Tests.ps1
- repoMgr.smoke.Tests.ps1
- repoMgr.unit.Tests.ps1
