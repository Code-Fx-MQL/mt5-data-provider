# Regista tarefa Windows para monitorar MT5 + Provider a cada 2 minutos
# Executar como Administrador (recomendado)

param(
    [int]$IntervalMinutes = 2,
    [string]$TaskName = "MT5-DataProvider-Watchdog"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$watchdog = Join-Path $PSScriptRoot "watchdog-mt5.ps1"

if (-not (Test-Path $watchdog)) {
    throw "Script nao encontrado: $watchdog"
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$watchdog`"" `
    -WorkingDirectory $root

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration ([TimeSpan]::MaxValue)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Tarefa criada: $TaskName" -ForegroundColor Green
Write-Host "  Intervalo: cada $IntervalMinutes minuto(s)"
Write-Host "  Script: $watchdog"
Write-Host "  Log: $root\logs\watchdog.log"
Write-Host ""
Write-Host "Testar agora:" -ForegroundColor Yellow
Write-Host "  powershell -File `"$watchdog`""
Write-Host ""
Write-Host "Ver tarefa: taskschd.msc -> $TaskName"