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
    $outputDir = 'output/tianjin-art-review'
    New-Item -ItemType Directory -Force -Path $outputDir, '.tmp/tianjin-art-review/userdata' | Out-Null
    $env:APPDATA = (Resolve-Path '.tmp/tianjin-art-review/userdata').Path
    $env:LOCALAPPDATA = $env:APPDATA
    $cases = @()
    foreach ($page in 1..6) {
        $cases += @{ Name="portraits-$page"; Flags="--capture-customer-expressions-page=$page" }
    }
    foreach ($size in @(1080,720)) {
        $sizeFlag = if ($size -eq 720) { '--capture-720' } else { '' }
        foreach ($day in @(1,5,9,15)) {
            $cases += @{ Name="day$day-$size"; Flags="--capture-tianjin-day=$day --capture-trained --capture-five-customers --capture-workbench-level=3 $sizeFlag" }
        }
    }
    $cases += @(
        @{ Name='stock-low'; Flags='--capture-tianjin-day=15 --capture-trained --capture-stock=2' },
        @{ Name='stock-empty'; Flags='--capture-tianjin-day=15 --capture-trained --capture-stock=0' },
        @{ Name='refill'; Flags='--capture-tianjin-day=9 --capture-trained --capture-refilling' },
        @{ Name='frying'; Flags='--capture-tianjin-day=8 --capture-fryer-workstation --capture-trained' },
        @{ Name='quality'; Flags='--capture-youtiao-quality' },
        @{ Name='basket-raised'; Flags='--capture-tianjin-day=15 --capture-trained --capture-fryer-state=raised --capture-stored-youtiao=6' },
        @{ Name='mixed-order'; Flags='--capture-tianjin-day=15 --capture-trained --capture-bagged --capture-coins' }
    )
    foreach ($case in $cases) {
        if ($Only.Count -gt 0 -and $case.Name -notin $Only) { continue }
        $log = ".tmp/tianjin-art-review/$($case.Name).log"
        $arguments = "--path . --log-file $log res://Scenes/Tests/VisualCapture.tscn -- $($case.Flags) --capture-output=res://$outputDir/$($case.Name).png"
        $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit(30000)) { $process.Kill($true); throw "Capture timed out: $($case.Name)" }
        if ($process.ExitCode -ne 0 -or -not (Test-Path "$outputDir/$($case.Name).png")) { throw "Capture failed: $($case.Name)" }
        if (Select-String -Path $log -Pattern 'SHADER ERROR|SCRIPT ERROR|\[FAIL\]|System\..*Exception') { throw "Capture logged an error: $log" }
        Write-Output "$outputDir/$($case.Name).png"
    }
    $figures = Get-ChildItem $outputDir -Filter '*.png' | Sort-Object Name | ForEach-Object {
        '<figure><a href="{0}"><img loading="lazy" src="{0}" alt="{1}"></a><figcaption>{1}</figcaption></figure>' -f $_.Name, $_.BaseName
    }
    $html = @'
<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>天津美术修复 · 验收图</title>
<style>body{margin:32px;background:#fff4d5;color:#4a291c;font:16px system-ui}main{max-width:1440px;margin:auto}h1{font-size:28px}figure{margin:28px 0}img{width:100%;height:auto;border:1px solid #ad8966;border-radius:8px}figcaption{padding:8px 0}a{color:inherit}</style>
<main><h1>天津美术修复 · 验收图</h1><p>24 款顾客 × 4 种表情；三个解锁阶段与最终关；1080p / 720p；库存与炸篮状态。点击图片查看原尺寸。</p>
'@
    ($html + ($figures -join "`n") + '</main></html>') | Set-Content "$outputDir/index.html" -Encoding utf8
}
finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    Pop-Location
}
