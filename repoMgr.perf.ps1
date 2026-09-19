#!/usr/bin/env pwsh
<#--------------------------------------------------------------------------
#  SCRIPT: repoMgr.perf.ps1 — MVx: mini viability experiment harness
#--------------------------------------------------------------------------
# PURPOSE:  Measures where repoMgr.ps1 actually spends its time, so optimization
#           decisions are driven by data instead of by single noisy suite runs.
# ABSTRACT: Runs controlled experiments against ONE disposable fixture:
#           - E1 Variance    : same command N times -> establishes the noise floor
#           - E2 GitSpawns   : shadows `git` to count and time every process spawn
#           - E3 LogScaling  : pre-seeds the audit JSON to prove/quantify log() O(n^2)
#           Read-only with respect to repoMgr.ps1 itself; nothing is instrumented
#           in the tool. Every experiment is a black-box A/B.
# REQUIRES: Git, PowerShell 7+.
# CREATED:  260919 BY: Copilot::repoMgr.WIZ-00.TOOLS
# COMPANY:  LogicWizards.NYC <LogicWizards.NYC>
# VERSION:  v0.1.0
# LICENSE:  AGPL-3.0 <https://www.gnu.org/licenses/agpl-3.0.html>
# USAGE:    ./repoMgr.perf.ps1                      # all experiments, 5 iterations
#           ./repoMgr.perf.ps1 -Iterations 9        # tighter medians
#           ./repoMgr.perf.ps1 -Experiment LogScaling
# NOTES:    Fixture lives inside the working folder (AGENTS.md Rule 4) and is
#           removed on exit. The live monorepo is never traversed (Rule 5).
#--------------------------------------------------------------------------#>

[CmdletBinding()]
param(
    [int]$Iterations = 5,
    [ValidateSet('All', 'Variance', 'GitSpawns', 'LogScaling')]
    [string]$Experiment = 'All',

    # --- internal: used when the harness re-invokes itself in a child process ---
    [switch]$InternalRun,
    [string]$Fixture,
    [string]$SafeDest,
    [string]$ModeArgs
)

$ErrorActionPreference = 'Stop'
$script:Here = $PSScriptRoot
$script:Target = Join-Path $script:Here 'repoMgr.ps1'

#--------------------------------------------------------------------------
# INTERNAL RUN - executes inside a child pwsh so `exit` in the dispatcher
# cannot kill the harness, and so each measurement starts from a cold runspace.
#--------------------------------------------------------------------------
if ($InternalRun) {
    $realGit = (Get-Command git -CommandType Application | Select-Object -First 1).Source
    $script:gitCount = 0
    $script:gitMs = 0.0

    # Shadows git.exe for the whole run: `git ...` and Invoke-GitSafe's `& 'git'`
    # both resolve here, so the spawn count is total, not sampled.
    function git {
        $script:gitCount++
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try { & $realGit @args 2>$null }
        finally { $sw.Stop(); $script:gitMs += $sw.Elapsed.TotalMilliseconds }
    }

    $auditPath = Join-Path $Fixture ('repoMgr-logs\repoMgr-audit-{0}.json' -f (Get-Date).ToString('yyyy-MM-dd'))
    $seeded = 0
    if (Test-Path $auditPath) {
        try { $seeded = @((Get-Content $auditPath -Raw | ConvertFrom-Json)).Count } catch { $seeded = 0 }
    }

    $splat = @{ root = $Fixture; backupdest = $SafeDest; lookback = '7 days ago'; drBranch = 'PERF-DR' }
    foreach ($flag in ($ModeArgs -split ',' | Where-Object { $_ })) { $splat[$flag] = $true }

    $total = [System.Diagnostics.Stopwatch]::StartNew()
    try { . $PSScriptRoot\repoMgr.ps1 @splat *> $null } catch { }
    $total.Stop()

    $after = 0
    if (Test-Path $auditPath) {
        try { $after = @((Get-Content $auditPath -Raw | ConvertFrom-Json)).Count } catch { $after = 0 }
    }

    [pscustomobject]@{
        TotalMs     = [math]::Round($total.Elapsed.TotalMilliseconds, 1)
        GitSpawns   = $script:gitCount
        GitMs       = [math]::Round($script:gitMs, 1)
        LogSeeded   = $seeded
        LogWritten  = [math]::Max(0, $after - $seeded)
    } | ConvertTo-Json -Compress | ForEach-Object { "##MVX##$_" }
    return
}

