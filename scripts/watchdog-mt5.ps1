# Watchdog MT5 + Data Provider — monitora e recupera automaticamente
# Uso:
#   .\scripts\watchdog-mt5.ps1              # uma verificacao
#   .\scripts\watchdog-mt5.ps1 -Loop         # loop continuo (60s)
#   .\scripts\watchdog-mt5.ps1 -DryRun       # so reporta, nao reinicia

param(
    [int]$IntervalSeconds = 60,
    [switch]$Loop,
    [switch]$DryRun,
    [switch]$StatusOnly,
    [string]$EnvFile = ""
)

$ErrorActionPreference = "Continue"
$root = Split-Path $PSScriptRoot -Parent
if (-not $EnvFile) { $EnvFile = Join-Path $root ".env" }
$logDir = Join-Path $root "logs"
$logFile = Join-Path $logDir "watchdog.log"
$python = Join-Path $root ".venv\Scripts\python.exe"

function Write-Log([string]$Message, [string]$Level = "INFO") {
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $line = "{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}" -f (Get-Date), $Level, $Message
    Add-Content -Path $logFile -Value $line -Encoding UTF8
    if ($Level -eq "ERROR") { Write-Host $line -ForegroundColor Red }
    elseif ($Level -eq "WARN") { Write-Host $line -ForegroundColor Yellow }
    else { Write-Host $line -ForegroundColor Cyan }
}

function Read-DotEnv([string]$Path) {
    $map = @{}
    if (-not (Test-Path $Path)) { return $map }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { return }
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()
        if ($val.StartsWith('"') -and $val.EndsWith('"')) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        $map[$key] = $val
    }
    return $map
}

function Test-TerminalRunning([string]$TerminalPath) {
    if (-not $TerminalPath) {
        $p = Get-Process -Name "terminal64" -ErrorAction SilentlyContinue
        return ($null -ne $p -and $p.Count -gt 0)
    }
    $norm = $TerminalPath.ToLower()
    $procs = Get-Process -Name "terminal64" -ErrorAction SilentlyContinue
    foreach ($proc in $procs) {
        if ($proc.Path -and $proc.Path.ToLower() -eq $norm) { return $true }
    }
    return $false
}

function Start-Terminal([string]$TerminalPath) {
    if (-not (Test-Path $TerminalPath)) {
        Write-Log "MT5_PATH invalido: $TerminalPath" "ERROR"
        return $false
    }
    if ($DryRun) {
        Write-Log "[DryRun] Iniciaria terminal: $TerminalPath" "WARN"
        return $true
    }
    Start-Process -FilePath $TerminalPath -WindowStyle Minimized | Out-Null
    Write-Log "Terminal MT5 iniciado: $TerminalPath"
    Start-Sleep -Seconds 20
    return (Test-TerminalRunning $TerminalPath)
}

function Test-ProviderHealth([string]$BaseUrl, [int]$TimeoutSec = 5, [string]$ApiKey = "") {
    try {
        $r = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec $TimeoutSec
        $mode = "unknown"
        if ($ApiKey) {
            try {
                $st = Invoke-RestMethod -Uri "$BaseUrl/v1/status" -Headers @{"X-API-Key" = $ApiKey} -TimeoutSec $TimeoutSec
                $mode = $st.mode
            }
            catch {
                # /v1/status pode falhar no arranque; ticker confirma auth + live
                try {
                    $tk = Invoke-RestMethod -Uri "$BaseUrl/v1/ticker/GBPUSD" -Headers @{"X-API-Key" = $ApiKey} -TimeoutSec $TimeoutSec
                    if ($tk.source -eq "mt5") { $mode = "live" } else { $mode = "auth-fail" }
                }
                catch { $mode = "auth-fail" }
            }
        }
        return @{
            Ok = ($r.status -eq "ok")
            Mode = $mode
            Body = $r
        }
    }
    catch {
        return @{ Ok = $false; Mode = "offline"; Body = $null; Error = $_.Exception.Message }
    }
}

function Test-ProviderData([string]$BaseUrl, [string]$ApiKey, [string]$Symbol = "GBPUSD") {
    try {
        $headers = @{}
        if ($ApiKey) { $headers["X-API-Key"] = $ApiKey }
        $r = Invoke-RestMethod -Uri "$BaseUrl/v1/ticker/$Symbol" -Headers $headers -TimeoutSec 10
        return @{
            Ok = ($r.source -eq "mt5" -and $null -ne $r.bid)
            Symbol = $r.symbol
            Bid = $r.bid
        }
    }
    catch {
        return @{ Ok = $false; Error = $_.Exception.Message }
    }
}

