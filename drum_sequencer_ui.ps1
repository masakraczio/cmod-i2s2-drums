Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ("HiResDrumSequencer" -as [type])) {
Add-Type -ReferencedAssemblies "System.Windows.Forms", "System.Drawing" -TypeDefinition @"
using System;
using System.Diagnostics;
using System.IO.Ports;
using System.Threading;
using System.Windows.Forms;

public sealed class HiResDrumSequencer : IDisposable
{
    private readonly object sync = new object();
    private readonly bool[,] pattern = new bool[8, 16];
    private readonly Control uiControl;
    private readonly Action<int> stepCallback;
    private readonly AutoResetEvent wake = new AutoResetEvent(false);
    private Thread worker;
    private SerialPort port;
    private bool disposed;
    private bool running;
    private bool stopRequested;
    private int bpm = 120;
    private int step;

    public HiResDrumSequencer(Control uiControl, Action<int> stepCallback)
    {
        this.uiControl = uiControl;
        this.stepCallback = stepCallback;
    }

    public bool IsRunning
    {
        get { lock (sync) return running; }
    }

    public void SetSerial(SerialPort serialPort)
    {
        lock (sync) port = serialPort;
    }

    public void SetPattern(int row, int column, bool enabled)
    {
        if (row < 0 || row >= 8 || column < 0 || column >= 16) return;
        lock (sync) pattern[row, column] = enabled;
    }

    public void SetBpm(int newBpm)
    {
        lock (sync) bpm = Math.Max(1, newBpm);
        wake.Set();
    }

    public void Start(int newBpm)
    {
        lock (sync)
        {
            bpm = Math.Max(1, newBpm);
            running = true;
            EnsureWorkerLocked();
        }
        wake.Set();
    }

    public void Stop()
    {
        lock (sync)
        {
            running = false;
            step = 0;
        }
        PostStep(-1);
        wake.Set();
    }

    public void SendByte(byte value)
    {
        lock (sync)
        {
            if (port != null && port.IsOpen)
            {
                byte[] data = new byte[] { value };
                port.Write(data, 0, 1);
            }
        }
    }

    public void Dispose()
    {
        Thread threadToJoin = null;
        lock (sync)
        {
            if (disposed) return;
            disposed = true;
            running = false;
            stopRequested = true;
            threadToJoin = worker;
        }
        wake.Set();
        if (threadToJoin != null && threadToJoin.IsAlive) threadToJoin.Join(500);
        wake.Dispose();
    }

    private void EnsureWorkerLocked()
    {
        if (worker != null && worker.IsAlive) return;
        stopRequested = false;
        worker = new Thread(RunLoop);
        worker.IsBackground = true;
        worker.Name = "CMOD A7 drum sequencer clock";
        worker.Priority = ThreadPriority.AboveNormal;
        worker.Start();
    }

    private void RunLoop()
    {
        Stopwatch clock = Stopwatch.StartNew();
        long nextTick = clock.ElapsedTicks;

        while (true)
        {
            bool shouldRun;
            int bpmSnapshot;
            lock (sync)
            {
                if (stopRequested) return;
                shouldRun = running;
                bpmSnapshot = bpm;
            }

            if (!shouldRun)
            {
                wake.WaitOne(20);
                nextTick = clock.ElapsedTicks;
                continue;
            }

            PlayCurrentStep();

            long stepTicks = Math.Max(1L, (long)(Stopwatch.Frequency * (15.0 / Math.Max(1, bpmSnapshot))));
            nextTick += stepTicks;

            while (true)
            {
                long now = clock.ElapsedTicks;
                long remaining = nextTick - now;
                if (remaining <= 0) break;

                int sleepMs = (int)Math.Min(5, Math.Max(1, remaining * 1000 / Stopwatch.Frequency));
                wake.WaitOne(sleepMs);

                lock (sync)
                {
                    if (stopRequested) return;
                    if (!running) break;
                }
            }

            long late = clock.ElapsedTicks - nextTick;
            if (late > stepTicks) nextTick = clock.ElapsedTicks;
        }
    }

    private void PlayCurrentStep()
    {
        bool[] hits = new bool[8];
        int activeStep;

        lock (sync)
        {
            activeStep = step;
            for (int row = 0; row < 8; row++) hits[row] = pattern[row, activeStep];
            step = (step + 1) & 15;
        }

        for (int row = 0; row < 8; row++)
        {
            if (hits[row]) SendByte((byte)('1' + row));
        }

        PostStep(activeStep);
    }

    private void PostStep(int activeStep)
    {
        if (uiControl == null || uiControl.IsDisposed || stepCallback == null) return;
        try
        {
            uiControl.BeginInvoke(stepCallback, new object[] { activeStep });
        }
        catch (InvalidOperationException)
        {
        }
    }
}
"@
}

