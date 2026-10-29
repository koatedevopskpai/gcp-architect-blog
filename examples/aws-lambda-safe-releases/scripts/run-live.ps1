[CmdletBinding()]
param(
    [switch]$TestNotification,
    [switch]$SkipApply,
    [switch]$SkipBaseline,
    [switch]$SkipApproval,
    [switch]$SkipHealthy,
    [switch]$CaptureMode,
    [switch]$NativeHelpers,
    [switch]$SelfTest,
    [switch]$ApproveSpend,
    [switch]$DestroyAfter,
    [string]$CaptureDir = "",
    [int]$MarkerTimeoutSeconds = 1800,
    [int]$MarkerPollSeconds = 2,
    [string]$RunId = ""
)

$ErrorActionPreference = "Stop"

if ($SelfTest) { $CaptureMode = $true }

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$region = "eu-west-2"
$functionName = "aws-lambda-safe-releases"
$aliasName = "live"
$appName = $functionName
$groupName = "$functionName-canary"
$alarmName = "$functionName-live-errors"
$runId = if ($RunId) { $RunId } else { Get-Date -Format "yyyyMMdd-HHmm" }
$rawDir = Join-Path $root "evidence/raw/$runId"
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
$logPath = Join-Path $rawDir "run-log.txt"

$captureDir = if ($CaptureDir) {
    if ([System.IO.Path]::IsPathRooted($CaptureDir)) { $CaptureDir } else { Join-Path $root $CaptureDir }
} else {
    Join-Path $rawDir "capture"
}
$captureDir = [System.IO.Path]::GetFullPath($captureDir)
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null

$script:CurrentStageId = ""
$script:TeardownDone = $false
$script:LoadProcess = $null

