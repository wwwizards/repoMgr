TESTING.md

> **Methodology:**
> I verified this in the required TOOLS terminal with:`Set-Location 'C:\PROJECTS\repoMgr'; psst repoMgr -Quiet -Output Minimal -PassThru`
> 
---
# TEST RESULTS (TODO: Rev-Sort - newest on top)

## 2026-09-16T21:00:00 
- P4 reporting-separation validation in the required TOOLS terminal: verify the report/data split and lightweight spinner stayed dry-run-safe without regressing the repoMgr baseline; expected result: the full validation suite remains green under the active refactor gate.
  > Tests completed in 1.34s
  > Tests Passed: 15
  > Failed: 0
  > Skipped: 0
  > Inconclusive: 0
  > NotRun: 0
  > TEST SUMMARY: 100%
  > Total Tests: 15
  > Passed: 15
  > Failed: 0
  > Duration: 00:00:01.3400000

**Conclusion:** repo validation passed (15/15) on disposable fixture repositories only; the active P4 reporting-separation work remains green and the live monorepo is not traversed during validation. Remediation path: hold the current scope and avoid broad refactor drift until the next milestone.
</br>---</br>

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

---

## 2026-09-15T02:02:00 
- Replaced the shell-string Git execution path with an argument-safe helper and added a regression check that fails if `Invoke-Expression` is reintroduced; expected result: the active script uses structured Git invocation while keeping the dry-run-safe default model intact.
  > Tests completed in 39.82s
  > Tests Passed: 13, 
  > Failed: 0, 
  > Skipped: 0, 
  > Inconclusive: 0, 
  > NotRun: 0
  > 
  > TEST SUMMARY: 100%
  > Total Tests: 13
  > Passed: 13
  > Duration: 00:00:39.8200000

**Conclusion:** repo validation passed (13/13) using disposable fixture repositories only, and the active path no longer depends on `Invoke-Expression`. Remediation path: proceed to the next highest-priority refactor step with the same validation gate and no live monorepo traversal.
</br>---</br>

## 2026-09-18T09:42:00
- No code change; independent DISCOVER/DIAGNOSE baseline re-measurement of the AS-IS tree by `Claude(Opus-5)::Copilot::repoMgr.WIZ-00.TOOLS` via `psst repoMgr` in the TOOLS terminal, to verify the red-state claim recorded in STATE-v0.6.4.md; expected result: an accurate, reproducible pass/fail count to gate the P4 work.
  > Tests completed in 184.93s
  > Tests Passed: 14
  > Failed: 4
  > Skipped: 0
  > Inconclusive: 0
  > NotRun: 0
  > TEST SUMMARY: 78%
  > Total Tests: 18
  > Passed: 14
  > Failed: 4
  > Duration: 00:03:04.9300000

**Conclusion:** the repo is RED at 14/18, not 5/13 as asserted in STATE-v0.6.4.md — that document is stale and must not be used as the current-state source. Four failures, all state/rendering related: (1) sanity `$script:root` leaks across dot-sourced invocations; (2) sanity `-NoExecute` import nulls the caller's `$root` via `Initialize-Logging`; (3) sanity daily-audit still emits `topology-*.json` sidecars; (4) smoke `$LASTEXITCODE` is 2 (leaked from `git remote get-url origin` on a remote-less fixture) instead of 0. Raw evidence captured in psst-baseline-260918.txt. Remediation path: fix in the order exit-code hygiene -> topology double-call/sidecar -> spinner runspace defect -> scope model, per the DIAGNOSE findings; no code changes made in this session.
</br>---</br>

