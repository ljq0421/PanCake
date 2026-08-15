# 五区域成长系统实施规格

> 运行时现状已收敛为三区域；正式入口、场景结构和当前验证合同见 `docs/three_area_workstation_runtime.md`。本文其余内容保留五区域设计与实施历史，和当前运行时冲突时以前述三区域合同为准。

> 状态：实施基线 v1。  
> 日期：2026-08-05。  
> 产品规则来源：`docs/five_area_progression_redesign_optimized.md`。  
> 适用工程：Godot 4.7.1，`D:\Project\ProjectCake\project-cake`。  
> 存档策略：游戏仍在开发阶段，只实现五区域新存档；不升级、不迁移历史开发存档。  
> 用途：冻结稳定 ID、运行时状态、服务接口、订单算法、场景职责、文件改造顺序和测试门槛，作为后续功能代码开发合同。

## 1. 文档优先级与完成定义

实施时按以下优先级处理冲突：

1. 本实施规格中的稳定 ID、状态机、API、文件职责和测试门槛；
2. `five_area_progression_redesign_optimized.md` 中的玩家规则与体验目标；
3. `game_design.md` 中仍未被五区域方案替代的煎饼操作与评分规则；
4. 当前运行时代码，仅作为可复用实现，不作为新设计依据；
5. `workstation_expansion_plan.md` 和旧三设备代码属于历史实现，不得覆盖本规格。

“功能完成”必须同时满足：

- 目录、服务、存档、场景和订单使用同一组稳定 ID；
- 服务层自检通过；
- 主场景集成自检通过；
- 非 headless GPU 运行无脚本错误；
- 真实鼠标路径完成规定动作；
- 人工视觉和玩法验收有独立记录。

自动化 PASS 只证明对应工程合同成立，不等于产品体验已经通过。

## 2. 当前实现与目标差距

当前工程事实：

- `GameSessionStore` 使用存档版本 2；
- `WorkstationProgressionService` 只有一个 `pending_purchase`；
- `workstation_expansion_catalog.gd` 的正式设备仍是豆浆机、油条机、鸡蛋仔机；
- `ExpansionProductionService` 和 `EquipmentBatchModel` 以整机单配方批次为中心；
- `OrderService` 仍是单份煎饼订单；
- `initial_unlock_workstation.tscn` 和适配器承载历史三设备入口；
- `main_page_prototype.tscn` 已有五区域布局雏形，但仍是原型，不是业务真源；
- 煎饼模拟、摊面、刷酱、小料、折叠和评分路径已经存在，应保留并通过适配层接入新主场景。

目标不是在旧三设备目录上追加饮品和蒸笼，而是建立新的五区域目录与运行时，再逐项切断历史入口。

## 3. 目标模块边界

```text
FiveAreaCatalog
  ├─ 稳定 ID、显示名、价格、门槛、设备参数、商品和补货参数
  └─ 纯查询，不保存玩家状态

StockInventoryModel + HoldRefillService
  ├─ 合法库存、容量、原子增减和长按补货进度
  └─ 不决定内容是否永久解锁

GameSessionStore (autoload: GameSession)
  ├─ 新游戏、存档读写、营业日边界
  ├─ 持有并协调下列服务
  └─ 对场景发出统一快照和变更信号

WorkstationProgressionService
  ├─ 金币、口碑、区域解锁、设备等级、内容和辅助所有权
  ├─ 分区熟练度、专精、双购买位和次日激活
  └─ 不处理机器计时、订单随机或场景节点

FiveAreaProductionService
  ├─ 成品饮品、油条、豆浆、蒸笼机器状态
  ├─ 库存原子消耗、成品产生、自动化动作和计时推进
  └─ 不生成订单、不计算成长推荐

PancakeHoldingTrayModel
  ├─ 两格成品快照、新鲜度、匹配与报废
  └─ 不修改煎饼原始评分

OrderService
  ├─ 教学队列、确定性订单生成、多商品订单、交付判定
  └─ 不读取场景节点，不直接修改金币

BusinessReportService
  ├─ 收入、成本、错单、缺货、浪费、熟练度和口碑来源
  └─ 输出当日日结快照

AttentionService
  ├─ 从机器和托盘快照派生最多三条临界提醒
  └─ 无持久状态

DailyGoalService
  ├─ 满台后的区域专精、每日招牌目标、事件计数和一次性奖励
  └─ 目标生成确定且可存档恢复

FiveAreaWorkstationController
  ├─ 连接场景信号与服务意图
  └─ 只做绑定、路由和可视刷新，不拥有业务规则
```

禁止的依赖：

- 目录不得依赖服务或场景；
- 模型不得访问 `GameSession` 自动加载；
- 服务不得 `get_node()` 查找 UI；
- UI 不得自行扣金币、改库存、推进熟练度或生成订单；
- `stock` 不得用于反推永久解锁；
- 场景脚本不得复制目录中的时间、容量、价格或门槛常量。

## 4. 稳定 ID 合同

稳定 ID 一旦进入五区域新存档和测试，不因显示文案、美术资源或平衡调整而改变。

### 4.1 区域和设备

| 顺序 | 区域 ID | 设备 ID | 显示名 |
|---:|---|---|---|
| 1 | `area.pancake` | `device.pancake_griddle` | 煎饼台 |
| 2 | `area.packaged_drink` | 独立设备见下文 | 成品饮品柜（仅常温库存） |
| 3 | `area.youtiao` | `device.youtiao_fryer` | 油条炸锅 |
| 4 | `area.fresh_soy_milk` | `device.fresh_soy_milk_machine` | 现磨豆浆机 |
| 5 | `area.steamer` | `device.steamer` | 多层蒸笼 |

设备等级统一使用整数：

- `0`：基础；
- `1`：中级；
- `2`：高级；
- `-1`：未拥有，仅允许作为查询结果，不能写入已解锁设备状态。

### 4.2 原料、商品与配方

水是店铺公共资源，不进入库存、不收费。设备需要“加水”动作时只记录动作完成，不消耗 `stock`。

| 区域 | 库存 ID | 配方/商品 ID | 产出 ID |
|---|---|---|---|
| 煎饼 | `stock.pancake.batter` | `recipe.pancake.base` | `product.pancake.custom` |
| 煎饼 | `stock.pancake.egg` | — | 成品快照组成 |
| 煎饼 | `stock.pancake.baocui` | — | 成品快照组成 |
| 煎饼 | `stock.pancake.scallion` | — | 成品快照组成 |
| 煎饼 | `stock.pancake.sauce.sweet_flour` | — | 成品快照组成 |
| 煎饼 | `stock.pancake.sauce.red_chili` | — | 成品快照组成 |
| 煎饼 | `stock.pancake.ham_sausage` | — | 成品快照组成 |
| 煎饼 | `stock.pancake.meat_floss` | — | 成品快照组成 |
| 煎饼 | `stock.pancake.pork_tenderloin` | — | 成品快照组成 |
| 煎饼 | `stock.pancake.coriander` | — | 成品快照组成 |
| 煎饼 | `stock.pancake.preserved_mustard` | — | 成品快照组成 |
| 饮品 | `stock.packaged_drink.milk` | `product.packaged_drink.milk` | 同商品 ID |
| 饮品 | `stock.packaged_drink.soy_milk` | `product.packaged_drink.soy_milk` | 同商品 ID |
| 饮品 | `stock.packaged_drink.walnut` | `product.packaged_drink.walnut` | 同商品 ID |
| 饮品 | `stock.packaged_drink.black_sesame` | `product.packaged_drink.black_sesame` | 同商品 ID |
| 油条 | `stock.youtiao.plain_dough` | `recipe.youtiao.plain` | `product.youtiao.plain` |
| 油条 | `stock.youtiao.oil_cake_dough` | `recipe.youtiao.oil_cake` | `product.youtiao.oil_cake` |
| 油条 | `stock.youtiao.sugar_oil_cake_dough` | `recipe.youtiao.sugar_oil_cake` | `product.youtiao.sugar_oil_cake` |
| 豆浆 | `stock.fresh_soy_milk.yellow_bean` | `recipe.fresh_soy_milk.yellow_bean` | `product.fresh_soy_milk.yellow_bean` |
| 豆浆 | `stock.fresh_soy_milk.black_bean` | `recipe.fresh_soy_milk.black_bean` | `product.fresh_soy_milk.black_bean` |
| 豆浆 | `stock.fresh_soy_milk.red_bean` | `recipe.fresh_soy_milk.red_bean` | `product.fresh_soy_milk.red_bean` |
| 豆浆 | `stock.fresh_soy_milk.multigrain` | `recipe.fresh_soy_milk.multigrain` | `product.fresh_soy_milk.multigrain` |
| 蒸笼 | `stock.steamer.mantou` | `recipe.steamer.mantou` | `product.steamer.mantou` |
| 蒸笼 | `stock.steamer.vegetable_bun` | `recipe.steamer.vegetable_bun` | `product.steamer.vegetable_bun` |
| 蒸笼 | `stock.steamer.meat_bun` | `recipe.steamer.meat_bun` | `product.steamer.meat_bun` |

成品豆奶固定使用 `product.packaged_drink.soy_milk`，现磨黄豆浆固定使用 `product.fresh_soy_milk.yellow_bean`。任何兼容别名都不得进入新目录。

### 4.3 熟练度与专精指标

| 区域 | 合格指标 ID | A级指标 ID |
|---|---|---|
| 煎饼 | `mastery.pancake.qualified` | `mastery.pancake.a_grade` |
| 饮品 | `mastery.packaged_drink.correct_temperature` | `mastery.packaged_drink.correct_streak_best` |
| 油条 | `mastery.youtiao.qualified` | `mastery.youtiao.a_grade` |
| 豆浆 | `mastery.fresh_soy_milk.qualified` | `mastery.fresh_soy_milk.a_grade` |
| 蒸笼 | `mastery.steamer.qualified` | `mastery.steamer.a_grade` |

教学状态使用区域 ID，不额外发明可变字符串：

- `tutorial.completed_area_ids`；
- `tutorial.queue_area_ids`；
- `tutorial.active_area_id`；
- `tutorial.failure_count_by_area`。

### 4.4 辅助、自动化与容量

