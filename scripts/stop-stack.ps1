# Para provider MT5 + tunel Cloudflare + desactiva tarefas (maquina antiga apos migracao)
param(
    [switch]$KeepTasks
)

$ErrorActionPreference = "Continue"
Write-Host "=== A parar stack MT5 Data Provider ===" -ForegroundColor Cyan

if (-not $KeepTasks) {
    foreach ($name in @("MT5-DataProvider-Watchdog", "MT5-Cloudflare-Tunnel")) {
        $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        if ($t) {
            Disable-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Tarefa desactivada: $name" -ForegroundColor Yellow
        }
    }
}

Get-Process -Name cloudflared -ErrorAction SilentlyContinue | ForEach-Object {
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    Write-Host "cloudflared parado (PID $($_.Id))" -ForegroundColor Yellow
}

Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
    Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
    Write-Host "Provider parado (PID $($_.OwningProcess))" -ForegroundColor Yellow
}

Start-Sleep 2
$cf = @(Get-Process -Name cloudflared -ErrorAction SilentlyContinue).Count
$port = @(Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue).Count
if ($cf -eq 0 -and $port -eq 0) {
    Write-Host "Stack parado com sucesso." -ForegroundColor Green
    exit 0
}
Write-Host "AVISO: ainda ha processos activos (cloudflared=$cf, porta8000=$port)" -ForegroundColor Red
exit 1