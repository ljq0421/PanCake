param([switch]$Verify, [switch]$Build)
$ErrorActionPreference = 'Stop'
$previewRoot = $PSScriptRoot
$previewEngine = 'D:\Godot\GodotSharp\Godot_v4.7.1-stable_mono_win64_console.exe'
$previewArtifacts = Join-Path $previewRoot 'artifacts\font-preview'
$previewProfile = Join-Path $previewArtifacts 'profile'
New-Item -ItemType Directory -Force -Path $previewProfile | Out-Null

if ($Build -or !(Test-Path -LiteralPath (Join-Path $previewRoot '.godot\mono\temp\bin\Debug\ProjectCake.dll'))) {
    Push-Location -LiteralPath $previewRoot
    try {
        & dotnet build --no-restore
        if ($LASTEXITCODE -ne 0) { throw '字体预览构建失败。' }
    } finally { Pop-Location }
}

# Isolate autoload settings and save discovery as well as the sample's own save.
# Only this child process receives these paths; the user's environment stays intact.
$previewStart = New-Object System.Diagnostics.ProcessStartInfo
$previewStart.FileName = $previewEngine
$previewStart.WorkingDirectory = $previewRoot
$previewStart.UseShellExecute = $false
$previewStart.CreateNoWindow = $true
$previewStart.EnvironmentVariables['APPDATA'] = $previewProfile
$previewStart.EnvironmentVariables['LOCALAPPDATA'] = $previewProfile
$previewStart.Arguments = '--path . --resolution 1280x720 --position 80,80 --log-file artifacts/font-preview/preview.log res://Scenes/Tests/FontPreview.tscn'
if ($Verify) { $previewStart.Arguments += ' -- --verify-font-preview' }
$previewRun = [System.Diagnostics.Process]::Start($previewStart)
if ($Verify) {
    $previewRun.WaitForExit()
    if ($previewRun.ExitCode -ne 0) { throw '字体预览检查失败，请查看 artifacts/font-preview/preview.log。' }
} else { Write-Output "字体预览已打开（PID $($previewRun.Id)）。F7 切换字体，F8 显隐对比栏。" }
