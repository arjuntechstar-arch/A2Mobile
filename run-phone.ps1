# Starts all A2Mobile services and deploys the Flutter app to a wireless Android phone.
# First use: provide the Pair device with pairing code address/port and code from Android.
# Later uses normally require only -WirelessDevice.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WirelessDevice,
    [string]$PairEndpoint,
    [string]$PairingCode,
    [switch]$Rebuild,
    [switch]$OpenBrowser,
    [switch]$ShareCustomerWeb
)

& (Join-Path $PSScriptRoot 'run-app.ps1') -WirelessDevice $WirelessDevice `
    -PairEndpoint $PairEndpoint -PairingCode $PairingCode -Rebuild:$Rebuild `
    -OpenBrowser:$OpenBrowser -ShareCustomerWeb:$ShareCustomerWeb
if ($LASTEXITCODE -ne 0) { throw "Wireless phone launch failed with exit code $LASTEXITCODE." }