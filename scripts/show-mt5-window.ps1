# Restaura e traz para frente a janela do terminal MT5 (util se arrancou minimizado)
param(
    [string]$EnvFile = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (-not $EnvFile) { $EnvFile = Join-Path $root ".env" }

$mt5Path = ""
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "^MT5_PATH=(.+)$") {
            $mt5Path = $matches[1].Trim().Trim('"')
        }
    }
}

$procs = @(Get-Process -Name "terminal64" -ErrorAction SilentlyContinue)
if ($procs.Count -eq 0) {
    Write-Host "Nenhum terminal64 em execucao." -ForegroundColor Red
    if ($mt5Path -and (Test-Path $mt5Path)) {
        Write-Host "A arrancar: $mt5Path" -ForegroundColor Yellow
        Start-Process -FilePath $mt5Path
    } else {
        Write-Host "Defina MT5_PATH no .env ou abra o MT5 manualmente." -ForegroundColor Yellow
    }
    exit 1
}

if ($mt5Path) {
    $norm = $mt5Path.ToLower()
    $match = $procs | Where-Object { $_.Path -and $_.Path.ToLower() -eq $norm }
    if ($match) { $procs = @($match) }
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Mt5Window {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

$shown = $false
foreach ($proc in $procs) {
    $hwnd = $proc.MainWindowHandle
    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Host "PID $($proc.Id): sem janela principal (pode estar na bandeja)" -ForegroundColor Yellow
        continue
    }
    [Mt5Window]::ShowWindow($hwnd, 9) | Out-Null   # SW_RESTORE
    [Mt5Window]::SetForegroundWindow($hwnd) | Out-Null
    Write-Host "MT5 restaurado: PID $($proc.Id) $($proc.Path)" -ForegroundColor Green
    $shown = $true
}

if (-not $shown) {
    Write-Host "Processo MT5 activo mas janela nao encontrada. Verifique o icono na barra de tarefas." -ForegroundColor Yellow
    $procs | ForEach-Object { Write-Host "  PID $($_.Id) path=$($_.Path)" }
    exit 1
}