| ID | 所属区域 | 效果 |
|---|---|---|
| `assist.youtiao.temperature_indicator` | 油条 | 强化生、合格、过火区间显示 |
| `automation.youtiao.auto_lift` | 油条 | 熟成时自动离油并进入沥油 |
| `automation.youtiao.auto_load` | 油条 | 按玩家已确认的配方和数量自动装载 |
| `automation.fresh_soy_milk.auto_water_start` | 豆浆 | 选豆后自动加水并启动 |
| `automation.fresh_soy_milk.auto_cup_rack` | 豆浆 | 完成后自动接杯到有限输出架 |
| `automation.pancake.auto_sauce_brush` | 煎饼 | 按当前订单完成标准刷酱 |
| `automation.pancake.press_once` | 煎饼 | 每张饼允许一次标准摊面 |
| `capacity.pancake_holding_tray.two_slots` | 煎饼 | 开放固定两格成品暂存 |
| `capacity.stock.intermediate` | 店铺 | 每种库存上限 6→10 |
| `capacity.stock.advanced` | 店铺 | 每种库存上限 10→14 |

蒸笼分层提示和全局临界提醒是基础可读性能力，不是付费成长项。

### 4.5 专精和每日目标 ID

专精等级 ID：

- `specialization.<area>.bronze`；
- `specialization.<area>.silver`；
- `specialization.<area>.gold`。

其中 `<area>` 固定使用 `pancake`、`packaged_drink`、`youtiao`、`fresh_soy_milk`、`steamer`。

每日目标 ID：

| ID | 条件 |
|---|---|
| `goal.signature.pancake_two_a` | 当日完成2份A级煎饼 |
| `goal.signature.packaged_drink_four_correct` | 连续正确完成4份饮品温度要求 |
| `goal.signature.youtiao_four_no_burn` | 完成4份B级以上油条且期间无焦糊 |
| `goal.signature.fresh_soy_milk_four_no_spoil` | 完成4杯B级以上豆浆且期间无报废 |
| `goal.signature.steamer_two_layers_no_spoil` | 至少两层同时运行并完成4份B级以上蒸品且无报废 |
| `goal.signature.combo_two_no_failure` | 完成2份双品或三件套餐且无错单 |

目标奖励默认20金币、2口碑。对应区域达到金牌时，区域目标金币乘1.25并四舍五入；口碑不放大。

## 5. 五区域目录结构

新增 `scripts/data/five_area_catalog.gd`，类保持纯静态查询。旧 `workstation_expansion_catalog.gd` 在切换完成后不得被正式运行时引用。

### 5.1 目录顶层结构

```gdscript
const BALANCE_VERSION := 1
const AREA_DEFINITIONS := {}
const DEVICE_DEFINITIONS := {}
const STOCK_DEFINITIONS := {}
const RECIPE_DEFINITIONS := {}
const PRODUCT_DEFINITIONS := {}
const PANCAKE_ORDER_TEMPLATES := {}
const GROWTH_DEFINITIONS := {}
const MASTERY_DEFINITIONS := {}
const ORDER_BALANCE := {}
const REPUTATION_BALANCE := {}
const DAILY_GOAL_DEFINITIONS := {}
```

所有查询返回深拷贝，调用者不得修改目录常量。

必须提供：

```gdscript
static func area_definition(area_id: StringName) -> Dictionary
static func device_definition(device_id: StringName) -> Dictionary
static func device_tier(device_id: StringName, tier: int) -> Dictionary
static func stock_definition(stock_id: StringName) -> Dictionary
static func recipe_definition(recipe_id: StringName) -> Dictionary
static func product_definition(product_id: StringName) -> Dictionary
static func growth_definition(growth_id: StringName) -> Dictionary
static func pancake_order_template(template_id: StringName) -> Dictionary
static func daily_goal_definition(goal_id: StringName) -> Dictionary
static func area_ids() -> Array[StringName]
static func stock_ids() -> Array[StringName]
static func growth_ids() -> Array[StringName]
static func validate_catalog() -> PackedStringArray
```

`validate_catalog()` 返回所有错误，不在发现第一个错误时停止。正式检查要求为空数组。

### 5.2 v0设备参数

数值是首轮可运行默认值，集中在目录中；试玩只改目录，不改服务代码。

| 设备 | 等级 | 容量/层数 | 加工时间 | 安全期 | 衰减/保温 |
|---|---:|---:|---:|---:|---|
| 饮品加热器 | 0 | 1 位 | 2.0秒 | 热饮8秒 | 之后冷却，不能作为热饮交付 |
| 饮品加热器 | 1 | 2 位 | 1.0秒 | 热饮8秒 | 同上 |
| 饮品加热器 | 2 | 4 位 | 1.0秒 | 无限 | 持续占位 |
| 油条炸锅 | 0 | 2 份 | 12.0秒 | 5.0秒 | 10秒线性降至60分，随后焦糊 |
| 油条炸锅 | 1 | 2 份 | 9.0秒 | 5.0秒 | 同上 |
| 油条炸锅 | 2 | 4 份 | 9.0秒 | 5.0秒 | 同上；不自带自动升篮 |
| 现磨豆浆机 | 0 | 2 杯 | 5.0秒 | 5.0秒 | 10秒线性降至60分，随后报废 |
| 现磨豆浆机 | 1 | 2 杯 | 3.0秒 | 5.0秒 | 同上 |
| 现磨豆浆机 | 2 | 4 杯 | 3.0秒 | 无限 | 保温并占用容量 |
| 蒸笼 | 0 | 1 层 | 配方时间×1.00 | 5.0秒 | 10秒线性降至60分，随后报废 |
| 蒸笼 | 1 | 2 层 | 配方时间×0.75 | 5.0秒 | 同上 |
| 蒸笼 | 2 | 4 层 | 配方时间×0.75 | 无限 | 熟成层关闭蒸汽并继续占层 |

饮品 0.3 秒输入宽限通过 `INPUT_GRACE_SECONDS := 0.3` 实现，只用于边界点击判定，不改变 UI 显示时长。

蒸品 v0 参数：

| 配方 | 单层容量 | 基础时间 | 原料成本 | 基础售价 |
|---|---:|---:|---:|---:|
| 馒头 | 4 | 10秒 | 2 | 6 |
| 菜包 | 3 | 14秒 | 4 | 10 |
| 肉包 | 2 | 18秒 | 6 | 15 |

其他商品 v0 成本与售价：

| 商品 | 原料成本 | 基础售价 |
|---|---:|---:|
| 纯牛奶 | 1 | 3 |
| 成品豆奶 | 2 | 5 |
| 核桃乳 | 3 | 7 |
| 黑芝麻乳 | 4 | 9 |
| 原味油条 | 2 | 6 |
| 油饼 | 3 | 8 |
| 糖油饼 | 4 | 11 |
| 黄豆豆浆 | 2 | 7 |
| 黑豆豆浆 | 3 | 9 |
| 红豆豆浆 | 4 | 11 |
| 五谷豆浆 | 5 | 14 |

煎饼库存 v0 单位成本：

| 库存 | 单位成本 |
|---|---:|
| 面糊、鸡蛋、薄脆、香葱、甜面酱、辣酱 | 1 |
| 火腿肠、肉松 | 2 |
| 里脊肉 | 3 |
| 香菜、榨菜 | 1 |

长按补货每单位时间：

| 库存类别 | 每单位秒数 |
|---|---:|
| 煎饼面糊、小料和酱料 | 0.25 |
| 成品饮品 | 0.50 |
| 油条面胚 | 0.25 |
| 豆浆豆料 | 1.50 |
| 蒸品半成品 | 1.50 |

机器产品品质统一为：

- A：`quality >= 90`；
- B：`75 <= quality < 90`；
- C：`60 <= quality < 75`；
- 报废：`quality < 60`，不可交付；
- 熟练度“合格”只统计 A/B。

煎饼沿用现有评分尺度，不为了和机器产品统一而改动手感：

- A：`score >= 85`；
- B：`70 <= score < 85`；
- C：`60 <= score < 70`；
- 失败：`score < 60`。

订单、熟练度和专精统一比较 `grade`，不能假设所有区域使用相同原始分数阈值。托盘新鲜度扣分后重新按煎饼阈值计算最终等级。

### 5.3 煎饼订单模板

保留现有煎饼评分维度，订单模板只声明要求，不复制评分公式。

| 模板 ID | 必需小料 | 酱料 | 火候 | 基础售价 |
|---|---|---|---|---:|
| `order.pancake.classic` | 鸡蛋、薄脆、香葱 | 甜面酱 | 金黄 | 8 |
| `order.pancake.scallion_light` | 鸡蛋、香葱 | 甜面酱 | 嫩火 | 7 |
| `order.pancake.chili_ham` | 鸡蛋、薄脆、火腿肠 | 辣酱 | 偏香脆 | 12 |
| `order.pancake.double_sauce` | 鸡蛋、薄脆、火腿肠、香葱 | 双酱 | 金黄 | 16 |
| `order.pancake.meat_floss_sweet` | 鸡蛋、薄脆、肉松、香葱 | 甜面酱 | 金黄 | 15 |
| `order.pancake.tenderloin_double_sauce` | 鸡蛋、里脊肉、香葱 | 双酱 | 偏香脆 | 18 |
| `order.pancake.coriander` | 鸡蛋、薄脆、香菜 | 甜面酱 | 金黄 | 10 |
| `order.pancake.preserved_mustard` | 鸡蛋、薄脆、榨菜 | 辣酱 | 金黄 | 11 |

模板只有在全部必需小料和酱料已解锁时才进入候选池。

### 5.4 成长购买目录

门槛缩写：

- `D`：最早营业日；
- `R`：最低口碑；
- `Q(area)`：区域合格数；
- `A(area)`：区域A级数；
- `T(area)`：已完成区域教学；
- `ALL`：五区域全部解锁。

表内短名固定映射：`pancake = area.pancake`、`drink = area.packaged_drink`、`youtiao = area.youtiao`、`soy = area.fresh_soy_milk`、`steamer = area.steamer`。

价格是 v0 可运行值，稳定 ID 和效果不可随平衡调整更名。

#### 店铺与煎饼