function Write-RunLog {
    param([string]$Message)
    $line = "$(Get-Date -Format o)  $Message"
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

function Write-JsonFile {
    param([string]$Path, [object]$Object)
    $json = $Object | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText(
        $Path,
        $json,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Write-CaptureStage {
    param(
        [string]$StageId,
        [string]$Title,
        [string]$Message,
        [string]$Url,
        [string]$ScreenshotName = "",
        [bool]$CaptureRequired = $true,
        [hashtable]$Context = @{},
        [switch]$NoWait
    )

    $script:CurrentStageId = $StageId
    $jsonPath = Join-Path $captureDir "$StageId.json"
    $markerPath = Join-Path $captureDir "$StageId.continue"

    $payload = [ordered]@{
        schemaVersion   = 1
        mode            = "capture"
        runId           = $runId
        region          = $region
        stageId         = $StageId
        title           = $Title
        message         = $Message
        url             = $Url
        screenshotName  = $ScreenshotName
        captureRequired = $CaptureRequired
        captureDir      = $captureDir
        jsonPath        = $jsonPath
        markerPath      = $markerPath
        emittedAtUtc    = (Get-Date).ToUniversalTime().ToString("o")
        context         = $Context
    }

    Write-JsonFile -Path $jsonPath -Object $payload
    Write-RunLog "STAGE $StageId emitted -> $jsonPath"

    if ($NoWait) {
        Write-RunLog "STAGE $StageId emitted without waiting (failure path)"
        return
    }

    $deadline = (Get-Date).AddSeconds($MarkerTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $markerPath) {
            Remove-Item -LiteralPath $markerPath -Force
            Write-RunLog "STAGE $StageId continued (marker consumed)"
            return
        }
        Start-Sleep -Seconds $MarkerPollSeconds
    }

    throw "Timed out after $MarkerTimeoutSeconds s waiting for marker: $markerPath"
}

function Write-CaptureFailure {
    param([string]$Message)
    if (-not $CaptureMode) { return }
    $payload = [ordered]@{
        schemaVersion = 1
        mode          = "capture"
        runId         = $runId
        region        = $region
        stageId       = $script:CurrentStageId
        error         = $Message
        captureDir    = $captureDir
        emittedAtUtc  = (Get-Date).ToUniversalTime().ToString("o")
    }
    $path = Join-Path $captureDir "failure.json"
    Write-JsonFile -Path $path -Object $payload
    Write-RunLog "FAILURE recorded -> $path"
}

function Show-Stage {
    param(
        [string]$StageId = "",
        [string]$Title,
        [string]$Message,
        [string]$Url,
        [string]$DoneText = "Screenshot done - continue",
        [int]$AutoCloseSeconds = 0,
        [string]$ScreenshotName = "",
        [bool]$CaptureRequired = $true,
        [hashtable]$Context = @{},
        [switch]$NoWait
    )

    if ($CaptureMode) {
        if (-not $StageId) { throw "Capture mode requires an explicit -StageId for stage '$Title'" }
        Write-CaptureStage -StageId $StageId -Title $Title -Message $Message -Url $Url `
            -ScreenshotName $ScreenshotName -CaptureRequired $CaptureRequired `
            -Context $Context -NoWait:$NoWait
        return
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    if ($Url) { Start-Process $Url | Out-Null }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.ClientSize = New-Object System.Drawing.Size(560, 285)
    $form.StartPosition = "Manual"
    $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Location = New-Object System.Drawing.Point(($area.Right - 580), ($area.Bottom - 325))
    $form.TopMost = $true
    $form.FormBorderStyle = "FixedToolWindow"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.AutoSize = $false
    $label.Size = New-Object System.Drawing.Size(530, 190)
    $label.Location = New-Object System.Drawing.Point(12, 12)
    $form.Controls.Add($label)

    $open = New-Object System.Windows.Forms.Button
    $open.Text = "Open console"
    $open.Size = New-Object System.Drawing.Size(130, 34)
    $open.Location = New-Object System.Drawing.Point(12, 230)
    $open.Add_Click({ if ($Url) { Start-Process $Url | Out-Null } })
    if (-not $Url) { $open.Enabled = $false }
    $form.Controls.Add($open)

    $hide = New-Object System.Windows.Forms.Button
    $hide.Text = "Hide 60s"
    $hide.Size = New-Object System.Drawing.Size(110, 34)
    $hide.Location = New-Object System.Drawing.Point(152, 230)
    $form.Controls.Add($hide)

    $done = New-Object System.Windows.Forms.Button
    $done.Text = $DoneText
    $done.Size = New-Object System.Drawing.Size(270, 34)
    $done.Location = New-Object System.Drawing.Point(272, 230)
    $done.Add_Click({ $form.Close() })
    $form.Controls.Add($done)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 60000
    $timer.Add_Tick({
        $timer.Stop()
        $form.Show()
        $form.Activate()
    })
    $hide.Add_Click({
        $form.Hide()
        $timer.Start()
    })

    if ($AutoCloseSeconds -gt 0) {
        $auto = New-Object System.Windows.Forms.Timer
        $auto.Interval = $AutoCloseSeconds * 1000
        $auto.Add_Tick({
            $auto.Stop()
            $form.Close()
        })
        $auto.Start()
    }

    [void]$form.ShowDialog()
    $form.Dispose()
    Write-RunLog "Acknowledged: $Title"
}

function Ask-YesNo {
    param([string]$Title, [string]$Message)
    if ($CaptureMode) {
        throw "Interactive confirmation requested in capture mode: '$Title'. Use explicit flags (-ApproveSpend / -DestroyAfter)."
    }
    Add-Type -AssemblyName System.Windows.Forms
    $result = [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    return $result -eq [System.Windows.Forms.DialogResult]::Yes
}

function Get-AwsText {
    param([string[]]$Arguments)
    $output = & aws @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "aws $($Arguments -join ' ') failed: $output"
    }
    return (($output | Out-String).Trim())
}

function Invoke-CheckedBash {
    param([string]$Command)
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($NativeHelpers) {
            $output = & python scripts/native-capture-helper.py $Command 2>&1
        } else {
            $output = & bash -c $Command 2>&1
        }
        $exit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $old
    }
    $text = ($output | Out-String).Trim()
    if ($exit -ne 0) {
        throw "bash command failed (exit $exit): $Command`n$text"
    }
    return $text
}

function Invoke-CheckedTerraform {
    param([string[]]$Arguments)
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & terraform @Arguments 2>&1
        $exit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $old
    }
    $text = ($output | Out-String).Trim()
    if ($exit -ne 0) {
        throw "terraform $($Arguments -join ' ') failed: $text"
    }
    return $text
}

function Wait-Until {
    param(
        [scriptblock]$Condition,
        [int]$TimeoutSeconds,
        [string]$Description,
        [int]$IntervalSeconds = 5
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Condition) { return $true }
        Start-Sleep -Seconds $IntervalSeconds
    }
    Write-RunLog "Timeout waiting for $Description"
    return $false
}

