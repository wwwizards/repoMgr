#--------------------------------------------------------------------------#>
# TESTS: repoMgr.sanity.Tests.ps1 - validation baseline for current behavior
#--------------------------------------------------------------------------#>
# ABSTRACT: Sanity tests for the current repoMgr PowerShell flow.
# CREATED 260828 BY: Joe Negron
# UPDATED 260915 BY: SOLOMON(MAI-Code-1.1-Flash)::Copilot::repoMgr.WIZ-00.TOOLS
# VERSION: v0.6.4.4
# LICENSE: MIT
# REQUIREMENTS: PowerShell 7.0 or later + pester/psst module(s)
#--------------------------------------------------------------------------#>
Describe "repoMgr Sanity Tests" {
    It "Dry-run discovery and recovery reporting flow does not mutate state" {
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "sanity-default"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-default"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }

        try {
            New-Item -ItemType Directory -Path $fixture -Force | Out-Null
            git -C $fixture init | Out-Null
            git -C $fixture checkout -b main | Out-Null
            git -C $fixture config user.name "RepoMgr Test"
            git -C $fixture config user.email "repomgr@example.com"
            "seed" | Set-Content -Path (Join-Path $fixture "README.md")
            git -C $fixture add README.md
            git -C $fixture commit -m "seed" | Out-Null

            { . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -backup -stats -topology -risk -dryrun | Out-Null } | Should -Not -Throw
        }
        finally {
            for ($i = 0; $i -lt 5; $i++) {
                try {
                    if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction Stop }
                    if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction Stop }
                    break
                }
                catch {
                    Start-Sleep -Milliseconds 300
                }
            }
        }
    }

    It "Shows help and resolves a valid repo branch under the current recovery/discovery config contract" {
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "sanity-help"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-help"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }

        try {
            New-Item -ItemType Directory -Path $fixture -Force | Out-Null
            git -C $fixture init | Out-Null
            git -C $fixture checkout -b main | Out-Null
            git -C $fixture config user.name "RepoMgr Test"
            git -C $fixture config user.email "repomgr@example.com"
            "seed" | Set-Content -Path (Join-Path $fixture "README.md")
            git -C $fixture add README.md
            git -C $fixture commit -m "seed" | Out-Null

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -dryrun | Out-Null

            { show-help } | Should -Not -Throw
            Get-GoodBranch -repoPath $fixture | Should -Be "main"
            Get-RepoRole -repoPath $fixture | Should -Be "Root"
        }
        finally {
            for ($i = 0; $i -lt 5; $i++) {
                try {
                    if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction Stop }
                    if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction Stop }
                    break
                }
                catch {
                    Start-Sleep -Milliseconds 300
                }
            }
        }
    }

    It "Does not leak the previous fixture root across script invocations" {
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "sanity-state-isolation"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-state-isolation"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }

        try {
            New-Item -ItemType Directory -Path $fixture -Force | Out-Null
            git -C $fixture init | Out-Null
            git -C $fixture checkout -b main | Out-Null
            git -C $fixture config user.name "RepoMgr Test"
            git -C $fixture config user.email "repomgr@example.com"
            "seed" | Set-Content -Path (Join-Path $fixture "README.md")
            git -C $fixture add README.md
            git -C $fixture commit -m "seed" | Out-Null

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -NoExecute | Out-Null
            $root | Should -Be $fixture

            . "$PSScriptRoot\repoMgr.ps1" -NoExecute | Out-Null
            $root | Should -BeNullOrEmpty
            $script:root | Should -BeNullOrEmpty
        }
        finally {
            for ($i = 0; $i -lt 5; $i++) {
                try {
                    if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction Stop }
                    if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction Stop }
                    break
                }
                catch {
                    Start-Sleep -Milliseconds 300
                }
            }
        }
    }

    It "Aggregates audit data into a single daily log under the fixture instead of creating orphaned topology files" {
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "sanity-daily-audit"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-daily-audit"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }

        try {
            New-Item -ItemType Directory -Path $fixture -Force | Out-Null
            git -C $fixture init | Out-Null
            git -C $fixture checkout -b main | Out-Null
            git -C $fixture config user.name "RepoMgr Test"
            git -C $fixture config user.email "repomgr@example.com"
            "seed" | Set-Content -Path (Join-Path $fixture "README.md")
            git -C $fixture add README.md
            git -C $fixture commit -m "seed" | Out-Null

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -topology -dryrun | Out-Null

            $logDir = Join-Path $fixture "repoMgr-logs"
            $dailyLog = Get-ChildItem -Path $logDir -Filter "repoMgr-audit-*.json" | Select-Object -First 1
            $dailyLog | Should -Not -BeNullOrEmpty

            $content = Get-Content -Path $dailyLog.FullName -Raw
            $content | Should -Match 'TOPOLOGY'
            $content | Should -Not -Match 'topology-.*\.json'

            $sidecars = Get-ChildItem -Path $logDir -Filter "topology-*.json" -ErrorAction SilentlyContinue
            $sidecars.Count | Should -Be 0
        }
        finally {
            for ($i = 0; $i -lt 5; $i++) {
                try {
                    if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction Stop }
                    if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction Stop }
                    break
                }
                catch {
                    Start-Sleep -Milliseconds 300
                }
            }
        }
    }
}
