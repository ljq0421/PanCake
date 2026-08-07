# 五区域缺失美术素材与 UI 占位清单

更新日期：2026-08-07

## 口径

本清单以 `scripts/data/five_area_catalog.gd`、`resources/art/ASSET_MANIFEST.md`、`resources/art` 磁盘文件和 `scenes/gameplay/initial_unlock_workstation.tscn` 的运行时引用为依据。

- “缺失”只表示当前没有与五区域稳定 ID 对应的专用正式素材；不能把已有但未接入的 34+18 张工作台扩展素材再次报成缺失。
- “已有可复用”与“已接入运行时”是两种状态。例如黄豆/黑豆/红豆/五谷豆浆与原味油条已有素材，但部分尚未绑定到五区域生产界面。
- 临时 UI 占位不是正式美术，也不代表对应区域的完整生产交互已经完成。

## 当前可见场景必须补齐

| 类别 | 缺失专用素材 | 建议目标文件 | 当前游戏内替代 |
| --- | --- | --- | --- |
| 设备 | 成品饮品机基础/中级 | `packaged_drink_heater_tier_1_v1.png`、`packaged_drink_heater_tier_2_v1.png` | `PackagedDrinkPlaceholder`：解锁后显示 `PanelContainer + Label` |
| 设备 | 蒸品蒸箱基础/中级 | `steamer_tier_1_v1.png`、`steamer_tier_2_v1.png` | `SteamerPlaceholder`：解锁后显示 `PanelContainer + Label` |
| 煎饼内容 | 香菜的盘中份量、撒料状态和 1～6 份库存状态 | `ingredients/coriander/` 下的专用 PNG 组 | `CorianderButton` 使用 `IngredientStockSlot` 的名称/数量文本 |
| 煎饼内容 | 榨菜的盘中份量、撒料状态和 1～6 份库存状态 | `ingredients/preserved_mustard/` 下的专用 PNG 组 | `PreservedMustardButton` 使用 `IngredientStockSlot` 的名称/数量文本 |

## 后续五区域商品缺失

这些项目已经进入目录数据，但当前正式场景尚未提供完整生产界面。接入界面前继续使用带名称、数量、状态和倒计时的 `Button`、`Label`、`ProgressBar`，不得拿无关商品图冒充。

| 区域 | 缺失输入素材 | 缺失成品素材 | 数量 |
| --- | --- | --- | ---: |
| 成品饮品 | 牛奶、成品豆奶、核桃饮品、黑芝麻饮品的专用包装/加热输入图 | 对应 4 种加热后商品图 | 8 |
| 油条 | 油饼面坯、糖油饼面坯 | 油饼、糖油饼 | 4 |
| 蒸品 | 馒头、菜包、肉包的半成品/上屉状态 | 馒头、菜包、肉包的熟成状态 | 6 |

## 已有但尚需绑定，不计入缺失

- 现磨豆浆机 tier 1～3、油条炸锅 tier 1～3。
- 黄豆、黑豆、红豆、五谷输入图，以及原味、黑豆、红豆、五谷豆浆杯。
- 原味油条面坯与原味油条。
- 宽头摊饼器、自动酱刷、一键压饼器、4×3 小料盘、锁定盖板和小料盒。

## 状态边界

| 状态 | 当前结论 |
| --- | --- |
| 已生成 | 上述“缺失”项目尚未生成专用正式图 |
| 已导入 | 缺失项目无可导入文件 |
| 已接入运行时 | 成品饮品机、蒸箱、香菜、榨菜已有明确 UI 控件占位；其余后续商品仍等待对应生产界面 |
| 人工视觉确认 | UI 占位需真人检查可读性；正式素材生成后仍需单独人工验收 |