function Invoke-Teardown {
    param([string]$Reason = "authorised")
    if ($script:TeardownDone) {
        Write-RunLog "Teardown already completed; skipping ($Reason)"
        return [pscustomobject]@{
            DestroyOutput  = ""
            BudgetOutput   = ""
            TeardownPath   = (Join-Path $rawDir "teardown.txt")
            TeardownOutput = "already completed"
        }
    }

    Write-RunLog "Teardown start ($Reason)"
    $destroyOut = Invoke-CheckedTerraform @("-chdir=infra", "destroy", "-auto-approve", "-input=false")
    $destroyOut | Tee-Object -FilePath (Join-Path $rawDir "terraform-destroy.txt")

    # Keep the tag-scoped budget as a guardrail after the stack is gone.
    $budgetOut = Invoke-CheckedTerraform @("-chdir=infra", "apply", "-auto-approve", "-input=false", "-target=aws_budgets_budget.demo")
    $budgetOut | Tee-Object -FilePath (Join-Path $rawDir "restore-budget.txt")

    $teardownPath = Join-Path $rawDir "teardown.txt"
    $teardownOut = Invoke-CheckedBash "AWS_REGION='$region' PROJECT='aws-lambda-safe-releases' scripts/verify-teardown.sh"
    $teardownOut | Tee-Object -FilePath $teardownPath

    $script:TeardownDone = $true
    Write-RunLog "Teardown complete ($Reason)"
    return [pscustomobject]@{
        DestroyOutput = $destroyOut
        BudgetOutput  = $budgetOut
        TeardownPath  = $teardownPath
        TeardownOutput = $teardownOut
    }
}

function Invoke-SelfTest {
    Write-RunLog "SELF-TEST: capture checkpoints only (no AWS, Terraform or bash calls)"
    $stages = @(
        @{ id = "01-baseline"; title = "01 - Baseline v1"; shot = "01-baseline.png"; ctx = @{ functionVersion = "1"; apiUrl = "https://example.invalid/api" } },
        @{ id = "02-healthy"; title = "02 - Healthy candidate v2"; shot = "02-healthy-candidate.png"; ctx = @{ deploymentId = "d-SELFTEST1"; functionVersion = "2" } },
        @{ id = "03-canary"; title = "03 - Faulty canary v3"; shot = "03-canary-routing.png"; ctx = @{ deploymentId = "d-SELFTEST2"; targetVersion = "3"; previousVersion = "2" } },
        @{ id = "04-alarm"; title = "04 - Alarm ALARM"; shot = "04-alarm.png"; ctx = @{ alarmName = "aws-lambda-safe-releases-live-errors"; deploymentId = "d-SELFTEST2" } },
        @{ id = "05-rollback"; title = "05 - Automatic rollback to v2"; shot = "05-rollback.png"; ctx = @{ deploymentId = "d-SELFTEST2"; restoredVersion = "2" } },
        @{ id = "06-recovery"; title = "06 - Recovery verified"; shot = "06-recovery.png"; ctx = @{ aliasVersion = "2"; loadPath = "selftest/load.json" } },
        @{ id = "07-no-drift"; title = "07 - No alias drift"; shot = "07-no-drift.png"; ctx = @{ planPath = "selftest/post-rollback-plan.txt"; planText = "No changes. Your infrastructure matches the configuration." } },
        @{ id = "08-evidence"; title = "08 - Evidence captured"; shot = ""; required = $false; ctx = @{ evidenceDir = "selftest/evidence" } },
        @{ id = "09-cleanup"; title = "09 - Cleanup verified"; shot = "08-cleanup.png"; ctx = @{ teardownPath = "selftest/teardown.txt"; budgetRestored = $true } }
    )

    foreach ($s in $stages) {
        $stageParams = @{
            StageId        = $s.id
            Title          = $s.title
            Message        = "SELF-TEST: no cloud resources were created. Create the marker file to continue."
            Url            = ""
            ScreenshotName = $s.shot
            Context        = $s.ctx
        }
        if ($s.ContainsKey("required")) { $stageParams.CaptureRequired = $s.required }
        Show-Stage @stageParams
    }

    Write-RunLog "SELF-TEST complete: all checkpoints emitted and consumed"
}