| 成长 ID | 位 | 价格 | 门槛 | 效果 |
|---|---|---:|---|---|
| `growth.tool.pancake.wide_spreader` | 安装 | 12 | D2 | 摊面有效宽度×1.65；升级外观和指示圈同步放大 |
| `growth.add_on.pancake.red_chili` | 内容 | 8 | R10 | 解锁辣酱库存与订单 |
| `growth.add_on.pancake.ham_sausage` | 内容 | 12 | D4 | 解锁火腿肠 |
| `growth.equipment.pancake.intermediate` | 安装 | 24 | A(pancake)2 | 扩大合格火候窗口 |
| `growth.add_on.pancake.meat_floss` | 内容 | 18 | R45 | 解锁肉松 |
| `growth.capacity.pancake_holding_tray.two_slots` | 内容 | 32 | D8，T(youtiao) | 开放两格托盘 |
| `growth.add_on.pancake.coriander` | 内容 | 10 | D8 | 解锁香菜 |
| `growth.add_on.pancake.preserved_mustard` | 内容 | 12 | R100 | 解锁榨菜 |
| `growth.add_on.pancake.pork_tenderloin` | 内容 | 28 | D10 | 解锁里脊肉 |
| `growth.automation.pancake.auto_sauce_brush` | 安装 | 36 | A(pancake)5 | 开放自动酱刷 |
| `growth.equipment.pancake.advanced` | 安装 | 48 | ALL，A(pancake)10 | 快速回温 |
| `growth.automation.pancake.press_once` | 安装 | 60 | ALL，A(pancake)20，需宽幅摊饼器/中级鏊子/自动酱刷 | 每张饼一次标准摊面 |
| `growth.capacity.stock.intermediate` | 内容 | 20 | R80 | 库存上限提升到10 |
| `growth.capacity.stock.advanced` | 内容 | 40 | ALL，R200，需中级容量 | 库存上限提升到14 |

#### 成品饮品

| 成长 ID | 位 | 价格 | 门槛 | 效果 |
|---|---|---:|---|---|
| `growth.area.packaged_drink` | 安装 | 30 | Q(pancake)6，T(pancake) | 仅解锁饮品柜、纯牛奶库存和常温教学单 |
| `growth.equipment.packaged_drink.basic` | 安装 | 12 | T(drink) | 次日安装一位基础加热器并触发一次热饮教学 |
| `growth.product.packaged_drink.soy_milk` | 内容 | 12 | R30 | 解锁成品豆奶 |
| `growth.equipment.packaged_drink.intermediate` | 安装 | 24 | 已购买基础加热器，Q(drink)6 | 2位、1秒加热 |
| `growth.product.packaged_drink.walnut` | 内容 | 18 | D11 | 解锁核桃乳 |
| `growth.product.packaged_drink.black_sesame` | 内容 | 24 | R160 | 解锁黑芝麻乳 |
| `growth.equipment.packaged_drink.advanced` | 安装 | 48 | ALL，最高连续正确温度 8 | 4位、持续保温 |

饮品柜与加热器使用独立所有权：`owns_area("area.packaged_drink")` 只允许常温成品饮品；`owns_device("device.packaged_drink_heater")` 才允许操作加热位。常温教学完成后才会生成普通常温饮品订单；基础加热器次日生效后生成一张独占、无限时的加热纯牛奶教学单，完成前普通订单不得生成 `heated`。油条区域要求该设备教学已完成。

兼容旧档时不提升顶层存档版本。若旧档在营业中，迁移延迟到日结；届时将加热位饮品无损退回库存（可暂时超容量），暂存既有加热器等级并重新锁定设备。玩家重新购买基础加热器后恢复已付费的双位或四位等级，但仍只触发一次新的热饮教学。

#### 油条

| 成长 ID | 位 | 价格 | 门槛 | 效果 |
|---|---|---:|---|---|
| `growth.area.youtiao` | 安装 | 60 | R60，T(drink) | 解锁区域、基础炸锅和原味油条 |
| `growth.assist.youtiao.temperature_indicator` | 安装 | 16 | R70 | 强化火候区间 |
| `growth.recipe.youtiao.oil_cake` | 内容 | 18 | D7 | 解锁油饼 |
| `growth.equipment.youtiao.intermediate` | 安装 | 42 | Q(youtiao)6 | 加工12→9秒 |
| `growth.recipe.youtiao.sugar_oil_cake` | 内容 | 24 | R140 | 解锁糖油饼 |
| `growth.automation.youtiao.auto_lift` | 安装 | 54 | ALL，A(youtiao)5 | 熟成自动升篮 |
| `growth.equipment.youtiao.advanced` | 安装 | 72 | ALL，A(youtiao)8 | 容量2→4，不自动升篮 |
| `growth.automation.youtiao.auto_load` | 安装 | 66 | ALL，A(youtiao)10，需自动升篮 | 自动装载已确认批次 |

#### 现磨豆浆

| 成长 ID | 位 | 价格 | 门槛 | 效果 |
|---|---|---:|---|---|
| `growth.area.fresh_soy_milk` | 安装 | 90 | D10，T(youtiao) | 解锁区域、基础设备和黄豆豆浆 |
| `growth.recipe.fresh_soy_milk.black_bean` | 内容 | 18 | D10 | 解锁黑豆豆浆 |
| `growth.equipment.fresh_soy_milk.intermediate` | 安装 | 54 | Q(soy)6 | 加工5→3秒 |
| `growth.recipe.fresh_soy_milk.red_bean` | 内容 | 24 | R150 | 解锁红豆豆浆 |
| `growth.recipe.fresh_soy_milk.multigrain` | 内容 | 30 | D16 | 解锁五谷豆浆 |
| `growth.automation.fresh_soy_milk.auto_water_start` | 安装 | 60 | ALL，A(soy)5 | 自动加水并启动 |
| `growth.equipment.fresh_soy_milk.advanced` | 安装 | 84 | ALL，A(soy)8 | 容量2→4并保温 |
| `growth.automation.fresh_soy_milk.auto_cup_rack` | 安装 | 72 | ALL，A(soy)10，需自动加水启动 | 自动接杯到4格输出架 |

#### 蒸笼

| 成长 ID | 位 | 价格 | 门槛 | 效果 |
|---|---|---:|---|---|
| `growth.area.steamer` | 安装 | 120 | Q(soy)4，T(soy) | 解锁区域、基础蒸笼和馒头 |
| `growth.recipe.steamer.vegetable_bun` | 内容 | 24 | D15 | 解锁菜包 |
| `growth.equipment.steamer.intermediate` | 安装 | 66 | Q(steamer)9 | 2层、时间×0.75 |
| `growth.recipe.steamer.meat_bun` | 内容 | 36 | R200 | 解锁肉包 |
| `growth.equipment.steamer.advanced` | 安装 | 108 | A(steamer)8 | 4层、熟成层自动停汽 |

### 5.5 目录校验规则

`validate_catalog()` 至少检查：

- 所有 ID 唯一且前缀正确；
- 区域顺序固定为五项；
- 所有设备引用有效区域；
- 每个配方的库存、设备和产出存在；
- 每个成长项只有一个购买位；
- 价格非负，目标等级连续；
- 前置成长存在且无循环；
- 非开局内容都有解锁来源；
- 新存档解锁项不会产生锁定订单；
- 成品豆奶和现磨豆浆 ID 不相等；
- 蒸笼配方不会被整机单批模型声明；
- 自动化动作在目标模型中存在；
- 显示名、描述和失败提示键完整。

## 6. 新存档合同

### 6.1 版本和不兼容处理

- `GameSessionStore.SAVE_VERSION` 提升为 `3`；
- 增加 `save_kind := "five_area_v1"`；
- 版本或 `save_kind` 不匹配时，`has_save()` 返回 `false`；
- 开始界面显示“开发存档结构已更新，请开始新游戏”；
- 不读取旧 `pending_purchase`、鸡蛋仔或旧设备字段；
- 不编写升级、兑换或兼容分支。

### 6.2 新存档顶层结构

```gdscript
{
    "version": 3,
    "save_kind": "five_area_v1",
    "started_at_unix": 0,
    "last_played_at_unix": 0,
    "day_open": true,
    "business_paused": false,
    "order_sequence": 0,
    "order_rng_seed": 0,
    "orders_completed": 0,
    "progression": {},
    "inventory": {},
    "production": {},
    "pancake_holding_tray": {},
    "orders": {},
    "daily_goal": {},
    "today_ledger": {},
    "last_bill": {},
}
```

`started_at_unix` 只用于展示。机器计时、托盘新鲜度和顾客耐心不得通过系统时间离线推进。

继续游戏载入后先强制 `business_paused = true`，等待正式场景完成绑定并由玩家明确继续；不得在场景加载帧中推进任何计时。

### 6.3 新游戏默认状态

```gdscript
progression = {
    "coins": 0,
    "reputation": 0,
    "current_day": 1,
    "unlocked_area_ids": ["area.pancake"],
    "equipment_levels": {"device.pancake_griddle": 0},
    "unlocked_recipe_ids": ["recipe.pancake.base"],
    "unlocked_product_ids": [],
    "unlocked_add_on_ids": [
        "stock.pancake.egg",
        "stock.pancake.baocui",
        "stock.pancake.scallion",
        "stock.pancake.sauce.sweet_flour"
    ],
    "owned_assist_ids": [],
    "owned_automation_ids": [],
    "owned_capacity_ids": [],
    "mastery": {},
    "specialization": {},
    "notified_specialization_ids": [],
    "pending_install_purchase": "",
    "pending_content_purchase": "",
    "tutorial_completed_area_ids": [],
    "tutorial_queue_area_ids": ["area.pancake"],
    "tutorial_active_area_id": "area.pancake",
    "tutorial_failure_count_by_area": {},
}
```

初始库存每项 6 份：

- 面糊；
- 鸡蛋；
- 薄脆；
- 香葱；
- 甜面酱。

甜面酱是库存与订单配方的一部分，但不是 `MaterialDock` 槽位。正式场景必须把 `SweetFlourSauceBrush` 固定放在煎饼台面，用它承载手动刷甜面酱的可见入口；甜面酱的消耗、余量和补充仍由库存模型处理，不得因为移出台面材料槽而改成无限库存。

其余合法库存键可以初始化为 0，但绝不能因此视为已解锁。辣酱、火腿肠和后续区域商品不出现在 UI 和订单候选池。

### 6.4 保存时机与原子性

立即保存：

- 新游戏建立；
- 购买成功；
- 次日激活成功；
- 订单结算或婉拒；
- 原料实际扣除；
- 成品收取、托盘存放/取出/报废；
- 营业结束。

