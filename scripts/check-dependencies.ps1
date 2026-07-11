# Verifica dependencias para MT5 Data Provider (modo live + tunel)
param(
    [switch]$InstallMissing,
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"
$ok = $true

function Report([string]$Name, [bool]$Pass, [string]$Detail = "", [string]$Fix = "") {
    $script:ok = $ok -and $Pass
    if ($Quiet -and $Pass) { return }
    $icon = if ($Pass) { "[OK]" } else { "[--]" }
    $color = if ($Pass) { "Green" } else { "Red" }
    Write-Host "$icon $Name" -ForegroundColor $color
    if ($Detail) { Write-Host "     $Detail" -ForegroundColor Gray }
    if (-not $Pass -and $Fix) { Write-Host "     -> $Fix" -ForegroundColor Yellow }
}

# Windows
$os = Get-CimInstance Win32_OperatingSystem
$isWin = $os.Caption -match "Windows"
Report "Windows" $isWin $os.Caption

# Python 3.11+
$py = $null
foreach ($cmd in @("python", "py")) {
    $c = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($c) { $py = $c; break }
}
$pyVer = $null
if ($py) {
    try {
        $pyVer = & $py.Source -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
    } catch {}
}
$pyOk = $pyVer -and ([version]$pyVer -ge [version]"3.11")
Report "Python 3.11+" $pyOk $(if ($pyVer) { "v$pyVer ($($py.Source))" } else { "nao encontrado" }) "winget install Python.Python.3.12"

if (-not $pyOk -and $InstallMissing) {
    winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements -e -h 2>$null
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) {
        $pyVer = & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
        $pyOk = [version]$pyVer -ge [version]"3.11"
    }
}

# MetaTrader 5
$mt5Paths = @()
$searchRoots = @(
    "C:\MT5\Instances",
    "C:\Program Files",
    "C:\Program Files (x86)"
)
foreach ($root in $searchRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem -Path $root -Filter "terminal64.exe" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $mt5Paths += $_.FullName
    }
}
$mt5Ok = $mt5Paths.Count -gt 0
$mt5Detail = if ($mt5Paths.Count -gt 0) { $mt5Paths[0] + $(if ($mt5Paths.Count -gt 1) { " (+$($mt5Paths.Count - 1) mais)" } else { "" }) } else { "Instale MT5 e copie terminal para C:\MT5\Instances\..." }
Report "MetaTrader 5 (terminal64.exe)" $mt5Ok $mt5Detail "Instalar MT5 do broker e anotar MT5_PATH no .env"

# cloudflared (opcional mas recomendado para harness na nuvem)
$cf = Get-Command cloudflared -ErrorAction SilentlyContinue
if (-not $cf) {
    $wingetCf = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "cloudflared.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wingetCf) { $cf = $wingetCf }
}
$cfOk = $null -ne $cf
$localCf = Join-Path (Split-Path $PSScriptRoot -Parent) "tools\cloudflared.exe"
if (-not $cfOk -and (Test-Path $localCf)) { $cfOk = $true; $cf = Get-Item $localCf }
$cfDetail = if ($cf) { if ($cf.FullName) { $cf.FullName } else { $cf.Source } } else { "opcional para acesso remoto" }
Report "cloudflared (tunel HTTPS)" $cfOk $cfDetail ".\scripts\install-cloudflared.ps1"

if (-not $cfOk -and $InstallMissing) {
    & (Join-Path $PSScriptRoot "install-cloudflared.ps1") -Quiet
    $localCf = Join-Path (Split-Path $PSScriptRoot -Parent) "tools\cloudflared.exe"
    if (Test-Path $localCf) { $cfOk = $true }
    else {
        $cf = Get-Command cloudflared -ErrorAction SilentlyContinue
        $cfOk = $null -ne $cf
    }
}

# Porta 8000 livre ou provider ja ativo
$port8000 = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
$portOk = $true
$portDetail = if ($port8000) { "Em uso (PID $($port8000.OwningProcess)) - provider pode ja estar ativo" } else { "Livre" }
Report "Porta 8000" $portOk $portDetail

# .env
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root ".env"
$envOk = Test-Path $envFile
Report "Ficheiro .env" $envOk $(if ($envOk) { $envFile } else { "Copie .env.example ou importe migracao" }) ".\scripts\migrate-import.ps1 ou copy .env.example .env"

if (-not $Quiet) {
    Write-Host ""
    if ($ok) {
        Write-Host "Todas as dependencias criticas OK." -ForegroundColor Green
    } else {
        Write-Host "Faltam dependencias - use -InstallMissing ou siga docs/MIGRACAO-WINDOWS.md" -ForegroundColor Yellow
    }
}

if (-not $ok) { exit 1 }
exit 0