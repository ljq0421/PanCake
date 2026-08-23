$ErrorActionPreference = 'Stop'
$godot = 'D:\Godot\Godot_v4.7.1-stable_win64.exe'
$project = Split-Path -Parent $PSScriptRoot
$testData = Join-Path $project '.godot-user-no-spreader-visual'

if (-not (Test-Path -LiteralPath $godot)) {
	throw "Godot executable not found: $godot"
}

New-Item -ItemType Directory -Force -Path (Join-Path $testData 'Roaming'), (Join-Path $testData 'Local') | Out-Null
$env:APPDATA = Join-Path $testData 'Roaming'
$env:LOCALAPPDATA = Join-Path $testData 'Local'

Write-Host 'Starting Project Cake without the spreader artwork or custom cursor ring.'
Write-Host 'Spreading simulation and pancake rendering remain enabled. Test save data is isolated from your normal save.'
Write-Host 'Close the game window to finish the test.'
& $godot --path $project -- --disable-spreader-visual
exit $LASTEXITCODE
