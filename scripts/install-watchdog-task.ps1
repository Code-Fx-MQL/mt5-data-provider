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

$psArgs = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watchdog`""
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument $psArgs `
    -WorkingDirectory $root

# RepetitionDuration max ~31 dias por trigger Once (limite do Task Scheduler)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

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