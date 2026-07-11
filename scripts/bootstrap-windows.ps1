# Bootstrap completo - nova maquina Windows (deps + venv + migracao + tarefas + arranque)
param(
    [string]$MigrationZip = "",
    [string]$ProjectRoot = "",
    [string]$RepoUrl = "https://github.com/Code-Fx-MQL/mt5-data-provider.git",
    [string]$InstallDir = "C:\MT5\mt5-data-provider",
    [switch]$SkipClone,
    [switch]$SkipCloudflare,
    [switch]$SkipTasks,
    [switch]$InstallDeps,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"
$scriptsDir = $PSScriptRoot

function Find-Mt5Terminal {
    $candidates = @()
    $roots = @("C:\MT5\Instances", "C:\Program Files", "C:\Program Files (x86)")
    foreach ($r in $roots) {
        if (-not (Test-Path $r)) { continue }
        Get-ChildItem $r -Filter "terminal64.exe" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $candidates += $_.FullName
        }
    }
    return $candidates | Select-Object -Unique
}

function Update-EnvKey([string]$EnvPath, [string]$Key, [string]$Value) {
    $lines = if (Test-Path $EnvPath) { Get-Content $EnvPath } else { @() }
    $pattern = "^$([regex]::Escape($Key))="
    $found = $false
    $out = foreach ($line in $lines) {
        if ($line -match $pattern) {
            $found = $true
            "$Key=$Value"
        } else { $line }
    }
    if (-not $found) { $out += "$Key=$Value" }
    $out | Set-Content $EnvPath -Encoding UTF8
}

Write-Host ""
Write-Host "=== MT5 Data Provider - Bootstrap Windows ===" -ForegroundColor Cyan
Write-Host ""

# 1) Projeto
if (-not $SkipClone -and -not $ProjectRoot) {
    if (-not (Test-Path $InstallDir)) {
        Write-Host "A clonar repositorio em $InstallDir ..." -ForegroundColor Yellow
        $parent = Split-Path $InstallDir -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        git clone $RepoUrl $InstallDir
    } else {
        Write-Host "Diretorio ja existe: $InstallDir" -ForegroundColor Gray
    }
    $ProjectRoot = $InstallDir
}
if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path $scriptsDir -Parent
}
Set-Location $ProjectRoot
Write-Host "Projeto: $ProjectRoot" -ForegroundColor Green

# 2) Dependencias
$depArgs = @("-File", (Join-Path $scriptsDir "check-dependencies.ps1"))
if ($InstallDeps) { $depArgs += "-InstallMissing" }
& powershell @depArgs
if ($LASTEXITCODE -ne 0 -and -not $InstallDeps) {
    Write-Host "AVISO: Algumas dependencias em falta. A continuar com -InstallDeps recomendado." -ForegroundColor Yellow
}

# 3) Migracao
if ($MigrationZip) {
    & powershell -File (Join-Path $scriptsDir "migrate-import.ps1") -MigrationZip $MigrationZip -ProjectRoot $ProjectRoot
} elseif (-not (Test-Path (Join-Path $ProjectRoot ".env"))) {
    Copy-Item (Join-Path $ProjectRoot ".env.example") (Join-Path $ProjectRoot ".env")
    Write-Host "Criado .env a partir de .env.example - edite antes de producao." -ForegroundColor Yellow
}

$envPath = Join-Path $ProjectRoot ".env"

# 4) Auto-detectar MT5_PATH se vazio
$mt5Terminals = @(Find-Mt5Terminal)
if ($mt5Terminals.Count -gt 0) {
    $currentPath = ""
    Get-Content $envPath -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_ -match "^MT5_PATH=(.+)$") { $currentPath = $matches[1].Trim('"') }
    }
    if (-not $currentPath -or -not (Test-Path $currentPath)) {
        $chosen = $mt5Terminals[0]
        if (-not $NonInteractive -and $mt5Terminals.Count -gt 1) {
            Write-Host "Terminais MT5 encontrados:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $mt5Terminals.Count; $i++) {
                Write-Host "  [$i] $($mt5Terminals[$i])"
            }
            $idx = Read-Host "Escolha indice (Enter=0)"
            if ($idx -match "^\d+$" -and [int]$idx -lt $mt5Terminals.Count) { $chosen = $mt5Terminals[[int]$idx] }
        }
        Update-EnvKey $envPath "MT5_PATH" "`"$chosen`""
        Write-Host "MT5_PATH definido: $chosen" -ForegroundColor Green
    }
}

# 5) Producao defaults no .env
foreach ($pair in @(
    @("MT5_PROVIDER_MODE", "live"),
    @("MT5_HOST", "127.0.0.1"),
    @("MT5_PORT", "8000"),
    @("MT5_DOCS_ENABLED", "false"),
    @("MT5_DEBUG_ERRORS", "false"),
    @("MT5_EXPOSE_INTERNAL", "false")
)) {
    $key, $val = $pair
    $hasKey = Select-String -Path $envPath -Pattern "^$key=" -Quiet
    if (-not $hasKey) { Update-EnvKey $envPath $key $val }
}

# 6) Python venv + pacote
$venvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Host "A criar venv..." -ForegroundColor Yellow
    python -m venv (Join-Path $ProjectRoot ".venv")
}
$pip = Join-Path $ProjectRoot ".venv\Scripts\pip.exe"
& $pip install -e ".[mt5,dev]" -q
Write-Host "Pacote instalado: mt5-data-provider[mt5,dev]" -ForegroundColor Green

# 7) Testes rapidos
& $venvPython -m pytest -q --tb=no -x 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Testes unitarios: OK" -ForegroundColor Green
} else {
    Write-Host "Testes unitarios: falha (verifique manualmente)" -ForegroundColor Yellow
}

# 8) Tarefas agendadas
if (-not $SkipTasks) {
    & powershell -File (Join-Path $scriptsDir "install-all-tasks.ps1")
}

# 9) Cloudflare (se config importada)
if (-not $SkipCloudflare) {
    $cfConfig = Join-Path $env:USERPROFILE ".cloudflared\config.yml"
    if (Test-Path $cfConfig) {
        Write-Host "Config Cloudflare encontrada - watchdog de tunel ativo via tarefa." -ForegroundColor Green
    } else {
        Write-Host "Sem config Cloudflare - execute install-cloudflare-tunnel.ps1 se precisar de URL publica." -ForegroundColor Yellow
    }
}

# 10) Arranque inicial
Write-Host ""
Write-Host "A iniciar stack (watchdog MT5)..." -ForegroundColor Cyan
& powershell -File (Join-Path $scriptsDir "watchdog-mt5.ps1")
$mt5Ok = $LASTEXITCODE -eq 0

if (-not $SkipCloudflare -and (Test-Path (Join-Path $env:USERPROFILE ".cloudflared\config.yml"))) {
    & powershell -File (Join-Path $scriptsDir "watchdog-cloudflare.ps1")
}

Write-Host ""
Write-Host "=== Bootstrap concluido ===" -ForegroundColor Cyan
Write-Host "Projeto:     $ProjectRoot"
Write-Host "Provider:    http://127.0.0.1:8000/health"
Write-Host "Logs:        $ProjectRoot\logs\"
Write-Host ""
Write-Host "Verificar:" -ForegroundColor Yellow
Write-Host "  .\scripts\watchdog-mt5.ps1 -StatusOnly"
Write-Host "  .\scripts\watchdog-cloudflare.ps1 -StatusOnly"
Write-Host ""
if (-not $mt5Ok) {
    Write-Host "AVISO: Provider/terminal pode precisar de login manual no MT5." -ForegroundColor Yellow
    exit 1
}
exit 0