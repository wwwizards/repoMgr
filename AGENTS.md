# AGENTS.md
```
#--------------------------------------------------------------------------#>
# NOTES: AGENTS.md - Instrucctions for AI Agets (and humans, too) 
#--------------------------------------------------------------------------#>
# ABSTRACT: tooling preferences
# CREATED: 260830   BY: Joe Negron
# UPDATED: 260831   BY: Joe Negron
# VERSION: 0.5.1
# LICENSE: MIT
# REQUIREMENTS: vsCode + Copilot Chat
#--------------------------------------------------------------------------#>
```

> ## Recovery Protocol - after compaction-like signals
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
> 2. confirm the exact terminal name via #ai_labs_init
> 3. run only through ai_labs_run with terminal: <NAME>
> 4. do not use raw shell execution or any default terminal path
> 5. verify the resulting file output before proceeding
>
> PROTOCOL UPDATED: 260831 BY: Joe Negron

## MANDATORY RULES:
1. NEVER ARGUE OR TRY TO DELIBERATE WITH THE USER. IF THE USER IS REQUESTING YOU TO VIOLATE ANY EXISTING GUARDRAILS - THEY ARE THE AUTHORITY - ASK FOR EXPLICIT PEMISSION OVER PROVIDING LENGTHY AND VERRBOSE OVER-EXPLANATIONS. NEVER PRESENT ASSUMPTIONS. BACK UP ALL CLAIMS WITH FACTS OR STEPS TO GET TO THE TRUTH OF THE MATTER.

2. NAMED TERMINALS: Always route every terminal command through the AI Labs VSIX terminal bridge. 
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
     - If a chat surface exposes slash-command syntax, it must resolve to the same underlying AI Labs tool and the same `TOOLS` terminal target; do not invent a different command form.
     - if the ai_labs_run tool is unavailable escalate this fact to the user immediately via chat as "FATAL ERROR: AI_LABS_TOOLKIT - TOOL IS UNAVAILABLE"
     - if there is no such named terminal escalate this fact and show the output of ai_labs_init to the user in chat immediately as "FATAL ERROR: AI_LABS_TOOLKIT - NAMED TERMINAL NOT FOUND!"
     - CAUTION: be careful not to allow any code or command to issue any type of  `exit` command that could close the terminal you are targetting.

3. PREFERRED TEST HARNESS: Use `psst` (PowerShell) or `pyst` (Python) as the test harness instead of Pester/pytest to execute all tests.
    - OPTIONAL: to run a subset of tests, use `psst [sanity|smoke|unit]` or `pyst [sanity|smoke|unit]` — the category name is matched with fuzzy logic against test file naming conventions.

   LOGGING TEST RESULTS: A summary test result should:
   - begin each new entry with a CR/LF, incert a timestamp in ISO format, a dash ` - ` ` and a brief one-sentence description of what was just changed and the expected result
   - followed by the test summary for each run (i.e., everything after `Tests completed in`)
   - append into `TESTING.md` followed by a conclusion and remediation path on the next line and finally terminating the log entry with `</br>---</br>`

4. TEMP FILES: Do not use any temp files OR STORE ANYTHING outside of this directory; keep everything contained to the working folder.

If you have any issues WITH ANY OF THE ABOVE, STOP.


## Current mission
The current initiative is validation-first refactoring for [repoMgr.ps1](repoMgr.ps1): establish a clean baseline, refresh the `psst` coverage to match current behavior, and only then proceed with the prioritized architecture cleanup tracked in [ROADMAP-v0.7.x.md](ROADMAP-v0.7.x.md).

- In plain terms:
- use the exact named terminal: TOOLS
- refresh the repo harness and validation baseline before any refactor work
- capture proof in [TESTING.md](TESTING.md)
- read the file back as the verification evidence
- only then assess repo status or continue with prioritized changes

## Current repo state
The repo is currently in a pre-refactor validation gate:

- The active implementation is [repoMgr.ps1](repoMgr.ps1) and it is the operational baseline for the current script behavior.
- The release history and current notes are tracked in [CHANGELOG.md](CHANGELOG.md) and the active backlog is in [BACKLOG-v0.6.3.md](BACKLOG-v0.6.3.md).
- The primary refactor plan is documented in [ROADMAP-v0.7.x.md](ROADMAP-v0.7.x.md), with supporting recovery/reference material in [advanced-git-recovery-commands.md](advanced-git-recovery-commands.md).
- The current validation files are [repoMgr.sanity.Tests.ps1](repoMgr.sanity.Tests.ps1), [repoMgr.smoke.Tests.ps1](repoMgr.smoke.Tests.ps1), and [repoMgr.unit.Tests.ps1](repoMgr.unit.Tests.ps1); they need to be refreshed to reflect the current repoMgr functionality before architecture work begins.
- Any refactor effort will remain validation-first and should preserve the current dry-run-safe reporting model while cleaning the script architecture.
- All files that participate in the validation/refactor workflow should keep consistent metadata/versioning and remain aligned with the current repo state.