计时状态每 1 秒节流保存一次，并在暂停、返回菜单和窗口退出时强制保存。

写盘使用临时文件后替换正式文件。写盘失败不得清空内存状态，并通过统一错误提示告知玩家。

## 7. 统一结果、失败码与库存事务

### 7.1 结果与失败码

所有可失败的服务方法返回：

```gdscript
{
    "success": false,
    "reason": &"failure.code",
    "details": {},
    "changed": false,
}
```

成功返回 `reason = &""`。服务只返回稳定失败码和数据，不返回决定业务的中文字符串；UI 负责本地化。

通用失败码：

| 失败码 | 含义 |
|---|---|
| `unknown_id` | 目录中不存在该 ID |
| `area_locked` | 区域未解锁 |
| `content_locked` | 配方、商品或小料未解锁 |
| `equipment_not_owned` | 设备未拥有 |
| `invalid_state` | 当前状态不允许动作 |
| `invalid_quantity` | 数量小于1或超过容量 |
| `capacity_full` | 设备、输出架或托盘已满 |
| `insufficient_stock` | 库存不足，且未发生部分扣除 |
| `insufficient_coins` | 金币不足 |
| `requirements_not_met` | 成长门槛未满足 |
| `purchase_slot_occupied` | 对应购买位已有待激活项 |
| `already_owned` | 已拥有或已达到目标等级 |
| `mixed_recipe_batch` | 单批尝试混入不同主配方 |
| `order_not_active` | 订单不在活动队列 |
| `product_mismatch` | 商品或成品快照不匹配 |
| `temperature_mismatch` | 饮品温度不匹配 |
| `product_expired` | 成品已报废或托盘过期 |
| `activation_failed` | 次日激活未完成，营业日不推进 |
| `save_failed` | 内存成功但写盘失败，需要显式提示 |

### 7.2 库存与补货合同

新增 `scripts/gameplay/stock_inventory_model.gd`，替代把所有内容都称作配料的旧模型。它只接受 `FiveAreaCatalog.stock_ids()` 中的 ID。

公开 API：

```gdscript
signal stock_changed(stock_id: StringName, current: int, capacity: int)

func current(stock_id: StringName) -> int
func capacity(stock_id: StringName) -> int
func can_consume(stock_id: StringName, quantity: int) -> bool
func consume_many(stock_id: StringName, quantity: int) -> Dictionary
func add_many(stock_id: StringName, quantity: int) -> Dictionary
func set_capacity_for_all(capacity: int) -> Dictionary
func snapshot() -> Dictionary
func load_snapshot(snapshot: Dictionary) -> Dictionary
```

事务规则：

- 未知 ID、负数、零数量和超容量请求明确失败；
- `consume_many()` 要么完整扣除，要么完全不变；
- `add_many()` 返回实际增加量，容量满时不收费；
- 加载时未知 ID 报数据错误，不静默加入目录；
- 容量升级不改变当前数量，不赠库存；
- 未解锁但合法的库存可以保存为0或历史调试值，但正式 UI、生产和订单仍依据永久解锁过滤。

保留并改造 `HoldRefillService`：

```gdscript
func begin_refill(stock_id: StringName) -> Dictionary
func advance_refill(stock_id: StringName, delta: float) -> Dictionary
func release_refill(stock_id: StringName) -> Dictionary
func refill_status(stock_id: StringName) -> Dictionary
```

- 只有已解锁库存允许补货；
- 每完成一单位补货进度才原子扣除该单位金币并增加一单位库存；
- 松开、切换库存或保存时保留未满一单位的进度；
- 金币不足或容量已满立即停止，不多扣金币；
- 补货不占安装位或内容位；
- 每次真实扣费写入 `stock_cost` 日账本事件。

## 8. 成长服务合同

### 8.1 公开 API

```gdscript
func snapshot() -> Dictionary
func load_snapshot(snapshot: Dictionary) -> Dictionary
func area_unlocked(area_id: StringName) -> bool
func equipment_tier(device_id: StringName) -> int
func content_unlocked(content_id: StringName) -> bool
func owns_growth(growth_id: StringName) -> bool
func mastery_value(metric_id: StringName) -> int
func purchase_status(growth_id: StringName) -> Dictionary
func purchase(growth_id: StringName) -> Dictionary
func growth_recommendations(limit_total: int = 3) -> Dictionary
func record_area_result(area_id: StringName, result: Dictionary) -> Dictionary
func complete_tutorial(area_id: StringName) -> Dictionary
func record_tutorial_failure(area_id: StringName) -> Dictionary
func begin_next_business_day() -> Dictionary
```

`growth_recommendations()` 返回：

```gdscript
{
    "recommended": Array[Dictionary],
    "install": Array[Dictionary],
    "content": Array[Dictionary],
    "nearest_locked": Array[Dictionary],
}
```

`limit_total` 限制总候选数；UI 只按 `recommended` 的顺序展示，其他三个数组保留为兼容分组字段。每个候选额外返回从零开始的 `route_index` 和 `pending_activation`。

候选来自目录常量 `FIXED_GROWTH_ROUTE`，不得按价格、缺口、金币、口碑、熟练度或可购买性重新排序，也不得用后续可购买项替换当前项。遍历规则只有两条：

1. 已激活/已拥有项跳过；
2. 已预订但尚未激活项不跳过，继续占据原路线位置。

日结关闭不会放宽任何成长准入条件。即使当前三项全部不可购买，也必须保留各自真实的营业日、口碑、区域、前置成长、教学、五区全开、熟练度和金币缺口；不得把其中任何一项临时提升为可预订。一次预订只会把所选项改为待激活，并让同一购买位的其他项目显示购买位占用；它不能满足或替换其他卡片的成长条件。`growth_recommendations()`、`purchase_status()` 和 `purchase()` 必须复用同一个严格购买状态。

固定路线的 10 个三项批次为：

1. 宽幅摊饼器、辣椒酱、成品饮品柜；
2. 宽容火候鏊子、火腿肠、成品豆奶；
3. 双位饮品加热器、肉松、油条炸锅；
4. 油温提示、油饼、库存容量 10；
5. 快速油条炸锅、香菜、现磨豆浆机；
6. 黑豆豆浆、快速豆浆机、两格暂存托盘；
7. 榨菜、核桃乳、多层蒸笼；
8. 菜包、快速双层蒸笼、里脊肉；
9. 糖油饼、红豆豆浆、黑芝麻乳；
10. 肉包、五谷豆浆、自动酱刷。

满台后依次为：高级鏊子、单次压饼、库存容量 14、高级饮品加热器、自动升篮、高级油条锅、自动投胚、自动加水、高级豆浆机、自动接杯、高级蒸笼。

卡面、悬停和按钮禁用状态必须由同一个展示状态生成。可购买项三者统一为“可预订，明日生效”；不可购买项的卡面取 `missing_requirements` 的第一项，悬停列出全部缺口。所有数值门槛使用实际进度 `x/y`；未知 ID 或未知原因显示“成长配置异常，无法预订”并记录错误，不允许回退为“暂不满足条件”。

### 8.2 购买事务

购买顺序固定：

1. 查询目录；
2. 判断是否已拥有；
3. 判断目标购买位是否为空；
4. 使用同一个严格准入函数检查日数、口碑、区域、教学、前置成长、五区全开和熟练度，不得过滤或替换任何条件；
5. 检查金币；
6. 一次性扣费并写入对应 pending 字段；
7. 返回扣费、购买位和激活日；
8. `GameSessionStore` 同步写盘并发信号。

`purchase_status()` 和 `purchase()` 必须调用同一个 `_evaluate_purchase()`，禁止预览可买、实际却因不同规则失败。

### 8.3 次日激活事务

`begin_next_business_day()`：

1. 仅允许在 `day_open == false` 时调用；
2. 复制当前成长快照作为回滚点；
3. 先验证安装位和内容位的目录定义仍有效；
4. 按“安装位→内容位”应用；
5. 新区域激活时同时开放基础设备、基础配方/商品，并把区域加入教学队列；
6. 新内容不赠库存；
7. 两项全部成功后清空 pending、营业日加1；
8. 任一失败则恢复回滚点，不加营业日、不吞金币；
9. 返回 `activated_growth_ids` 和 `restock_required_ids`。

### 8.4 熟练度记录

- 服务只接收已经由订单结算确认的结果；
- A级同时计入合格；B级只计合格；C级和失败不计；
- 饮品正确商品、正确温度且及时交付时计一次 `correct_temperature`；
- 饮品连续正确值失败即清零，但保留历史最佳；
- 套餐中的每个成功商品分别推进对应区域熟练度；
- 同一成品只能产生一次熟练度事件，事件带稳定 `settlement_id` 去重。

### 8.5 防卡关

追赶门槛是派生结果，不修改目录原值：

- 当前日大于区域目标窗口上限2天；
- 前一区域教学已完成；
- 原门槛按 `ceil(original * 0.8)` 计算；
- 最低仍为3份合格品；
- 只作用于下一区域开放，不作用于设备、配方或专精。

### 8.6 专精计算

专精等级从教学和熟练度派生，不允许 UI 直接写等级：

| 等级 | 普通区域 | 成品饮品 |
|---|---|---|
| 未评级 | 教学未完成 | 教学未完成 |
| 铜牌 | 教学完成 | 教学完成 |
| 银牌 | Q>=20 且 A>=8 | 正确温度>=20 且最佳连续>=8 |
| 金牌 | Q>=50 且 A>=25 | 正确温度>=50 且最佳连续>=25 |

`specialization_rank(area_id)` 返回 `none|bronze|silver|gold`。达到新等级时只把通知 ID 写入 `notified_specialization_ids`，不重复发放永久数值加成。

## 9. 生产状态机

所有计时只在以下条件同时满足时推进：

- 营业日开放；
- 游戏未暂停；
- 当前场景不是日结或设置遮罩；
- `delta > 0`。

### 9.1 成品饮品加热位

单个槽位状态：

```text
empty
  └─ load(product) → heating
heating
  └─ elapsed >= duration → ready_hot
ready_hot
  ├─ collect → empty + heated product
  └─ base/mid hot window elapsed → cooled
cooled
  └─ discard → empty + waste event
```

规则：

