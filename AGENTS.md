## Project Scope
如果要求生成透明背景图片，先生成绿色背景的图片，再扣出透明背景。

godot编辑器在 D:\Godot\GodotSharp 路径下

## 各城市通用经营机制

- 顾客耐心、同屏顾客数量、金币收取等基础经营机制，各个城市统一使用通用机制，优先复用共享逻辑，避免分别维护城市专属实现。
- 同屏顾客上限统一为 5 名（不是每日顾客总数）；关卡配置、顾客队列、界面展示和交付区域需保持一致。
- 每正确交付一件顾客所需商品，恢复耐心总量的 15%，最多恢复到满值，并立即更新耐心条和表情；多商品订单在部分交付后同样恢复，重复、失败或错配交付不恢复。
- 扬州为已确认特例：保留整盘上桌，不适用部分交付恢复耐心；将商品放入备餐托盘不视为向顾客交付，不触发耐心恢复。
- 各城市最终满意度只按已完成订单的顾客计算，流失顾客不计入满意度平均值。
- 各城市小费统一四舍五入到整数；对于非负小费，0.5 向上取整，C# 使用 `MidpointRounding.AwayFromZero`，不使用默认银行家舍入或直接向上取整。
- 允许城市保留教学保护，以明确的教学关卡配置或策略实现，不要求教学关卡与普通营业规则完全一致。
- 金币收取统一沿用天津与武汉已有的点击收钱机制，复用共享金币盘与收取反馈逻辑；现有说明见 `docs/天津与武汉点击收钱.md`，后续城市也遵循该机制。
- 天津为 2026-09-11 已确认收银交互特例：三个阶段使用 `天津-煎饼*.png` 新背景，付款自动记账并飞币进入背景挂件；挂件替代桌面金币盘，点击只打开本次营业明细并暂停营业，不再点击收钱。逐单评价只保留本次营业，不写入存档。其他城市继续沿用共享点击收钱机制。
- 武汉为 2026-09-11 已确认收银交互特例：豆皮解锁前后分别使用 `武汉-热干面.png`、`武汉-热干面-豆皮.png`；完全沿用天津挂件收银规则，付款自动记账并飞币进入右侧挂件，点击查看本次营业明细并暂停营业，不再点击收钱。逐单评价仅保留本次营业，不写入存档；两城复用营业明细与飞币组件。
- 后续新增或修改城市时，以上通用机制一并适用；如需城市特例，先向用户确认。

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
