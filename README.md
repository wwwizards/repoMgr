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
# UPDATED:  260915 BY: SOLOMON(MAI-Code-1.1-Flash)::Copilot::repoMgr.WIZ-00.TOOLS
# COMPANY:  LogicWizards.NYC <LogicWizards.NYC>
# VERSION:  v0.6.4.4
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
#     -NoExecute        # Imports the function library without executing the default workflow.
#--------------------------------------------------------------------------#>
```

| Related docs | Purpose |
| --- | --- |
| [advanced-git-recovery-commands.md](advanced-git-recovery-commands.md) | Git forensics, recovery, detached HEAD, and branch archaeology cheatsheet & playbook. |
|AGENTS.md  | Guardrails for AI-Assisted R&D|
| [BACKLOG-v0.6.3.md](BACKLOG-v0.6.3.md) | Active backlog, operational notes, and dispatcher/UX rationale. |
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes for repoMgr. |
|ROADMAP.md| Living doc for tracking SDLC-STATE|

![alt text](BACKLOG-v0.6.3.md-RepoMgr-OnePage.png)

## Overview
repoMgr is a PowerShell-based monorepo workflow manager for Git repositories. It discovers nested repos, records topology, detects remote collisions, analyzes drift and detached HEAD risk, creates DR branches, and produces JSON logs for downstream AI-assisted workflows and handoff documentation.

## Mission context
This project is not just a general monorepo utility - although it will likely become one. It was born out of necessity, and, as of this writing, is operating in a live recovery/discovery and triage context for a corrupted repo environment, where `repoMgr.ps1` is serving as a forensic tool and a DR-support workflow while the broader remediation effort is still in progress.

The current live baseline is proven by the 260914 run in REPORT-260914-all-backup-recovery.txt: the script was executed in dry-run mode with `-all -backup -recovery`, the root repo was active on `DEV` with 79 pending changes, and the `.AI-TRAINING` repo was already on a DR branch (`RepoMgr-DR-260901`) with 68 pending changes. The repeated `repoMgr-logs` and `topology-*.json` artifacts are part of the operational workflow, not incidental output.

The refactor roadmap must therefore preserve the current recovery/discovery behaviors that are already serving the active incident:
- topology capture for repo correlation and collision analysis
- remote-collision detection for bad-bot fallout and repo drift
- detached-HEAD and divergence risk reporting
- DR branch creation as a safe snapshot/rollback path
- dry-run-first reporting so the tooling can be used without rerailing recovery work
- structured JSON artifacts that support downstream triage, handoff analysis, and ETL-style recovery planning

The architecture cleanup is intended to improve maintainability without disrupting the operational triage flow or the larger recovery effort. In practical terms, every refactor remains dry-run-safe and must not rerail the active forensic workflow.

## Version
v0.6.4.4

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
- Mission-aware validation coverage for recovery/discovery and triage support
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
.\repoMgr.ps1 -NoExecute
.\repoMgr.ps1 -Force -recovery
```

The default operational mode is safe: the script runs in dry-run mode unless `-Force` is supplied. This prevents accidental branch creation or destructive changes while still allowing inspection and reporting tasks to run.

## Testing
Use the project’s preferred harness:

```powershell
psst repoMgr
```

The validation suite is intentionally scoped to disposable Git fixtures created under the system temp directory. This keeps the live monorepo and any active recovery workspace out of the test path while still exercising the real dry-run behavior, DR branch safety checks, topology reporting, and risk analysis logic.

This runs the validation set for:
- repoMgr.sanity.Tests.ps1
- repoMgr.smoke.Tests.ps1
- repoMgr.unit.Tests.ps1
