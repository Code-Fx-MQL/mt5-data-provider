# Aplica mapeamento harness->MT5 no .env (ex. XAUUSD:GOLD) e reinicia provider
param(
    [string]$ProjectRoot = "",
    [hashtable]$Map = @{ "XAUUSD" = "GOLD" },
    [switch]$NoRestart
)

$ErrorActionPreference = "Stop"
if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path $PSScriptRoot -Parent
}
$envFile = Join-Path $ProjectRoot ".env"
if (-not (Test-Path $envFile)) {
    throw ".env nao encontrado: $envFile"
}

$lines = Get-Content $envFile
$symbolLine = $lines | Where-Object { $_ -match "^MT5_SYMBOLS=" } | Select-Object -First 1
$entries = @{}
if ($symbolLine) {
    $raw = ($symbolLine -split "=", 2)[1]
    foreach ($chunk in $raw.Split(",")) {
        $chunk = $chunk.Trim()
        if (-not $chunk) { continue }
        if ($chunk.Contains(":")) {
            $k, $v = $chunk.Split(":", 2)
            $entries[$k.Trim().ToUpper()] = $v.Trim()
        } else {
            $entries[$chunk.ToUpper()] = $chunk
        }
    }
}

foreach ($key in $Map.Keys) {
    $entries[$key.ToUpper()] = $Map[$key]
    Write-Host "Map: $key -> $($Map[$key])" -ForegroundColor Green
}

$newLine = "MT5_SYMBOLS=" + (($entries.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key):$($_.Value)" }) -join ",")
$out = foreach ($line in $lines) {
    if ($line -match "^MT5_SYMBOLS=") { $newLine } else { $line }
}
if (-not ($out -match "^MT5_SYMBOLS=")) {
    $out += $newLine
}
Set-Content -Path $envFile -Value $out -Encoding UTF8
Write-Host "Actualizado: $envFile" -ForegroundColor Cyan

if (-not $NoRestart) {
    & (Join-Path $PSScriptRoot "watchdog-mt5.ps1")
}