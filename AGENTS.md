# AGENTS.md
```
#--------------------------------------------------------------------------#>
# NOTES: AGENTS.md - Instrucctions for AI Agets (and humans, too) 
#--------------------------------------------------------------------------#>
# ABSTRACT: tooling preferences
# CREATED 260830 BY: Joe Negron
# VERSION: 0.1.3
# LICENSE: MIT
# REQUIREMENTS: vsCode + Copilot Chat
#--------------------------------------------------------------------------#>
```

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
   - append into `TESTING.md` followed by a conclusion and remediation path on the next line with `---`

4. TEMP FILES: Do not use any temp files OR STORE ANYTHING outside of this directory; keep everything contained to the working folder.

If you have any issues WITH ANY OF THE ABOVE, STOP.


## Current mission
the  current mission is to resolve the repo validation path and produce verifiable proof from the required TOOLS terminal, without violating the repo instructions in AGENTS.md.

- In plain terms:
- use the exact named terminal: TOOLS
- run the repo harness through that path
- capture output into TESTING.md
- read the file back as the proof
- only then assess repo status or continue with fixes

## Current repo state
From the visible evidence I do have:

- The active implementation remains repoMgr-v0.5.0.ps1
- repoMgr.ps1 IS A COPY which was corrected for the active syntax issues that were blocking the script
- The test suite in:
    - repoMgr.sanity.Tests.ps1
    - repoMgr.smoke.Tests.ps1
    - repoMgr.unit.Tests.ps1 
    still needs to be aligned to the actual v0.5.0 behavior
- any changes (if needed) will be made to repoMgr.ps1 and labeled as v0.5.1 in the meta header
- all files should have a similar metaheader withtheir versions aligned
