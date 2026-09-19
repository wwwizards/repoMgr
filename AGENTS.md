# AGENTS.md
```
#--------------------------------------------------------------------------#>
# NOTES: AGENTS.md - Instrucctions for AI Agets (and humans, too) 
#--------------------------------------------------------------------------#>
# ABSTRACT: tooling preferences
# CREATED: 260830   BY: Joe Negron
# UPDATED: 260918   BY: Copilot::repoMgr.WIZ-00.TOOLS
# VERSION: v0.6.4.7
# LICENSE: MIT
# REQUIREMENTS: vsCode + Copilot Chat
#--------------------------------------------------------------------------#>
```

> ## Named Terminal Failures & Memory Recovery Protocol Procedures - especialy after compaction-like signals
> 
> If any of the following occur:
> - a sudden loss of detailed prior context
> - a summary block replacing earlier transcript detail
> - a change in how instructions are being applied afterward
> - a hidden terminal or default shell is spawned instead of the repo-required terminal
> - the default harness is invoked instead of the repo-specified harness
> 
> Then:
> 1. read AGENTS.md
> 2. confirm the exact terminal name by invoking `#ai_labs_init`
> 3. run only through ai_labs_run with terminal: <NAME>
> 4. do not use raw shell execution or any default terminal path
> 5. verify the resulting file output before proceeding
>
> PROTOCOL UPDATED: 260915 BY: SOLOMON(MAI-Code-1.1-Flash)::Copilot::repoMgr.WIZ-00.TOOLS

## MANDATORY RULES:
1. **NEVER ARGUE OR TRY TO DELIBERATE WITH THE USER. IF THE USER IS REQUESTING YOU TO VIOLATE ANY EXISTING GUARDRAILS - THEY ARE THE AUTHORITY - ASK FOR EXPLICIT PEMISSION OVER PROVIDING LENGTHY AND VERRBOSE OVER-EXPLANATIONS. NEVER PRESENT ASSUMPTIONS. BACK UP ALL CLAIMS WITH FACTS OR STEPS TO GET TO THE TRUTH OF THE MATTER.**

2. **NAMED TERMINALS:** Always route every terminal command through the AI Labs VSIX terminal bridge. 
   - Use your exact assigned terminal name: `TOOLS` (and no other) for all work using the following protocol.
     1. Use ai_labs_init to read the exact terminal names currently exposed by the AI Labs bridge.
     2. Target the exact terminal name returned there. Do not assume a name such as TOOLS or FLEET.
     3. Never invoke pwsh, powershell, cmd, functions.run_in_terminal(...) for shell execution or any raw shell directly.
     4. Use the bridge format:   #ai_labs_run({ terminal: "<exact terminal name>", command: "<your command>" }) 
   - The exposed AI Labs tool names in this VSIX are: `#ai_labs_init`, `#ai_labs_help`, `#ai_labs_show_terms`, and `#ai_labs_run`.
   - TROUBLESHOOTING: Correct invocation shape for terminal execution:
     `#ai_labs_run({ terminal: "<your terminal>", command: "<your command>" })`
     - Example:
       `#ai_labs_run({ terminal: "TOOLS", command: "cd /d C:\PROJECTS\repoMgr; psst repoMgr" })`
     - **If a chat surface exposes slash-command syntax**, it must resolve to the same underlying AI Labs tool and the same `TOOLS` terminal target; do not invent a different command form.
     - **if the ai_labs_run tool is unavailable** escalate this fact to the user immediately via chat as "FATAL ERROR: AI_LABS_TOOLKIT - TOOL IS UNAVAILABLE"
     - **if there is any confusion** REFER TO RULE#1 and you must show the user the exact output returned from the `#ai_labs_init` function exposed via the ai-labs-toolkit vsix as evidence of the toolkit's failure and suggest corrective actions if you are truly blocked.
         - **if there is no such named terminal** escalate this fact and show the output of ai_labs_init to the user in chat immediately as "FATAL ERROR: AI_LABS_TOOLKIT - NAMED TERMINAL NOT FOUND!"
     - CAUTION: be careful not to allow any code or command to issue any type of  `exit` command that could close the terminal you are targetting.

