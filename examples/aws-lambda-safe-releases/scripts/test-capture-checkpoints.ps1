[CmdletBinding()]
param(
    [switch]$KeepArtifacts,
    [int]$StageTimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
$exampleRoot = Split-Path -Parent $PSScriptRoot
$runLive = Join-Path $PSScriptRoot "run-live.ps1"
if (-not (Test-Path -LiteralPath $runLive)) { throw "run-live.ps1 not found at $runLive" }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$testRoot = Join-Path $env:TEMP "aws-lambda-safe-releases-capture-test-$stamp"
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

$expected = @(
    "01-baseline",
    "02-healthy",
    "03-canary",
    "04-alarm",
    "05-rollback",
    "06-recovery",
    "07-no-drift",
    "08-evidence",
    "09-cleanup"
)

function Start-SelfTest {
    param([string]$CaptureDir, [string]$RunId, [int]$MarkerTimeout)

    $outLog = Join-Path $CaptureDir "child-stdout.log"
    $errLog = Join-Path $CaptureDir "child-stderr.log"
    $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$runLive`" -CaptureMode -SelfTest -RunId `"$RunId`" -CaptureDir `"$CaptureDir`" -MarkerTimeoutSeconds $MarkerTimeout -MarkerPollSeconds 1"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = $argLine
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    return [pscustomobject]@{
        Process   = $proc
        StdOut    = $proc.StandardOutput.ReadToEndAsync()
        StdErr    = $proc.StandardError.ReadToEndAsync()
        StdOutLog = $outLog
        StdErrLog = $errLog
    }
}

function Complete-SelfTest {
    param([object]$Child)
    $Child.Process.WaitForExit()
    $stdout = $Child.StdOut.Result
    $stderr = $Child.StdErr.Result
    Set-Content -LiteralPath $Child.StdOutLog -Value $stdout -Encoding UTF8
    Set-Content -LiteralPath $Child.StdErrLog -Value $stderr -Encoding UTF8
    return $Child.Process.ExitCode
}

function Wait-ForStageJson {
    param([string]$CaptureDir, [string]$StageId, [int]$TimeoutSeconds)
    $json = Join-Path $CaptureDir "$StageId.json"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $json) { return $true }
        Start-Sleep -Milliseconds 200
    }
    return $false
}

$failures = New-Object System.Collections.Generic.List[string]
$passes = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------------------
# Case 1: positive - all markers created, expect exit 0 and 9 JSON files.
# ---------------------------------------------------------------------------
$capture1 = Join-Path $testRoot "positive"
New-Item -ItemType Directory -Force -Path $capture1 | Out-Null
$runId1 = "selftest-pos-$stamp"
Write-Host "== Case 1: positive (create all markers) =="
$child = Start-SelfTest -CaptureDir $capture1 -RunId $runId1 -MarkerTimeout $StageTimeoutSeconds
$seen = @{}
$deadline = (Get-Date).AddSeconds(($StageTimeoutSeconds * $expected.Count) + 60)
while (-not $child.Process.HasExited -and (Get-Date) -lt $deadline) {
    foreach ($id in $expected) {
        if ($seen.ContainsKey($id)) { continue }
        $json = Join-Path $capture1 "$id.json"
        $marker = Join-Path $capture1 "$id.continue"
        if ((Test-Path -LiteralPath $json) -and -not (Test-Path -LiteralPath $marker)) {
            Set-Content -LiteralPath $marker -Value "continue" -NoNewline -Encoding ASCII
            $seen[$id] = $true
            Write-Host ("  marker created: {0}.continue" -f $id)
        }
    }
    if ($child.Process.HasExited) { break }
    Start-Sleep -Milliseconds 200
}
$exit1 = Complete-SelfTest -Child $child

if ($exit1 -eq 0) { $passes.Add("positive: exit code 0") } else { $failures.Add("positive: expected exit 0, got $exit1") }
$jsonCount = ($expected | Where-Object { Test-Path -LiteralPath (Join-Path $capture1 "$_.json") }).Count
if ($jsonCount -eq $expected.Count) { $passes.Add("positive: $jsonCount/$($expected.Count) stage JSON files emitted") }
else { $failures.Add("positive: only $jsonCount/$($expected.Count) stage JSON files emitted") }

$leftMarkers = (Get-ChildItem -LiteralPath $capture1 -Filter "*.continue" -File -ErrorAction SilentlyContinue).Count
if ($leftMarkers -eq 0) { $passes.Add("positive: all markers consumed") }
else { $failures.Add("positive: $leftMarkers marker(s) left behind") }

if (-not (Test-Path -LiteralPath (Join-Path $capture1 "failure.json"))) { $passes.Add("positive: no failure.json") }
else { $failures.Add("positive: unexpected failure.json") }

$meta = Get-Content -LiteralPath (Join-Path $capture1 "01-baseline.json") -Raw | ConvertFrom-Json
if ($meta.mode -eq "capture" -and $meta.markerPath -and $meta.jsonPath) { $passes.Add("positive: stage JSON has mode/markerPath/jsonPath") }
else { $failures.Add("positive: stage JSON missing mode/markerPath/jsonPath") }
if ($meta.context.functionVersion -eq "1") { $passes.Add("positive: context emitted") }
else { $failures.Add("positive: context missing") }

# ---------------------------------------------------------------------------
# Case 2: negative - no markers, short timeout, expect exit 2 + failure.json.
# ---------------------------------------------------------------------------
$capture2 = Join-Path $testRoot "timeout"
New-Item -ItemType Directory -Force -Path $capture2 | Out-Null
$runId2 = "selftest-timeout-$stamp"
Write-Host "== Case 2: timeout (no markers) =="
$child2 = Start-SelfTest -CaptureDir $capture2 -RunId $runId2 -MarkerTimeout 2
$child2.Process.WaitForExit()
$exit2 = Complete-SelfTest -Child $child2
if ($exit2 -eq 2) { $passes.Add("timeout: exit code 2") } else { $failures.Add("timeout: expected exit 2, got $exit2") }
$failurePath = Join-Path $capture2 "failure.json"
if (Test-Path -LiteralPath $failurePath) {
    $failure = Get-Content -LiteralPath $failurePath -Raw | ConvertFrom-Json
    if ($failure.stageId -eq "01-baseline" -and $failure.error -match "Timed out") {
        $passes.Add("timeout: failure.json records stage and timeout error")
    } else {
        $failures.Add("timeout: failure.json has unexpected stage/error")
    }
} else {
    $failures.Add("timeout: failure.json not written")
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "== Results =="
foreach ($p in $passes) { Write-Host ("  PASS  " + $p) -ForegroundColor Green }
foreach ($f in $failures) { Write-Host ("  FAIL  " + $f) -ForegroundColor Red }
Write-Host ""
Write-Host ("Artifacts: " + $testRoot)

# Clean the gitignored self-test raw dirs created by run-live.ps1.
if (-not $KeepArtifacts) {
    foreach ($rid in @($runId1, $runId2)) {
        $raw = Join-Path $exampleRoot "evidence/raw/$rid"
        if (Test-Path -LiteralPath $raw) { Remove-Item -Recurse -Force -LiteralPath $raw }
    }
    Write-Host "Removed self-test raw dirs (use -KeepArtifacts to keep them)."
}

if ($failures.Count -gt 0) { exit 1 }
Write-Host "ALL CAPTURE-MODE LOCAL CHECKS PASSED" -ForegroundColor Green
exit 0
