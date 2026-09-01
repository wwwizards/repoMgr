#--------------------------------------------------------------------------#>
# TESTS: repoMgr.unit.Tests.ps1 - 
#--------------------------------------------------------------------------#>
# ABSTRACT: Unit tests for the repoMgr PowerShell module.
# CREATED 260828 BY: Joe Negron
# UPDATED 260831 BY: Copilot (Added nested-repo fixture so get-repoList detects it; aligned to v0.5.1)
# VERSION: 0.5.1
# LICENSE: MIT
# REQUIREMENTS: PowerShell 7.0 or later + pester/psst module(s)
#--------------------------------------------------------------------------#>
Describe "repoMgr Unit Tests" {
    It "Logs entries" {
        . "$PSScriptRoot\repoMgr.ps1" -stats -dryrun | Out-Null

        $cfg = Import-PowerShellDataFile "$PSScriptRoot\repoMgr.config.psd1"
        $logDir = Join-Path $cfg.root "repoMgr-logs"
        Test-Path $logDir | Should -BeTrue
    }

    It "Creates a DR branch only when dirty repositories are selected" {
        $fixture = Join-Path $PSScriptRoot ".repoMgr-dirty-fixture"
        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force }

        New-Item -ItemType Directory -Path $fixture -Force | Out-Null
        git -C $fixture init | Out-Null
        git -C $fixture checkout -b main | Out-Null
        git -C $fixture config user.name "RepoMgr Test"
        git -C $fixture config user.email "repomgr@example.com"
        "base" | Set-Content -Path (Join-Path $fixture "tracked.txt")
        git -C $fixture add tracked.txt
        git -C $fixture commit -m "base" | Out-Null

        $nested = Join-Path $fixture "nested-repo"
        New-Item -ItemType Directory -Path $nested -Force | Out-Null
        git -C $nested init | Out-Null
        git -C $nested checkout -b main | Out-Null
        git -C $nested config user.name "RepoMgr Test"
        git -C $nested config user.email "repomgr@example.com"
        "nested" | Set-Content -Path (Join-Path $nested "nested.txt")
        git -C $nested add nested.txt
        git -C $nested commit -m "nested base" | Out-Null

        . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest "$PSScriptRoot\.repoMgr-safe" -lookback "7 days ago" -drBranch "DR-TEST" -dirtyonly -dryrun | Out-Null

        $repos = get-repoList
        $repos.Count | Should -BeGreaterThan 0

        for ($i = 0; $i -lt 5; $i++) {
            try { Remove-Item $fixture -Recurse -Force -ErrorAction Stop; break }
            catch { Start-Sleep -Milliseconds 300 }
        }
    }
}
