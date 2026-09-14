#--------------------------------------------------------------------------#>
# TESTS: repoMgr.smoke.Tests.ps1 - smoke coverage for current repoMgr behavior
#--------------------------------------------------------------------------#>
# ABSTRACT: Smoke tests for the current repoMgr PowerShell reporting flow.
# CREATED 260828 BY: Joe Negron
# UPDATED 260914 BY: Copilot (refreshed for current stats/topology/risk flow)
# VERSION: 0.6.4.x - next refactor target
# LICENSE: MIT
# REQUIREMENTS: PowerShell 7.0 or later + pester/psst module(s)
#--------------------------------------------------------------------------#>
Describe "repoMgr Smoke Tests" {
    It "Loads the current config contract used by recovery/discovery reporting" {
        $cfg = Import-PowerShellDataFile "$PSScriptRoot\repoMgr.config.psd1"
        $cfg.root | Should -Not -BeNullOrEmpty
        $cfg.lookback | Should -Not -BeNullOrEmpty
        $cfg.drBranch | Should -Not -BeNullOrEmpty
    }

    It "Runs the default reporting flow without mutation while preserving recovery triage safeguards" {
        . "$PSScriptRoot\repoMgr.ps1" -stats -topology -risk -dryrun | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It "Performs a detached-head risk analysis when a repo is checked out detached" {
        $fixture = Join-Path $PSScriptRoot ".repoMgr-risk-fixture"
        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force }

        New-Item -ItemType Directory -Path $fixture -Force | Out-Null
        git -C $fixture init | Out-Null
        git -C $fixture checkout -b main | Out-Null
        git -C $fixture config user.name "RepoMgr Test"
        git -C $fixture config user.email "repomgr@example.com"
        "base" | Set-Content -Path (Join-Path $fixture "app.txt")
        git -C $fixture add app.txt
        git -C $fixture commit -m "base" | Out-Null

        git -C $fixture checkout --detach HEAD | Out-Null
        "detached" | Set-Content -Path (Join-Path $fixture "app.txt")
        git -C $fixture add app.txt
        git -C $fixture commit -m "detached change" | Out-Null

        . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest "$PSScriptRoot\.repoMgr-safe" -lookback "7 days ago" -drBranch "DR-TEST" -dryrun | Out-Null

        $results = Analyze-RepoRisk -repoPath $fixture
        $results | Should -Not -BeNullOrEmpty
        $results[0].IsDivergent | Should -BeTrue

        for ($i = 0; $i -lt 5; $i++) {
            try { Remove-Item $fixture -Recurse -Force -ErrorAction Stop; break }
            catch { Start-Sleep -Milliseconds 300 }
        }
    }
}
