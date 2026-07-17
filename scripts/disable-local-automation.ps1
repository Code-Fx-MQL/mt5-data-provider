# Desactiva/remove automacao local (use quando a producao corre noutra VPS/PC)
# - Tarefas MT5 watchdog + Cloudflare
# - Tarefa CRT-Agent-Scan (se existir neste PC)
param(
    [switch]$KeepTasks  # so desactiva, nao remove
)

$ErrorActionPreference = "Continue"
$tasks = @(
    "MT5-DataProvider-Watchdog",
    "MT5-Cloudflare-Tunnel",
    "CRT-Agent-Scan"
)

Write-Host "=== Desactivar automacao local (stack em VPS) ===" -ForegroundColor Cyan

foreach ($name in $tasks) {
    $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if (-not $t) {
        Write-Host "  (ausente) $name" -ForegroundColor Gray
        continue
    }
    Disable-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue | Out-Null
    if ($KeepTasks) {
        Write-Host "  Desactivada: $name" -ForegroundColor Yellow
    } else {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "  Removida: $name" -ForegroundColor Yellow
    }
}

# Para processos de tunel/provider se ainda estiverem a correr neste PC
Get-Process -Name cloudflared -ErrorAction SilentlyContinue | ForEach-Object {
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    Write-Host "  cloudflared parado (PID $($_.Id))" -ForegroundColor Yellow
}

Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
    $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    if ($proc -and ($proc.Path -match "mt5|python|uvicorn" -or $proc.ProcessName -match "python")) {
        Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
        Write-Host "  provider :8000 parado (PID $($_.OwningProcess))" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "OK — este PC ja nao corre watchdogs/scan automaticos." -ForegroundColor Green
Write-Host "Producao: MT5 na VPS + CRT em https://crt.fullscopetrade.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para reactivar neste PC (nao faca se a VPS ja tem o stack):" -ForegroundColor Gray
Write-Host "  .\scripts\install-all-tasks.ps1"
Write-Host "  cd ..\agent-harness; .\scripts\register-scheduled-task.ps1"