$script:serial = $null
$script:step = 0
$script:cells = @()
$script:stepLabels = @()
$script:sequencer = $null
$script:pressedKeys = New-Object 'System.Collections.Generic.HashSet[System.Windows.Forms.Keys]'

$drums = @(
    @{ Key = "1"; Name = "Kick" },
    @{ Key = "2"; Name = "Snare" },
    @{ Key = "3"; Name = "Closed HH" },
    @{ Key = "4"; Name = "Open HH" },
    @{ Key = "5"; Name = "Clap" },
    @{ Key = "6"; Name = "Low Tom" },
    @{ Key = "7"; Name = "High Tom" },
    @{ Key = "8"; Name = "Crash" }
)

function Send-Drum([string]$key) {
    if ($script:sequencer) {
        $script:sequencer.SendByte([byte][char]$key[0])
    } elseif ($script:serial -and $script:serial.IsOpen) {
        $script:serial.Write($key)
    }
}

function Start-Sequencer {
    $script:sequencer.Start([int]$bpm.Value)
}

function Stop-Sequencer {
    $script:sequencer.Stop()
}

function Load-SampleBank {
    if (-not ($script:serial -and $script:serial.IsOpen)) {
        [System.Windows.Forms.MessageBox]::Show("Connect serial port first.", "Sample bank")
        return
    }

    $bankPath = Join-Path $PSScriptRoot "src\rtl\generated\sample_bank.hex"
    if (-not (Test-Path $bankPath)) {
        [System.Windows.Forms.MessageBox]::Show("Missing sample bank: $bankPath", "Sample bank")
        return
    }

    Stop-Sequencer
    $status.Text = "Loading sample bank..."
    $form.Refresh()

    try {
        $hex = Get-Content $bankPath
        $bytes = New-Object byte[] $hex.Count
        for ($i = 0; $i -lt $hex.Count; $i++) {
            $bytes[$i] = [Convert]::ToByte($hex[$i], 16)
        }

        $script:serial.Write("L")
        Start-Sleep -Milliseconds 100

        $chunk = 1024
        for ($offset = 0; $offset -lt $bytes.Length; $offset += $chunk) {
            $count = [Math]::Min($chunk, $bytes.Length - $offset)
            $script:serial.Write($bytes, $offset, $count)
            if (($offset % (16 * $chunk)) -eq 0) {
                $pct = [int](100 * $offset / [Math]::Max(1, $bytes.Length))
                $status.Text = "Loading sample bank... $pct%"
                $form.Refresh()
            }
        }

        $status.Text = "Sample bank loaded: $($bytes.Length) bytes"
    } catch {
        $status.Text = "Sample bank load failed"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Sample bank")
    }
}

function Set-StepHighlight([int]$activeStep) {
    for ($i = 0; $i -lt $script:stepLabels.Count; $i++) {
        if ($i -eq $activeStep) {
            $script:stepLabels[$i].BackColor = [System.Drawing.Color]::FromArgb(60, 120, 210)
            $script:stepLabels[$i].ForeColor = [System.Drawing.Color]::White
        } else {
            $script:stepLabels[$i].BackColor = [System.Drawing.SystemColors]::Control
            $script:stepLabels[$i].ForeColor = [System.Drawing.Color]::Black
        }
    }
}

function Clear-Pattern {
    foreach ($row in $script:cells) {
        foreach ($cell in $row) {
            $cell.Checked = $false
        }
    }
}

