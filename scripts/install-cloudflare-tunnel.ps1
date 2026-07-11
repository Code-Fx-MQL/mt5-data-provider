# Configura Cloudflare Tunnel no Windows para expor mt5-data-provider (:8000)
# Requer: cloudflared instalado + login Cloudflare (cert.pem em ~/.cloudflared)
# Executar como Administrador para instalar serviço Windows

param(
    [string]$TunnelName = "mt5-provider",
    [string]$Hostname = "mt5.fullscopetrade.com",
    [int]$LocalPort = 8000,
    [switch]$SkipService,
    [switch]$SkipDns
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$cfDir = Join-Path $env:USERPROFILE ".cloudflared"
$configPath = Join-Path $cfDir "config.yml"
$projectConfig = Join-Path $root "deploy\cloudflare\config.yml"

function Get-CloudflaredPath {
    $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $winget = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "cloudflared.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($winget) { return $winget.FullName }
    throw "cloudflared nao encontrado. Instale: winget install Cloudflare.cloudflared"
}

function Test-CloudflareLogin {
    $cert = Join-Path $cfDir "cert.pem"
    if (-not (Test-Path $cert)) {
        Write-Host "Login Cloudflare necessario." -ForegroundColor Yellow
        Write-Host "  cloudflared tunnel login" -ForegroundColor Cyan
        Write-Host "Autorize o dominio fullscopetrade.com no browser." -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Invoke-Cloudflared {
    param([string[]]$Args)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    try {
        return & $cloudflared @Args 2>$null
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Get-TunnelInfo {
    param([string]$Name)
    $json = Invoke-Cloudflared -Args @("tunnel", "list", "--output", "json")
    if (-not $json) { return $null }
    $tunnels = ($json | Out-String).Trim() | ConvertFrom-Json
    return $tunnels | Where-Object { $_.name -eq $Name } | Select-Object -First 1
}

$cloudflared = Get-CloudflaredPath
Write-Host "cloudflared: $cloudflared" -ForegroundColor Gray
& $cloudflared --version

if (-not (Test-Path $cfDir)) {
    New-Item -ItemType Directory -Path $cfDir -Force | Out-Null
}

if (-not (Test-CloudflareLogin)) {
    Write-Host ""
    Write-Host "A executar login..." -ForegroundColor Cyan
    & $cloudflared tunnel login
    if (-not (Test-CloudflareLogin)) {
        throw "Login nao concluido. Execute: cloudflared tunnel login"
    }
}

$tunnel = Get-TunnelInfo -Name $TunnelName
if (-not $tunnel) {
    Write-Host "A criar tunel: $TunnelName" -ForegroundColor Cyan
    Invoke-Cloudflared -Args @("tunnel", "create", $TunnelName) | Out-Host
    $tunnel = Get-TunnelInfo -Name $TunnelName
    if (-not $tunnel) {
        throw "Falha ao criar tunel $TunnelName"
    }
}

$tunnelId = $tunnel.id
$credFile = Join-Path $cfDir "$tunnelId.json"
if (-not (Test-Path $credFile)) {
    throw "Credenciais nao encontradas: $credFile"
}

Write-Host "Tunel: $TunnelName ($tunnelId)" -ForegroundColor Green

$configYaml = @"
tunnel: $tunnelId
credentials-file: $credFile

ingress:
  - hostname: $Hostname
    service: http://127.0.0.1:$LocalPort
  - service: http_status:404
"@

Set-Content -Path $configPath -Value $configYaml -Encoding UTF8
$deployDir = Split-Path $projectConfig -Parent
if (-not (Test-Path $deployDir)) {
    New-Item -ItemType Directory -Path $deployDir -Force | Out-Null
}
Set-Content -Path $projectConfig -Value $configYaml -Encoding UTF8
Write-Host "Config: $configPath" -ForegroundColor Green

if (-not $SkipDns) {
    Write-Host "A registar DNS: $Hostname -> $TunnelName" -ForegroundColor Cyan
    Invoke-Cloudflared -Args @("tunnel", "route", "dns", $TunnelName, $Hostname) | ForEach-Object { Write-Host $_ }
}

if (-not $SkipService) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "AVISO: Sem privilegios Admin - servico nao instalado." -ForegroundColor Yellow
        Write-Host "  Execute como Admin ou use: .\scripts\start-tunnel.ps1" -ForegroundColor Yellow
    } else {
        $svc = Get-Service -Name "Cloudflared" -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Host "Reinstalando servico Cloudflared..." -ForegroundColor Cyan
            Stop-Service Cloudflared -Force -ErrorAction SilentlyContinue
            & $cloudflared service uninstall 2>$null
        }
        & $cloudflared --config $configPath service install
        Start-Service Cloudflared -ErrorAction SilentlyContinue
        Write-Host "Servico Cloudflared instalado e iniciado." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Proximos passos ===" -ForegroundColor Cyan
Write-Host "1. Garantir provider em http://localhost:$LocalPort"
Write-Host "2. Testar: curl https://$Hostname/health"
Write-Host "3. Harness cloud (EasyPanel):"
Write-Host "     MT5_PROVIDER_URL=https://$Hostname"
Write-Host "     MT5_PROVIDER_API_KEY=<sua chave MT5_API_KEYS>"
Write-Host ""
Write-Host "Arrancar manualmente: .\scripts\start-tunnel.ps1" -ForegroundColor Yellow