#--------------------------------------------------------------------------
# HARNESS
#--------------------------------------------------------------------------
function New-PerfFixture {
    $fixture = Join-Path $script:Here 'perf-fixture'
    $origin = Join-Path $script:Here 'perf-fixture-origin.git'
    $safe = Join-Path $script:Here 'perf-fixture-safe'
    foreach ($p in @($fixture, $origin, $safe)) {
        if (Test-Path $p) { Remove-Item $p -Recurse -Force }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    git init --bare $origin *>$null
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    New-Item -ItemType Directory -Path $safe -Force | Out-Null

    git init -b main $fixture *>$null
    git -C $fixture remote add origin $origin *>$null
    'root' | Set-Content (Join-Path $fixture 'app.txt')
    git -C $fixture add . *>$null
    git -C $fixture -c user.email=p@p -c user.name=perf commit -m 'root' *>$null

    # Nested repo intentionally shares the origin so the collision path is exercised.
    $nested = Join-Path $fixture 'nested'
    New-Item -ItemType Directory -Path $nested -Force | Out-Null
    git init -b main $nested *>$null
    git -C $nested remote add origin $origin *>$null
    'nested' | Set-Content (Join-Path $nested 'lib.txt')
    git -C $nested add . *>$null
    git -C $nested -c user.email=p@p -c user.name=perf commit -m 'nested' *>$null
    $sw.Stop()

    return [pscustomobject]@{
        Fixture = $fixture; Origin = $origin; SafeDest = $safe
        BuildMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    }
}

function Remove-PerfFixture {
    param($Ctx)
    foreach ($p in @($Ctx.Fixture, $Ctx.Origin, $Ctx.SafeDest)) {
        for ($i = 0; $i -lt 5; $i++) {
            try { if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction Stop }; break }
            catch { Start-Sleep -Milliseconds 300 }
        }
    }
}

function Set-SeededAuditLog {
    param([string]$FixturePath, [int]$Count)
    $dir = Join-Path $FixturePath 'repoMgr-logs'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $file = Join-Path $dir ('repoMgr-audit-{0}.json' -f (Get-Date).ToString('yyyy-MM-dd'))
    if ($Count -le 0) { if (Test-Path $file) { Remove-Item $file -Force }; return }

    $entries = 1..$Count | ForEach-Object {
        [pscustomobject]@{
            runId = [guid]::NewGuid().ToString(); timestamp = (Get-Date).ToString('o')
            action = 'SEED'; path = $FixturePath; root = $FixturePath
            dryRun = $true; force = $false; result = "seeded entry $_"
        }
    }
    $entries | ConvertTo-Json -Depth 6 | Set-Content -Path $file -Encoding UTF8
}

