#--------------------------------------------------------------------------#>
# TESTS: repoMgr.sanity.Tests.ps1 - 
#--------------------------------------------------------------------------#>
# ABSTRACT: Sanity tests for the repoMgr PowerShell module.
# CREATED 260828 BY: Joe Negron
# VERSION: 0.2.2
# LICENSE: MIT
# REQUIREMENTS: PowerShell 7.0 or later + pester/psst module(s)
#--------------------------------------------------------------------------#>
Describe "repoMgr Sanity Tests" {
    It "Dry-run backup does not mutate" {
        { . "$PSScriptRoot\repoMgr.ps1" -backup -dryrun | Out-Null } | Should -Not -Throw
    }

    It "Shows help and resolves a valid repo branch" {
        $fixture = Join-Path $PSScriptRoot ".repoMgr-sanity-fixture"
        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force }

        New-Item -ItemType Directory -Path $fixture -Force | Out-Null
        git -C $fixture init | Out-Null
        git -C $fixture checkout -b main | Out-Null
        git -C $fixture config user.name "RepoMgr Test"
        git -C $fixture config user.email "repomgr@example.com"
        "seed" | Set-Content -Path (Join-Path $fixture "README.md")
        git -C $fixture add README.md
        git -C $fixture commit -m "seed" | Out-Null

        . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest "$PSScriptRoot\.repoMgr-safe" -lookback "7 days ago" -drBranch "DR-TEST" | Out-Null

        { show-help } | Should -Not -Throw
        Get-GoodBranch -repoPath $fixture | Should -Be "main"
        Get-RepoRole -repoPath $fixture | Should -Be "Standard"

        Remove-Item $fixture -Recurse -Force
    }
}