- 装入时原子扣除一份成品饮品库存；
- 只有允许加热的已解锁商品可装入；
- 高级设备 `ready_hot` 不超时但持续占位；
- `cooled` 不可作为常温订单交付，因为它经历了错误加热；
- 0.3秒输入宽限只影响在临界帧发起的 `collect()`；
- 每个槽位独立保存 `product_id`、`elapsed_seconds`、`hot_elapsed_seconds` 和状态。

### 9.2 油条炸锅

```text
idle
  └─ load(recipe, quantity) → loaded
loaded
  └─ start → frying
frying
  └─ elapsed >= cook_seconds → ready_safe
ready_safe
  ├─ lift/manual_or_auto → draining
  └─ safe elapsed → overcooking
overcooking
  ├─ lift → draining（保留当前品质）
  └─ decay elapsed >= 10s → burnt
draining
  └─ elapsed >= 2s → ready_to_collect
ready_to_collect
  └─ collect → idle + product batch
burnt
  └─ discard → idle + waste event
```

规则：

- 同批配方必须一致；
- `load()` 完整校验后一次性扣库存；
- 高级设备只扩容，不自动离油；
- `auto_lift` 只替代 `lift`，不替代配方和数量选择；
- `auto_load` 只在玩家已经确认 `job_profile` 后执行一次装载，不自行读取订单决定生产；
- 黄色预警为熟成前3秒，红色预警为安全期剩2秒；
- 焦糊整批不可交付，按原料成本进入浪费。

### 9.3 现磨豆浆机

```text
idle
  └─ load(recipe, quantity) → loaded
loaded
  ├─ add_water → water_added
  └─ auto_water_start → processing
water_added
  └─ start → processing
processing
  └─ elapsed >= cook_seconds → ready_safe / held
ready_safe
  ├─ collect → idle + products
  ├─ auto_cup → output_rack + idle
  └─ safe elapsed → quality_decay
quality_decay
  ├─ collect → idle + current-quality products
  ├─ auto_cup → output_rack + idle
  └─ decay elapsed >= 10s → spoiled
held (advanced)
  ├─ collect → idle + products
  └─ auto_cup → output_rack + idle
spoiled
  └─ discard → idle + waste event
```

自动接杯架：

- 固定4格；
- 一批全部放得下才自动转移，否则设备继续占用；
- 输出架产品保留 `product_id`、品质和完成顺序；
- 输出架不无限保鲜：普通成品保持当前品质60秒，之后报废；
- 自动接杯只释放机器，不产生免费容量。

### 9.4 蒸笼

整机只保存设备等级和固定4个层槽。可用层数由等级决定，未开放层保持 `locked`。

每层状态：

```text
locked
empty
  └─ load(recipe, quantity) → loaded
loaded
  └─ start → steaming
steaming
  └─ elapsed >= cook_seconds → ready_safe / held
ready_safe
  ├─ collect → empty + products
  └─ safe elapsed → oversteaming
oversteaming
  ├─ collect → empty + current-quality products
  └─ decay elapsed >= 10s → spoiled
held (advanced)
  └─ collect → empty + products
spoiled
  └─ discard → empty + waste event
```

规则：

- 每层独立保存和推进；
- 加载一层只扣该层原料；
- 一层只允许一种配方；
- 操作、收取、丢弃或显示其他层不得修改本层时间；
- 设备升级只改变可用层数和新批次时间，不重算已经开始的批次；
- 暂停、退出和重新载入不推进离线时间；
- 熟成前3秒黄色提示，安全期剩2秒红色提示；
- 高级层熟成后进入 `held`，仍占层。

### 9.5 煎饼成品暂存托盘

托盘固定两个槽：

```text
locked / empty
empty
  └─ store(product_snapshot) → fresh
fresh
	├─ serve_active_order → empty
	├─ discard → empty + waste event
	└─ elapsed >= 20s → aging
aging
	├─ serve_active_order → empty（带新鲜度扣分）
	├─ discard → empty + waste event
	└─ elapsed >= 60s → stale
stale
	├─ serve_active_order → empty（固定扣20分）
	└─ discard/auto_day_end_clear → empty + waste event
```

成品快照至少包含：

```gdscript
{
    "product_instance_id": &"",
    "product_id": &"product.pancake.custom",
    "source_order_template_id": &"",
    "heat_preference": &"",
    "ingredient_ids": PackedStringArray(),
    "sauce_ids": PackedStringArray(),
    "fold_snapshot": {},
    "dimension_scores": {},
    "serving_score_basis": {},
    "base_score": 0.0,
    "stored_elapsed_seconds": 0.0,
}
```

交付不使用 `source_order_template_id` 作为硬门槛。暂存煎饼可以交给任意当前活动订单，但必须依据成品快照重新计算该订单下的火候、酱料、配料、订单和等待时间分，再扣新鲜度分；差异只能影响评分和结算反馈，不能替玩家拒绝错单。递餐期间暂停鏊上在制煎饼，付款后为下一位顾客恢复原制作阶段。

新鲜度 v0：

- 0～20秒：扣0分；
- 20～60秒：线性扣0～20分；
- 60秒及以后：固定扣20分，标记为 `stale`，仍可交付。

## 10. 生产服务 API

`FiveAreaProductionService` 持有饮品槽、炸锅、豆浆机、蒸笼和豆浆输出架模型。

```gdscript
signal machine_changed(device_id: StringName, snapshot: Dictionary)
signal product_created(product: Dictionary)
signal waste_recorded(entry: Dictionary)
signal stock_changed(stock_id: StringName, current: int)

func configure(progression: RefCounted, inventory: RefCounted) -> void
func advance_time(delta: float) -> void
func machine_snapshot(device_id: StringName) -> Dictionary
func all_machine_snapshots() -> Dictionary

func load_drink(slot_index: int, product_id: StringName) -> Dictionary
func collect_drink(slot_index: int) -> Dictionary
func discard_drink(slot_index: int) -> Dictionary

func load_batch(device_id: StringName, recipe_id: StringName, quantity: int) -> Dictionary
func perform_action(device_id: StringName, action_id: StringName) -> Dictionary
func collect_batch(device_id: StringName) -> Dictionary
func discard_batch(device_id: StringName) -> Dictionary

func load_steamer_layer(layer_index: int, recipe_id: StringName, quantity: int) -> Dictionary
func start_steamer_layer(layer_index: int) -> Dictionary
func collect_steamer_layer(layer_index: int) -> Dictionary
func discard_steamer_layer(layer_index: int) -> Dictionary

func output_rack_snapshot() -> Array[Dictionary]
func collect_output_rack(slot_index: int) -> Dictionary
func snapshot() -> Dictionary
func load_snapshot(snapshot: Dictionary) -> Dictionary
```

库存消耗必须先验证所有条件，再一次性调用 `consume_many()`。任何失败都不能部分扣库存或部分装载。

所有可交付成品统一为产品实例：

```gdscript
{
    "product_instance_id": &"runtime.product.000001",
    "area_id": &"area.youtiao",
    "product_id": &"product.youtiao.plain",
    "quantity": 1,
    "quality": 100.0,
    "grade": &"A",
    "temperature_mode": &"room_temperature",
    "composition": {},
    "status": &"available",
    "owner_order_id": &"",
}
```

`product_instance_id` 在一个存档内唯一。状态固定为 `available|reserved|consumed|wasted`；`consumed` 和 `wasted` 是终态，不得再次使用。

### 10.1 成品归属与取出

除豆浆自动接杯架和煎饼成品托盘外，首版不设置通用成品仓或隐形服务柜。

- 饮品、油条、豆浆和蒸品未分配前继续占用设备或可见输出架；
- 当前活动订单可以逐项接收已经匹配的成品实例；
- 等待订单只用于让玩家提前规划，不能接收或冻结成品；
- 从设备取出时必须同时指定当前活动订单和目标 item index；
- `GameSessionStore` 先调用订单预览，再从设备取出，再把实例附加到订单；预览同时返回容量和匹配结果；
- 事务任一步失败时同时回滚生产和订单快照；
- 一次只取出目标订单需要的数量，多余批次继续占用机器；
- 附加到订单的实例进入 `reserved`，不能改投其他订单；
- 订单完成时进入 `consumed`；订单错单、婉拒或超时时进入 `wasted` 并写浪费事件。

这条规则防止批量生产变成无限成品库存，也保证高级设备保温、输出架和煎饼托盘仍有明确价值。

包括煎饼暂存托盘在内的可交付成品，即使商品、配方或温度不匹配，也允许被玩家放入活动订单，错误在正式提交时结算；否则系统会替玩家消除错单。`preview_attach_product()` 必须返回 `will_match` 和 `mismatch_reasons`，但只有槽位已满、实例终态、订单非活动或已有递餐/付款事务时才阻止附加。

## 11. 订单生成与结算算法

### 11.1 确定性随机

- 新游戏生成并保存 `order_rng_seed`；测试可以注入固定 seed；
- 每生成一个订单递增 `order_sequence`；
- 单次订单 RNG 使用 `hash(order_rng_seed, order_sequence)` 初始化；
- 禁止使用全局随机状态决定订单；
- 保存并恢复后，下一个订单必须与未退出时一致。

### 11.2 候选过滤

普通订单候选过滤顺序：

1. 区域已永久解锁；
2. 区域教学已完成；
3. 商品、配方和必需小料永久解锁；
4. 设备能够生产该商品；
5. 模板数据通过目录校验。

普通订单不检查当前库存，否则备货和缺货婉拒失去意义。

保护性教学单不检查当前库存。新区域生效后的首位教学顾客必须出现；库存为 0 时，动态引导的第一步改为指向对应槽位并提示长按补货，不赠送免费库存。

### 11.3 教学优先级

1. 若已有 `active_tutorial_area_id`，且当天尚未生成教学单，生成该区域固定单品教学单；五个区域都允许在库存为 0 时生成，并从长按补货开始引导；
2. 教学单固定为当天第1位顾客；若当天队列已经生成，则在下一营业日第1位出现；
3. 教学期间不生成三件套，也不组合其他未教学内容；
4. 成功完成后标记教学完成，次日才从队列激活下一区域教学；
5. 主动跳过或连续失败2次后结束教学，但不给熟练度；
6. 同一天只处理一个区域教学。

区域教学以完成整套制作与交付流程为通过条件，不设置 70 分或其他最低评分门槛；评分仍照常进入账单与熟练度统计。

