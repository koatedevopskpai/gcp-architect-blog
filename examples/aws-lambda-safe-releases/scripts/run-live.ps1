[CmdletBinding()]
param(
    [switch]$TestNotification,
    [switch]$SkipApply,
    [switch]$SkipBaseline,
    [switch]$SkipApproval,
    [switch]$SkipHealthy,
    [string]$RunId = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

function Write-RunLog {
    param([string]$Message)
    $line = "$(Get-Date -Format o)  $Message"
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

function Show-Stage {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Url,
        [string]$DoneText = "Screenshot done - continue",
        [int]$AutoCloseSeconds = 0
    )

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
        $output = & bash -c $Command 2>&1
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

$lambdaAliasUrl = "https://$region.console.aws.amazon.com/lambda/home?region=$region#/functions/$functionName/aliases/$aliasName"
$alarmUrl = "https://$region.console.aws.amazon.com/cloudwatch/home?region=$region#alarmsV2:alarm/$alarmName"

function Get-DeploymentUrl([string]$Id) {
    return "https://$region.console.aws.amazon.com/codesuite/codedeploy/deployments/$Id?region=$region"
}

if ($TestNotification) {
    Write-RunLog "Test notification"
    Show-Stage -Title "Screenshot notification test" `
        -Message "If you can read this, the notification works.`n`n1. Click 'Hide 60s' to clear the screen.`n2. Confirm the browser opened the Lambda page.`n3. Click 'Test complete' to exit.`n`nThis test auto-closes after 90 seconds." `
        -Url $lambdaAliasUrl `
        -DoneText "Test complete" `
        -AutoCloseSeconds 90
    exit 0
}

Write-RunLog "Run $runId starting"

if (-not $SkipApproval) {
    if (-not (Ask-YesNo "Spend approval" "Create the demo stack in $region?`n`nExpected cost: under `$0.20.`nCeiling: `$2-5.`n`nClick Yes to proceed.")) {
        Write-RunLog "Aborted at spend approval"
        exit 1
    }
}

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
    Show-Stage -Title "01 - Baseline v$baselineVersion" `
        -Message "Baseline v$baselineVersion is healthy.`n`nCapture: Lambda alias page showing 'live' -> version $baselineVersion.`nThe API response should say version=baseline.`n`nSave as 01-baseline.png." `
        -Url $lambdaAliasUrl
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
Show-Stage -Title "02 - Healthy candidate v$healthyVersion" `
    -Message "Healthy candidate v$healthyVersion is at 100%.`n`nCapture: CodeDeploy deployment $healthyId (Succeeded) and the alias at v$healthyVersion.`n`nSave as 02-healthy-candidate.png." `
    -Url (Get-DeploymentUrl $healthyId)

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

$canary = Wait-Until -TimeoutSeconds 120 -Description "canary weights" -Condition {
    $weights = Get-AwsText @("lambda", "get-alias", "--function-name", $functionName, "--name", $aliasName, "--region", $region, "--query", "RoutingConfig.AdditionalVersionWeights", "--output", "json")
    return ($weights -ne "null" -and $weights -ne "{}" -and $weights.Trim() -ne "")
}
if (-not $canary) { throw "canary weights never appeared" }
Show-Stage -Title "03 - Faulty canary v$faultyVersion" `
    -Message "Canary is routing to faulty v$faultyVersion.`n`nTime-sensitive: capture within ~2 minutes.`nCapture: deployment $faultyId showing the 10% canary and the alias weights.`n`nSave as 03-canary-routing.png." `
    -Url (Get-DeploymentUrl $faultyId)

# Stage 4 - alarm
$alarmFired = Wait-Until -TimeoutSeconds 300 -Description "alarm ALARM" -Condition {
    return (Get-AwsText @("cloudwatch", "describe-alarms", "--alarm-names", $alarmName, "--region", $region, "--query", "MetricAlarms[0].StateValue", "--output", "text")) -eq "ALARM"
}
if (-not $alarmFired) {
    Write-RunLog "Alarm did not fire; stopping deployment with auto-rollback"
    & aws deploy stop-deployment --deployment-id $faultyId --auto-rollback-enabled --region $region | Out-Null
    Show-Stage -Title "ALARM DID NOT FIRE" `
        -Message "The alarm did not reach ALARM within 5 minutes. The deployment was stopped with auto-rollback.`n`nRecord this as a failed detection; do not present it as success." `
        -Url (Get-DeploymentUrl $faultyId)
    throw "alarm did not fire"
}
Show-Stage -Title "04 - Alarm ALARM" `
    -Message "CloudWatch alarm '$alarmName' is in ALARM.`n`nCapture: the alarm page with metric, dimensions and time window.`n`nSave as 04-alarm.png." `
    -Url $alarmUrl

# Stage 5 - rollback
$rolledBack = Wait-Until -TimeoutSeconds 300 -Description "rollback of $faultyId" -Condition {
    $status = Get-AwsText @("deploy", "get-deployment", "--deployment-id", $faultyId, "--region", $region, "--query", "deploymentInfo.status", "--output", "text")
    $weights = Get-AwsText @("lambda", "get-alias", "--function-name", $functionName, "--name", $aliasName, "--region", $region, "--query", "RoutingConfig.AdditionalVersionWeights", "--output", "json")
    $weightsCleared = ($weights -eq "null" -or $weights -eq "{}" -or $weights.Trim() -eq "")
    return (($status -eq "Stopped" -or $status -eq "Failed") -and $weightsCleared)
}
if (-not $rolledBack) { throw "alias did not return to v$preFaultVersion" }
Show-Stage -Title "05 - Automatic rollback to v$preFaultVersion" `
    -Message "CodeDeploy rolled back automatically.`n`nCapture: deployment $faultyId events/status and the alias back at v$preFaultVersion.`n`nSave as 05-rollback.png." `
    -Url (Get-DeploymentUrl $faultyId)

# Stage 6 - recovery
$load.WaitForExit(420000) | Out-Null
$loadSummary = Get-Content $loadPath -Raw | ConvertFrom-Json
Write-RunLog ("Load summary: " + ($loadSummary | ConvertTo-Json -Compress))
Show-Stage -Title "06 - Recovery verified" `
    -Message "Alias is back at v$preFaultVersion and the load completed.`n`nStatus counts: $($loadSummary.status_counts | ConvertTo-Json -Compress)`nVersion counts: $($loadSummary.version_counts | ConvertTo-Json -Compress)`n`nCapture: alias at v$preFaultVersion and the load summary.`nSave as 06-recovery.png." `
    -Url $lambdaAliasUrl

# Stage 7 - no drift
Write-RunLog "Stage 7 terraform plan"
$planPath = Join-Path $rawDir "post-rollback-plan.txt"
$planOut = Invoke-CheckedTerraform @("-chdir=infra", "plan", "-input=false", "-no-color")
$planOut | Tee-Object -FilePath $planPath
Start-Process notepad.exe $planPath | Out-Null
Show-Stage -Title "07 - No alias drift" `
    -Message "terraform plan is open in Notepad. It must show no changes to the alias or function.`n`nCapture the plan summary.`n`nSave as 07-no-drift.png." `
    -Url ""

# Stage 8 - evidence
Write-RunLog "Stage 8 collect evidence"
$env:DEPLOYMENT_ID = $faultyId
$evidenceOut = Invoke-CheckedBash "AWS_REGION='$region' RUN_ID='$runId' DEPLOYMENT_ID='$faultyId' FUNCTION_NAME='$functionName' ALIAS_NAME='$aliasName' CODEDEPLOY_APP='$appName' CODEDEPLOY_GROUP='$groupName' scripts/collect-evidence.sh"
$evidenceOut | Tee-Object -FilePath (Join-Path $rawDir "collect-evidence.txt")
Show-Stage -Title "08 - Evidence captured" `
    -Message "Raw evidence is in evidence/raw/$runId.`n`nNext: choose retain or destroy in the dialog." `
    -Url ""

# Stage 9 - cleanup
$destroy = Ask-YesNo "Cleanup" "Destroy all demo resources now?`n`nYes = destroy and verify.`nNo = retain (about `$0.50-2/month)."
if ($destroy) {
    Write-RunLog "terraform destroy"
    $destroyOut = Invoke-CheckedTerraform @("-chdir=infra", "destroy", "-auto-approve", "-input=false")
    $destroyOut | Tee-Object -FilePath (Join-Path $rawDir "terraform-destroy.txt")

    # Keep the tag-scoped budget as a guardrail after the stack is gone.
    $budgetOut = Invoke-CheckedTerraform @("-chdir=infra", "apply", "-auto-approve", "-input=false", "-target=aws_budgets_budget.demo")
    $budgetOut | Tee-Object -FilePath (Join-Path $rawDir "restore-budget.txt")

    $teardownPath = Join-Path $rawDir "teardown.txt"
    $teardownOut = Invoke-CheckedBash "AWS_REGION='$region' PROJECT='aws-lambda-safe-releases' scripts/verify-teardown.sh"
    $teardownOut | Tee-Object -FilePath $teardownPath
    Start-Process notepad.exe $teardownPath | Out-Null
    Show-Stage -Title "09 - Cleanup verified" `
        -Message "Teardown checks are open in Notepad. The tag-scoped budget was restored.`n`nCapture the empty resource lists.`n`nSave as 08-cleanup.png." `
        -Url ""
} else {
    Write-RunLog "Retained by user"
    Show-Stage -Title "09 - Retained" `
        -Message "Resources retained. Record the review date and expected monthly cost in STATUS.md." `
        -Url $lambdaAliasUrl
}

Write-RunLog "Run complete: $runId"