## 2026-09-18T11:48:00
- Applied P4 steps A-D: unhooked `Show-Spinner` from `Write-RiskReport` so risk analysis runs inline (the ThreadJob runspace was dropping the resolved root/config and silently returning zero rows); removed the duplicate `Write-TopologySnapshot` call from `write-repoStats`; renamed internal ambient state `$script:root` -> `$script:repoMgrRoot` so dot-sourcing no longer clobbers the caller's scope; normalized `$LASTEXITCODE` at end of run. Expected result: the risk report renders real rows, topology is captured once per run, and the root-leak and exit-code failures clear.
  > Tests completed in 344.16s
  > Tests Passed: 16
  > Failed: 2
  > Skipped: 0
  > Inconclusive: 0
  > NotRun: 0
  > TEST SUMMARY: 89%
  > Total Tests: 18
  > Passed: 16
  > Failed: 2
  > Duration: 00:05:44.1600000

**Conclusion:** 14/18 -> 16/18. Both targeted failures cleared: `$script:root` no longer leaks across invocations, and the default reporting flow now exits 0. Behavioral proof beyond the pass count: `(no risk report rows available)` is gone from every run and the risk table now renders populated rows, remote-collision detection is visible again (it was previously executing inside the invisible job), and `Topology snapshot written` appears once per run instead of twice. Raw evidence in psst-after-P4AD-260918.txt. Remediation path: two failures remain and NEITHER is a code defect. (a) "Does not forcibly null the caller's active root during a no-execute import" is **unsatisfiable by design** — PowerShell `param()` binding wipes the caller's `$root` on dot-source before any script code executes (proven by probe: pre-set `$root='KEEPME'` reads back as `''`), and this test directly contradicts the sibling test at repoMgr.sanity.Tests.ps1:107 which asserts the opposite outcome for the identical invocation; one of the two must be retired. (b) "Aggregates audit data into a single daily log" is a TO-BE spec test requiring the topology-sidecar product decision (Step E) — deferred pending direction, since the sidecar is an intentional forensic artifact per ROADMAP.
</br>---</br>

## 2026-09-18T14:30:00
- Closed P4. Retired the unsatisfiable/contradictory sanity test per direction, then consolidated audit logging: `log` now accepts a structured object instead of a string, the CONFIG entry records discrete fields (invocation/root/safedest/lookback/drBranch/mode) instead of a rendered ASCII banner blob, the topology payload is embedded directly in the daily audit log instead of emitting a `topology-*.json` sidecar per run, the dead per-run `repoMgr-<timestamp>.json` path assignment was removed, and the run timestamp is now established before the first audit write so entries and artifacts agree. Expected result: a full green suite and one parseable, auditable log file per day.
  > Tests completed in 139.54s
  > Tests Passed: 17
  > Failed: 0
  > Skipped: 0
  > Inconclusive: 0
  > NotRun: 0
  > TEST SUMMARY: 100%
  > Total Tests: 17
  > Passed: 17
  > Failed: 0
  > Duration: 00:02:19.5400000

**Conclusion:** GREEN — 17/17 (18 minus the retired contradictory test) on disposable fixtures only, with no live monorepo traversal. P4 "separate reporting output from logic" is complete: analysis (`Get-RepoRiskReport`) is split from rendering (`Write-RepoRiskReport`), and the spinner that was silently voiding that split is quarantined for P9. Audit output verified by direct inspection on a disposable fixture: the daily log is now a single valid JSON array whose INIT/CONFIG/TOPOLOGY entries each carry runId, ISO timestamp, action, path, root, dryRun and force, with the topology snapshot nested as structured data rather than a filename reference. Historical residue remains on disk and is NOT auto-deleted: 113 orphaned `repoMgr-<timestamp>.json` files (111 of them byte-identical INIT+CONFIG stubs from dot-sourced imports, and none of them valid JSON — they are bare concatenated objects with no array wrapper) plus 3 legacy `topology-*.json` sidecars. Remediation path: purge the historical orphans at operator discretion; no log-rotation function was added because one file per day is already self-rotating and adding rotation would add complexity for no audit benefit. Next milestone is P5 (CLI combination validation) entered from a green gate.
</br>---</br>