### 11.4 区域权重

每个可用区域先取得原始权重：

- 煎饼：100；
- 新区域教学完成但合格数 `< 3`：15；
- 合格数 `3～7`：25；
- 合格数 `>= 8`：35。

选择时对当前候选区域归一化。套餐按权重无放回抽取不同区域，避免同一设备被包装成假套餐。

### 11.5 套餐复杂度

五区未全部解锁或仍有活动教学时：100% 单品。

五区全开且无活动教学时：

- 单品：72%；
- 双品：20%；
- 三件：8%。

若候选区域不足对应数量，向下回退到可生成的最高复杂度，不重新掷骰。

复杂度系数：

| 复杂度 | 金币 | 成功口碑 | 错单损失 | 缺货婉拒 |
|---|---:|---:|---:|---:|
| 单品 | 1.00 | 1.00 | 1.00 | 0.50 |
| 双品 | 1.15 | 1.50 | 1.50 | 1.00 |
| 三件 | 1.30 | 2.00 | 2.00 | 1.50 |

金币最终向最近整数四舍五入，最低为1。口碑变更也四舍五入，但缺货婉拒最低损失为1。

### 11.6 商品与温度

- 区域选中后，在该区域已解锁产品模板中按目录 `order_weight` 抽取；
- 基础产品 `order_weight = 100`；
- 中价产品 `70`；高价产品 `40`；
- 饮品教学完成后，允许加热的饮品有35%概率要求 `heated`；
- 未要求加热时 `temperature_mode = room_temperature`；
- 订单文案由结构化数据生成，禁止另存一份自由文本温度判断。

### 11.7 顾客耐心

单项基础耐心：

| 区域 | 秒数 |
|---|---:|
| 煎饼 | 72 |
| 饮品 | 24 |
| 油条 | 36 |
| 豆浆 | 32 |
| 蒸品 | 44 |

套餐耐心：

```text
max(item_patience) + 0.6 × sum(other_item_patience) + 10 × (item_count - 1)
```

教学单不限时，不消耗 `remaining_patience_seconds`；界面必须明确显示“教学单·不限时”。普通订单的计算结果保留到0.1秒。

### 11.8 订单结构

```gdscript
{
    "order_id": &"runtime.order.000001",
    "sequence": 1,
    "complexity": &"single",
    "items": [
        {
            "area_id": &"area.packaged_drink",
            "product_id": &"product.packaged_drink.soy_milk",
            "quantity": 1,
            "temperature_mode": &"heated",
            "pancake_template_id": &"",
            "prepared_product_instance_ids": PackedStringArray(),
        }
    ],
    "patience_seconds": 24.0,
    "remaining_patience_seconds": 24.0,
    "tutorial_no_countdown": false,
    "teaching_area_id": &"",
    "base_coins": 5,
    "reward_multiplier": 1.0,
    "production_started": false,
    "production_source_ids": PackedStringArray(),
    "status": &"waiting",
}
```

队列固定最多4单：位置0是唯一 `active` 订单，位置1～3为 `waiting`。只有非教学的活动订单消耗顾客耐心、接收成品并允许交付或婉拒；教学活动订单不限时，等待订单激活前不消耗耐心。等待订单完整展示，玩家可以据此提前启动批次，但成品必须继续占用机器或可见暂存设施。活动订单进入终态后，第一张等待订单转为活动，随后补满队列。

当前活动订单存在时，首次执行任何消耗生产原料的动作，控制器必须调用 `mark_production_started()`。补货、丢弃成品和纯 UI 选择不计为开始生产。等待订单不能被标记为开始生产。

### 11.9 交付结算

订单状态：`waiting → active → completed/refused/failed/expired`，终态不可再次结算。

结算顺序：

1. 校验订单仍活动；
2. 校验所有必需 item 已附加足量 `reserved` 成品；
3. 再次校验商品、数量、温度和煎饼要求；
4. 生成一次性 `settlement_id`；
5. 把所有保留成品设为 `consumed`；
6. 计算金币、口碑、熟练度和浪费；
7. 更新日账本；
8. 推进顾客队列；
9. 保存；
10. 发出结算与队列信号。

缺少任一 item 时不能按下正式交付；玩家可以选择“提交现有内容”，此操作直接按错单结算，所有已保留成品进入 `wasted`。部分正确的套餐不发部分金币，日结逐项显示错误原因。

口碑 v0 规则：

- 所有商品最终等级均为 A：基础成功口碑 `+4`；
- 所有商品最终等级均为 A/B 且至少一项为 B：基础成功口碑 `+3`；
- 所有商品均可交付但至少一项为 C：基础成功口碑 `+1`；
- 错单或耐心耗尽：基础口碑 `-2`；
- 未开始生产的缺货婉拒：基础口碑 `-1`。

基础口碑乘第11.5节复杂度系数后四舍五入；非零结果的绝对值最低为1。

缺货婉拒始终允许，但 `production_started == true` 时按错单损失而不是婉拒损失处理。玩家确认前 UI 必须显示预计口碑损失。

## 12. OrderService API

```gdscript
signal queue_changed(snapshot: Array[Dictionary])
signal order_settled(result: Dictionary)
signal tutorial_state_changed(snapshot: Dictionary)

func configure(catalog: Script, progression: RefCounted, inventory: RefCounted, seed: int) -> void
func ensure_queue(target_size: int = 4) -> Dictionary
func current_order() -> Dictionary
func waiting_orders() -> Array[Dictionary]
func activate_order(order_id: StringName) -> Dictionary
func preview_refusal(order_id: StringName) -> Dictionary
func refuse_order(order_id: StringName) -> Dictionary
func mark_production_started(order_id: StringName, source_instance_id: StringName) -> Dictionary
func preview_attach_product(order_id: StringName, item_index: int, product: Dictionary) -> Dictionary
func attach_product(order_id: StringName, item_index: int, product: Dictionary) -> Dictionary
func settle_order(order_id: StringName, submit_incomplete: bool = false) -> Dictionary
func advance_time(delta: float) -> Array[Dictionary]
func snapshot() -> Dictionary
func load_snapshot(snapshot: Dictionary) -> Dictionary
```

订单格式化使用：

```gdscript
static func format_title(order: Dictionary) -> String
static func format_requirements(order: Dictionary) -> String
static func normalized_temperature_mode(value: Variant) -> StringName
```

未知温度值返回数据错误，不猜测为常温。

## 13. 日结与临界提醒

### 13.1 日账本事件

业务服务不直接拼日结文字。所有变化写入标准事件：

```gdscript
{
    "event_id": &"",
    "kind": &"sale|stock_cost|waste|order_failure|refusal|reputation|mastery",
    "area_id": &"",
    "source_id": &"",
    "quantity": 0,
    "coins_delta": 0,
    "reputation_delta": 0,
    "details": {},
}
```

`BusinessReportService.build_bill()` 必须保证：

- 总收入等于所有 sale 之和；
- 现金成本等于当天实际补货付款与其他真实扣款之和；
- 净利润等于总收入减现金成本；
- 各区域浪费之和等于总浪费；
- 订单状态数量之和等于当天进入终态的订单数；
- 熟练度增量可追溯到 settlement ID。

原料在补货时已经付款，因此报废报表的“损失成本”是现金成本的归因子集，不能再次计入现金成本或再次扣金币。

公开 API：

```gdscript
signal ledger_changed(snapshot: Dictionary)

func begin_day(day: int) -> void
func record_event(event: Dictionary) -> Dictionary
func build_bill() -> Dictionary
func snapshot() -> Dictionary
func load_snapshot(snapshot: Dictionary) -> Dictionary
func close_day() -> Dictionary
```

`event_id` 必须唯一；重复事件返回成功但 `changed = false`，避免保存恢复或重复信号造成二次记账。

### 13.2 AttentionService

输入：全部机器快照、豆浆输出架、托盘快照。

每个条目统一输出：

```gdscript
{
    "source_id": &"",
    "area_id": &"",
    "severity": &"yellow|red",
    "seconds_to_irreversible_loss": 0.0,
    "status_key": &"",
}
```

排序：

1. 红色先于黄色；
2. 距不可逆损失时间更短者优先；
3. 时间相同按区域顺序；
4. 只返回前三项。

不得把普通加工中项目塞入提醒条。

公开 API：

```gdscript
static func build_attention(
    machine_snapshots: Dictionary,
    output_rack: Array[Dictionary],
    tray_snapshot: Dictionary
) -> Array[Dictionary]
```

### 13.3 DailyGoalService

只有五区全部解锁且所有区域教学完成后才生成每日目标。

生成规则：

1. 收集达到银牌的区域目标；
2. 用 `hash(order_rng_seed, current_day, "daily_goal")` 建立确定性 RNG；
3. 在符合条件的区域目标中等权抽取；
4. 若尚无银牌区域，使用 `goal.signature.combo_two_no_failure`；
5. 一天只生成一个目标，保存恢复不得重抽；
6. 目标完成后返回带唯一 `reward_event_id` 的奖励请求；`GameSessionStore` 成功应用金币与口碑后，再标记 `rewarded = true`；
7. 未完成目标在日结后失效，不跨日累计，也不施加惩罚。

公开 API：

```gdscript
signal daily_goal_changed(snapshot: Dictionary)
signal daily_goal_completed(result: Dictionary)

func begin_day(context: Dictionary) -> Dictionary
func record_business_event(event: Dictionary) -> Dictionary
func current_goal() -> Dictionary
func snapshot() -> Dictionary
func load_snapshot(snapshot: Dictionary) -> Dictionary
```

目标状态至少包含：

```gdscript
{
    "goal_id": &"",
    "day": 0,
    "area_id": &"",
    "progress": 0,
    "target": 0,
    "failed_condition": false,
    "completed": false,
    "rewarded": false,
}
```

所有进度来自日账本标准事件，不从 UI 文案或场景节点推断。

## 14. 场景和 UI 合同

### 14.1 目标场景

新增正式主场景：

`scenes/gameplay/five_area_workstation.tscn`

`main_page_prototype.tscn` 只作为布局参考，不能直接承担业务状态。现有 `workstation.tscn` 在煎饼站拆分完成前保持可运行，禁止在拆分过程中破坏已有煎饼验证。

### 14.2 固定场景结构

以下稳定结构必须写入 `.tscn`，不能由脚本运行时创建：

