# Corrige paths de credenciais no config.yml apos migracao entre PCs Windows
param(
    [string]$ConfigPath = (Join-Path $env:USERPROFILE ".cloudflared\config.yml")
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\cloudflared-common.ps1")

if (-not (Test-Path $ConfigPath)) {
    throw "Config nao encontrada: $ConfigPath"
}

$changed = Repair-CloudflaredConfig -ConfigPath $ConfigPath
$meta = Get-CloudflaredTunnelMeta -ConfigPath $ConfigPath

Write-Host "Config: $ConfigPath" -ForegroundColor Cyan
Write-Host "Tunnel: $($meta.TunnelId)" -ForegroundColor Gray
Write-Host "Credenciais: $($meta.CredentialsFile)" -ForegroundColor Gray

if (-not (Test-Path $meta.CredentialsFile)) {
    Write-Host "ERRO: ficheiro de credenciais em falta" -ForegroundColor Red
    Write-Host "Execute migrate-import.ps1 ou copie *.json para $env:USERPROFILE\.cloudflared\" -ForegroundColor Yellow
    exit 1
}

if ($changed) {
    Write-Host "Paths corrigidos para este PC ($env:USERPROFILE)" -ForegroundColor Green
} else {
    Write-Host "Config ja correcta" -ForegroundColor Green
}