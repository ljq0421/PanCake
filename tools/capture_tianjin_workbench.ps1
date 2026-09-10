param(
    [string]$Godot = 'D:/Godot/GodotSharp/Godot_v4.7.1-stable_mono_win64_console.exe',
    [string]$OutputName = 'tianjin-workbench-v1'
)
$ErrorActionPreference = 'Stop'
if ($OutputName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'OutputName must be a single directory name.' }
$projectRoot = Split-Path $PSScriptRoot -Parent
$previousAppData = $env:APPDATA
Push-Location $projectRoot
try {
    $outputDir = Join-Path $projectRoot ".tmp/$OutputName"
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    $cases = @(
        @{Name='A-basic'; Flags='--capture-day15 --capture-workbench-level=1 --capture-customers=2'},
        @{Name='B-mid'; Flags='--capture-day15 --capture-workbench-level=2 --capture-customers=3 --capture-mixed-stock --capture-trained'},
        @{Name='C-pressure'; Flags='--capture-day15 --capture-workbench-level=3 --capture-mixed-stock --capture-trained --capture-coins --capture-bagged'},
        @{Name='720'; Flags='--capture-day15 --capture-workbench-level=3 --capture-mixed-stock --capture-trained --capture-720'},
        @{Name='empty'; Flags='--capture-day15 --capture-workbench-level=3 --capture-stock=0 --capture-trained'},
        @{Name='refill'; Flags='--capture-day11 --capture-workbench-level=2 --capture-refilling --capture-trained'},
        @{Name='pancake-lv1'; Flags='--capture-day9 --capture-workbench-level=1 --capture-pancake-ready --capture-trained'},
        @{Name='pancake-lv2'; Flags='--capture-day9 --capture-workbench-level=2 --capture-sauce-ready --capture-trained'},
        @{Name='frying'; Flags='--capture-fryer-workstation --capture-fryer-level3 --capture-workbench-level=3 --capture-trained'},
        @{Name='pause'; Flags='--capture-day11 --capture-workbench-level=3 --capture-pause --capture-trained'}
    )
    foreach ($case in $cases) {
        # A fresh per-image profile prevents tutorial state leaking between fixtures.
        $env:APPDATA = Join-Path $outputDir "userdata/$($case.Name)-$([Guid]::NewGuid().ToString('N'))"
        $stem = ".tmp/$OutputName/final-$($case.Name)"
        $captureArgs = "--path . --log-file $stem.log res://Scenes/Tests/VisualCapture.tscn -- $($case.Flags) --capture-output=res://$stem.png"
        $process = Start-Process -FilePath $Godot -ArgumentList $captureArgs -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit(30000)) { throw "Capture timed out (PID $($process.Id)): $($case.Name)" }
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath "$stem.png")) { throw "Capture failed: $($case.Name)" }
        Write-Output "$stem.png"
    }
}
finally {
    $env:APPDATA = $previousAppData
    Pop-Location
}
