# Arranca Cloudflare Tunnel em foreground (util para debug)
param(
    [string]$ConfigPath = (Join-Path $env:USERPROFILE ".cloudflared\config.yml")
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot "lib\cloudflared-common.ps1")

if (-not (Test-Path $ConfigPath)) {
    $alt = Join-Path $root "deploy\cloudflare\config.yml"
    if (Test-Path $alt) {
        $ConfigPath = $alt
    } else {
        throw "Config nao encontrada. Execute primeiro: .\scripts\install-cloudflare-tunnel.ps1"
    }
}

Repair-CloudflaredConfig -ConfigPath $ConfigPath | Out-Null
$meta = Get-CloudflaredTunnelMeta -ConfigPath $ConfigPath
if (-not $meta.TunnelId) {
    throw "tunnel ID nao encontrado em $ConfigPath"
}
if (-not (Test-Path $meta.CredentialsFile)) {
    throw "Credenciais em falta: $($meta.CredentialsFile). Execute .\scripts\fix-cloudflared-config.ps1"
}

$cloudflared = Get-CloudflaredPath -ProjectRoot $root
if (-not $cloudflared) {
    throw "cloudflared nao encontrado - execute .\scripts\install-cloudflared.ps1"
}

$logDir = Join-Path $root "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$cfLog = Join-Path $logDir "cloudflared.err.log"

if (-not (Test-ProviderListening -Port $meta.LocalPort)) {
    Write-Host "AVISO: provider :$($meta.LocalPort) offline - https://$($meta.PublicHostname)/health vai falhar com 502" -ForegroundColor Yellow
}

Write-Host "Tunel Cloudflare - config: $ConfigPath" -ForegroundColor Cyan
Write-Host "Log: $cfLog" -ForegroundColor Gray
Write-Host "Ctrl+C para parar" -ForegroundColor Gray
& $cloudflared tunnel --config $ConfigPath --logfile $cfLog run $meta.TunnelId