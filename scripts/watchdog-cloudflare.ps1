# Garante um unico processo cloudflared para o tunel MT5 provider
param(
    [switch]$DryRun,
    [switch]$StatusOnly
)

$ErrorActionPreference = "Continue"
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot "lib\cloudflared-common.ps1")

$logDir = Join-Path $root "logs"
$logFile = Join-Path $logDir "cloudflared-watchdog.log"
$config = Join-Path $env:USERPROFILE ".cloudflared\config.yml"

function Write-Log([string]$Message, [string]$Level = "INFO") {
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $line = "{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}" -f (Get-Date), $Level, $Message
    Add-Content -Path $logFile -Value $line -Encoding UTF8
    if ($Level -eq "ERROR") { Write-Host $line -ForegroundColor Red }
    elseif ($Level -eq "WARN") { Write-Host $line -ForegroundColor Yellow }
    else { Write-Host $line -ForegroundColor Cyan }
}

function Test-TunnelHealthy([string]$Hostname) {
    try {
        $r = Invoke-WebRequest -Uri "https://$Hostname/health" -UseBasicParsing -TimeoutSec 8
        return ($r.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Wait-TunnelHealthy([string]$Hostname, [int]$MaxSeconds = 25) {
    $deadline = (Get-Date).AddSeconds($MaxSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-TunnelHealthy $Hostname) { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

$cf = Get-CloudflaredPath -ProjectRoot $root
if (-not $cf) {
    Write-Log "cloudflared nao encontrado - execute: .\scripts\install-cloudflared.ps1" "ERROR"
    exit 1
}

if (-not (Test-Path $config)) {
    Write-Log "Config ausente: $config - execute install-cloudflare-tunnel.ps1" "ERROR"
    exit 1
}

if (Repair-CloudflaredConfig -ConfigPath $config) {
    Write-Log "Config Cloudflare: paths de credenciais corrigidos para $env:USERPROFILE" "INFO"
}

$meta = Get-CloudflaredTunnelMeta -ConfigPath $config
if (-not $meta.TunnelId) {
    Write-Log "tunnel ID nao encontrado em $config" "ERROR"
    exit 1
}
if (-not (Test-Path $meta.CredentialsFile)) {
    Write-Log "Credenciais em falta: $($meta.CredentialsFile) - execute .\scripts\fix-cloudflared-config.ps1 ou migrate-import.ps1" "ERROR"
    exit 1
}

$procs = @(Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue)
$healthy = Test-TunnelHealthy $meta.PublicHostname

if ($StatusOnly) {
    $provider = if (Test-ProviderListening -Port $meta.LocalPort) { "OK" } else { "OFF" }
    Write-Host "cloudflared: $($procs.Count) processo(s), provider:$provider, publico: $(if ($healthy) { 'OK' } else { 'FALHA' })"
    exit 0
}

if (-not (Test-ProviderListening -Port $meta.LocalPort)) {
    Write-Log "Provider :$($meta.LocalPort) offline - a arrancar via watchdog-mt5" "WARN"
    if (-not $DryRun) {
        & powershell -NoProfile -File (Join-Path $PSScriptRoot "watchdog-mt5.ps1") | Out-Null
        Start-Sleep -Seconds 5
        if (-not (Test-ProviderListening -Port $meta.LocalPort)) {
            Write-Log "Provider ainda offline em :$($meta.LocalPort) - tunel ficara em 502 ate API subir" "WARN"
        }
    }
}

if ($procs.Count -gt 1) {
    Write-Log "Multiplos cloudflared ($($procs.Count)) - a reiniciar" "WARN"
    if (-not $DryRun) {
        $procs | Stop-Process -Force
        Start-Sleep -Seconds 2
        $procs = @()
    }
}

if ($procs.Count -eq 0 -or -not $healthy) {
    if ($procs.Count -gt 0 -and -not $healthy) {
        Write-Log "Tunel sem resposta publica - reiniciando" "WARN"
        if (-not $DryRun) { $procs | Stop-Process -Force; Start-Sleep -Seconds 2 }
    }
    if ($DryRun) {
        Write-Log "DRY-RUN: iniciaria cloudflared tunnel run $($meta.TunnelId)" "INFO"
    } else {
        $cfLog = Join-Path $logDir "cloudflared.err.log"
        $proc = Start-CloudflaredTunnel -CloudflaredPath $cf -ConfigPath $config -TunnelId $meta.TunnelId -LogFile $cfLog
        Start-Sleep -Seconds 4
        if ($proc.HasExited) {
            Write-Log "cloudflared terminou logo apos arranque (exit $($proc.ExitCode))" "ERROR"
            foreach ($line in (Get-CloudflaredLogTail -LogFile $cfLog)) {
                Write-Log "  $line" "ERROR"
            }
            exit 1
        }
        $alive = @(Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue).Count
        if ($alive -eq 0) {
            Write-Log "Nenhum processo cloudflared activo apos arranque" "ERROR"
            foreach ($line in (Get-CloudflaredLogTail -LogFile $cfLog)) {
                Write-Log "  $line" "ERROR"
            }
            exit 1
        }
        $ok = Wait-TunnelHealthy $meta.PublicHostname
        if ($ok) {
            Write-Log "Tunel iniciado - https://$($meta.PublicHostname) OK" "INFO"
        } else {
            if (-not (Test-ProviderListening -Port $meta.LocalPort)) {
                Write-Log "Tunel activo mas provider :$($meta.LocalPort) offline - health publico em 502" "WARN"
            } else {
                Write-Log "Tunel activo mas health publico ainda falha (aguarde DNS/propagacao)" "WARN"
            }
            foreach ($line in (Get-CloudflaredLogTail -LogFile $cfLog -Lines 4)) {
                Write-Log "  $line" "WARN"
            }
        }
    }
} else {
    Write-Log "Tunel OK ($($procs.Count) processo)" "INFO"
}