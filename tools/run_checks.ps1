$ErrorActionPreference = 'Stop'
$godot = 'D:\Godot\Godot_v4.7.1-stable_win64_console.exe'
$project = Split-Path -Parent $PSScriptRoot
$sandboxData = Join-Path $project '.godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $sandboxData 'Roaming'), (Join-Path $sandboxData 'Local') | Out-Null
$env:APPDATA = Join-Path $sandboxData 'Roaming'
$env:LOCALAPPDATA = Join-Path $sandboxData 'Local'
$checks = @(
	'res://tests/integration/start_menu_self_check.gd',
	'res://tests/unit/game_session_progression_self_check.gd',
	'res://tests/integration/daily_growth_self_check.gd',
	'res://tests/integration/ingredient_unlock_self_check.gd',
	'res://tests/integration/tool_equipment_effect_self_check.gd',
	'res://tests/integration/stall_upgrade_self_check.gd',
	'res://tests/unit/ingredient_stock_self_check.gd',
	'res://tests/unit/payment_coin_model_self_check.gd',
	'res://tests/unit/progression_refill_self_check.gd',
    'res://tests/unit/pancake_model_self_check.gd',
    'res://tests/unit/p0_2_simulation_self_check.gd',
    'res://tests/unit/p0_4_sauce_self_check.gd',
    'res://tests/unit/p0_5_fold_self_check.gd',
    'res://tests/unit/p1_vertical_slice_self_check.gd',
    'res://tests/integration/p0_2_interaction_self_check.gd',
    'res://tests/integration/p0_3_renderer_self_check.gd',
    'res://tests/integration/p0_4_interaction_self_check.gd',
    'res://tests/integration/p0_5_interaction_self_check.gd',
	'res://tests/integration/p1_audio_self_check.gd',
	'res://tests/integration/ingredient_stock_interaction_self_check.gd',
	'res://tests/integration/initial_unlock_workstation_self_check.gd',
	'res://tests/integration/workstation_hold_refill_self_check.gd',
	'res://tests/integration/result_panel_layout_self_check.gd',
    'res://tests/integration/p1_interaction_self_check.gd',
    'res://tests/integration/m0_self_check.gd'
)

foreach ($check in $checks) {
    Write-Host "Running $check"
    $logFile = Join-Path $env:TEMP ("projectcake-check-{0}.log" -f [Guid]::NewGuid().ToString('N'))
    & $godot --headless --path $project --log-file $logFile -s $check
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Godot log: $logFile"
        exit $LASTEXITCODE
    }
}

Write-Host 'All Project Cake checks passed.'
