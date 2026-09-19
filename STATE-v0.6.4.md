# repoMgr Roadmap v0.6.4.x
> **Generated: 260917** | **Source:** repoMgr reporting + architecture review
> **Target script version:** v0.6.4.4
> **Targeted Repos For Cleanup:** LogicWizards-core: as identified by `REPORT-260914-all-backup-recovery.txt`
> ***CREATED:** 260918 **BY:** Joe Negron
> ***UPDATES:** 260919 **BY:** Joe Negron
> — See [README.md](README.md), [CHANGELOG.md](CHANGELOG.md), [repoMgr.ps1](repoMgr.ps1), [repoMgr.sanity.Tests.ps1](repoMgr.sanity.Tests.ps1), [repoMgr.smoke.Tests.ps1](repoMgr.smoke.Tests.ps1), and [repoMgr.unit.Tests.ps1](repoMgr.unit.Tests.ps1) for current context.

I will cut through the churn and summarize the actual open work, what’s verified, and what is still pending so you have a clean status snapshot.

## Debrief: current state of the open work

The user is right suspecting that: — the agent, `SOLOMON(MAI-Code-1.1-Flash)::Copilot::repoMgr.WIZ-00.TOOLS`, drifted into side quests and did not correctly report the current SDLC-STATE. The actual state is determined by issueing the `psst repoMgr` command in the assigned terminal `TOOLS` as per guardrails in `AGENTS.md` to run the full regression test suite (smoke, sanity & unit tests) for this repo, and then comparing those results to the combined P1 through P4 priorities as laid out in ROADMAP-v0.7.x.md. 

**Currently:**

- The repo is NOT green.
- The validation gate is STILL the primary task.
- The P4 refactor is STILL blocked by the same real failures, not by a vague “cleanup” backlog.

### Fresh evidence
The latest TOOLS validation run reported:

- Exit code: 13
- Tests Passed: 5
- Failed: 13
- Skipped: 0
- NotRun: 0

This is the current truth, and it is more important than any speculative cleanup.

---

## What is actually OPEN:

### 1) Restore the validation baseline
This is the top priority and remains the real gate.

- Required harness: TOOLS terminal + psst
- Source of truth: `AGENTS.md`
- Validation status: still failing, not “mostly there”

### 2) Fix the root cause in `repoMgr.ps1`
The two concrete problems we confirmed are:

- Spinner/report path is still unstable in the job/task execution path
- Import-only execution still mutates or initializes state in a way that poisons later runs

The failure is reproducible in the reporting flow, with the last red case showing an exception in the risk-report call path from `repoMgr.unit.Tests.ps1:267-278`.

### 3) Finish the P4 separation work
The intended refactor is still:

- separate analysis logic from rendering
- keep dry-run safety intact
- keep reporting output distinct from data generation
- keep the simple spinner UX without breaking task execution

This is still valid work, but it must be derived from the failing green/red gate, not from opportunistic cleanup.

### 4) Clean up the audit/log behavior
There is still a legitimate issue around noisy sidecar files and the daily audit path, but it is secondary. It should not outrank a failing regression suite.

---

## What is not the current problem
These are not the real blockers right now:

- release notes
- broad documentation churn
- older backlog items
- “nice to have” cleanup
- chasing historical artifacts from earlier runs

Those can wait. The active task is to make the current suite green again.

---

## What I have verified
- The repo is under the required TOOLS discipline and is still being checked with the repo’s validation harness.
- We have a real red state in the current branch.
- The failure clusters around the reporting path in `repoMgr.ps1`, not around random repo logic.

I also checked the validation log in `TESTING.md`, and it is not a reliable current-state source unless it is updated with fresh evidence. The active status is the latest run, not the older historical entries.

---

## Recommended next move
The right sequence is simple:

1. Stop broad refactors.
2. Fix the smallest failing regression in the reporting path.
3. Re-run the full suite in TOOLS.
4. Only then continue the P4 and logging cleanup.

That is the disciplined path. The current work is not “rabbit holes”; it is a failing validation gate with a couple of concrete root causes. We should treat it that way and close the loop on one fix at a time.