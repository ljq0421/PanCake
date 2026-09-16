param(
    [string]$Godot = 'D:/Godot/GodotSharp/Godot_v4.7.1-stable_mono_win64_console.exe',
    [string]$Templates = '',
    [switch]$Qa,
    [switch]$Release
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Push-Location $repo
$previousAppData = $env:APPDATA
$previousLocalData = $env:LOCALAPPDATA
try {
    $cache = Join-Path $repo '.tmp/demo-implementation'
    $templateCache = Join-Path $cache 'export-templates'
    New-Item -ItemType Directory -Force -Path $templateCache | Out-Null
    if ($Templates) {
        foreach ($name in @('windows_debug_x86_64.exe','windows_release_x86_64.exe')) {
            Copy-Item -LiteralPath (Join-Path $Templates $name) -Destination (Join-Path $templateCache $name)
        }
    }
    $template = if ($Release) { 'windows_release_x86_64.exe' } else { 'windows_debug_x86_64.exe' }
    if (-not (Test-Path -LiteralPath (Join-Path $templateCache $template))) {
        throw 'Install Godot 4.7.1 .NET export templates and supply their directory with -Templates.'
    }
    $folder = if ($Qa) { 'demo-qa' } else { 'demo-pilot' }
    $preset = if ($Qa) { 'Demo QA Windows' } else { 'Demo Pilot Windows' }
    $name = if ($Qa) { 'BreakfastDemoQA' } else { 'BreakfastDemo' }
    $output = Join-Path $repo ('output/' + $folder)
    New-Item -ItemType Directory -Force -Path $output | Out-Null
    $env:APPDATA = Join-Path $cache 'export-userdata'
    $env:LOCALAPPDATA = Join-Path $cache 'export-localdata'
    $mode = if ($Release) { '--export-release' } else { '--export-debug' }
    $log = Join-Path $cache ($folder + '-build.log')
    & $Godot --headless --editor --path $repo --log-file $log $mode $preset (Join-Path $output ($name + '.exe'))
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $output 'data_ProjectCake_windows_x86_64/ProjectCake.dll'))) {
        throw 'Export failed or C# runtime files are missing. Read the build log.'
    }
    if (Select-String -LiteralPath $log -Pattern 'Export .NET Project:|Failed to export project|Failed to build project' -Quiet) {
        throw 'The exporter reported a .NET build failure. Do not distribute this output.'
    }
    Copy-Item -LiteralPath 'resource/fonts/KNMaiyuan/OFL.txt' -Destination (Join-Path $output 'FONT-LICENSE-KNMaiyuan.txt')
    if (-not $Qa) {
        Copy-Item -LiteralPath 'docs/Demo-Pilot试玩说明.md' -Destination (Join-Path $output 'README.md')
        Copy-Item -LiteralPath 'docs/Demo-Music-Credits.md' -Destination (Join-Path $output 'MUSIC-CREDITS.md')
        Copy-Item -LiteralPath 'docs/Demo-TwoCities-ReleaseNotes.md' -Destination (Join-Path $output 'RELEASE-NOTES.md')
    }
    Write-Output ('Exported: ' + (Join-Path $output ($name + '.exe')))
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalData
    Pop-Location
}
