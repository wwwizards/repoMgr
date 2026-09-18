#--------------------------------------------------------------------------#>
# TESTS: repoMgr.smoke.Tests.ps1 - smoke coverage for current repoMgr behavior
#--------------------------------------------------------------------------#>
# ABSTRACT: Smoke tests for the current repoMgr PowerShell reporting flow.
# CREATED 260828 BY: Joe Negron
# UPDATED 260915 BY: SOLOMON(MAI-Code-1.1-Flash)::Copilot::repoMgr.WIZ-00.TOOLS
# VERSION: v0.6.4.4
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
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "smoke-default"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-smoke-default"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }

        try {
            New-Item -ItemType Directory -Path $fixture -Force | Out-Null
            git -C $fixture init | Out-Null
            git -C $fixture checkout -b main | Out-Null
            git -C $fixture config user.name "RepoMgr Test"
            git -C $fixture config user.email "repomgr@example.com"
            "base" | Set-Content -Path (Join-Path $fixture "app.txt")
            git -C $fixture add app.txt
            git -C $fixture commit -m "base" | Out-Null

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -stats -topology -risk -dryrun | Out-Null
            $LASTEXITCODE | Should -Be 0
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

    It "Performs a detached-head risk analysis when a repo is checked out detached" {
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "smoke-risk"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-smoke-risk"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }

        try {
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

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -dryrun | Out-Null

            $results = Analyze-RepoRisk -repoPath $fixture
            $results | Should -Not -BeNullOrEmpty
            $results[0].IsDivergent | Should -BeTrue
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

    It "Forces recovery from detached HEAD, orphaned files, and same-remote collisions" {
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
        $fixture = Join-Path $base "smoke-force-recovery"
        $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-smoke-force-recovery"
        $origin = Join-Path $base "smoke-force-recovery-origin.git"

        if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $origin) { Remove-Item $origin -Recurse -Force -ErrorAction SilentlyContinue }

        try {
            New-Item -ItemType Directory -Path $fixture -Force | Out-Null
            git init --bare $origin | Out-Null

            git -C $fixture init | Out-Null
            git -C $fixture checkout -b main | Out-Null
            git -C $fixture config user.name "RepoMgr Test"
            git -C $fixture config user.email "repomgr@example.com"
            git -C $fixture remote add origin $origin
            "base" | Set-Content -Path (Join-Path $fixture "app.txt")
            git -C $fixture add app.txt
            git -C $fixture commit -m "base" | Out-Null
            git -C $fixture push -u origin main | Out-Null

            $nested = Join-Path $fixture "nested-repo"
            New-Item -ItemType Directory -Path $nested -Force | Out-Null
            git -C $nested init | Out-Null
            git -C $nested checkout -b main | Out-Null
            git -C $nested config user.name "RepoMgr Test"
            git -C $nested config user.email "repomgr@example.com"
            git -C $nested remote add origin $origin
            "nested" | Set-Content -Path (Join-Path $nested "nested.txt")
            git -C $nested add nested.txt
            git -C $nested commit -m "nested base" | Out-Null
            git -C $nested push -u origin main | Out-Null

            "orphan data" | Set-Content -Path (Join-Path $fixture "orphan.txt")
            git -C $fixture checkout --detach HEAD | Out-Null
            "detached" | Set-Content -Path (Join-Path $fixture "app.txt")
            git -C $fixture add app.txt
            git -C $fixture commit -m "detached recovery probe" | Out-Null

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -safedest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -all -backup -recovery -Force | Out-Null

            $LASTEXITCODE | Should -Be 0
            (git -C $fixture branch --list "DR-TEST") | Should -Not -BeNullOrEmpty
            (git -C $fixture branch --list "recovered-*") | Should -Not -BeNullOrEmpty
            (git -C $fixture rev-parse --abbrev-ref HEAD) | Should -Be "main"

            $collision = Get-RemoteCollisions
            $collision | Should -Not -BeNullOrEmpty
            $collision[0].Type | Should -Be "Repo"
        }
        finally {
            for ($i = 0; $i -lt 5; $i++) {
                try {
                    if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force -ErrorAction Stop }
                    if (Test-Path $safeDir) { Remove-Item $safeDir -Recurse -Force -ErrorAction Stop }
                    if (Test-Path $origin) { Remove-Item $origin -Recurse -Force -ErrorAction Stop }
                    break
                }
                catch {
                    Start-Sleep -Milliseconds 300
                }
            }
        }
    }
}
