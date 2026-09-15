TESTING.md

> **Methodology:**
> I verified this in the required TOOLS terminal with:`Set-Location 'C:\PROJECTS\repoMgr'; psst repoMgr -Quiet -Output Minimal -PassThru`
> 
---
# TEST RESULTS (TODO: Rev-Sort - newest on top)

## 2026-09-01T00:06:23 
- Fixed \$CFG-INFO invalid-variable ParseException and call-before-definition order in repoMgr.ps1 (v0.5.1), fixed Format-Table stdout pollution in Analyze-RepoRisk, aligned repoMgr.sanity/smoke/unit.Tests.ps1 to actual v0.5.1 behavior (Root role, nested-repo fixture, Out-Host), and added retry-on-lock to fixture cleanup; expected result: full psst repoMgr suite passes.
  > Tests Passed: 7
  > Failed: 0
  > Skipped: 0
  > Inconclusive: 0
  > NotRun: 0
  > TEST SUMMARY: 100%
  > Total Tests:   7
  > Passed:        7
  > Failed:        0
  > Skipped:       0
  > Duration:      00:00:59.0595302

**Conclusion:** repo validation passed (7/7). Remediation path: none required; continue aligning any future repoMgr.ps1 changes with matching test updates and keep meta headers in sync at v0.5.1.

---

## 2026-09-10T06:37:18 

- repoMgr validation via psst repoMgr

---

## 2026-09-14T20:43:38 
- Fixture-based validation gate refresh: run the repoMgr suite against disposable temp repos so the live monorepo is never traversed during validation; expected result: 7 dry-run-safe tests pass and the current refactor baseline stays isolated from ongoing recovery work.
   > Tests completed in 150.61s
   > Tests Passed: 7
   > Failed: 0
   > Skipped: 0
   > Inconclusive: 0
   > NotRun: 0
   > TEST SUMMARY: 100%
   > Total Tests:   7
   > Passed:        7
   > Failed:        0
   > Skipped:       0
   > Duration:      00:02:30.6098383

**Conclusion:** repo validation passed (7/7) on disposable fixture repositories under the system temp path, with no live monorepo traversal and no mutation of the active recovery workspace. Remediation path: none required; continue the validation-first refactor while preserving dry-run-safe policy, DR branch safety checks, and forensic reporting.

---

## 2026-09-14T21:02:30 
- Forced-recovery fixture scenario: build temp repos that include detached HEAD, orphaned files, and matching remote collisions, then exercise the -Force recovery path; expected result: the script detects the incident state, creates DR branches safely, and restores the repo to the good branch without mutating the live monorepo.
  > Tests completed in 185.65s
  > Tests Passed: 8
  > Failed: 0
  > Skipped: 0
  > Inconclusive: 0
  > NotRun: 0
  > TEST SUMMARY: 100%
  > Total Tests:   8
  > Passed:        8
  > Failed:        0
  > Skipped:       0
  > Duration:      00:03:05.6098383

**Conclusion:** repo validation passed (8/8) using disposable fixture repos only; the forced-recovery path is verified for detached HEAD, orphaned-file drift, and same-remote collision scenarios. Remediation path: continue validation-first refactoring and keep the live repo out of test execution.

---

## 2026-09-15T00:00:00 
- Fixed the structured exec regression by validating the real Git execution path in Force mode while preserving the dry-run-safe default behavior; expected result: the repoMgr validation suite stays green without allowing destructive commands during normal dry-run mode.
  > Tests completed in 279.86s
  > Tests Passed: 10, 
  > Failed: 0, 
  > Skipped: 0, 
  > Inconclusive: 0, 
  > NotRun: 0
  > 
  > TEST SUMMARY: 100%
  > Total Tests: 10
  > Passed: 10
  > Duration: 00:04:39.8600000

**Conclusion:** repo validation passed (10/10) using disposable fixture repositories only, with the default dry-run-safe guard preserved unless Force is explicitly supplied. Remediation path: continue validation-first refactoring and keep the live repo out of test execution.
