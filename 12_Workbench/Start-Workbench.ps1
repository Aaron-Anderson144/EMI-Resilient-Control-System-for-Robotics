param(
    [ValidateRange(1024,65535)][int]$Port = 8765,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$workbenchRoot = $PSScriptRoot
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $workbenchRoot '..')).Path
$localFolder = Join-Path $workbenchRoot 'local'
$endpointFile = Join-Path $localFolder 'endpoint.json'
if (-not $PSBoundParameters.ContainsKey('Port') -and (Test-Path -LiteralPath $endpointFile)) {
    try {
        $savedEndpoint = Get-Content -LiteralPath $endpointFile -Raw | ConvertFrom-Json
        $savedPort = 0
        if ([int]::TryParse([string]$savedEndpoint.port, [ref]$savedPort) -and $savedPort -ge 1024 -and $savedPort -le 65535) {
            $Port = $savedPort
        }
    } catch { }
}
$workbenchUrl = "http://127.0.0.1:$Port"

function Get-WorkbenchState {
    try { return Invoke-RestMethod -Uri "$workbenchUrl/api/state" -TimeoutSec 2 }
    catch { return $null }
}

$existingState = Get-WorkbenchState
if ($existingState) {
    if ($existingState.project.root -and
        [IO.Path]::GetFullPath($existingState.project.root).TrimEnd('\','/') -eq $projectRoot.TrimEnd('\','/')) {
        if (-not $NoBrowser) { Start-Process $workbenchUrl }
        Write-Output "EMI Robotics workbench is ready: $workbenchUrl"
        exit 0
    }
    throw "Port $Port is already serving another project. Start with -Port and a different port."
}

$pythonCandidates = @()
if ($env:EMI_PYTHON) { $pythonCandidates += $env:EMI_PYTHON }
$pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
if ($pythonCommand -and $pythonCommand.Source -notlike '*\Microsoft\WindowsApps\*') {
    $pythonCandidates += $pythonCommand.Source
}
$pythonCandidates += (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
$pythonCandidates += (Join-Path $env:LOCALAPPDATA 'Programs/Python/Python313/python.exe')
$pythonCandidates += (Join-Path $env:LOCALAPPDATA 'Programs/Python/Python312/python.exe')
$pythonExecutable = $null
foreach ($candidatePython in ($pythonCandidates | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $candidatePython -PathType Leaf)) { continue }
    try {
        & $candidatePython -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>$null
        if ($LASTEXITCODE -eq 0) { $pythonExecutable = $candidatePython; break }
    } catch { }
}
if (-not $pythonExecutable) {
    throw 'Python 3.10 or newer is needed. Set EMI_PYTHON to its python.exe path and start again.'
}

New-Item -ItemType Directory -Path $localFolder -Force | Out-Null
$serverScript = Join-Path $workbenchRoot 'server.py'
$serverArguments = @(('"{0}"' -f $serverScript), '--port', "$Port", '--no-browser')
$serverProcess = Start-Process -FilePath $pythonExecutable -ArgumentList $serverArguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $localFolder 'server.stdout.log') -RedirectStandardError (Join-Path $localFolder 'server.stderr.log')
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Milliseconds 500
    $readyState = Get-WorkbenchState
    if ($readyState -and $readyState.project.root -and
        [IO.Path]::GetFullPath($readyState.project.root).TrimEnd('\','/') -eq $projectRoot.TrimEnd('\','/')) {
        @{port=$Port} | ConvertTo-Json | Set-Content -LiteralPath $endpointFile -Encoding utf8
        if (-not $NoBrowser) { Start-Process $workbenchUrl }
        Write-Output "EMI Robotics workbench is ready: $workbenchUrl"
        exit 0
    }
    $serverProcess.Refresh()
    if ($serverProcess.HasExited) { break }
}
throw "The workbench could not start. See $localFolder\server.stderr.log. Another application may be using port $Port."
