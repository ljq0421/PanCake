$ErrorActionPreference = 'Stop'
$godot = 'D:\Godot\Godot_v4.7.1-stable_win64_console.exe'
$project = Split-Path -Parent $PSScriptRoot
$sandboxData = Join-Path $project '.godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $sandboxData 'Roaming'), (Join-Path $sandboxData 'Local') | Out-Null
$env:APPDATA = Join-Path $sandboxData 'Roaming'
$env:LOCALAPPDATA = Join-Path $sandboxData 'Local'

$headlessChecks = @(
	'res://tests/unit/five_area_catalog_self_check.gd',
	'res://tests/unit/five_area_progression_service_self_check.gd',
	'res://tests/unit/five_area_game_session_store_self_check.gd',
	'res://tests/unit/five_area_order_service_self_check.gd',
	'res://tests/unit/five_area_playable_order_self_check.gd',
	'res://tests/unit/youtiao_fryer_self_check.gd',
	'res://tests/integration/five_area_growth_ui_self_check.gd',
	'res://tests/integration/three_playable_area_order_loop_self_check.gd',
	'res://tests/integration/five_area_formal_scene_self_check.gd'
)

foreach ($check in $headlessChecks) {
	Write-Host "Running $check"
	$logFile = Join-Path $env:TEMP ("projectcake-f3-{0}.log" -f [Guid]::NewGuid().ToString('N'))
	& $godot --headless --path $project --log-file $logFile -s $check
	if ($LASTEXITCODE -ne 0) {
		Write-Host "Godot log: $logFile"
		exit $LASTEXITCODE
	}
}

$pointerChecks = @(
	'res://tests/integration/direct_soy_gpu_pointer_smoke.gd'
)
foreach ($pointerCheck in $pointerChecks) {
	$pointerLog = Join-Path $env:TEMP ("projectcake-f3-pointer-{0}.log" -f [Guid]::NewGuid().ToString('N'))
	Write-Host "Running $pointerCheck with GPU and real pointer input"
	& $godot --path $project --log-file $pointerLog -s $pointerCheck
	if ($LASTEXITCODE -ne 0) {
		Write-Host "Godot log: $pointerLog"
		exit $LASTEXITCODE
	}
}

Write-Host 'All Project Cake F3 checks passed.'
