# Instala tarefas Windows: watchdog MT5 + watchdog Cloudflare
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

Write-Host "A instalar tarefas agendadas..." -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "install-watchdog-task.ps1") -IntervalMinutes 2
& (Join-Path $PSScriptRoot "install-cloudflare-task.ps1") -IntervalMinutes 2

Write-Host ""
Write-Host "Tarefas activas (taskschd.msc):" -ForegroundColor Green
Write-Host "  MT5-DataProvider-Watchdog  - terminal + provider :8000"
Write-Host "  MT5-Cloudflare-Tunnel      - tunel HTTPS publico"
Write-Host ""
Write-Host "Testar agora:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName MT5-DataProvider-Watchdog"
Write-Host "  Start-ScheduledTask -TaskName MT5-Cloudflare-Tunnel"