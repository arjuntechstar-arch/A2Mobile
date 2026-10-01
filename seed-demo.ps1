# Add repeatable local demo data without replacing existing records.
[CmdletBinding()]
param([switch]$Preview)
$ErrorActionPreference = 'Stop'
$demoPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
Push-Location (Join-Path $PSScriptRoot 'backend')
try {
    $demoArguments = @('-m', 'app.demo_seed')
    if ($Preview) { $demoArguments += '--preview' }
    & $demoPython @demoArguments
    if ($LASTEXITCODE -ne 0) { throw 'Demo seeding failed. See the error above.' }
} finally { Pop-Location }
