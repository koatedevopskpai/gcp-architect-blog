<#
.SYNOPSIS
    Capture CLI-obtainable evidence for the SLO post, then hand off to the
    screenshot drop zone for the console-only artifacts (SLO burn, alert firing).

.DESCRIPTION
    Drives the baseline -> burn -> recovery load phases against the slo-demo
    Cloud Run service and writes the CLI evidence into
    public/evidence/slos-for-cloud-run/. Uses a built-in runspace load generator
    (no `hey`/`vegeta` needed).

    Requires: gcloud (authenticated), a completed `terraform apply`, and
    Windows PowerShell 5.1+ / PowerShell 7.

.PARAMETER Project
    GCP project id. Defaults to gcp-architect-demo-2026.

.PARAMETER Region
    Cloud Run region. Defaults to us-central1.

.PARAMETER Service
    Cloud Run service name. Defaults to slo-demo.

.PARAMETER Seconds
    Length of each phase, in seconds. Defaults to 180.

.PARAMETER Concurrency
    Concurrent workers per phase. Defaults to 20.

.EXAMPLE
    ./capture-evidence.ps1
    ./capture-evidence.ps1 -Seconds 240 -Concurrency 30
#>
[CmdletBinding()]
param(
    [string]$Project     = "gcp-architect-demo-2026",
    [string]$Region      = "us-central1",
    [string]$Service     = "slo-demo",
    [int]   $Seconds     = 180,
    [int]   $Concurrency = 20
)

$ErrorActionPreference = 'Stop'

# Attribute gcloud's API quota/usage to the target project, so a stale ADC
# quota project ("project ... does not match quota project ...") can't bite.
$env:CLOUDSDK_BILLING_QUOTA_PROJECT = $Project

function Get-UtcStamp { (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }

# ---------------------------------------------------------------------------
# Built-in load generator: N runspaces each hammer a URL in a loop for a fixed
# wall-clock window. Phase 2 passes two paths (fail + slow) so workers alternate.
# ---------------------------------------------------------------------------
$script:LoadWorker = {
    param([string]$BaseUrl, [string[]]$Paths, [long]$DeadlineTicks, [int]$WorkerIndex)

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::DefaultConnectionLimit = 200
    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromSeconds(30)
    $deadline = [DateTime]::new([long]$DeadlineTicks)

    $ok = 0; $fail = 0; $other = 0; $slow = 0; $n = 0; $sumMs = 0.0
    $i = $WorkerIndex
    while ([DateTime]::UtcNow -lt $deadline) {
        $path = $Paths[$i % $Paths.Count]
        $i++
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $resp = $client.GetAsync($BaseUrl + $path).GetAwaiter().GetResult()
            $sw.Stop()
            $code = [int]$resp.StatusCode
            if ($code -ge 500) { $fail++ }
            elseif ($code -ge 400) { $other++ }   # 4xx (e.g. 403 = IAM problem)
            else { $ok++ }
            if ($sw.Elapsed.TotalMilliseconds -ge 1000) { $slow++ }
        } catch {
            $sw.Stop(); $fail++
        }
        $sumMs += $sw.Elapsed.TotalMilliseconds; $n++
    }
    [pscustomobject]@{ Ok = $ok; Fail = $fail; Other = $other; Slow = $slow; N = $n; SumMs = $sumMs }
}

function Invoke-LoadPhase {
    param(
        [string]   $BaseUrl,
        [string[]] $Paths,
        [int]      $Seconds,
        [int]      $Concurrency
    )
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    $pool = [runspacefactory]::CreateRunspacePool(1, $Concurrency)
    $pool.Open()

    $handles = @()
    for ($w = 0; $w -lt $Concurrency; $w++) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript($script:LoadWorker).
            AddArgument($BaseUrl).AddArgument($Paths).
            AddArgument($deadline.Ticks).AddArgument($w)
        $handles += [pscustomobject]@{ PS = $ps; Handle = $ps.BeginInvoke() }
    }

    $stats = foreach ($h in $handles) { $h.PS.EndInvoke($h.Handle) }
    foreach ($h in $handles) { $h.PS.Dispose() }
    $pool.Close(); $pool.Dispose()

    $sum = { param($p) ($stats | Measure-Object -Property $p -Sum).Sum }
    $ok    = & $sum Ok
    $fail  = & $sum Fail
    $other = & $sum Other
    $slow  = & $sum Slow
    $n     = & $sum N
    $ms    = & $sum SumMs
    $avg   = if ($n -gt 0) { [math]::Round($ms / $n) } else { 0 }

    [pscustomobject]@{ Ok = $ok; Fail = $fail; Other = $other; Slow = $slow; Total = $n; AvgMs = $avg }
}

# Repo root is two levels up from examples/slos-for-cloud-run.
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$evid = Join-Path $root "public/evidence/slos-for-cloud-run"
New-Item -ItemType Directory -Force -Path $evid | Out-Null
Write-Host "Evidence dir: $evid"