```text
FiveAreaWorkstation
└─ SafeArea
   ├─ Header
   │  ├─ DayLabel
   │  ├─ CoinsLabel
   │  ├─ ReputationLabel
   │  ├─ PauseButton
   │  └─ SettingsButton
   ├─ CustomerQueue
   │  ├─ OrderCard1
   │  ├─ OrderCard2
   │  ├─ OrderCard3
   │  └─ OrderCard4
   ├─ AttentionRail
   │  ├─ AttentionItem1
   │  ├─ AttentionItem2
   │  └─ AttentionItem3
   ├─ Worktop
   │  ├─ PancakeStation
   │  │  └─ SweetFlourSauceBrush
   │  ├─ PackagedDrinkStation
   │  ├─ YoutiaoStation
   │  ├─ FreshSoyMilkStation
   │  └─ SteamerStation
   ├─ PancakeHoldingTray
   │  ├─ Slot1
   │  └─ Slot2
   ├─ MaterialDock
   │  ├─ Slot01
   │  ├─ ...
   │  └─ Slot18
   ├─ FeedbackLayer
   ├─ DailyBillOverlay
   ├─ PauseOverlay
   └─ SettingsOverlay
```

`MaterialDock` 固定为单行 18 格，`Slot01` 至 `Slot18` 必须全部预先写入 `.tscn`，按工作台区域顺序绑定稳定槽位；不得改回 12 格、增加第二排或把甜面酱刷塞入材料槽。未解锁材料显示锁定内容或锁定盖板，但节点位置不移动。

当前稳定映射：`Slot01–Slot03` 为豆料区。五谷未解锁时三格整格显示黄豆、黑豆、红豆；五谷解锁后切换为 `.tscn` 预制的上下六格，上排仍为黄豆、黑豆、红豆，下排第一格为五谷，后两格保留锁定。`Slot04–Slot06` 为原味油条、油饼、糖油饼面胚库存，不再显示或写入炸物成品。豆料和面胚统一使用“移动超过 10px 拖入设备、原地长按 0.2 秒补货”的互斥手势；短按面胚槽用于选择自动投胚配方。

油条成品沥油后留在炸篮，订单商品点击可直接取用；仅原味油条可从炸篮拖入煎饼。旧存档的 `prepared_product_slots` 只作为不可见兼容交付来源，交付或日结后清空，不再接收新成品。

正式场景预置 `TutorialGuideOverlay`。暖金箭头、浅米提示牌和深棕文字只读取输入，永不拦截鼠标；引导层不得绘制目标边框、填充或阴影，不得覆盖或改变工作台原有颜色。它根据订单、库存和设备状态指向唯一下一步，等待阶段指向设备状态区。

预先创建最大数量的稳定槽位：材料18格、饮品4位、蒸笼4层、托盘2格、提醒3条、订单4张。未开放项隐藏或锁定，不在运行时创建/销毁结构。

`DailyBillOverlay` 固定包含：

```text
DailyBillOverlay
├─ Summary
│  ├─ RevenueLabel
│  ├─ CashCostLabel
│  ├─ NetProfitLabel
│  └─ ReputationLabel
├─ WasteBreakdown
├─ MasteryBreakdown
├─ InstallRecommendations
│  ├─ InstallOption1
│  ├─ InstallOption2
│  └─ InstallOption3
├─ ContentRecommendations
│  ├─ ContentOption1
│  ├─ ContentOption2
│  └─ ContentOption3
├─ NearestLockedGoal
├─ TomorrowPreview
└─ BeginNextDayButton
```

购买后只刷新对应购买位；另一个购买位仍可操作。`BeginNextDayButton` 必须显示两项待激活内容和待补货清单。

### 14.3 站点子场景

新增：

- `scenes/gameplay/stations/pancake_station.tscn`；
- `scenes/gameplay/stations/packaged_drink_station.tscn`；
- `scenes/gameplay/stations/youtiao_station.tscn`；
- `scenes/gameplay/stations/fresh_soy_milk_station.tscn`；
- `scenes/gameplay/stations/steamer_station.tscn`；
- `scenes/gameplay/components/pancake_holding_tray.tscn`；
- `scenes/ui/daily_bill_overlay.tscn`；
- `scenes/ui/attention_rail.tscn`。

站点脚本只提供：

```gdscript
signal intent_requested(intent: Dictionary)
func apply_snapshot(snapshot: Dictionary) -> void
func set_locked(locked: bool, reason_text: String) -> void
func set_interaction_enabled(enabled: bool) -> void
```

业务操作以 intent 传给控制器，例如：

```gdscript
{
    "type": &"load_steamer_layer",
    "layer_index": 1,
    "recipe_id": &"recipe.steamer.vegetable_bun",
    "quantity": 2,
}
```

### 14.4 煎饼拆分约束

- 保留 `PancakeModel`、`PancakeScorer`、`IngredientModel`、`PancakeFoldModel` 和输入采样器；
- 从 `workstation.gd` 提取站点绑定，不重写摊面模拟和评分；
- 煎饼完成时产出结构化成品快照，交给订单或托盘；
- 当前包装用“托盘”与“成品暂存托盘”必须使用不同节点名、ID和文案，避免语义冲突；
- 暂存托盘节点不得复用 `PancakeFoldModel.can_use_tray()` 的包装托盘含义。

### 14.5 输入和可访问性

- 所有核心动作支持鼠标按下/拖动/释放；
- 不能只有 hover 才能得知锁定条件或临界状态；
- 装饰子节点使用 `mouse_filter = IGNORE`，不拦截按钮和拖放；
- 黄色/红色必须同时配图标和文字；
- 每个区域使用不同完成音效；静音时仍可完成；
- 遮罩打开时暂停生产、顾客耐心和托盘新鲜度；
- 场景刷新不得改变服务状态。

## 15. GameSessionStore 协调合同

新增信号：

```gdscript
signal inventory_changed(snapshot: Dictionary)
signal production_changed(snapshot: Dictionary)
signal order_queue_changed(snapshot: Array[Dictionary])
signal attention_changed(snapshot: Array[Dictionary])
signal business_bill_changed(snapshot: Dictionary)
signal daily_goal_changed(snapshot: Dictionary)
signal save_rejected(reason: StringName)
```

`GameSessionStore` 是唯一允许写正式存档文件的对象。其他服务返回快照或发内部信号，不自行写文件。

每个标准业务事件由 `GameSessionStore` 依次投递给 `BusinessReportService` 和 `DailyGoalService`，两者都用 `event_id` 去重。金币、口碑和熟练度的实际修改只执行一次，报表与目标服务只消费结果事件，不能再次修改同一结算。

新增/替换公开 API：

```gdscript
func begin_new_game() -> Dictionary
func continue_game() -> Dictionary
func reset_incompatible_development_save() -> Dictionary
func session_snapshot() -> Dictionary
func progression_snapshot() -> Dictionary
func production_snapshot() -> Dictionary
func order_snapshot() -> Dictionary
func daily_goal_snapshot() -> Dictionary
func purchase_growth(growth_id: StringName) -> Dictionary
func begin_next_business_day() -> Dictionary
func dispatch_workstation_intent(intent: Dictionary) -> Dictionary
func pause_business() -> void
func resume_business() -> void
func end_business_day() -> Dictionary
```

场景只能通过这些 API 或控制器访问业务，不直接取得可变服务引用。测试可以在服务单元层直接构造服务。

## 16. 文件改造清单

### 16.1 新增

数据：

- `scripts/data/five_area_catalog.gd`

模型：

- `scripts/gameplay/packaged_drink_heater_model.gd`
- `scripts/gameplay/youtiao_fryer_model.gd`
- `scripts/gameplay/fresh_soy_milk_model.gd`
- `scripts/gameplay/steamer_model.gd`
- `scripts/gameplay/pancake_holding_tray_model.gd`
- `scripts/gameplay/product_instance_model.gd`
- `scripts/gameplay/stock_inventory_model.gd`

服务：

- `scripts/services/five_area_production_service.gd`
- `scripts/services/business_report_service.gd`
- `scripts/services/attention_service.gd`
- `scripts/services/daily_goal_service.gd`

控制与视图：

- `scripts/ui/five_area_workstation_controller.gd`
- `scripts/ui/stations/pancake_station_view.gd`
- `scripts/ui/stations/packaged_drink_station_view.gd`
- `scripts/ui/stations/youtiao_station_view.gd`
- `scripts/ui/stations/fresh_soy_milk_station_view.gd`
- `scripts/ui/stations/steamer_station_view.gd`
- `scripts/ui/pancake_holding_tray_view.gd`
- `scripts/ui/attention_rail_view.gd`
- `scripts/ui/daily_bill_view.gd`

场景按第14节新增。

### 16.2 重写或扩展

- `scripts/services/workstation_progression_service.gd`：切换到新目录、双购买位、区域与熟练度；
- `scripts/services/order_service.gd`：重写为确定性多商品订单；
- `scripts/services/customer_queue_service.gd`：改为保存 order ID 和顾客表现，不自行轮转旧订单；
- `scripts/services/game_session_store.gd`：存档版本3、协调所有服务；
- `scripts/services/hold_refill_service.gd`：改用新库存模型、稳定库存 ID 和日账本事件；
- `scripts/gameplay/workstation.gd`：仅做煎饼站拆分，禁止顺手重写模拟；
- `scripts/gameplay/pancake_scorer.gd`：只增加成品快照输出适配，不改变既有评分维度；
- `scenes/main/start_menu.tscn`：处理不兼容开发存档提示；
- `project.godot`：完成正式切换后将主入口指向新流程。

### 16.3 退出正式运行时

完成切换并通过回归后，下列历史模块不得再被正式入口引用：

- `scripts/data/workstation_expansion_catalog.gd`；
- `scripts/services/expansion_production_service.gd`；
- `scripts/gameplay/equipment_batch_model.gd`；
- `scripts/ui/initial_unlock_workstation_adapter.gd`；
- `scenes/gameplay/initial_unlock_workstation.tscn` 的历史三设备入口。

可以暂时保留文件用于对照，但测试必须断言正式依赖图中不存在引用。确认无用后再单独删除，不能在功能重构中顺带破坏历史验证证据。

## 17. TDD 测试矩阵

### 17.1 目录与新存档

新增：