function Load-DemoPattern {
    Clear-Pattern
    foreach ($s in @(0, 4, 8, 12)) { $script:cells[0][$s].Checked = $true }
    foreach ($s in @(4, 12)) { $script:cells[1][$s].Checked = $true }
    foreach ($s in @(0, 2, 4, 6, 8, 10, 12, 14)) { $script:cells[2][$s].Checked = $true }
    foreach ($s in @(3, 11)) { $script:cells[4][$s].Checked = $true }
    foreach ($s in @(15)) { $script:cells[7][$s].Checked = $true }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "CMOD A7 Drum Sampler"
$form.Size = New-Object System.Drawing.Size(860, 500)
$form.StartPosition = "CenterScreen"
$form.KeyPreview = $true
$script:sequencer = [HiResDrumSequencer]::new($form, [Action[int]]{
    param($activeStep)
    Set-StepHighlight $activeStep
})

$ports = New-Object System.Windows.Forms.ComboBox
$ports.DropDownStyle = "DropDownList"
$ports.Location = New-Object System.Drawing.Point(14, 14)
$ports.Size = New-Object System.Drawing.Size(110, 28)
[System.IO.Ports.SerialPort]::GetPortNames() | ForEach-Object { [void]$ports.Items.Add($_) }
if ($ports.Items.Count -gt 0) { $ports.SelectedIndex = 0 }
$form.Controls.Add($ports)

$connect = New-Object System.Windows.Forms.Button
$connect.Text = "Connect"
$connect.Location = New-Object System.Drawing.Point(132, 12)
$connect.Size = New-Object System.Drawing.Size(90, 30)
$form.Controls.Add($connect)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Disconnected"
$status.Location = New-Object System.Drawing.Point(236, 18)
$status.Size = New-Object System.Drawing.Size(190, 20)
$form.Controls.Add($status)

$bpmLabel = New-Object System.Windows.Forms.Label
$bpmLabel.Text = "BPM"
$bpmLabel.Location = New-Object System.Drawing.Point(450, 18)
$bpmLabel.Size = New-Object System.Drawing.Size(34, 20)
$form.Controls.Add($bpmLabel)

$bpm = New-Object System.Windows.Forms.NumericUpDown
$bpm.Minimum = 40
$bpm.Maximum = 240
$bpm.Value = 120
$bpm.Location = New-Object System.Drawing.Point(486, 14)
$bpm.Size = New-Object System.Drawing.Size(64, 24)
$form.Controls.Add($bpm)

$play = New-Object System.Windows.Forms.Button
$play.Text = "Play"
$play.Location = New-Object System.Drawing.Point(566, 12)
$play.Size = New-Object System.Drawing.Size(74, 30)
$form.Controls.Add($play)

$stop = New-Object System.Windows.Forms.Button
$stop.Text = "Stop"
$stop.Location = New-Object System.Drawing.Point(646, 12)
$stop.Size = New-Object System.Drawing.Size(74, 30)
$form.Controls.Add($stop)

$clear = New-Object System.Windows.Forms.Button
$clear.Text = "Clear"
$clear.Location = New-Object System.Drawing.Point(726, 12)
$clear.Size = New-Object System.Drawing.Size(74, 30)
$form.Controls.Add($clear)

$demo = New-Object System.Windows.Forms.Button
$demo.Text = "Demo"
$demo.Location = New-Object System.Drawing.Point(14, 420)
$demo.Size = New-Object System.Drawing.Size(90, 30)
$form.Controls.Add($demo)

$loadBank = New-Object System.Windows.Forms.Button
$loadBank.Text = "Load Bank"
$loadBank.Location = New-Object System.Drawing.Point(114, 420)
$loadBank.Size = New-Object System.Drawing.Size(100, 30)
$form.Controls.Add($loadBank)

$padX = 14
$padY = 62
for ($i = 0; $i -lt $drums.Count; $i++) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = "$($drums[$i].Key)`r`n$($drums[$i].Name)"
    $button.Tag = $drums[$i].Key
    $button.Location = New-Object System.Drawing.Point($padX, ($padY + ($i % 4) * 70))
    $button.Size = New-Object System.Drawing.Size(92, 58)
    if ($i -ge 4) {
        $button.Location = New-Object System.Drawing.Point(($padX + 104), ($padY + (($i - 4) % 4) * 70))
    }
    $button.Add_Click({ Send-Drum $this.Tag })
    $form.Controls.Add($button)
}

