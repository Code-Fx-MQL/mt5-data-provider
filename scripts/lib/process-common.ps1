function Start-HiddenPowerShellScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [string[]]$ScriptArgs = @(),
        [switch]$Wait
    )
    $argList = @(
        "-NoProfile",
        "-NonInteractive",
        "-WindowStyle", "Hidden",
        "-ExecutionPolicy", "Bypass",
        "-File", $ScriptPath
    ) + $ScriptArgs
    $params = @{
        FilePath = "powershell.exe"
        ArgumentList = $argList
        WindowStyle = "Hidden"
    }
    if ($Wait) {
        $params["Wait"] = $true
        Start-Process @params | Out-Null
    } else {
        Start-Process @params | Out-Null
    }
}