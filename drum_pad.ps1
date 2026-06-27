Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "CMOD A7 Drum Pad"
$form.Size = New-Object System.Drawing.Size(430, 260)
$form.StartPosition = "CenterScreen"

$serial = $null

$ports = New-Object System.Windows.Forms.ComboBox
$ports.DropDownStyle = "DropDownList"
$ports.Location = New-Object System.Drawing.Point(14, 14)
$ports.Size = New-Object System.Drawing.Size(110, 28)
[System.IO.Ports.SerialPort]::GetPortNames() | ForEach-Object { [void]$ports.Items.Add($_) }
if ($ports.Items.Count -gt 0) { $ports.SelectedIndex = 0 }
$form.Controls.Add($ports)

$connect = New-Object System.Windows.Forms.Button
$connect.Text = "Connect"
$connect.Location = New-Object System.Drawing.Point(134, 12)
$connect.Size = New-Object System.Drawing.Size(90, 30)
$form.Controls.Add($connect)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Disconnected"
$status.Location = New-Object System.Drawing.Point(240, 18)
$status.Size = New-Object System.Drawing.Size(160, 20)
$form.Controls.Add($status)

function Send-Drum([string]$key) {
    if ($script:serial -and $script:serial.IsOpen) {
        $script:serial.Write($key)
    }
}

$connect.Add_Click({
    try {
        if ($script:serial -and $script:serial.IsOpen) {
            $script:serial.Close()
            $connect.Text = "Connect"
            $status.Text = "Disconnected"
            return
        }

        $script:serial = New-Object System.IO.Ports.SerialPort($ports.SelectedItem, 115200, "None", 8, "One")
        $script:serial.Open()
        $connect.Text = "Disconnect"
        $status.Text = "Connected: $($ports.SelectedItem)"
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Serial error")
    }
})

$pads = @(
    @("1", "Kick", 14, 60),
    @("2", "Snare", 114, 60),
    @("3", "Closed HH", 214, 60),
    @("4", "Open HH", 314, 60),
    @("5", "Clap", 14, 135),
    @("6", "Low Tom", 114, 135),
    @("7", "High Tom", 214, 135),
    @("8", "Crash", 314, 135)
)

foreach ($pad in $pads) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = "$($pad[0])`n$($pad[1])"
    $button.Location = New-Object System.Drawing.Point($pad[2], $pad[3])
    $button.Size = New-Object System.Drawing.Size(86, 58)
    $button.Tag = $pad[0]
    $button.Add_Click({ Send-Drum $this.Tag })
    $form.Controls.Add($button)
}

$form.Add_KeyDown({
    param($sender, $event)
    if ($event.KeyCode -ge [System.Windows.Forms.Keys]::D1 -and $event.KeyCode -le [System.Windows.Forms.Keys]::D8) {
        Send-Drum ([string]([int]$event.KeyCode - [int][System.Windows.Forms.Keys]::D0))
    }
})
$form.KeyPreview = $true

$form.Add_FormClosing({
    if ($script:serial -and $script:serial.IsOpen) {
        $script:serial.Close()
    }
})

[void]$form.ShowDialog()
