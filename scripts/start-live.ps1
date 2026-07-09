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

if (-not (Test-Path (Join-Path $root ".env"))) {
    Copy-Item (Join-Path $root ".env.example") (Join-Path $root ".env")
    Write-Host "Criado .env a partir de .env.example — configure MT5_PATH e API keys" -ForegroundColor Yellow
}

$env:MT5_PROVIDER_MODE = "live"
Write-Host "MT5 Data Provider — modo LIVE" -ForegroundColor Cyan
Write-Host "Docs: http://localhost:8000/docs" -ForegroundColor Green
& $python -m mt5_provider.cli