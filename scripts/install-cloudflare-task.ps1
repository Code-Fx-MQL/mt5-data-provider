# Tarefa Windows: manter Cloudflare Tunnel ativo (logon + a cada 2 min)
param(
    [int]$IntervalMinutes = 2,
    [string]$TaskName = "MT5-Cloudflare-Tunnel"
)

$ErrorActionPreference = "Stop"
$watchdog = Join-Path $PSScriptRoot "watchdog-cloudflare.ps1"
$root = Split-Path $PSScriptRoot -Parent

if (-not (Test-Path $watchdog)) {
    throw "Script nao encontrado: $watchdog"
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$watchdog`"" `
    -WorkingDirectory $root

$atLogon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$repeat = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($atLogon, $repeat) -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Tarefa criada: $TaskName" -ForegroundColor Green
Write-Host "  Logon + cada $IntervalMinutes min"
Write-Host "  Log: $root\logs\cloudflared-watchdog.log"
Write-Host ""
Write-Host "Testar:" -ForegroundColor Yellow
Write-Host "  powershell -File `"$watchdog`""