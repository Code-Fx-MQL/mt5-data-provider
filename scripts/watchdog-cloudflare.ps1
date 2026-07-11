# Garante um unico processo cloudflared para o tunel MT5 provider
param(
    [switch]$DryRun,
    [switch]$StatusOnly
)

$ErrorActionPreference = "Continue"
$root = Split-Path $PSScriptRoot -Parent
$logDir = Join-Path $root "logs"
$logFile = Join-Path $logDir "cloudflared-watchdog.log"
$config = Join-Path $env:USERPROFILE ".cloudflared\config.yml"
$publicHostname = "mt5.fullscopetrade.com"
$tunnelId = ""
if (Test-Path $config) {
    $firstLine = Get-Content $config -TotalCount 5 -ErrorAction SilentlyContinue
    foreach ($line in $firstLine) {
        if ($line -match "^tunnel:\s*(.+)$") {
            $tunnelId = $matches[1].Trim()
            break
        }
    }
    $ingress = Get-Content $config -ErrorAction SilentlyContinue | Where-Object { $_ -match "hostname:" }
    if ($ingress -match "hostname:\s*(\S+)") {
        $publicHostname = $matches[1].Trim()
    }
}
if (-not $tunnelId) {
    Write-Log "tunnel ID nao encontrado em $config" "ERROR"
    exit 1
}

function Write-Log([string]$Message, [string]$Level = "INFO") {
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $line = "{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}" -f (Get-Date), $Level, $Message
    Add-Content -Path $logFile -Value $line -Encoding UTF8
    if ($Level -eq "ERROR") { Write-Host $line -ForegroundColor Red }
    elseif ($Level -eq "WARN") { Write-Host $line -ForegroundColor Yellow }
    else { Write-Host $line -ForegroundColor Cyan }
}

function Get-CloudflaredPath {
    $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $localBin = Join-Path $root "tools\cloudflared.exe"
    if (Test-Path $localBin) { return $localBin }
    $roots = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
        "${env:ProgramFiles}\Cloudflare",
        "${env:ProgramFiles(x86)}\Cloudflare"
    )
    foreach ($searchRoot in $roots) {
        if (-not (Test-Path $searchRoot)) { continue }
        $hit = Get-ChildItem $searchRoot -Filter "cloudflared.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Test-TunnelHealthy {
    try {
        $r = Invoke-WebRequest -Uri "https://$publicHostname/health" -UseBasicParsing -TimeoutSec 8
        return ($r.StatusCode -eq 200)
    } catch {
        return $false
    }
}

$cf = Get-CloudflaredPath
if (-not $cf) {
    Write-Log "cloudflared nao encontrado - execute: .\scripts\install-cloudflared.ps1" "ERROR"
    exit 1
}

if (-not (Test-Path $config)) {
    Write-Log "Config ausente: $config - execute install-cloudflare-tunnel.ps1" "ERROR"
    exit 1
}

$procs = @(Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue)
$healthy = Test-TunnelHealthy

if ($StatusOnly) {
    Write-Host "cloudflared: $($procs.Count) processo(s), publico: $(if ($healthy) { 'OK' } else { 'FALHA' })"
    exit 0
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
        Write-Log "DRY-RUN: iniciaria cloudflared tunnel run $tunnelId" "INFO"
    } else {
        $cfLog = Join-Path $logDir "cloudflared.err.log"
        $args = "tunnel --config `"$config`" --logfile `"$cfLog`" run $tunnelId"
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $cf
        $psi.Arguments = $args
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.CreateNoWindow = $true
        $psi.UseShellExecute = $true
        [void][System.Diagnostics.Process]::Start($psi)
        Start-Sleep -Seconds 6
        $ok = Test-TunnelHealthy
        if ($ok) {
            Write-Log "Tunel iniciado - https://$publicHostname OK" "INFO"
        } else {
            Write-Log "Tunel iniciado mas health publico ainda falha" "WARN"
        }
    }
} else {
    Write-Log "Tunel OK ($($procs.Count) processo)" "INFO"
}