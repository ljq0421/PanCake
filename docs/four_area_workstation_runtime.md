# 四区单鏊工作台运行时合同

> 正式基线：2026-08-28，Godot 4.7.1。本文件是当前玩法、场景、存档和自动验证的唯一规则来源。

## 正式玩法

- 固定四区：`area.pancake`（煎饼）、`area.youtiao`（油条）、`area.fresh_soy_milk`（现磨豆浆）、`area.packaged_drink`（成品饮品）。
- 煎饼区只有 `device.pancake_griddle`，其 `griddle_count` 固定为 `1`；成长不提供第二或第三个鏊位。
- 正式工作台入口是 `res://scenes/gameplay/four_area_workstation.tscn`。它继承旧路径 `five_area_workstation.tscn` 的资源内容，后者只作为存量资源兼容层，不代表五区玩法，也不得作为新功能入口。
- 订单、库存、成长和设备只能引用上列四区目录中存在的稳定 ID。

## 存档与成长

- 当前存档格式为版本 10、`save_kind = breakfast_stall_four_area_v1`。所有更早开发存档均不兼容并在启动时清除。
- 继续游戏恢复活动订单、顾客到店状态、生产快照、金币、成长和库存；恢复过程不得重新生成或重放已保存顾客。
- 日结收取待付款，然后清空未结订单、进行中的设备、单鏊成品、暂存成品和库存。次日回到备货窗口。
- 当日购买的成长在下一营业日激活；其新解锁库存从零开始，必须通过备货获得。

## 公开接口与测试

- 新测试使用 `GameSession` 的中性公开接口：`is_four_area_save_active`、`four_area_progression_snapshot`、`four_area_production_snapshot`、`pancake_griddles_snapshot`、`save_pancake_griddles`、`production_machine_snapshot`、`advance_production`、`restock_status` 与 `advance_restock_hold`。
- `tools/run_checks.ps1` 自动发现全部 unit/integration 自检，每项以独立 Godot 进程和 60 秒超时运行，并在全部完成后汇总。
- `four_area_first_day_e2e_self_check.gd` 建立空白首日存档；`four_area_existing_save_e2e_self_check.gd` 在新进程中恢复该存档并验证继续、日结、跨日与成长激活。
