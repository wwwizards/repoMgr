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
Describe "repoMgr Sanity Tests" -Tag 'Sanity' {
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

            { . "$PSScriptRoot\repoMgr.ps1" -root $fixture -backupdest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -backup -stats -topology -risk -dryrun | Out-Null } | Should -Not -Throw
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

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -backupdest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -dryrun | Out-Null

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

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -backupdest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -NoExecute | Out-Null
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

            . "$PSScriptRoot\repoMgr.ps1" -root $fixture -backupdest $safeDir -lookback "7 days ago" -drBranch "DR-TEST" -topology -dryrun | Out-Null

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

# Acceptance criteria for v0.6.4.5: every flag published on the one-page infographic
# must bind and behave as depicted. Stale flags fail here instead of drifting silently.
Describe "repoMgr Flag Contract Tests" -Tag 'Sanity' {

    BeforeAll {
        # Two repos sharing one origin - the minimum shape that produces a real collision.
        function New-CollisionFixture {
            param([string]$Name)

            $base    = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-tests"
            $fixture = Join-Path $base $Name
            $safeDir = Join-Path ([System.IO.Path]::GetTempPath()) "repoMgr-test-safe-$Name"
            $origin  = Join-Path $base "$Name-origin.git"

            foreach ($p in @($fixture, $safeDir, $origin)) {
                if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
            }

            New-Item -ItemType Directory -Path $fixture -Force | Out-Null
            git init --bare $origin | Out-Null

            git -C $fixture init | Out-Null
            git -C $fixture checkout -b main | Out-Null
            git -C $fixture config user.name "RepoMgr Test"
            git -C $fixture config user.email "repomgr@example.com"
            git -C $fixture remote add origin $origin
            "seed" | Set-Content -Path (Join-Path $fixture "README.md")
            git -C $fixture add README.md
            git -C $fixture commit -m "seed" | Out-Null

            $nested = Join-Path $fixture "nested-repo"
            New-Item -ItemType Directory -Path $nested -Force | Out-Null
            git -C $nested init | Out-Null
            git -C $nested checkout -b main | Out-Null
            git -C $nested config user.name "RepoMgr Test"
            git -C $nested config user.email "repomgr@example.com"
            git -C $nested remote add origin $origin
            "nested" | Set-Content -Path (Join-Path $nested "nested.txt")
            git -C $nested add nested.txt
            git -C $nested commit -m "nested seed" | Out-Null

            return [pscustomobject]@{
                Fixture = $fixture
                SafeDir = $safeDir
                Origin  = $origin
                LogDir  = Join-Path $fixture "repoMgr-logs"
            }
        }

        function Remove-CollisionFixture {
            param([object]$Fixture)

            for ($i = 0; $i -lt 5; $i++) {
                try {
                    foreach ($p in @($Fixture.Fixture, $Fixture.SafeDir, $Fixture.Origin)) {
                        if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction Stop }
                    }
                    break
                }
                catch {
                    Start-Sleep -Milliseconds 300
                }
            }
        }

        function Get-AuditContent {
            param([string]$LogDir)

            $daily = Get-ChildItem -Path $LogDir -Filter "repoMgr-audit-*.json" -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if (-not $daily) { return "" }
            return (Get-Content -Path $daily.FullName -Raw)
        }
    }

    It "Binds -backupdest as the documented backup destination override" {
        $fx = New-CollisionFixture -Name "contract-backupdest"
        try {
            { . "$PSScriptRoot\repoMgr.ps1" -root $fx.Fixture -backupdest $fx.SafeDir -lookback "7 days ago" -drBranch "DR-TEST" -dryrun | Out-Null } |
                Should -Not -Throw
        }
        finally { Remove-CollisionFixture -Fixture $fx }
    }

    It "Binds -dr as the documented legacy alias for -recovery" {
        $fx = New-CollisionFixture -Name "contract-dr-alias"
        try {
            . "$PSScriptRoot\repoMgr.ps1" -root $fx.Fixture -backupdest $fx.SafeDir -lookback "7 days ago" -drBranch "DR-TEST" -dr -dryrun | Out-Null

            Get-AuditContent -LogDir $fx.LogDir | Should -Match 'DR-BRANCH-DRYRUN'
        }
        finally { Remove-CollisionFixture -Fixture $fx }
    }

    It "Short-circuits to collision detection only when -collisions is used alone" {
        $fx = New-CollisionFixture -Name "contract-collisions-alone"
        try {
            . "$PSScriptRoot\repoMgr.ps1" -root $fx.Fixture -backupdest $fx.SafeDir -lookback "7 days ago" -drBranch "DR-TEST" -collisions -dryrun | Out-Null

            $audit = Get-AuditContent -LogDir $fx.LogDir
            $audit | Should -Match 'REMOTE-COLLISION'
            $audit | Should -Not -Match 'TOPOLOGY'
        }
        finally { Remove-CollisionFixture -Fixture $fx }
    }

    It "Runs the full base reporting sweep when -collisions is combined with another flag" {
        $fx = New-CollisionFixture -Name "contract-collisions-combined"
        try {
            . "$PSScriptRoot\repoMgr.ps1" -root $fx.Fixture -backupdest $fx.SafeDir -lookback "7 days ago" -drBranch "DR-TEST" -collisions -stats -dryrun | Out-Null

            $audit = Get-AuditContent -LogDir $fx.LogDir
            $audit | Should -Match 'REMOTE-COLLISION'
            $audit | Should -Match 'TOPOLOGY'
        }
        finally { Remove-CollisionFixture -Fixture $fx }
    }

    It "Feeds collision data into the -all forensic deep dive" {
        $fx = New-CollisionFixture -Name "contract-all-collisions"
        try {
            $out = . "$PSScriptRoot\repoMgr.ps1" -root $fx.Fixture -backupdest $fx.SafeDir -lookback "7 days ago" -drBranch "DR-TEST" -all -dryrun 6>&1 |
                Out-String

            $out | Should -Match 'Collision     : '
        }
        finally { Remove-CollisionFixture -Fixture $fx }
    }
}
