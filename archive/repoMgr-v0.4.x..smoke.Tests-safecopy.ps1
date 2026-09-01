#--------------------------------------------------------------------------#>
# TESTS: repoMgr.smoke.Tests.ps1 - 
#--------------------------------------------------------------------------#>
# ABSTRACT: Smoke tests for the repoMgr PowerShell module.
# CREATED 260828 BY: Joe Negron
# VERSION: 0.2.2
# LICENSE: MIT
# REQUIREMENTS: PowerShell 7.0 or later + pester/psst module(s)
#--------------------------------------------------------------------------#>
Describe "repoMgr Smoke Tests" {
    It "Loads config" {
        $cfg = Import-PowerShellDataFile "$PSScriptRoot\repoMgr.config.psd1"
        $cfg.root | Should -Not -BeNullOrEmpty
    }

    It "Detects repos" {
        . "$PSScriptRoot\repoMgr.ps1" -stats -dryrun | Out-Null
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

        . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest "$PSScriptRoot\.repoMgr-safe" -lookback "7 days ago" -drBranch "DR-TEST" | Out-Null

        $results = Analyze-RepoRisk -repoPath $fixture
        $results | Should -Not -BeNullOrEmpty
        $results[0].IsDivergent | Should -BeTrue

        Remove-Item $fixture -Recurse -Force
    }
}