- `tests/unit/five_area_catalog_self_check.gd`；
- `tests/unit/five_area_new_save_self_check.gd`；
- `tests/unit/stock_inventory_self_check.gd`；
- `tests/unit/five_area_refill_self_check.gd`。

必须覆盖：

- ID 唯一、引用有效、前置无环；
- 新游戏只开放煎饼；
- 辣酱和火腿库存键不会解锁内容；
- 成品豆奶与现磨豆浆完全分离；
- 版本2开发存档被拒绝，不执行迁移；
- 新存档 JSON 往返后数据一致。
- 库存增减原子、容量限制、未知 ID 和补货逐单位扣费正确；
- 未解锁库存不能补货，也不能反推永久解锁。

### 17.2 成长与购买

新增 `tests/unit/five_area_progression_self_check.gd`。

覆盖：

- 安装位和内容位可在同一天各买一项；
- 同一购买位第二项失败且不扣金币；
- 预览和实际购买准入一致；
- 次日按安装→内容顺序激活；
- 激活失败整体回滚；
- 新区域不赠库存并进入教学队列；
- 熟练度 settlement 去重；
- 追赶门槛只影响下一区域。

### 17.3 各设备模型

新增：

- `tests/unit/packaged_drink_heater_self_check.gd`；
- `tests/unit/youtiao_fryer_self_check.gd`；
- `tests/unit/fresh_soy_milk_self_check.gd`；
- `tests/unit/steamer_layers_self_check.gd`；
- `tests/unit/pancake_holding_tray_self_check.gd`。

共同覆盖：

- 未拥有设备拒绝；
- 未解锁配方拒绝；
- 未满容量允许启动；
- 混配方拒绝；
- 库存不足不部分扣除；
- 状态转换、临界时间、品质和报废；
- 高级保温仍占容量；
- 暂停和载入不产生离线时间；
- 自动化不产生免费库存。
- 除豆浆输出架和煎饼托盘外不存在通用成品缓冲；未分配成品继续占用设备；
- 按份取出批次时，多余数量继续留在机器。

专项覆盖：

- 饮品0.3秒边界与冷却状态；
- 高级炸锅没有隐式自动升篮；
- 豆浆输出架满时不释放机器；
- 蒸笼四层无串扰；
- 托盘可向活动订单交付匹配或不匹配成品、两格上限、60秒后固定扣20分和日结清空。
- 煎饼85/70/60等级边界保持不变，托盘新鲜度扣分后正确重算等级。

### 17.4 订单

新增 `tests/unit/five_area_order_generation_self_check.gd`。

覆盖：

- 固定 seed 与 sequence 生成相同订单；
- 保存恢复后下一个订单一致；
- 普通订单不按当前库存过滤；
- 五区域教学单在库存为 0 时仍生成，并保留真实补货成本；
- 同日只教学一个区域；
- 五区前只有单品；
- 五区后72/20/8分支通过边界 RNG 用例；
- 套餐区域不重复；
- 锁定配方不出现；
- 温度缺省归一化为常温，未知值报错；
- 终态订单不能重复结算；
- 套餐不发部分奖励。
- 只有活动订单能接收成品；等待订单不能冻结成品；
- 普通机器错配商品可以附加并在提交时判错，托盘错配则在附加前拒绝；
- 订单完成、婉拒或超时后，保留成品只进入一个终态且不能复用。

### 17.5 报表和提醒

新增：

- `tests/unit/business_report_self_check.gd`；
- `tests/unit/attention_service_self_check.gd`。
- `tests/unit/daily_goal_service_self_check.gd`。

覆盖：

- 日结分项与总额守恒；
- 浪费分析值不二次扣金币；
- settlement ID 不重复计熟练度；
- 红色优先、按损失时间排序、最多三条；
- 普通加工项目不进入提醒。
- 未满台不生成目标；固定日和seed生成相同目标；银牌候选、金牌奖励、失败条件和一次性奖励正确；
- 保存恢复不重抽目标，未完成目标不跨日。

### 17.6 集成与场景

新增：

- `tests/integration/five_area_scene_contract_self_check.gd`；
- `tests/integration/five_area_unlock_flow_self_check.gd`；
- `tests/integration/five_area_order_tutorial_self_check.gd`；
- `tests/integration/five_area_concurrent_production_self_check.gd`；
- `tests/integration/five_area_save_resume_self_check.gd`；
- `tests/integration/pancake_holding_tray_interaction_self_check.gd`；
- `tests/integration/five_area_visual_smoke.gd`。

场景合同检查固定节点、最大槽位、脚本类型、信号连接和 `mouse_filter`。禁止用只检查节点存在的测试替代真实动作链。

### 17.7 真实运行与人工验收

需要单独记录：

- GPU非headless打开正式主场景；
- 鼠标完成五区域各一份商品；
- 同时运行油条、豆浆和两层蒸笼；
- 将煎饼放入托盘再交付匹配订单；
- 静音条件下识别所有临界状态；
- 日结购买两个不同购买位并在次日看到正确安装；
- 从新游戏连续玩到五区全开。

## 18. 自动检查入口

新增 `tools/run_five_area_checks.ps1`，按层执行：

1. 目录和纯模型；
2. 成长、订单、报表服务；
3. 新存档和场景合同；
4. 并行生产和存档恢复；
5. 既有煎饼核心回归。

每个 Godot headless 命令必须显式传入唯一可写日志：

```powershell
& $godot --headless --path . --log-file "$env:TEMP\projectcake-five-area-catalog.log" -s res://tests/unit/five_area_catalog_self_check.gd
```

runner 遇到首个失败返回非0，但保留所有已完成测试日志。最终还要执行 `git diff --check`。

## 19. 分阶段实施顺序

### F0：目录与失败测试

1. 新增五区域目录和目录校验；
2. 写新存档、稳定 ID 和旧存档拒绝测试；
3. 不接场景、不删旧代码。

门槛：目录测试和新存档测试通过。

### F1：成长与存档

1. 重写成长服务；
2. 实现双购买位和次日事务；
3. GameSessionStore 切换版本3；
4. 接入新游戏和开发存档重建提示。

门槛：成长、扣费、激活、回滚、新存档持久化全部通过。

### F2：订单、账本与教学

1. 重写 OrderService；
2. 实现确定性 RNG、教学队列和多商品结构；
3. 实现 BusinessReportService；
4. 暂时使用模型级产品实例完成测试。

门槛：固定 seed、套餐、缺货、温度、结算和日结守恒通过。

### F3：成品饮品与油条

1. 先写模型测试；
2. 实现饮品加热位和炸锅；
3. 接入库存与订单；
4. 建立两个站点 `.tscn` 和真实鼠标路径。

门槛：两设备单独和并行运行，过火与温度错误可见。

### F4：现磨豆浆与蒸笼

1. 实现豆浆机和输出架；
2. 实现蒸笼四层模型；
3. 接入自动化、提醒和存档恢复；
4. 建立站点场景。

门槛：四层无串扰、无离线推进、输出架阻塞正确。

### F5：煎饼站与成品托盘

1. 在不改变模拟/评分的前提下提取煎饼站；
2. 定义成品实例快照；
3. 实现双格托盘和匹配；
4. 接入临界提醒和日结浪费。

门槛：既有煎饼回归通过，托盘无复制/错配/跨日保留。

### F6：正式主场景与日结 UI

1. 组装五区域正式场景；
2. 接入4张订单卡、3条提醒、双购买位和锁定预览；
3. 切换主入口；
4. 断开历史三设备正式引用。

门槛：场景合同、GPU运行、真实鼠标路径和日结次日激活通过。

### F7：专精、招牌目标与22日标定

1. 接入派生的铜/银/金专精；
2. 实现 DailyGoalService，每天生成一个可选招牌目标；
3. 记录三轮完整22日真人试玩；
4. 只在目录中调整价格、门槛、权重和时间。

门槛：不存在连续超过两日无目标；五区解锁窗口和失败率达到设计指标。

## 20. 各阶段禁止顺手修改的内容

- F0～F2 不重做主界面美术；
- F3～F4 不重写煎饼模拟；
- F5 不调整套餐经济；
- F6 不新增排行榜、随机价格、饮品加料或蒸品预制；
- F7 调数值不改稳定 ID 和服务 API；
- 任何阶段都不通过运行时动态创建替代应存在于 `.tscn` 的稳定结构；
- 任何自动 PASS 都不能把未完成的真实鼠标和人工验收标为完成。

## 21. 实施完成清单

代码完成：

- [ ] 五区域目录是唯一运行时目录；
- [ ] 新存档版本3只开放煎饼；
- [ ] 双购买位和次日激活原子化；
- [ ] 五区域生产状态机全部实现；
- [ ] 蒸笼四层独立；
- [ ] 托盘两格和新鲜度实现；
- [ ] 多商品订单和教学算法实现；
- [ ] 日结分项守恒；
- [ ] 临界提醒最多三条；
- [ ] 历史鸡蛋仔入口不再被正式运行时引用。

验证完成：

- [ ] 目录/模型测试通过；
- [ ] 服务/存档测试通过；
- [ ] 场景合同测试通过；
- [ ] 既有煎饼回归通过；
- [ ] GPU非headless运行通过；
- [ ] 五区域真实鼠标路径通过；
- [ ] 人工视觉通过；
- [ ] 至少三轮22日试玩记录完成；
- [ ] `git diff --check` 通过。

## 22. 已冻结与可调边界

已冻结，不得在实现中自行改动：

- 五区域顺序、稳定 ID 和区域职责；
- 双购买位、次日生效和不赠库存；
- 普通订单不按当前库存过滤；
- 同日只教学一个区域；
- 高级炸锅不自带自动升篮；
- 蒸笼无自动生产；
- 托盘固定两格、不跨日；
- 新存档不兼容历史开发存档；
- 场景结构归 `.tscn`、脚本负责绑定。

只能通过目录配置调整：

- 价格、口碑门槛、熟练度门槛；
- 加工时间、安全期、品质衰减；
- 托盘20/60秒；
- 订单权重、温度概率、套餐比例；
- 商品成本、售价和顾客耐心；
- 专精数量。

需要产品重新确认才能改变：

- 新区域或第六设备位；
- 第二个煎饼鏊子；
- 员工、外卖、排行榜、随机行情；
- 饮品加料或蒸品现场制作；
- 自动化替代范围；
- 托盘容量升级或无限保鲜。