$gridX = 250
$gridY = 76
$cellSize = 24

for ($s = 0; $s -lt 16; $s++) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = [string]($s + 1)
    $label.TextAlign = "MiddleCenter"
    $label.Location = New-Object System.Drawing.Point(($gridX + $s * 34), 54)
    $label.Size = New-Object System.Drawing.Size($cellSize, 18)
    $form.Controls.Add($label)
    $script:stepLabels += $label
}

for ($r = 0; $r -lt 8; $r++) {
    $name = New-Object System.Windows.Forms.Label
    $name.Text = $drums[$r].Name
    $name.Location = New-Object System.Drawing.Point(($gridX - 86), ($gridY + $r * 38 + 4))
    $name.Size = New-Object System.Drawing.Size(78, 20)
    $form.Controls.Add($name)

    $row = @()
    for ($s = 0; $s -lt 16; $s++) {
        $box = New-Object System.Windows.Forms.CheckBox
        $box.Appearance = "Button"
        $box.Text = ""
        $box.Tag = [int[]]@($r, $s)
        $box.Location = New-Object System.Drawing.Point(($gridX + $s * 34), ($gridY + $r * 38))
        $box.Size = New-Object System.Drawing.Size($cellSize, $cellSize)
        $box.Add_CheckedChanged({
            param($sender, $event)
            $pos = $sender.Tag
            $script:sequencer.SetPattern($pos[0], $pos[1], $sender.Checked)
        })
        $form.Controls.Add($box)
        $row += $box
    }
    $script:cells += ,$row
}

$connect.Add_Click({
    try {
        if ($script:serial -and $script:serial.IsOpen) {
            Stop-Sequencer
            $script:serial.Close()
            $script:sequencer.SetSerial($null)
            $connect.Text = "Connect"
            $status.Text = "Disconnected"
            return
        }

        if (-not $ports.SelectedItem) {
            [System.Windows.Forms.MessageBox]::Show("No serial port selected.", "Serial")
            return
        }

        $script:serial = New-Object System.IO.Ports.SerialPort($ports.SelectedItem, 115200, "None", 8, "One")
        $script:serial.Open()
        $script:sequencer.SetSerial($script:serial)
        $connect.Text = "Disconnect"
        $status.Text = "Connected: $($ports.SelectedItem)"
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Serial error")
    }
})

$play.Add_Click({
    Start-Sequencer
})

$stop.Add_Click({
    Stop-Sequencer
})

$clear.Add_Click({ Clear-Pattern })
$demo.Add_Click({ Load-DemoPattern })
$loadBank.Add_Click({ Load-SampleBank })

$bpm.Add_ValueChanged({
    $script:sequencer.SetBpm([int]$bpm.Value)
})

$form.Add_KeyDown({
    param($sender, $event)
    if (-not $script:pressedKeys.Add($event.KeyCode)) {
        return
    }

    if ($event.KeyCode -ge [System.Windows.Forms.Keys]::D1 -and $event.KeyCode -le [System.Windows.Forms.Keys]::D8) {
        Send-Drum ([string]([int]$event.KeyCode - [int][System.Windows.Forms.Keys]::D0))
    }
    if ($event.KeyCode -eq [System.Windows.Forms.Keys]::Space) {
        if ($script:sequencer.IsRunning) {
            Stop-Sequencer
        } else {
            Start-Sequencer
        }
    }
})

$form.Add_KeyUp({
    param($sender, $event)
    [void]$script:pressedKeys.Remove($event.KeyCode)
})

$form.Add_FormClosing({
    Stop-Sequencer
    if ($script:sequencer) {
        $script:sequencer.Dispose()
    }
    if ($script:serial -and $script:serial.IsOpen) {
        $script:serial.Close()
    }
})

Load-DemoPattern
[void]$form.ShowDialog()
