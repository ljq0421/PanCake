$ErrorActionPreference = 'Stop'
$godot = 'D:\Godot\Godot_v4.7.1-stable_win64_console.exe'
$project = Split-Path -Parent $PSScriptRoot
$sandboxData = Join-Path $project '.godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $sandboxData 'Roaming'), (Join-Path $sandboxData 'Local') | Out-Null
$env:APPDATA = Join-Path $sandboxData 'Roaming'
$env:LOCALAPPDATA = Join-Path $sandboxData 'Local'
$logFile = Join-Path $env:TEMP ("projectcake-ingredient-stock-visual-{0}.log" -f [Guid]::NewGuid().ToString('N'))
& $godot --path $project --log-file $logFile -s res://tests/integration/ingredient_stock_visual_smoke.gd
exit $LASTEXITCODE
