# Inicia MT5 Data Provider em modo live (Windows + terminal MT5)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

if (-not (Test-Path (Join-Path $root ".venv"))) {
    Write-Host "Criando venv..." -ForegroundColor Yellow
    python -m venv (Join-Path $root ".venv")
}

$pip = Join-Path $root ".venv\Scripts\pip.exe"
$python = Join-Path $root ".venv\Scripts\python.exe"

& $pip install -e ".[mt5,dev]" -q

$envFile = Join-Path $root ".env"
if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $root ".env.example") $envFile
    Write-Host "Criado .env - configure MT5_PATH e API keys" -ForegroundColor Yellow
}

$env:MT5_PROVIDER_MODE = "live"
Write-Host "MT5 Data Provider - modo LIVE" -ForegroundColor Cyan
Write-Host "Docs: http://localhost:8000/docs" -ForegroundColor Green
Set-Location $root
& $python -m mt5_provider.cli