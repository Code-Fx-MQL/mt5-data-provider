# Importa pacote de migracao (env + cloudflared)
param(
    [Parameter(Mandatory = $true)]
    [string]$MigrationZip,
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"
if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path $PSScriptRoot -Parent
}
if (-not (Test-Path $MigrationZip)) {
    throw "ZIP nao encontrado: $MigrationZip"
}

$tempDir = Join-Path $env:TEMP ("mt5-import-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Path $tempDir | Out-Null
Expand-Archive -Path $MigrationZip -DestinationPath $tempDir -Force

$envSrc = Join-Path $tempDir ".env"
if (-not (Test-Path $envSrc)) {
    throw ".env nao encontrado dentro do ZIP"
}
Copy-Item $envSrc (Join-Path $ProjectRoot ".env") -Force
Write-Host "Importado .env -> $ProjectRoot\.env" -ForegroundColor Green

$cfSrc = Join-Path $tempDir "cloudflared"
$cfHome = Join-Path $env:USERPROFILE ".cloudflared"
if (Test-Path $cfSrc) {
    if (-not (Test-Path $cfHome)) { New-Item -ItemType Directory -Path $cfHome | Out-Null }
    Get-ChildItem $cfSrc -File | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $cfHome $_.Name) -Force
        Write-Host "Importado cloudflared/$($_.Name)" -ForegroundColor Green
    }
    # Copia tambem para deploy/cloudflare (referencia no repo)
    $deployCf = Join-Path $ProjectRoot "deploy\cloudflare"
    if (-not (Test-Path $deployCf)) { New-Item -ItemType Directory -Path $deployCf | Out-Null }
    $cfg = Join-Path $cfSrc "config.yml"
    if (Test-Path $cfg) {
        Copy-Item $cfg (Join-Path $deployCf "config.yml") -Force
    }
}

$manifest = Join-Path $tempDir "MANIFEST.json"
if (Test-Path $manifest) {
    $meta = Get-Content $manifest -Raw | ConvertFrom-Json
    Write-Host "Migracao de: $($meta.source_machine) em $($meta.exported_at)" -ForegroundColor Cyan
}

Remove-Item $tempDir -Recurse -Force
Write-Host "Importacao concluida." -ForegroundColor Green