param(
    [string]$Godot = 'D:/Godot/GodotSharp/Godot_v4.7.1-stable_mono_win64_console.exe',
    [string[]]$Only = @()
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
Push-Location $projectRoot
try {
    $outputDir = 'output/tianjin-stage-workbench'
    New-Item -ItemType Directory -Force -Path $outputDir, '.tmp/tianjin-stages/userdata' | Out-Null
    $env:APPDATA = (Resolve-Path '.tmp/tianjin-stages/userdata').Path
    $env:LOCALAPPDATA = $env:APPDATA
    $cases = @(
        @{Name='day01'; Flags='--capture-tianjin-day=1 --capture-workbench-level=1'},
        @{Name='day04'; Flags='--capture-tianjin-day=4 --capture-workbench-level=2 --capture-trained'},
        @{Name='day05'; Flags='--capture-tianjin-day=5 --capture-workbench-level=1'},
        @{Name='day08-frying'; Flags='--capture-tianjin-day=8 --capture-fryer-workstation --capture-workbench-level=2 --capture-trained'},
        @{Name='day09'; Flags='--capture-tianjin-day=9 --capture-workbench-level=1 --capture-trained'},
        @{Name='day15-bagged'; Flags='--capture-tianjin-day=15 --capture-workbench-level=3 --capture-trained --capture-bagged --capture-coins'},
        @{Name='day15-720'; Flags='--capture-tianjin-day=15 --capture-workbench-level=3 --capture-trained --capture-720 --capture-pancake-ready'},
        @{Name='empty'; Flags='--capture-tianjin-day=15 --capture-workbench-level=3 --capture-trained --capture-stock=0'},
        @{Name='refill'; Flags='--capture-tianjin-day=9 --capture-workbench-level=2 --capture-trained --capture-refilling'}
    )
    foreach ($case in $cases) {
        if ($Only.Count -gt 0 -and $case.Name -notin $Only) { continue }
        $stem = "$outputDir/$($case.Name)"
        $captureArgs = "--path . --log-file .tmp/tianjin-stages/$($case.Name).log res://Scenes/Tests/VisualCapture.tscn -- $($case.Flags) --capture-output=res://$stem.png"
        $process = Start-Process -FilePath $Godot -ArgumentList $captureArgs -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit(30000)) { throw "Capture timed out (PID $($process.Id)): $($case.Name)" }
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath "$stem.png")) { throw "Capture failed: $($case.Name)" }
        Write-Output "$stem.png"
    }
}
finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    Pop-Location
}
