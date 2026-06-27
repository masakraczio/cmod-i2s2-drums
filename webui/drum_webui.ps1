param(
    [int]$Port = 8765,
    [switch]$NoBrowser,
    [switch]$Check
)

$ErrorActionPreference = "Stop"

$script:serial = $null
$script:serialPortName = $null
$script:root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:projectRoot = Split-Path -Parent $script:root
$script:indexPath = Join-Path $script:root "index.html"
$script:sampleBankPath = Join-Path $script:projectRoot "src\rtl\generated\sample_bank.hex"

function Get-RequestBody {
    param([System.Net.HttpListenerRequest]$Request)

    if (-not $Request.HasEntityBody) {
        return @{}
    }

    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    try {
        $text = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        return @{}
    }

    return $text | ConvertFrom-Json
}

function Send-Bytes {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [byte[]]$Bytes,
        [string]$ContentType,
        [int]$StatusCode = 200
    )

    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.ContentLength64 = $Bytes.Length
    $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
    $Response.OutputStream.Close()
}

function Send-Text {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$Text,
        [string]$ContentType = "text/plain; charset=utf-8",
        [int]$StatusCode = 200
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    Send-Bytes -Response $Response -Bytes $bytes -ContentType $ContentType -StatusCode $StatusCode
}

function Send-Json {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [object]$Object,
        [int]$StatusCode = 200
    )

    $json = $Object | ConvertTo-Json -Depth 8 -Compress
    Send-Text -Response $Response -Text $json -ContentType "application/json; charset=utf-8" -StatusCode $StatusCode
}

function Send-ErrorJson {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$Message,
        [int]$StatusCode = 500
    )

    Send-Json -Response $Response -StatusCode $StatusCode -Object @{
        ok = $false
        error = $Message
    }
}

function Get-SerialStatus {
    @{
        ok = $true
        connected = [bool]($script:serial -and $script:serial.IsOpen)
        port = $script:serialPortName
    }
}

function Open-SerialPort {
    param(
        [string]$PortName,
        [int]$Baud = 115200
    )

    if ([string]::IsNullOrWhiteSpace($PortName)) {
        throw "No serial port selected."
    }

    if ($script:serial -and $script:serial.IsOpen) {
        $script:serial.Close()
    }

    $script:serial = New-Object System.IO.Ports.SerialPort($PortName, $Baud, "None", 8, "One")
    $script:serial.WriteTimeout = 2000
    $script:serial.ReadTimeout = 2000
    $script:serial.Open()
    $script:serialPortName = $PortName
}

function Close-SerialPort {
    if ($script:serial) {
        if ($script:serial.IsOpen) {
            $script:serial.Close()
        }
        $script:serial.Dispose()
        $script:serial = $null
        $script:serialPortName = $null
    }
}

function Send-DrumKey {
    param([string]$Key)

    if (-not ($script:serial -and $script:serial.IsOpen)) {
        throw "Serial port is not connected."
    }
    if ($Key -notmatch "^[1-8]$") {
        throw "Invalid drum key."
    }

    $script:serial.Write($Key)
}

function Load-SampleBank {
    if (-not ($script:serial -and $script:serial.IsOpen)) {
        throw "Serial port is not connected."
    }
    if (-not (Test-Path -LiteralPath $script:sampleBankPath)) {
        throw "Missing sample bank: $script:sampleBankPath"
    }

    $lines = Get-Content -LiteralPath $script:sampleBankPath
    $bytes = New-Object byte[] $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $bytes[$i] = [Convert]::ToByte($lines[$i], 16)
    }

    $script:serial.Write("L")
    Start-Sleep -Milliseconds 100

    $chunk = 1024
    for ($offset = 0; $offset -lt $bytes.Length; $offset += $chunk) {
        $count = [Math]::Min($chunk, $bytes.Length - $offset)
        $script:serial.Write($bytes, $offset, $count)
    }

    return $bytes.Length
}

function Handle-Request {
    param([System.Net.HttpListenerContext]$Context)

    $request = $Context.Request
    $response = $Context.Response
    $path = $request.Url.AbsolutePath

    try {
        if ($request.HttpMethod -eq "OPTIONS") {
            $response.AddHeader("Access-Control-Allow-Origin", "*")
            $response.AddHeader("Access-Control-Allow-Headers", "Content-Type")
            $response.AddHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
            Send-Text -Response $response -Text ""
            return
        }

        switch ($path) {
            { $_ -eq "/" -or $_ -eq "/index.html" } {
                $html = [System.IO.File]::ReadAllText($script:indexPath)
                Send-Text -Response $response -Text $html -ContentType "text/html; charset=utf-8"
                return
            }

            "/api/ports" {
                Send-Json -Response $response -Object @{
                    ok = $true
                    ports = [System.IO.Ports.SerialPort]::GetPortNames()
                }
                return
            }

            "/api/status" {
                Send-Json -Response $response -Object (Get-SerialStatus)
                return
            }

            "/api/connect" {
                $body = Get-RequestBody -Request $request
                $baud = if ($body.baud) { [int]$body.baud } else { 115200 }
                Open-SerialPort -PortName ([string]$body.port) -Baud $baud
                Send-Json -Response $response -Object (Get-SerialStatus)
                return
            }

            "/api/disconnect" {
                Close-SerialPort
                Send-Json -Response $response -Object (Get-SerialStatus)
                return
            }

            "/api/drum" {
                $body = Get-RequestBody -Request $request
                Send-DrumKey -Key ([string]$body.key)
                Send-Json -Response $response -Object @{ ok = $true }
                return
            }

            "/api/load-bank" {
                $count = Load-SampleBank
                Send-Json -Response $response -Object @{
                    ok = $true
                    bytes = $count
                }
                return
            }

            default {
                Send-ErrorJson -Response $response -Message "Not found" -StatusCode 404
                return
            }
        }
    } catch {
        Send-ErrorJson -Response $response -Message $_.Exception.Message -StatusCode 500
    }
}

if ($Check) {
    if (-not (Test-Path -LiteralPath $script:indexPath)) {
        throw "Missing web UI: $script:indexPath"
    }
    [void][System.IO.Ports.SerialPort]::GetPortNames()
    Write-Host "Web UI check OK"
    exit 0
}

if (-not (Test-Path -LiteralPath $script:indexPath)) {
    throw "Missing web UI: $script:indexPath"
}

$prefix = "http://127.0.0.1:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
    Write-Host "CMOD A7 Drum Web UI: $prefix"
    Write-Host "Press Ctrl+C to stop."
    if (-not $NoBrowser) {
        Start-Process $prefix
    }

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        Handle-Request -Context $context
    }
} finally {
    Close-SerialPort
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}
