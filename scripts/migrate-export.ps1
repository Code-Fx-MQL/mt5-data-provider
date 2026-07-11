# Exporta pacote de migracao (env + cloudflared) da maquina atual
param(
    [string]$OutputZip = "",
    [string]$Hostname = "mt5.fullscopetrade.com"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
if (-not $OutputZip) {
    $OutputZip = Join-Path $root "mt5-migration-$stamp.zip"
}

$tempDir = Join-Path $env:TEMP "mt5-migration-$stamp"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir | Out-Null

# .env
$envSrc = Join-Path $root ".env"
if (-not (Test-Path $envSrc)) {
    throw ".env nao encontrado em $root - configure antes de exportar"
}
Copy-Item $envSrc (Join-Path $tempDir ".env")

# Cloudflared
$cfHome = Join-Path $env:USERPROFILE ".cloudflared"
$cfDest = Join-Path $tempDir "cloudflared"
New-Item -ItemType Directory -Path $cfDest | Out-Null
$cfFiles = @("config.yml", "cert.pem")
Get-ChildItem $cfHome -Filter "*.json" -ErrorAction SilentlyContinue | ForEach-Object { $cfFiles += $_.Name }
foreach ($name in $cfFiles) {
    $src = Join-Path $cfHome $name
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $cfDest $name)
    }
}

# Manifest
$envMap = @{}
Get-Content $envSrc | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
        $k, $v = $line.Split("=", 2)
        $envMap[$k.Trim()] = if ($k -match "PASSWORD|API_KEY|SECRET") { "***" } else { $v.Trim() }
    }
}

$pyVer = "unknown"
try { $pyVer = & python -c "import sys; print(sys.version)" 2>$null } catch {}

$manifest = @{
    exported_at = (Get-Date).ToString("o")
    hostname = $Hostname
    source_machine = $env:COMPUTERNAME
    python = $pyVer
    project_root = $root
    env_keys = $envMap.Keys | Sort-Object
    cloudflared_files = @(Get-ChildItem $cfDest -File | ForEach-Object { $_.Name })
    notes = @(
        "Copie este ZIP para a nova maquina Windows",
        "Na nova maquina: git clone + bootstrap-windows.ps1 -MigrationZip com este ZIP",
        "Mantenha o mesmo MT5_API_KEYS para nao alterar MT5_PROVIDER_API_KEY no harness"
    )
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $tempDir "MANIFEST.json") -Encoding UTF8

if (Test-Path $OutputZip) { Remove-Item $OutputZip -Force }
Compress-Archive -Path (Join-Path $tempDir "*") -DestinationPath $OutputZip -Force
Remove-Item $tempDir -Recurse -Force

Write-Host "Pacote de migracao criado:" -ForegroundColor Green
Write-Host "  $OutputZip"
Write-Host "  Tamanho: $([math]::Round((Get-Item $OutputZip).Length / 1KB)) KB"
Write-Host ""
Write-Host "Proximo passo na NOVA maquina:" -ForegroundColor Cyan
Write-Host "  git clone https://github.com/Code-Fx-MQL/mt5-data-provider.git C:\MT5\mt5-data-provider"
Write-Host "  cd C:\MT5\mt5-data-provider"
Write-Host '  .\scripts\bootstrap-windows.ps1 -MigrationZip "D:\caminho\mt5-migration.zip"'