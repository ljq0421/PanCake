param([string[]]$Shots = @('tianjin', 'rush', 'wuhan', 'pages'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$work = Join-Path $root 'output/steam-trailer-zh/work'
New-Item -ItemType Directory -Force $work | Out-Null
$previous = $env:APPDATA
try {
    $env:APPDATA = Join-Path $work 'userdata'
    foreach ($shot in $Shots) {
        if ($shot -notin @('tianjin', 'rush', 'wuhan', 'pages', 'journey', 'journey64')) { throw 'Unknown shot' }
        $arguments = "--path . --log-file output/steam-trailer-zh/work/$shot.log --write-movie output/steam-trailer-zh/work/$shot.avi --fixed-fps 30 --disable-vsync res://Scenes/Tests/SteamTrailerCapture.tscn -- --demo-pilot --shot=$shot"
        $p = Start-Process 'D:/Godot/GodotSharp/Godot_v4.7.1-stable_mono_win64_console.exe' -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput "$work/$shot-console.log" -RedirectStandardError "$work/$shot-errors.log"
        $p.WaitForExit()
        if ($p.ExitCode -ne 0 -or !(Select-String -Path "$work/$shot-console.log" -SimpleMatch "TRAILER_CAPTURE_OK $shot" -Quiet)) {
            Get-Content "$work/$shot-errors.log" -TotalCount 8
            throw "Capture failed: $shot"
        }
        Write-Output "CAPTURE_OK $shot"
    }
} finally { $env:APPDATA = $previous }
