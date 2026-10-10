# Setup Android SDK script for FleetOpt AI
$ErrorActionPreference = "Stop"

$androidDir = "C:\Android"
$sdkDir = "$androidDir\sdk"
$cmdlineDir = "$sdkDir\cmdline-tools\latest"

if (-not (Test-Path $cmdlineDir)) {
    Write-Host "[*] Creating Android SDK directories at $sdkDir..."
    New-Item -ItemType Directory -Force -Path $cmdlineDir | Out-Null
    
    $zipUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    $zipPath = "$env:TEMP\cmdline-tools.zip"
    
    Write-Host "[*] Downloading Android SDK Command-Line Tools..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    
    Write-Host "[*] Extracting Command-Line Tools..."
    Expand-Archive -Path $zipPath -DestinationPath "$env:TEMP\cmdline-tools-extracted" -Force
    
    # Move files to latest/
    Copy-Item -Path "$env:TEMP\cmdline-tools-extracted\cmdline-tools\*" -Destination $cmdlineDir -Recurse -Force
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\cmdline-tools-extracted" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[✓] Command-Line Tools installed at $cmdlineDir"
}

# Configure flutter
Write-Host "[*] Configuring Flutter Android SDK path..."
& flutter config --android-sdk $sdkDir

Write-Host "[✓] Android SDK configured. Verifying with flutter doctor..."
& flutter doctor
