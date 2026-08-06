$ErrorActionPreference = 'Stop'
$godot = 'D:\Godot\Godot_v4.7.1-stable_win64_console.exe'
$project = Split-Path -Parent $PSScriptRoot
$sandboxData = Join-Path $project '.godot-user'
New-Item -ItemType Directory -Force -Path (Join-Path $sandboxData 'Roaming'), (Join-Path $sandboxData 'Local') | Out-Null
$env:APPDATA = Join-Path $sandboxData 'Roaming'
$env:LOCALAPPDATA = Join-Path $sandboxData 'Local'

$checks = @(
    'res://tests/unit/five_area_restock_self_check.gd',
	'res://tests/integration/workstation_hold_refill_self_check.gd'
)

foreach ($check in $checks) {
    Write-Host "Running $check"
    $logFile = Join-Path $env:TEMP ("projectcake-workstation-expansion-{0}.log" -f [Guid]::NewGuid().ToString('N'))
    & $godot --headless --path $project --log-file $logFile -s $check
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Godot log: $logFile"
        exit $LASTEXITCODE
    }
}

Write-Host 'All Project Cake formal restock checks passed.'
