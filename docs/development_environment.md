# Project Cake 开发环境

> 记录日期：2026-08-01

- 引擎版本：Godot 4.7.1 stable
- Windows 编辑器：`D:\Godot\Godot_v4.7.1-stable_win64.exe`
- Windows 控制台：`D:\Godot\Godot_v4.7.1-stable_win64_console.exe`
- 渲染器：Mobile（M0 不切换 Forward+）
- 基准逻辑画布：1920×1080
- 默认开发窗口：1280×720，可拉伸并保持中央 1920×1080 安全区

最小启动验证：

```powershell
& 'D:\Godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit
```

自动检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
```

`tools/run_checks.ps1` 会把测试进程的 `APPDATA` 和 `LOCALAPPDATA` 临时指向工程内已忽略的 `.godot-user/`。这是当前受限开发环境所需的隔离措施；不改变系统环境变量，也不改变发布版的 `user://` 语义。

使用实际 Mobile/D3D12 设备创建并更新动态热力图纹理：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_mobile_smoke.ps1
```

该命令会短暂打开游戏窗口并自动退出。

P0.2 真人鼠标验收使用 `tests/manual/p0_2_mouse_playtest.md`，通过前不进入 P0.3。

P0.2 CPU 成本和四次大刮操作量基准：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_cpu_benchmark.ps1
```

历史基准和 128×128 网格决策记录在 `docs/p0_2_performance_report.md`。

自动检查仅验证工程、数据和坐标契约，不能替代后续真人鼠标操作验收。
