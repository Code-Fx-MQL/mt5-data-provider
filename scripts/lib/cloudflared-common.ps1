function Get-CloudflaredPath {
    param([string]$ProjectRoot)
    $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if ($ProjectRoot) {
        $localBin = Join-Path $ProjectRoot "tools\cloudflared.exe"
        if (Test-Path $localBin) { return $localBin }
    }
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

function Repair-CloudflaredConfig {
    param(
        [string]$ConfigPath = (Join-Path $env:USERPROFILE ".cloudflared\config.yml")
    )
    if (-not (Test-Path $ConfigPath)) { return $false }
    $cfHome = Join-Path $env:USERPROFILE ".cloudflared"
    $lines = Get-Content $ConfigPath
    $changed = $false
    $tunnelId = ""
    $newLines = foreach ($line in $lines) {
        if ($line -match "^tunnel:\s*(.+)$") {
            $tunnelId = $matches[1].Trim()
            $line
        } elseif ($line -match "^credentials-file:\s*(.+)$") {
            $old = $matches[1].Trim()
            $fileName = Split-Path $old -Leaf
            if (-not $fileName) { $fileName = "$tunnelId.json" }
            $expected = Join-Path $cfHome $fileName
            if ($old -ne $expected) {
                $changed = $true
                "credentials-file: $expected"
            } else {
                $line
            }
        } else {
            $line
        }
    }
    if ($changed) {
        Set-Content -Path $ConfigPath -Value $newLines -Encoding UTF8
    }
    return $changed
}

function Get-CloudflaredTunnelMeta {
    param(
        [string]$ConfigPath = (Join-Path $env:USERPROFILE ".cloudflared\config.yml")
    )
    $meta = @{
        TunnelId = ""
        CredentialsFile = ""
        PublicHostname = "mt5.fullscopetrade.com"
        LocalPort = 8000
    }
    if (-not (Test-Path $ConfigPath)) { return $meta }
    foreach ($line in Get-Content $ConfigPath) {
        if ($line -match "^tunnel:\s*(.+)$") {
            $meta.TunnelId = $matches[1].Trim()
        } elseif ($line -match "^credentials-file:\s*(.+)$") {
            $meta.CredentialsFile = $matches[1].Trim()
        } elseif ($line -match "hostname:\s*(\S+)") {
            $meta.PublicHostname = $matches[1].Trim()
        } elseif ($line -match "service:\s*http://[^:]+:(\d+)") {
            $meta.LocalPort = [int]$matches[1]
        }
    }
    return $meta
}

function Test-ProviderListening {
    param([int]$Port = 8000)
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    return ($null -ne $conn)
}

function Start-CloudflaredTunnel {
    param(
        [string]$CloudflaredPath,
        [string]$ConfigPath,
        [string]$TunnelId,
        [string]$LogFile
    )
    $argList = @(
        "tunnel",
        "--config", $ConfigPath,
        "--logfile", $LogFile,
        "run",
        $TunnelId
    )
    return Start-Process -FilePath $CloudflaredPath -ArgumentList $argList -WindowStyle Hidden -PassThru
}

function Get-CloudflaredLogTail {
    param(
        [string]$LogFile,
        [int]$Lines = 8
    )
    if (-not (Test-Path $LogFile)) { return @() }
    return @(Get-Content $LogFile -Tail $Lines -ErrorAction SilentlyContinue)
}