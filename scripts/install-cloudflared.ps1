# Instala cloudflared via winget e mostra caminho
param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Find-Cloudflared {
    $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $roots = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
        "${env:ProgramFiles}\Cloudflare",
        "${env:ProgramFiles(x86)}\Cloudflare"
    )
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        $hit = Get-ChildItem $root -Filter "cloudflared.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

$existing = Find-Cloudflared
if ($existing) {
    if (-not $Quiet) { Write-Host "cloudflared ja instalado: $existing" -ForegroundColor Green }
    exit 0
}

if (-not $Quiet) { Write-Host "A instalar cloudflared via winget..." -ForegroundColor Cyan }
winget install Cloudflare.cloudflared --accept-package-agreements --accept-source-agreements -e -h
if ($LASTEXITCODE -ne 0) {
    Write-Host "Falha winget. Tente manual: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/" -ForegroundColor Red
    exit 1
}

# Atualizar PATH da sessao
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

$path = Find-Cloudflared
if (-not $path) {
    Write-Host "Instalado mas nao encontrado - reinicie o PowerShell e execute watchdog-cloudflare.ps1" -ForegroundColor Yellow
    exit 1
}

if (-not $Quiet) {
    Write-Host "cloudflared instalado: $path" -ForegroundColor Green
    & $path --version
}
exit 0