function Get-ProviderPid() {
    $conn = Get-NetTCPConnection -LocalPort $script:Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($conn) { return $conn.OwningProcess }
    return $null
}

function Start-Provider([string]$Root, [string]$PythonExe) {
    if (-not (Test-Path $PythonExe)) {
        Write-Log "Python venv nao encontrado: $PythonExe" "ERROR"
        return $false
    }
    if ($DryRun) {
        Write-Log "[DryRun] Iniciaria mt5_provider.cli na porta $script:Port" "WARN"
        return $true
    }
    $existing = Get-ProviderPid
    if ($existing) {
        Write-Log "Provider ja escuta na porta $script:Port (PID $existing)" "WARN"
        return $true
    }
    Start-Process -FilePath $PythonExe `
        -ArgumentList "-m", "mt5_provider.cli" `
        -WorkingDirectory $Root `
        -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 4
    $health = Test-ProviderHealth $script:BaseUrl 5 $script:ApiKey
    if ($health.Ok) {
        Write-Log "Provider reiniciado - mode=$($health.Mode)"
        return $true
    }
    Write-Log "Provider nao respondeu apos arranque: $($health.Error)" "ERROR"
    return $false
}

function Restart-ProviderIfHung() {
    $providerPid = Get-ProviderPid
    if (-not $providerPid) { return $false }
    $health = Test-ProviderHealth $script:BaseUrl 3 $script:ApiKey
    if ($health.Ok) { return $false }
    if ($DryRun) {
        Write-Log "[DryRun] Mataria provider hung PID $providerPid" "WARN"
        return $true
    }
    Stop-Process -Id $providerPid -Force -ErrorAction SilentlyContinue
    Write-Log "Provider hung (PID $providerPid) - terminado" "WARN"
    Start-Sleep -Seconds 2
    return $true
}

function Invoke-WatchdogOnce() {
    $env = Read-DotEnv $EnvFile
    $script:Port = if ($env["MT5_PORT"]) { [int]$env["MT5_PORT"] } else { 8000 }
    $script:BaseUrl = "http://127.0.0.1:$($script:Port)"
    $terminalPath = $env["MT5_PATH"]
    $script:ApiKey = ($env["MT5_API_KEYS"] -split "," | Select-Object -First 1) -replace "^[^:]+:", ""

    Write-Log "=== Watchdog check ==="

    # 1) Terminal MT5
    $terminalUp = Test-TerminalRunning $terminalPath
    if ($terminalUp) {
        Write-Log "MT5 terminal: OK"
    }
    else {
        Write-Log "MT5 terminal: OFFLINE" "WARN"
        if ($StatusOnly) {
            Write-Log "StatusOnly - terminal nao sera reiniciado" "WARN"
        }
        elseif ($terminalPath) {
            $terminalUp = Start-Terminal $terminalPath
        }
        else {
            Write-Log "MT5_PATH nao definido - nao consigo reiniciar terminal automaticamente" "ERROR"
        }
    }

    # 2) Provider API
    if (-not $StatusOnly) { Restart-ProviderIfHung | Out-Null }
    $health = Test-ProviderHealth $script:BaseUrl 5 $script:ApiKey
    if ($health.Ok -and $health.Mode -eq "live") {
        Write-Log "Provider API: OK (live)"
    }
    else {
        Write-Log "Provider API: $($health.Mode) - $($health.Error)" "WARN"
        if (-not $StatusOnly -and $terminalUp) {
            Start-Provider $root $python | Out-Null
            $health = Test-ProviderHealth $script:BaseUrl 5 $script:ApiKey
        }
    }

    # 3) Dados reais (ticker)
    if ($health.Ok) {
        $data = Test-ProviderData $script:BaseUrl $script:ApiKey
        if ($data.Ok) {
            Write-Log "Dados MT5: OK $($data.Symbol) bid=$($data.Bid)"
        }
        else {
            Write-Log "Dados MT5: FALHA - $($data.Error)" "ERROR"
            Write-Log "Verifique login no terminal e MT5_SYMBOLS no .env" "WARN"
        }
    }

    return @{
        Terminal = $terminalUp
        Provider = $health.Ok
        Mode = $health.Mode
    }
}

Write-Log "Watchdog MT5 iniciado (Loop=$Loop DryRun=$DryRun)"

if ($Loop) {
    while ($true) {
        Invoke-WatchdogOnce | Out-Null
        Start-Sleep -Seconds $IntervalSeconds
    }
}
else {
    $result = Invoke-WatchdogOnce
    if (-not $result.Terminal -or -not $result.Provider) { exit 1 }
    exit 0
}