# Clear stale markers so an interrupted prior run cannot auto-advance this one.
$staleMarkers = Get-ChildItem -LiteralPath $captureDir -Filter "*.continue" -File -ErrorAction SilentlyContinue
if ($staleMarkers) {
    $staleMarkers | Remove-Item -Force
    Write-RunLog "Cleared $($staleMarkers.Count) stale marker(s) from $captureDir"
}

$lambdaAliasUrl = "https://${region}.console.aws.amazon.com/lambda/home?region=${region}#/functions/${functionName}/aliases/${aliasName}"
$alarmUrl = "https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#alarmsV2:alarm/${alarmName}"

function Get-DeploymentUrl([string]$Id) {
    return "https://${region}.console.aws.amazon.com/codesuite/codedeploy/deployments/${Id}?region=${region}"
}

if ($SelfTest) {
    try {
        Invoke-SelfTest
        exit 0
    } catch {
        $selfTestError = $_.Exception.Message
        Write-RunLog "SELF-TEST FAILED: $selfTestError"
        Write-CaptureFailure -Message $selfTestError
        exit 2
    }
}

if ($TestNotification) {
    Write-RunLog "Test notification"
    Show-Stage -StageId "00-notification-test" `
        -Title "Screenshot notification test" `
        -Message "If you can read this, the notification works.`n`n1. Click 'Hide 60s' to clear the screen.`n2. Confirm the browser opened the Lambda page.`n3. Click 'Test complete' to exit.`n`nThis test auto-closes after 90 seconds." `
        -Url $lambdaAliasUrl `
        -DoneText "Test complete" `
        -AutoCloseSeconds 90
    exit 0
}

Write-RunLog "Run $runId starting (captureMode=$CaptureMode destroyAfter=$DestroyAfter)"

if ($CaptureMode -and -not ($SkipApproval -or $ApproveSpend)) {
    Write-RunLog "Capture mode requires explicit spend approval (-ApproveSpend or -SkipApproval). No dialog was shown."
    Write-CaptureFailure -Message "Spend approval not granted in capture mode."
    exit 1
}

if (-not $SkipApproval) {
    if ($CaptureMode) {
        Write-RunLog "Spend approved via -ApproveSpend/-SkipApproval (capture mode)"
    } elseif (-not (Ask-YesNo "Spend approval" "Create the demo stack in $region?`n`nExpected cost: under `$0.20.`nCeiling: `$2-5.`n`nClick Yes to proceed.")) {
        Write-RunLog "Aborted at spend approval"
        exit 1
    }
}

$exitCode = 0

