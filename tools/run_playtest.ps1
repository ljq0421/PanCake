param(
    [string]$SessionName = "manual",
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$safeSessionName = ($SessionName -replace '[^A-Za-z0-9_-]', '_').Trim('_')
if ([string]::IsNullOrWhiteSpace($safeSessionName)) {
    $safeSessionName = "manual"
}
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resultDirectory = Join-Path $projectRoot "playtest-results\$timestamp-$safeSessionName"
$profileDirectory = Join-Path $projectRoot "playtest-profiles\$safeSessionName"
New-Item -ItemType Directory -Force -Path $resultDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $profileDirectory | Out-Null

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = & (Join-Path $PSScriptRoot "resolve_godot.ps1")
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = $profileDirectory
$env:LOCALAPPDATA = $profileDirectory
try {
    & $GodotPath `
        --path $projectRoot `
        --log-file (Join-Path $resultDirectory "godot.log") `
        -- `
        --playtest-telemetry `
        "--playtest-output=$resultDirectory" `
        "--playtest-session=$safeSessionName"
    $gameExitCode = $LASTEXITCODE
}
finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($null -ne $pythonCommand -and (Test-Path -LiteralPath (Join-Path $resultDirectory "events.jsonl"))) {
    & $pythonCommand.Source (Join-Path $PSScriptRoot "summarize_playtest.py") $resultDirectory
}
else {
    Write-Warning "Python was unavailable; events.jsonl and summary.json were still exported."
}

Write-Output "Playtest results: $resultDirectory"
exit $gameExitCode
