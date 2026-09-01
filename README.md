# repoMgr — LogicWizards Monorepo Multi‑Tool Manager

## Version
0.2.2

## Features
- Full backup + safe-copy archive to the configured destination
- Repo discovery and nested repo detection
- Repo drift reporting with branch status and recent history
- DR branch creation for all repos or dirty repos only
- Reintegration scaffold for nested repositories
- Detached HEAD recovery helpers
- JSON logging under the repo root log folder
- Dry-run mode for safe simulation
- Pester-compatible validation suite

## Configuration
The script reads repoMgr.config.psd1 and uses the following values:
- root: monorepo root directory
- safedest: backup destination
- lookback: git history window, such as "120 days ago"
- drBranch: disaster-recovery branch name

## Usage
.\repoMgr.ps1 -help
.\repoMgr.ps1 -backup
.\repoMgr.ps1 -stats
.\repoMgr.ps1 -recovery
.\repoMgr.ps1 -recovery -dirtyonly
.\repoMgr.ps1 -reintegration
.\repoMgr.ps1 -dryrun
.\repoMgr.ps1 -all

The -all switch runs the full lifecycle sequence: backup, stats, nested repo detection, DR branch creation, and reintegration scaffolding.

## Testing
Use the project’s preferred harness:
psst repoMgr

This runs the validation set for:
- repoMgr.sanity.Tests.ps1
- repoMgr.smoke.Tests.ps1
- repoMgr.unit.Tests.ps1
