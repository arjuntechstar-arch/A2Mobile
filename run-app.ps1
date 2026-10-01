# Run from any directory: & 'C:\path\to\A2Mobile\run-app.ps1'
[CmdletBinding()]
param(
    [switch]$Rebuild,
    [switch]$OpenBrowser,
    [switch]$WebOnly,
    [string]$WirelessDevice,
    [string]$PairEndpoint,
    [string]$PairingCode,
    [switch]$ShareCustomerWeb
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$pythonPath = Join-Path $projectRoot '.venv\Scripts\python.exe'
$adminPath = Join-Path $projectRoot 'admin'
$mobilePath = Join-Path $projectRoot 'mobile'
$logPath = Join-Path $env:TEMP 'a2mobile-run'

function Test-LocalPort([int]$Port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $connection = $client.ConnectAsync('127.0.0.1', $Port)
        return ($connection.Wait(500) -and $client.Connected)
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Start-AppService {
    param([string]$Name, [int]$Port, [string]$Executable,
          [string]$Arguments, [string]$Directory, [string]$HealthUrl)

    if (Test-LocalPort $Port) {
        Write-Host "$Name already has a listener on port $Port; checking response."
    } else {
        $process = Start-Process -FilePath $Executable -ArgumentList $Arguments `
            -WorkingDirectory $Directory -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $logPath "$Name.out.log") `
            -RedirectStandardError (Join-Path $logPath "$Name.err.log")
        Write-Host "Starting $Name (PID $($process.Id))..."
    }

    $deadline = (Get-Date).AddSeconds(60)
    do {
        try {
            $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) { return }
        } catch { }
        if ($process -and $process.HasExited) {
            throw "$Name exited. Check $logPath\$Name.err.log"
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw "$Name did not become ready at $HealthUrl. Check logs in $logPath and ensure port $Port is available."
}

function Start-AndroidApp {
    param(
        [string]$WirelessDevice,
        [string]$PairEndpoint,
        [string]$PairingCode
    )

function Invoke-Adb {
    param([string]$AdbPath, [string[]]$Arguments)
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # A disconnected wireless device can write "error: closed" to stderr.
        # Capture it so a transient transport failure does not terminate this script.
        $ErrorActionPreference = 'Continue'
        $output = @(& $AdbPath @Arguments 2>&1)
        return [PSCustomObject]@{ Output = $output; ExitCode = $LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Get-CompatibleAndroidDevice {
    param([string]$AdbPath, [string[]]$SupportedAbis)
    $devices = Invoke-Adb -AdbPath $AdbPath -Arguments @('devices')
    if ($devices.ExitCode -ne 0) { return $null }
    foreach ($line in $devices.Output) {
        if ($line.ToString() -notmatch '^\s*(\S+)\s+device(?:\s|$)') { continue }
        $candidateId = $Matches[1]
        $abi = Invoke-Adb -AdbPath $AdbPath -Arguments @('-s', $candidateId, 'shell', 'getprop', 'ro.product.cpu.abi')
        if ($abi.ExitCode -ne 0) { continue }
        $value = [string]($abi.Output | Select-Object -Last 1)
        if ($SupportedAbis -contains $value.Trim()) { return $candidateId }
    }
    return $null
}

    $sdkRoot = $env:ANDROID_SDK_ROOT
    if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_HOME }
    if (-not $sdkRoot -and $env:LOCALAPPDATA) {
        $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    }

    if ($sdkRoot -and (Test-Path -LiteralPath (Join-Path $sdkRoot 'platform-tools\adb.exe'))) {
        $adbPath = Join-Path $sdkRoot 'platform-tools\adb.exe'
    } else {
        $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
        if ($adbCommand) { $adbPath = $adbCommand.Source }
        if (-not $adbPath -and (Test-Path -LiteralPath 'C:\adb\adb.exe')) {
            $adbPath = 'C:\adb\adb.exe'
        }
    }
    if (-not $adbPath) {
        throw 'ADB was not found. Install Android platform-tools or set ANDROID_SDK_ROOT.'
    }

    $emulatorPath = if ($sdkRoot) { Join-Path $sdkRoot 'emulator\emulator.exe' }
    if (-not $emulatorPath -or -not (Test-Path -LiteralPath $emulatorPath)) {
        $emulatorCommand = Get-Command emulator -ErrorAction SilentlyContinue
        if ($emulatorCommand) { $emulatorPath = $emulatorCommand.Source }
    }

    $adbServer = Invoke-Adb -AdbPath $adbPath -Arguments @('start-server')
    if ($adbServer.ExitCode -ne 0) { throw 'ADB could not start. Check your Android SDK installation.' }

    if (($PairEndpoint -and -not $PairingCode) -or ($PairingCode -and -not $PairEndpoint)) {
        throw 'Wireless pairing needs both -PairEndpoint (from the pairing screen) and -PairingCode.'
    }
    foreach ($endpoint in @($WirelessDevice, $PairEndpoint) | Where-Object { $_ }) {
        if ($endpoint -notmatch '^[^\s:]+:\d+$') {
            throw "Wireless device endpoints must use IP_ADDRESS:PORT. Invalid value: $endpoint"
        }
    }
    if ($PairEndpoint) {
        Write-Host "Pairing with Android phone at $PairEndpoint..."
        $pair = Invoke-Adb -AdbPath $adbPath -Arguments @('pair', $PairEndpoint, $PairingCode)
        if ($pair.ExitCode -ne 0 -or -not (($pair.Output -join "`n") -match 'Successfully paired|Already paired')) {
            throw 'Wireless pairing failed. Open Developer options > Wireless debugging > Pair device with pairing code and use that address, port, and current code.'
        }
    }
    if ($WirelessDevice) {
        Write-Host "Connecting to Android phone at $WirelessDevice..."
        $connect = Invoke-Adb -AdbPath $adbPath -Arguments @('connect', $WirelessDevice)
        if ($connect.ExitCode -ne 0 -or -not (($connect.Output -join "`n") -match 'connected to|already connected to')) {
            throw 'Could not connect to the wireless phone. Ensure the phone and PC are on the same Wi-Fi, Wireless debugging is enabled, and use the Device IP address & port (not the pairing port).'
        }
    }

    $supportedAbis = @('x86_64', 'arm64-v8a', 'armeabi-v7a')
    $deviceId = $null
    if ($WirelessDevice) {
        $escapedDeviceId = [regex]::Escape($WirelessDevice)
        $connected = Invoke-Adb -AdbPath $adbPath -Arguments @('devices')
        if ($connected.ExitCode -ne 0 -or -not (($connected.Output -join "`n") -match "(?m)^\s*$escapedDeviceId\s+device(?:\s|$)")) {
            throw "Wireless phone $WirelessDevice is not ready in ADB. Unlock it and accept any debugging prompt, then run this command again."
        }
        $abi = Invoke-Adb -AdbPath $adbPath -Arguments @('-s', $WirelessDevice, 'shell', 'getprop', 'ro.product.cpu.abi')
        $abiValue = if ($abi.ExitCode -eq 0) { ([string]($abi.Output | Select-Object -Last 1)).Trim() } else { '' }
        if ($supportedAbis -notcontains $abiValue) {
            throw "Wireless phone $WirelessDevice uses unsupported ABI '$abiValue'. Flutter requires one of: $($supportedAbis -join ', ')."
        }
        $deviceId = $WirelessDevice
    } else {
        $deviceId = Get-CompatibleAndroidDevice -AdbPath $adbPath -SupportedAbis $supportedAbis
    }

    if (-not $deviceId) {
        if (-not $emulatorPath) {
            throw 'No supported Android emulator is connected and the Android emulator was not found. Set ANDROID_SDK_ROOT.'
        }
        $avds = @(& $emulatorPath -list-avds | Where-Object { $_.Trim() })
        $avdName = $null
        foreach ($candidateAvd in $avds) {
            $avdIni = Join-Path (Join-Path $env:USERPROFILE '.android\avd') "$($candidateAvd.Trim()).ini"
            $avdPath = $null
            if (Test-Path -LiteralPath $avdIni) {
                $pathLine = Get-Content -LiteralPath $avdIni | Where-Object { $_ -match '^path=' } | Select-Object -First 1
                if ($pathLine) { $avdPath = $pathLine.Substring(5) }
            }
            if (-not $avdPath) { $avdPath = Join-Path (Join-Path $env:USERPROFILE '.android\avd') "$($candidateAvd.Trim()).avd" }
            $configPath = Join-Path $avdPath 'config.ini'
            if (Test-Path -LiteralPath $configPath) {
                $abiLine = Get-Content -LiteralPath $configPath | Where-Object { $_ -match '^abi\.type=' } | Select-Object -First 1
                if ($abiLine -and $supportedAbis -contains $abiLine.Substring('abi.type='.Length).Trim()) {
                    $avdName = $candidateAvd.Trim()
                    break
                }
            }
        }
        if (-not $avdName) {
            if (-not $avds.Count) { throw 'No Android emulator is configured. Create an AVD in Android Studio Device Manager.' }
            throw "No Flutter-compatible emulator is configured. Your existing AVD uses 32-bit x86, which Flutter does not support. Create an x86_64 AVD in Android Studio Device Manager, then run this script again."
        }

        Write-Host "Starting Android emulator '$avdName'..."
        Start-Process -FilePath $emulatorPath -ArgumentList @('-avd', $avdName) | Out-Null

        $deviceDeadline = (Get-Date).AddMinutes(3)
        do {
            Start-Sleep -Seconds 2
            $deviceId = Get-CompatibleAndroidDevice -AdbPath $adbPath -SupportedAbis $supportedAbis
        } while (-not $deviceId -and (Get-Date) -lt $deviceDeadline)
        if (-not $deviceId) { throw 'The supported Android emulator did not connect to ADB within 3 minutes. Check Android Studio, Wireless debugging, and ADB.' }
    }

    Write-Host "Waiting for Android device $deviceId to finish booting..."
    $bootDeadline = (Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Seconds 2
        $boot = Invoke-Adb -AdbPath $adbPath -Arguments @('-s', $deviceId, 'shell', 'getprop', 'sys.boot_completed')
        $bootState = if ($boot.ExitCode -eq 0) { [string]($boot.Output | Select-Object -Last 1) } else { '' }
    } while ($bootState.Trim() -ne '1' -and (Get-Date) -lt $bootDeadline)
    if ($bootState.Trim() -ne '1') { throw "Android device $deviceId did not finish booting within 3 minutes." }

    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $flutterCommand) { throw 'Flutter is not on PATH. Install Flutter to run the Android app.' }
    Write-Host "Running the customer app on $deviceId..."
    $apiBaseUrl = 'http://10.0.2.2:8000/api'
    if ($deviceId -notmatch '^emulator-') {
        $reverse = Invoke-Adb -AdbPath $adbPath -Arguments @('-s', $deviceId, 'reverse', 'tcp:8000', 'tcp:8000')
        if ($reverse.ExitCode -ne 0) { throw "Could not forward the physical device API connection for $deviceId. Reconnect the device and try again." }
        $apiBaseUrl = 'http://127.0.0.1:8000/api'
    }
    Push-Location $mobilePath
    $previousJavaHome = $env:JAVA_HOME
    try {
        if (-not $env:JAVA_HOME -or -not (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
            $studioJbr = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'
            if (Test-Path -LiteralPath (Join-Path $studioJbr 'bin\java.exe')) {
                $env:JAVA_HOME = $studioJbr
                Write-Host 'Using Android Studio Java because JAVA_HOME is invalid.'
            }
        }
        & $flutterCommand.Source run -d $deviceId "--dart-define=API_BASE_URL=$apiBaseUrl"
        if ($LASTEXITCODE -ne 0) { throw "Flutter run failed with exit code $LASTEXITCODE. See the Flutter error above." }
    } finally {
        $env:JAVA_HOME = $previousJavaHome
        Pop-Location
    }
}

foreach ($required in @($pythonPath, (Join-Path $projectRoot '.env'),
        (Join-Path $adminPath 'node_modules\vite\bin\vite.js'))) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Missing $required. Follow docs/22-SETUP-AND-TESTING.md to install dependencies and configure the app."
    }
}
$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCommand) { throw 'Node.js is not on PATH. Install Node.js 22.12 or newer.' }
New-Item -ItemType Directory -Force -Path $logPath | Out-Null

# Validate the configured database without printing credentials or changing data.
Push-Location (Join-Path $projectRoot 'backend')
try {
    @'
from app.config import get_settings
from pymongo import MongoClient
try:
    with MongoClient(get_settings().mongodb_uri, serverSelectionTimeoutMS=5000) as client:
        hello = client.admin.command('hello')
        assert hello.get('setName') and hello.get('isWritablePrimary')
except Exception:
    raise SystemExit('Configured MongoDB is unavailable or is not a writable replica set.')
'@ | & $pythonPath -
    if ($LASTEXITCODE -ne 0) {
        throw 'Database check failed. Start your configured MongoDB replica set and check the root .env.'
    }
} finally { Pop-Location }

if ($Rebuild -or -not (Test-Path -LiteralPath (Join-Path $mobilePath 'build\web\index.html'))) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'Flutter is not on PATH. Install Flutter to build the customer app.'
    }
    Push-Location $mobilePath
    try {
        & flutter build web --no-wasm-dry-run --dart-define=API_BASE_URL=/api
        if ($LASTEXITCODE -ne 0) { throw 'Customer web build failed.' }
    } finally { Pop-Location }
}