try {
    if (-not $SkipApply) {
        Write-RunLog "terraform apply"
        $applyOut = Invoke-CheckedTerraform @("-chdir=infra", "apply", "-auto-approve", "-input=false")
        $applyOut | Tee-Object -FilePath (Join-Path $rawDir "terraform-apply.txt")
    }

    $apiUrl = (terraform -chdir=infra output -raw api_url).Trim()
    $bucket = (terraform -chdir=infra output -raw artifact_bucket).Trim()
    $env:AWS_REGION = $region
    $env:ARTIFACT_BUCKET = $bucket
    $env:FUNCTION_NAME = $functionName
    $env:ALIAS_NAME = $aliasName
    $env:CODEDEPLOY_APP = $appName
    $env:CODEDEPLOY_GROUP = $groupName
    $env:RUN_ID = $runId
    Write-RunLog "api_url=$apiUrl artifact_bucket=$bucket"

    if (-not $SkipBaseline) {
        # Stage 1 - baseline
        Write-RunLog "Stage 1 baseline load"
        & python scripts/load.py --url $apiUrl --seconds 60 --rate 10 --output (Join-Path $rawDir "baseline-load.json")
        $baselineVersion = Get-AwsText @("lambda", "get-alias", "--function-name", $functionName, "--name", $aliasName, "--region", $region, "--query", "FunctionVersion", "--output", "text")
        Show-Stage -StageId "01-baseline" `
            -Title "01 - Baseline v$baselineVersion" `
            -Message "Baseline v$baselineVersion is healthy.`n`nCapture: Lambda alias page showing 'live' -> version $baselineVersion.`nThe API response should say version=baseline.`n`nSave as 01-baseline.png." `
            -Url $lambdaAliasUrl `
            -ScreenshotName "01-baseline.png" `
            -Context @{ functionVersion = $baselineVersion; apiUrl = $apiUrl }
    } else {
        Write-RunLog "Skipping Stage 1 baseline (already completed)"
    }

    # Stage 2 - healthy candidate
    if (-not $SkipHealthy) {
        Write-RunLog "Stage 2 healthy deployment"
        $healthyOut = Invoke-CheckedBash "AWS_REGION='$region' ARTIFACT_BUCKET='$bucket' FUNCTION_NAME='$functionName' ALIAS_NAME='$aliasName' CODEDEPLOY_APP='$appName' CODEDEPLOY_GROUP='$groupName' scripts/deploy.sh healthy --wait"
        $healthyOut | Tee-Object -FilePath (Join-Path $rawDir "deploy-healthy.txt")
        $healthyId = [regex]::Match($healthyOut, 'deployment_id=([^\s]+)').Groups[1].Value.Trim()
    } else {
        Write-RunLog "Skipping healthy deployment (already completed)"
        $healthyId = Get-AwsText @("deploy", "list-deployments", "--application-name", $appName, "--deployment-group-name", $groupName, "--region", $region, "--query", "deployments[0]", "--output", "text")
    }
    $healthyVersion = Get-AwsText @("lambda", "get-alias", "--function-name", $functionName, "--name", $aliasName, "--region", $region, "--query", "FunctionVersion", "--output", "text")
    Show-Stage -StageId "02-healthy" `
        -Title "02 - Healthy candidate v$healthyVersion" `
        -Message "Healthy candidate v$healthyVersion is at 100%.`n`nCapture: CodeDeploy deployment $healthyId (Succeeded) and the alias at v$healthyVersion.`n`nSave as 02-healthy-candidate.png." `
        -Url (Get-DeploymentUrl $healthyId) `
        -ScreenshotName "02-healthy-candidate.png" `
        -Context @{ deploymentId = $healthyId; functionVersion = $healthyVersion; apiUrl = $apiUrl }

    # Stage 3 - faulty canary
    Write-RunLog "Stage 3 faulty deployment"
    $preFaultVersion = Get-AwsText @("lambda", "get-alias", "--function-name", $functionName, "--name", $aliasName, "--region", $region, "--query", "FunctionVersion", "--output", "text")
    $faultyOut = Invoke-CheckedBash "AWS_REGION='$region' ARTIFACT_BUCKET='$bucket' FUNCTION_NAME='$functionName' ALIAS_NAME='$aliasName' CODEDEPLOY_APP='$appName' CODEDEPLOY_GROUP='$groupName' scripts/deploy.sh faulty"
    $faultyOut | Tee-Object -FilePath (Join-Path $rawDir "deploy-faulty.txt")
    if ($LASTEXITCODE -ne 0) { throw "faulty deployment start failed" }
    $faultyId = [regex]::Match($faultyOut, 'deployment_id=([^\s]+)').Groups[1].Value.Trim()
    $faultyVersion = [regex]::Match($faultyOut, 'target_version=([^\s]+)').Groups[1].Value.Trim()
    Write-RunLog "faulty deployment $faultyId, target v$faultyVersion, previous v$preFaultVersion"

    $loadPath = Join-Path $rawDir "load.json"
    $python = (Get-Command python).Source
    $load = Start-Process -FilePath $python -ArgumentList @(
        "scripts/load.py", "--url", $apiUrl, "--seconds", "360", "--rate", "10", "--output", $loadPath
    ) -NoNewWindow -PassThru
    $script:LoadProcess = $load

    $canary = Wait-Until -TimeoutSeconds 120 -Description "canary weights" -Condition {
        $weights = Get-AwsText @("lambda", "get-alias", "--function-name", $functionName, "--name", $aliasName, "--region", $region, "--query", "RoutingConfig.AdditionalVersionWeights", "--output", "json")
        return ($weights -ne "null" -and $weights -ne "{}" -and $weights.Trim() -ne "")
    }
    if (-not $canary) { throw "canary weights never appeared" }
    Show-Stage -StageId "03-canary" `
        -Title "03 - Faulty canary v$faultyVersion" `
        -Message "Canary is routing to faulty v$faultyVersion.`n`nTime-sensitive: capture within ~2 minutes.`nCapture: deployment $faultyId showing the 10% canary and the alias weights.`n`nSave as 03-canary-routing.png." `
        -Url (Get-DeploymentUrl $faultyId) `
        -ScreenshotName "03-canary-routing.png" `
        -Context @{ deploymentId = $faultyId; targetVersion = $faultyVersion; previousVersion = $preFaultVersion; apiUrl = $apiUrl }

    # Stage 4 - alarm
    $alarmFired = Wait-Until -TimeoutSeconds 300 -Description "alarm ALARM" -Condition {
        return (Get-AwsText @("cloudwatch", "describe-alarms", "--alarm-names", $alarmName, "--region", $region, "--query", "MetricAlarms[0].StateValue", "--output", "text")) -eq "ALARM"
    }
    if (-not $alarmFired) {
        Write-RunLog "Alarm did not fire; stopping deployment with auto-rollback"
        & aws deploy stop-deployment --deployment-id $faultyId --auto-rollback-enabled --region $region | Out-Null
        Show-Stage -StageId "04-alarm-missing" `
            -Title "ALARM DID NOT FIRE" `
            -Message "The alarm did not reach ALARM within 5 minutes. The deployment was stopped with auto-rollback.`n`nRecord this as a failed detection; do not present it as success." `
            -Url (Get-DeploymentUrl $faultyId) `
            -ScreenshotName "04-alarm-missing.png" `
            -Context @{ deploymentId = $faultyId; timeoutSeconds = 300 } `
            -NoWait
        throw "alarm did not fire"
    }
    Show-Stage -StageId "04-alarm" `
        -Title "04 - Alarm ALARM" `
        -Message "CloudWatch alarm '$alarmName' is in ALARM.`n`nCapture: the alarm page with metric, dimensions and time window.`n`nSave as 04-alarm.png." `
        -Url $alarmUrl `
        -ScreenshotName "04-alarm.png" `
        -Context @{ alarmName = $alarmName; deploymentId = $faultyId }

    # Stage 5 - rollback
    $rolledBack = Wait-Until -TimeoutSeconds 300 -Description "rollback of $faultyId" -Condition {
        $status = Get-AwsText @("deploy", "get-deployment", "--deployment-id", $faultyId, "--region", $region, "--query", "deploymentInfo.status", "--output", "text")
        $weights = Get-AwsText @("lambda", "get-alias", "--function-name", $functionName, "--name", $aliasName, "--region", $region, "--query", "RoutingConfig.AdditionalVersionWeights", "--output", "json")
        $weightsCleared = ($weights -eq "null" -or $weights -eq "{}" -or $weights.Trim() -eq "")
        return (($status -eq "Stopped" -or $status -eq "Failed") -and $weightsCleared)
    }
    if (-not $rolledBack) { throw "alias did not return to v$preFaultVersion" }
    Show-Stage -StageId "05-rollback" `
        -Title "05 - Automatic rollback to v$preFaultVersion" `
        -Message "CodeDeploy rolled back automatically.`n`nCapture: deployment $faultyId events/status and the alias back at v$preFaultVersion.`n`nSave as 05-rollback.png." `
        -Url (Get-DeploymentUrl $faultyId) `
        -ScreenshotName "05-rollback.png" `
        -Context @{ deploymentId = $faultyId; restoredVersion = $preFaultVersion }

    # Stage 6 - recovery
    $load.WaitForExit(420000) | Out-Null
    $loadSummary = Get-Content $loadPath -Raw | ConvertFrom-Json
    Write-RunLog ("Load summary: " + ($loadSummary | ConvertTo-Json -Compress))
    Show-Stage -StageId "06-recovery" `
        -Title "06 - Recovery verified" `
        -Message "Alias is back at v$preFaultVersion and the load completed.`n`nStatus counts: $($loadSummary.status_counts | ConvertTo-Json -Compress)`nVersion counts: $($loadSummary.version_counts | ConvertTo-Json -Compress)`n`nCapture: alias at v$preFaultVersion and the load summary.`nSave as 06-recovery.png." `
        -Url $lambdaAliasUrl `
        -ScreenshotName "06-recovery.png" `
        -Context @{ aliasVersion = $preFaultVersion; loadPath = $loadPath; statusCounts = $loadSummary.status_counts; versionCounts = $loadSummary.version_counts }

    # Stage 7 - no drift
    Write-RunLog "Stage 7 terraform plan"
    $planPath = Join-Path $rawDir "post-rollback-plan.txt"
    $planOut = Invoke-CheckedTerraform @("-chdir=infra", "plan", "-input=false", "-no-color")
    $planOut | Tee-Object -FilePath $planPath
    if (-not $CaptureMode) { Start-Process notepad.exe $planPath | Out-Null }
    Show-Stage -StageId "07-no-drift" `
        -Title "07 - No alias drift" `
        -Message "terraform plan is captured. It must show no changes to the alias or function.`n`nCapture the plan summary.`n`nSave as 07-no-drift.png." `
        -Url "" `
        -ScreenshotName "07-no-drift.png" `
        -Context @{ planPath = $planPath; planText = $planOut }

    # Stage 8 - evidence
    Write-RunLog "Stage 8 collect evidence"
    $env:DEPLOYMENT_ID = $faultyId
    $evidenceOut = Invoke-CheckedBash "AWS_REGION='$region' RUN_ID='$runId' DEPLOYMENT_ID='$faultyId' FUNCTION_NAME='$functionName' ALIAS_NAME='$aliasName' CODEDEPLOY_APP='$appName' CODEDEPLOY_GROUP='$groupName' scripts/collect-evidence.sh"
    $evidenceOut | Tee-Object -FilePath (Join-Path $rawDir "collect-evidence.txt")
    Show-Stage -StageId "08-evidence" `
        -Title "08 - Evidence captured" `
        -Message "Raw evidence is in evidence/raw/$runId.`n`nNext: choose retain or destroy." `
        -Url "" `
        -ScreenshotName "" `
        -CaptureRequired $false `
        -Context @{ evidenceDir = $rawDir; deploymentId = $faultyId; collectOutput = $evidenceOut }

    # Stage 9 - cleanup
    $destroy = $false
    if ($DestroyAfter) {
        $destroy = $true
        Write-RunLog "Cleanup: destroy authorised by -DestroyAfter"
    } elseif ($CaptureMode) {
        $destroy = $false
        Write-RunLog "Cleanup: capture mode without -DestroyAfter; retaining (deterministic default)"
    } else {
        $destroy = Ask-YesNo "Cleanup" "Destroy all demo resources now?`n`nYes = destroy and verify.`nNo = retain (about `$0.50-2/month)."
    }

    if ($destroy) {
        $teardown = Invoke-Teardown -Reason $(if ($DestroyAfter) { "-DestroyAfter" } else { "interactive confirmation" })
        Show-Stage -StageId "09-cleanup" `
            -Title "09 - Cleanup verified" `
            -Message "Teardown checks are captured. The tag-scoped budget was restored.`n`nCapture the empty resource lists.`n`nSave as 08-cleanup.png." `
            -Url "" `
            -ScreenshotName "08-cleanup.png" `
            -Context @{
                teardownPath      = $teardown.TeardownPath
                teardownText      = $teardown.TeardownOutput
                budgetRestored    = $true
                terraformDestroy  = (Join-Path $rawDir "terraform-destroy.txt")
                restoreBudget     = (Join-Path $rawDir "restore-budget.txt")
            }
    } else {
        Write-RunLog "Retained by user"
        Show-Stage -StageId "09-retained" `
            -Title "09 - Retained" `
            -Message "Resources retained. Record the review date and expected monthly cost in STATUS.md." `
            -Url $lambdaAliasUrl `
            -ScreenshotName "" `
            -CaptureRequired $false `
            -Context @{ retained = $true; monthlyCost = "0.50-2 USD" }
    }

    Write-RunLog "Run complete: $runId"
    $exitCode = 0
}
catch {
    $errorMessage = $_.Exception.Message
    Write-RunLog "FAILED: $errorMessage"
    Write-CaptureFailure -Message $errorMessage

    if ($DestroyAfter) {
        try {
            Invoke-Teardown -Reason "failure cleanup" | Out-Null
        } catch {
            Write-RunLog "Failure cleanup could not complete: $($_.Exception.Message)"
        }
    }

    $exitCode = 2
}
finally {
    if ($script:LoadProcess -and -not $script:LoadProcess.HasExited) {
        try {
            Stop-Process -Id $script:LoadProcess.Id -Force
            Write-RunLog "Stopped background load process ($($script:LoadProcess.Id))"
        } catch {
            Write-RunLog "Could not stop background load process: $($_.Exception.Message)"
        }
    }
}

exit $exitCode
