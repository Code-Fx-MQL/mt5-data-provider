# Instala cloudflared (winget ou download directo se winget indisponivel)
param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$toolsDir = Join-Path $root "tools"
$localBin = Join-Path $toolsDir "cloudflared.exe"
$downloadUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"

function Find-Cloudflared {
    $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
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

$existing = Find-Cloudflared
if ($existing) {
    if (-not $Quiet) { Write-Host "cloudflared ja instalado: $existing" -ForegroundColor Green }
    exit 0
}

$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    if (-not $Quiet) { Write-Host "A instalar cloudflared via winget..." -ForegroundColor Cyan }
    & winget install Cloudflare.cloudflared --accept-package-agreements --accept-source-agreements -e -h
    if ($LASTEXITCODE -eq 0) {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $path = Find-Cloudflared
        if ($path) {
            if (-not $Quiet) {
                Write-Host "cloudflared instalado: $path" -ForegroundColor Green
                & $path --version
            }
            exit 0
        }
    }
    if (-not $Quiet) { Write-Host "winget falhou ou nao encontrou binario - a tentar download directo..." -ForegroundColor Yellow }
}

if (-not $Quiet) { Write-Host "A descarregar cloudflared para $localBin ..." -ForegroundColor Cyan }
if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir | Out-Null }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $downloadUrl -OutFile $localBin -UseBasicParsing

if (-not (Test-Path $localBin)) {
    Write-Host "Download falhou: $downloadUrl" -ForegroundColor Red
    exit 1
}

if (-not $Quiet) {
    Write-Host "cloudflared instalado: $localBin" -ForegroundColor Green
    & $localBin --version
}
exit 0