Start-AppService -Name 'api' -Port 8000 -Executable $pythonPath `
    -Arguments '-m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload' `
    -Directory (Join-Path $projectRoot 'backend') -HealthUrl 'http://127.0.0.1:8000/health/ready'
Start-AppService -Name 'admin' -Port 5173 -Executable $nodeCommand.Source `
    -Arguments 'node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5173 --strictPort' `
    -Directory $adminPath -HealthUrl 'http://127.0.0.1:5173'
$customerArguments = 'scripts/customer-web-server.py'
if ($ShareCustomerWeb) { $customerArguments += ' --host 0.0.0.0' }
Start-AppService -Name 'customer' -Port 5174 -Executable $pythonPath `
    -Arguments $customerArguments -Directory $projectRoot `
    -HealthUrl 'http://127.0.0.1:5174'

Write-Host "`nCustomer app (this PC): http://127.0.0.1:5174"
if ($ShareCustomerWeb) {
    $lanIp = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and $_.PrefixOrigin -ne 'WellKnown' } |
        Select-Object -ExpandProperty IPAddress -First 1
    if ($lanIp) { Write-Host "Customer app (same Wi-Fi): http://${lanIp}:5174" }
    else { Write-Host 'Customer app is shared on port 5174; use this PC''s Wi-Fi IPv4 address in the phone browser.' }
}
Write-Host 'Staff portal: http://localhost:5173'
Write-Host 'API docs:     http://localhost:8000/docs'
Write-Host "Logs:         $logPath"
Write-Host 'Web services run in the background. Use -Rebuild after customer web app code changes.'
if ($OpenBrowser) { Start-Process 'http://localhost:5174' }
if ($WebOnly) {
    Write-Host 'Web-only mode; skipping Android emulator launch.'
} else {
    Start-AndroidApp -WirelessDevice $WirelessDevice -PairEndpoint $PairEndpoint -PairingCode $PairingCode
}
