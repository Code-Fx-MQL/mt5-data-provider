# Arranca Cloudflare Tunnel em foreground (util para debug)
param(
    [string]$ConfigPath = (Join-Path $env:USERPROFILE ".cloudflared\config.yml")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ConfigPath)) {
    $root = Split-Path $PSScriptRoot -Parent
    $alt = Join-Path $root "deploy\cloudflare\config.yml"
    if (Test-Path $alt) {
        $ConfigPath = $alt
    } else {
        throw "Config nao encontrada. Execute primeiro: .\scripts\install-cloudflare-tunnel.ps1"
    }
}

$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
if (-not $cloudflared) {
    throw "cloudflared nao encontrado"
}

$logDir = Join-Path (Split-Path $PSScriptRoot -Parent) "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$cfLog = Join-Path $logDir "cloudflared.err.log"

Write-Host "Tunel Cloudflare - config: $ConfigPath" -ForegroundColor Cyan
Write-Host "Log: $cfLog" -ForegroundColor Gray
Write-Host "Ctrl+C para parar" -ForegroundColor Gray
& $cloudflared.Source tunnel --config $ConfigPath --logfile $cfLog run