# ---------------------------------------------------------------------------
# 1. Service pointer + health check
# ---------------------------------------------------------------------------
$url = (& gcloud run services describe $Service --region $Region --project $Project --format 'value(status.url)').Trim()
if ($LASTEXITCODE -ne 0 -or -not $url) { throw "Could not resolve service URL for '$Service'." }
Set-Content -LiteralPath (Join-Path $evid 'service-url.txt') -Value $url -Encoding UTF8
Write-Host "Service URL: $url"

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
try {
    $resp = Invoke-WebRequest -Uri "$url/health" -UseBasicParsing -TimeoutSec 15
    $code = [int]$resp.StatusCode
    $body = $resp.Content.ToString().Trim()
} catch {
    $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
    $body = ""
}
@(
    "HTTP $code - $url/health ($(Get-UtcStamp))"
    "body: $body"
) | Set-Content -LiteralPath (Join-Path $evid 'health-check.txt') -Encoding UTF8

# ---------------------------------------------------------------------------
# 2. Service + revision + alert-policy definitions (redact before publishing)
# ---------------------------------------------------------------------------
$desc = & gcloud run services describe $Service --region $Region --project $Project --format json
if ($LASTEXITCODE -eq 0) { $desc | Set-Content -LiteralPath (Join-Path $evid 'service-describe.json') -Encoding UTF8 }

$revs = & gcloud run revisions list --service $Service --region $Region --project $Project
if ($LASTEXITCODE -eq 0) { $revs | Set-Content -LiteralPath (Join-Path $evid 'revisions.txt') -Encoding UTF8 }

try {
    $pol = & gcloud monitoring policies list --project $Project --format json 2>$null
    if ($LASTEXITCODE -eq 0 -and $pol) {
        $pol | Set-Content -LiteralPath (Join-Path $evid 'alert-policies.json') -Encoding UTF8
    } else {
        throw "unavailable"
    }
} catch {
    "note: 'gcloud monitoring policies list' unavailable - capture alert policies via console" |
        Set-Content -LiteralPath (Join-Path $evid 'alert-policies.json') -Encoding UTF8
}

# ---------------------------------------------------------------------------
# 3. Drive the burn and record the run window + load output
# ---------------------------------------------------------------------------
$runFile = Join-Path $evid 'load-run.txt'
@(
    "# SLO burn run - $(Get-UtcStamp)"
    "# service=$Service region=$Region concurrency=$Concurrency phase=${Seconds}s"
    "# NOTE: paste the fast-burn alert firing + resolve timestamps (from the"
    "#       inbox / alert incidents) below the summary when captured."
) | Set-Content -LiteralPath $runFile -Encoding UTF8

function Write-Phase {
    param([string]$Label, [object]$Result)
    $line = "{0}  ok={1} fail(5xx)={2} other(4xx)={3} slow(>=1s)={4} total={5} avg={6}ms [{7}]" -f `
        $Label, $Result.Ok, $Result.Fail, $Result.Other, $Result.Slow, $Result.Total, $Result.AvgMs, (Get-UtcStamp)
    Add-Content -LiteralPath $runFile -Value $line -Encoding UTF8
    Write-Host $line
}

Write-Host "== Phase 1: baseline (green) - ${Seconds}s x $Concurrency workers"
Write-Phase "baseline" (Invoke-LoadPhase -BaseUrl $url -Paths @('/work') -Seconds $Seconds -Concurrency $Concurrency)

Write-Host "== Phase 2: burn - mixed 500s + slow responses"
Write-Phase "burn    " (Invoke-LoadPhase -BaseUrl $url -Paths @('/work?fail=1', '/work?latency_ms=1500') -Seconds $Seconds -Concurrency $Concurrency)

Write-Host "== Phase 3: recovery - clean traffic"
Write-Phase "recovery" (Invoke-LoadPhase -BaseUrl $url -Paths @('/work') -Seconds $Seconds -Concurrency $Concurrency)

@(
    ""
    "# captured $(Get-UtcStamp)"
    "# SLO burn at end of recovery window:"
    "#   1h burn = <fill from console>   (expect near 0 after recovery)"
) | ForEach-Object { Add-Content -LiteralPath $runFile -Value $_ -Encoding UTF8 }

# ---------------------------------------------------------------------------
# 4. Cost note template (fill after the billing line appears; billing lags ~1d)
# ---------------------------------------------------------------------------
$costFile = Join-Path $evid 'cost-note.txt'
if (-not (Test-Path -LiteralPath $costFile)) {
    @(
        "Window: Cloud Run slo-demo, scale-to-zero, client-side load burst only (no VM)."
        "Expected total: <`$1 for the run-and-capture session."
        "TODO: paste the actual billing line for the run window, then confirm teardown."
    ) | Set-Content -LiteralPath $costFile -Encoding UTF8
}

# ---------------------------------------------------------------------------
# 5. Teardown reminder
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Capture the console screenshots listed in:"
Write-Host "  $(Join-Path $evid 'SCREENSHOTS.md')"
Write-Host ""
Write-Host "Then tear down (same day):"
Write-Host "  terraform destroy -var=`"project_id=$Project`""
Write-Host ""
Write-Host "Done. Files written to $evid" -ForegroundColor Green
