# Descobre nomes MT5 reais no terminal e sugere linha MT5_SYMBOLS para o .env
param(
    [string]$ProjectRoot = "",
    [string[]]$HarnessSymbols = @(
        "XAUUSD", "GBPUSD", "USDCAD", "EURUSD", "GBPJPY",
        "AUDCAD", "USDCHF", "NZDUSD", "US30", "US100", "NAS100", "GER40"
    ),
    [string[]]$Candidates = @(
        "XAUUSD", "GOLD", "XAUUSD.", "XAUUSDm",
        "US30", "US30Cash", "US100", "US100Cash", "NAS100", "US500",
        "GER40", "GER40Cash", "DE40", "UK100"
    )
)

$ErrorActionPreference = "Stop"
if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path $PSScriptRoot -Parent
}
$envFile = Join-Path $ProjectRoot ".env"
$python = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    throw "venv nao encontrado — execute bootstrap-windows.ps1"
}

$script = @'
import MetaTrader5 as mt5
import json
import sys

harness = json.loads(sys.argv[1])
candidates = json.loads(sys.argv[2])

if not mt5.initialize():
    raise SystemExit("MT5 initialize falhou — terminal aberto e logado?")

# indexar candidatos que existem no broker
available = {}
for name in candidates:
    key = name.upper()
    info = mt5.symbol_info(name)
    if info is None:
        continue
    if not info.visible:
        mt5.symbol_select(name, True)
    available[key] = name

# mapeamento heurístico harness -> mt5
aliases = {
    "XAUUSD": ["GOLD", "XAUUSD", "XAUUSD.", "XAUUSDm"],
    "US30": ["US30Cash", "US30", "US500", "DJ30"],
    "US100": ["US100Cash", "US100", "NAS100", "USTEC"],
    "NAS100": ["NAS100", "US100Cash", "US100", "USTEC"],
    "GER40": ["GER40Cash", "GER40", "DE40", "DAX40"],
}

mapping = {}
missing = []
for sym in harness:
    sym_u = sym.upper()
    picks = aliases.get(sym_u, [sym_u])
    hit = None
    for p in picks:
        if p.upper() in available:
            hit = available[p.upper()]
            break
    if hit:
        mapping[sym_u] = hit
    else:
        missing.append(sym_u)

mt5.shutdown()
print(json.dumps({"mapping": mapping, "missing": missing, "available_sample": sorted(available.keys())[:30]}, ensure_ascii=False))
'@

$tmp = Join-Path $env:TEMP "discover_mt5_symbols.py"
Set-Content -Path $tmp -Value $script -Encoding UTF8
$out = & $python $tmp (ConvertTo-Json $HarnessSymbols -Compress) (ConvertTo-Json $Candidates -Compress)
$data = $out | ConvertFrom-Json

Write-Host "=== Simbolos MT5 disponiveis (amostra) ===" -ForegroundColor Cyan
$data.available_sample | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "=== Mapeamento sugerido (MT5_SYMBOLS) ===" -ForegroundColor Green
$parts = @()
foreach ($k in ($data.mapping.PSObject.Properties | Sort-Object Name)) {
    $parts += "$($k.Name):$($k.Value)"
    Write-Host "  $($k.Name) -> $($k.Value)"
}
$line = "MT5_SYMBOLS=" + ($parts -join ",")
Write-Host ""
Write-Host $line -ForegroundColor Yellow

if ($data.missing.Count -gt 0) {
    Write-Host ""
    Write-Host "Sem correspondencia no broker:" -ForegroundColor Red
    $data.missing | ForEach-Object { Write-Host "  $_" }
}

if (Test-Path $envFile) {
    Write-Host ""
    Write-Host "Para aplicar no .env e reiniciar provider:" -ForegroundColor Cyan
    Write-Host "  Edite $envFile" -ForegroundColor Gray
    Write-Host "  .\scripts\watchdog-mt5.ps1" -ForegroundColor Gray
}
Remove-Item $tmp -Force -ErrorAction SilentlyContinue