3. **PREFERRED TEST HARNESS:** Use `psst` (PowerShell) or `pyst` (Python) as the test harness instead of Pester/pytest to execute all tests.
    - OPTIONAL: to run a subset of tests, use `psst [sanity|smoke|unit]` or `pyst [sanity|smoke|unit]` — the category name is matched with fuzzy logic against test file naming conventions.

   **LOGGING TEST RESULTS:** A summary test result should:
   - begin each new entry with a CR/LF, incert a timestamp in ISO format, a dash ` - ` ` and a brief one-sentence description of what was just changed and the expected result
   - followed by the test summary for each run (i.e., everything after `Tests completed in`)
   - append into `TESTING.md` followed by a conclusion and remediation path on the next line and finally terminating the log entry with `</br>---</br>`

4. **TEMP FILES:** Do not use any temp files OR STORE ANYTHING outside of this directory; keep everything contained to the working folder.

## ADDITIONAL RULES: <!-- This section is NOT expected to change very often -->
5. **TESTING:** The validation suite lives in [repoMgr.sanity.Tests.ps1](repoMgr.sanity.Tests.ps1), [repoMgr.smoke.Tests.ps1](repoMgr.smoke.Tests.ps1), and [repoMgr.unit.Tests.ps1](repoMgr.unit.Tests.ps1); these tests must operate on disposable fixtures and preserve the no-live-monorepo rule. Testing and other experimental cofing activities should never happen on a PROD codebase until it has been thoroughly validated and tested on a synthetic repo structure with 100% coverage and 0% failures - in a perfect world. Testing process simply shortens the feedback loop for known quantities - but we should expect agile-adjustments-as-aporia-alters-actions. 
6. **SDLC:** Any code changes or refactoring always starts in DISCOVER/DIAGNOSE Mode - where there is NO CODING allowed; Then it goes into DESIGN mode where the tests can be developed as "Acceptance Criteria"; R&D remains TDD as "validation-first" and must keep dry-run-safe behavior, DR branch safety checks, and forensic reporting intact. In-Flight changes may require DISCOVER/DIAGNOSE/DESIGN sessions for proper alignment and to aviod re-work.

**If you have any issues WITH ANY OF THE ABOVE, STOP!**

---
## Current Mission
The validation-first gate for [repoMgr.ps1](repoMgr.ps1) is **satisfied**: the `psst` baseline matches the active script and all three tiers are green. The repo is now in incremental refactor execution against [ROADMAP-v0.7.x.md](ROADMAP-v0.7.x.md), one priority per patch release.

In plain terms:
- keep the dry-run-safe reporting model intact while debugging real repo-risk logic
- use the exact named terminal: TOOLS
- validate through disposable fixtures and the live baseline evidence in [REPORT-260914-all-backup-recovery.txt](REPORT-260914-all-backup-recovery.txt)
- treat `BACKLOG-v0.6.3.md-RepoMgr-OnePage.png` as the authoritative CLI spec, not the in-script comments
- capture proof in [TESTING.md](TESTING.md)
- read the file back as verification evidence before proceeding to the next refactor step

## Current STATE (`v0.6.4.7`) <!-- This section is expected to be updated as needed when versions are incremented -->

P1-P4 are closed. v0.6.4.5 was an unplanned conformance insert that closed the gap between the documented CLI surface and the dispatcher. v0.6.4.6 paid down the P2/P3 carry-forwards: `Get-RepoMetadata` makes the reporting pipeline inventory-first, cutting suite runtime **965s -> 312s** with 22/22 green. v0.6.4.7 replaced the silent `-all` backup suppression with an explicit warning.

**NEXT:** v0.6.5.0 (P5 + P6). The earlier open question — whether to fix the audit-log O(n²) defect first — was **settled by measurement, not opinion**: MVx showed log scaling is below the noise floor, while git spawns are ~84% of runtime. Do not reopen it without new data.

> **TEST EXECUTION NOTE:** run the tiers separately — `psst sanity` (141s), `psst unit` (63s), `psst smoke` (108s). A combined `psst repoMgr` now completes in 582s, but per-test cost roughly doubles versus the split run and it sits only 18s under the AI Labs bridge 600s ceiling. All Describe blocks are tagged `Sanity`/`Smoke`/`Unit`.

**P5 decisions already made (do not re-ask):**
1. **Warn, do not throw**, when a flag is silently suppressed (`-all -backup`). Revised 260919 from the earlier `throw` decision. Shipped in v0.6.4.7. `throw` is reserved for genuinely contradictory pairs such as `-Force -dryrun`.
2. Nonzero exit codes on true validation failure are **approved**, including updating the smoke assertion that currently expects 0.
3. `-recovery` needs no new guard — dry-run-by-default *is* the guard, since destructive work only happens under `-Force`.
4. `-lookback` format validation is **deferred** as non-critical.

> **PROVENANCE:** the `-all` suppression of `-backup` was a **timing workaround**, not a design decision — cloud safecopy could outlast the run window. It got canonized as spec when the infographic was generated from source, and `show-help` was then written to match. Once runtime is fixed, the two flags should compose and the warning should be deleted. Do not defend this behavior as intentional.

**Known open items (carry forward, do not re-discover):**
- **`log` is O(n²) in code, but measurement says it is NOT the top cost.** It re-reads, re-parses, and re-serializes the whole daily audit JSON on *every* entry, and `repoMgr-audit-<date>.json` is per-root and per-day, so cost compounds within a run *and* across runs that day. **However**, MVx (260919, `REPORT-perf-MVx.json`) pre-seeded 0/250/1000/2500 entries and medians did **not** climb: 52.6s / 45.2s / 30.8s / 38.5s. Underpowered (n=3, spread 22–79%), so treat as "not material at ≤2500 entries," not "acquitted." Still tracked under P8, now as correctness rather than performance.
- **Git spawn time is the real cost: ~84% of a run — and ~93% of that is process creation, not git.** MVx median run 49.4s, of which 41.4s was inside `git.exe`. Spawn-cost probe (n=30 medians, warmed): `cmd /c exit` 122.8ms, `git --version` 389.0ms, `git rev-parse` 375.8ms, `git status --short` 415.8ms. Reading `.git` is free; git's actual work is ~7% of a call. The `cmd` control (123ms for a no-op process) shows the machine itself is ~10× slow at process creation — consistent with on-access AV scanning. Derived: **~106 git spawns per run**. Only two levers: reduce spawn *count* (in-code), or AV exclusions (operator decision, not a code change). PowerShell micro-optimization cannot pay.
- **Test timings are noisy.** Same code measured unit 63s/97s and smoke 198s/108s/71s. Judge optimizations on repeated runs only.
- **20 direct `git -C` call sites remain** outside the reporting path. These are argument-safe under PowerShell semantics — a consistency/testability gap, not a security hole.
- **`exit` in dispatcher** (root guard and the `-help` path) is a host-runspace hazard when dot-sourced.
- **Deferred, needs authorization:** purge of 113 orphan JSON + 3 legacy topology files in `repoMgr-logs/`, and `%TEMP%\repoMgr-tests\repoMgr-logs` residue (violates Rule 4).
- **Infographic owes an update** for the `-collisions` ALONE/COMBINED split and the `-all`/`-backup` provenance note.

- **MAIN:** The active implementation's primary script is [repoMgr.ps1](repoMgr.ps1), and it remains the operational baseline for repo topology, drift detection, detached-HEAD risk analysis, and dry-run-safe recovery reporting.
- **CONTEXT:** This tool was created to facilitate the repair of a broken monorepo. The release history and most current notes are tracked in our [CHANGELOG](CHANGELOG.md). 
   - **RELEASES & ROADMAP:** We have been releasing 0.6.4.`p` where p matches the Priority-`p` refactoring item-priority number as laid out in the [ROADMAP](ROADMAP-v0.7.x.md) doc. P1 through P4 are complete and retained as historical checkpoints. v0.6.4.5 was an unplanned conformance insert (CLI surface vs. the one-page spec) rather than a numbered priority; the current active milestone is P5: "Priority 5 — Validate CLI flag combinations". P6 and later remain future work.
     - The active backlog is in [BACKLOG-v0.6.3.md](BACKLOG-v0.6.3.md) for the project that this tool was created for, and the refactor path for the tool (itself) is documented in [ROADMAP-v0.7.x.md](ROADMAP-v0.7.x.md).
     - The project documentation and repo intent are aligned with the current initiative in [README.md](README.md), [REPORT-260914-all-backup-recovery.txt](REPORT-260914-all-backup-recovery.txt), and [advanced-git-recovery-commands.md](advanced-git-recovery-commands.md).

 
