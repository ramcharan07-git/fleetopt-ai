# Script to launch FleetOpt AI Backend
Write-Host "[*] Starting FleetOpt AI FastAPI Backend with Uvicorn..."
Set-Location -Path "$PSScriptRoot\..\backend"
& ".\venv\Scripts\uvicorn.exe" app.main:app --host 0.0.0.0 --port 8000 --reload
