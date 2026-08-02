# P0.3 动态渲染实现与验证报告

> 日期：2026-08-01  
> 引擎：Godot 4.7.1 stable  
> 渲染器：Forward Mobile / D3D12

## 范围

本阶段只完成面饼动态渲染，不加入刷酱、配料、折叠，也不把 P1 的完整火候、翻面和火力玩法提前实现。

## 实现

- `PancakeModel` 仍是覆盖、厚度、湿度、成熟度和破损的唯一业务数据源。
- 第一张动态 RGBA8 纹理打包覆盖、归一化厚度、湿度和成熟度。
- 第二张动态 R8 纹理保存破损；鏊面遮罩由 Shader 按正式鏊子 732/1055 的椭圆比例计算，并与输入和模型共用参数。
- Shader 读取同一组数据纹理，混合临时生面糊、熟面饼、焦化和破边纹理。
- `1–5` 的直观视图和调试视图共用同一 Shader 与数据纹理，只切换显示模式。
- `PancakeVisual` 和 ShaderMaterial 是 `workstation.tscn` 的稳定节点/资源；脚本负责上传、节流、输入轨迹和刷新。
- 更新频率与渲染纹理尺寸由 `PancakeSimulationParameters` 配置，当前分别为 24 Hz 与 128×128。
- 输出像素到逻辑格子的映射在尺寸变化时预计算；常规更新复用同两个 `ImageTexture`，不持续创建 GPU 纹理。

## 自动验证

无窗口自检覆盖：

- 五个逻辑字段到数据纹理通道的数值映射。
- RGBA8 与 R8 格式。
- 24 Hz 刷新节流。
- 128×128 与运行时 64×64 尺寸切换。
- 120 次连续上传保持两个纹理 RID 不变。
- 调试视图和直观视图使用同一 Shader 切换。

真实 Mobile 渲染冒烟环境：NVIDIA GeForce RTX 5070，D3D12，1280×720 窗口。

| 指标 | 结果 |
|---|---:|
| 动态字段 CPU 上传基准 | 5.462 ms/次 |
| GPU 冒烟 240 次上传 | 5.231 ms/次 |
| 240 次上传静态内存变化 | +112.4 KiB |
| 纹理 RID | 全程复用 |
| 180 个渲染帧平均耗时 | 16.37 ms |
| 180 个渲染帧 P95 | 16.85 ms |
| 交互覆盖率 | 12.3% → 23.6% |

自动测试达到本机 60 FPS 工程门槛，但这不是不同目标 PC 的性能保证，也不能替代真人持续鼠标操作。

## 产物与复现

- 正常交互截图：`tmp/validation/p0_3_latest.png`
- 生湿/成熟/焦化字段注入截图：`tmp/validation/p0_3_material_states.png`
- 真人验收单：`tests/manual/p0_3_render_playtest.md`

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_cpu_benchmark.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_mobile_smoke.ps1
```

## 真人验收结论

2026-08-01，用户确认 P0.3 整体效果通过，可以按开发计划进入 P0.4。用户未提供逐项测试数据，因此不宣称已经分别测得 10 分钟持续操作、调试图一致性等细项结果；原始表格保持待测，作为后续回归清单。
