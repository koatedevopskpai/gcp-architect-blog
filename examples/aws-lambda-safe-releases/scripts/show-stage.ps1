[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Message,
    [string]$Url = "",
    [string]$DoneText = "Screenshot done - continue"
)

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

[void]$form.ShowDialog()
$form.Dispose()
