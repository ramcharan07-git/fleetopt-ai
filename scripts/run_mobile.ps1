# Script to launch FleetOpt AI Flutter Mobile App
Write-Host "[*] Launching FleetOpt AI Flutter Application..."
Set-Location -Path "$PSScriptRoot\..\mobile"
& flutter run -d chrome