function Invoke-PerfRun {
    param($Ctx, [string]$ModeArgs)
    $out = & pwsh -NoProfile -File $PSCommandPath -InternalRun `
        -Fixture $Ctx.Fixture -SafeDest $Ctx.SafeDest -ModeArgs $ModeArgs 2>$null
    $line = $out | Where-Object { $_ -like '##MVX##*' } | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace '^##MVX##', '') | ConvertFrom-Json
}

function Write-Stat {
    param([string]$Label, [double[]]$Samples)
    $s = $Samples | Sort-Object
    $median = $s[[math]::Floor($s.Count / 2)]
    [pscustomobject]@{
        Measure = $Label
        Min     = [math]::Round($s[0], 1)
        Median  = [math]::Round($median, 1)
        Max     = [math]::Round($s[-1], 1)
        Spread  = "$([math]::Round((($s[-1] - $s[0]) / [math]::Max($s[0], 1)) * 100, 0))%"
    }
}

#--------------------------------------------------------------------------
Write-Host "`n=== MVx: repoMgr performance experiment ===" -ForegroundColor Cyan
if (-not (Test-Path $script:Target)) { throw "repoMgr.ps1 not found beside the harness." }

$ctx = New-PerfFixture
Write-Host "Fixture built in $($ctx.BuildMs) ms  (2 repos, shared origin)" -ForegroundColor DarkGray
$results = [ordered]@{}

try {
    # --- E1 + E2: variance and git spawn accounting on the default flow -----
    if ($Experiment -in @('All', 'Variance', 'GitSpawns')) {
        Write-Host "`n[E1/E2] default reporting flow x$Iterations" -ForegroundColor Yellow
        Set-SeededAuditLog -FixturePath $ctx.Fixture -Count 0
        $runs = @()
        for ($i = 1; $i -le $Iterations; $i++) {
            Set-SeededAuditLog -FixturePath $ctx.Fixture -Count 0
            $r = Invoke-PerfRun -Ctx $ctx -ModeArgs 'dryrun'
            if ($r) { $runs += $r; Write-Host "  run $i : $($r.TotalMs) ms | $($r.GitSpawns) git spawns ($($r.GitMs) ms) | $($r.LogWritten) log writes" -ForegroundColor DarkGray }
        }
        if ($runs) {
            $results['E1_Total']  = Write-Stat 'Total run (ms)' ($runs.TotalMs)
            $results['E2_GitMs']  = Write-Stat 'Time in git (ms)' ($runs.GitMs)
            $g = $runs[0]
            $pct = [math]::Round(($g.GitMs / [math]::Max($g.TotalMs, 1)) * 100, 1)
            Write-Host "  -> git accounts for ~$pct% of run 1; $($g.GitSpawns) spawns, $($g.LogWritten) log writes" -ForegroundColor Green
        }
    }

    # --- E3: does a bigger pre-existing audit file slow the run down? -------
    if ($Experiment -in @('All', 'LogScaling')) {
        Write-Host "`n[E3] log() scaling vs pre-existing audit size" -ForegroundColor Yellow
        foreach ($seed in @(0, 250, 1000, 2500)) {
            $samples = @()
            for ($i = 1; $i -le ([math]::Max(3, [math]::Floor($Iterations / 2))); $i++) {
                Set-SeededAuditLog -FixturePath $ctx.Fixture -Count $seed
                $r = Invoke-PerfRun -Ctx $ctx -ModeArgs 'dryrun'
                if ($r) { $samples += $r.TotalMs }
            }
            if ($samples) {
                $stat = Write-Stat "seed=$seed entries" $samples
                $results["E3_seed$seed"] = $stat
                Write-Host "  seed $($seed.ToString().PadLeft(4)) entries -> median $($stat.Median) ms (min $($stat.Min), max $($stat.Max))" -ForegroundColor DarkGray
            }
        }
        Write-Host "  -> if median climbs with seed size, log() O(n^2) is confirmed" -ForegroundColor Green
    }
}
finally {
    Remove-PerfFixture -Ctx $ctx
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Fixture build cost: $($ctx.BuildMs) ms (excluded from run timings)" -ForegroundColor DarkGray
$results.Values | Format-Table -AutoSize | Out-String | Write-Host

$artifact = Join-Path $script:Here 'REPORT-perf-MVx.json'
[pscustomobject]@{
    generated  = (Get-Date).ToString('o')
    iterations = $Iterations
    experiment = $Experiment
    fixtureBuildMs = $ctx.BuildMs
    results    = $results
} | ConvertTo-Json -Depth 6 | Set-Content -Path $artifact -Encoding UTF8
Write-Host "Artifact: $artifact" -ForegroundColor DarkGray
