$ErrorActionPreference = 'Stop'
$godot = 'D:\Godot\Godot_v4.7.1-stable_win64_console.exe'
$project = Split-Path -Parent $PSScriptRoot
$sandboxData = Join-Path $project '.godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $sandboxData 'Roaming'), (Join-Path $sandboxData 'Local') | Out-Null
$env:APPDATA = Join-Path $sandboxData 'Roaming'
$env:LOCALAPPDATA = Join-Path $sandboxData 'Local'
$checks = @(
	'res://tests/integration/start_menu_self_check.gd',
	'res://tests/integration/ui_color_style_self_check.gd',
	'res://tests/unit/game_session_progression_self_check.gd',
	'res://tests/unit/ingredient_stock_self_check.gd',
	'res://tests/unit/payment_coin_model_self_check.gd',
	'res://tests/unit/five_area_restock_self_check.gd',
	'res://tests/unit/five_area_catalog_self_check.gd',
	'res://tests/unit/five_area_progression_service_self_check.gd',
	'res://tests/unit/five_area_game_session_store_self_check.gd',
	'res://tests/unit/five_area_order_service_self_check.gd',
	'res://tests/unit/five_area_playable_order_self_check.gd',
	'res://tests/unit/packaged_drink_heater_self_check.gd',
	'res://tests/unit/youtiao_fryer_self_check.gd',
	'res://tests/unit/f3_progression_path_self_check.gd',
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
	'res://tests/integration/f3_production_order_self_check.gd',
	'res://tests/integration/f3_station_scene_self_check.gd',
	'res://tests/integration/five_area_growth_ui_self_check.gd',
	'res://tests/integration/three_playable_area_order_loop_self_check.gd',
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
