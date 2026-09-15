#--------------------------------------------------------------------------#>
# TESTS: repoMgr.unit.Tests.ps1 - baseline unit coverage for current repoMgr behavior
#--------------------------------------------------------------------------#>
# ABSTRACT: Unit tests for the current repoMgr PowerShell flow.
# CREATED 260828 BY: Joe Negron
# UPDATED 260915 BY: SOLOMON(MAI-Code-1.1-Flash)::Copilot::repoMgr.WIZ-00.TOOLS
# VERSION: v0.6.4.0
# LICENSE: MIT
# REQUIREMENTS: PowerShell 7.0 or later + pester/psst module(s)
#--------------------------------------------------------------------------#>
Describe "repoMgr Unit Tests" {
    It "Creates the expected repo log directory during the recovery/discovery reporting flow" {
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "unit-logdir"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-unit-logdir"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }

        try {
            New-Item -ItemType Directory -Path $fixture -Force | Out-Null
            git -C $fixture init | Out-Null
            git -C $fixture checkout -b main | Out-Null
            git -C $fixture config user.name "RepoMgr Test"
            git -C $fixture config user.email "repomgr@example.com"
            "base" | Set-Content -Path (Join-Path $fixture "tracked.txt")
            git -C $fixture add tracked.txt
            git -C $fixture commit -m "base" | Out-Null

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -all -backup -recovery -dryrun | Out-Null
            $logDir = Join-Path $fixture "repoMgr-logs"
            Test-Path $logDir | Should -BeTrue
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

    It "Detects nested repos and respects dry-run-only repo operations used by triage work" {
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "unit-nested"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-unit-nested"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }

        try {
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

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -dirtyonly -dryrun | Out-Null

            $repos = get-repoList
            $repos.Count | Should -BeGreaterThan 0
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

    It "Executes git operations via structured arguments instead of string-evaluated shell commands" {
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "unit-safe-exec"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-unit-safe-exec"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }

        try {
            New-Item -ItemType Directory -Path $fixture -Force | Out-Null
            git -C $fixture init | Out-Null
            git -C $fixture checkout -b main | Out-Null
            git -C $fixture config user.name "RepoMgr Test"
            git -C $fixture config user.email "repomgr@example.com"
            "base" | Set-Content -Path (Join-Path $fixture "tracked.txt")
            git -C $fixture add tracked.txt
            git -C $fixture commit -m "base" | Out-Null

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -Force | Out-Null
            $result = exec -Command @("git", "-C", $fixture, "branch", "--show-current") -Path $fixture
            $result | Should -Be "main"
        }
        finally {
            if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
            if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It "Normalizes config overrides before repo discovery and recovery actions run" {
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "unit-config-normalize"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-unit-config-normalize"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }

        try {
            New-Item -ItemType Directory -Path $fixture -Force | Out-Null
            git -C $fixture init | Out-Null
            git -C $fixture checkout -b main | Out-Null
            git -C $fixture config user.name "RepoMgr Test"
            git -C $fixture config user.email "repomgr@example.com"
            "base" | Set-Content -Path (Join-Path $fixture "tracked.txt")
            git -C $fixture add tracked.txt
            git -C $fixture commit -m "base" | Out-Null

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -dryrun | Out-Null
            $config = Get-EffectiveConfig -Root "C:\temp\repo\" -Safedest "C:\temp\safe\" -Lookback "7 days ago" -DrBranch "DR-TEST"

            $config.Root | Should -Be "C:\temp\repo"
            $config.Safedest | Should -Be "C:\temp\safe"
            $config.Lookback | Should -Be "7 days ago"
            $config.DrBranch | Should -Be "DR-TEST"
        }
        finally {
            if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
            if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
