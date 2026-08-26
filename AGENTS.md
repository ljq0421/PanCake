## Project Scope
如果要求生成透明背景图片，先生成绿色背景的图片，再扣出透明背景。

## Godot Headless Tests In Codex

When running Godot headless tests from Codex sandbox, always pass `--log-file`
to a writable path. Godot 4.7.1 can crash while opening the default
`user://logs/godot*.log` under sandbox restrictions.

Use a writable temp path by default:

```powershell
& "D:\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/mvp_self_check.gd
```

For one-off commands, replace only the script path:

```powershell
& "D:\Godot\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/your_self_check.gd
```

Do not use `--log-file NUL`; Godot treats `NUL` as a reserved Windows device
name and may still crash.

Run commands from the directory that contains `project.godot`, usually:

```powershell
cd D:\Project\ProjectCake\project-cake
```

If a test reports `File not found`, first verify the `res://tests/...` file
exists before debugging game logic.