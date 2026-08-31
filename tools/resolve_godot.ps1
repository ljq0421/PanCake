param([switch]$Editor)

$configured = [Environment]::GetEnvironmentVariable('PROJECT_CAKE_GODOT')
$candidates = [System.Collections.Generic.List[string]]::new()
if (-not [string]::IsNullOrWhiteSpace($configured)) {
    $candidates.Add($configured)
}
if ($Editor) {
    $candidates.Add('D:\Godot\Godot_v4.7.1-stable_win64.exe')
}
else {
    $candidates.Add('D:\Godot\Godot_v4.7.1-stable_win64_console.exe')
}

foreach ($commandName in @('godot4', 'godot')) {
    $command = Get-Command $commandName -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $candidates.Add($command.Source)
    }
}

foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }
}

throw 'Godot executable not found. Set PROJECT_CAKE_GODOT to the Godot 4.7.1 console executable or add godot/godot4 to PATH.'
