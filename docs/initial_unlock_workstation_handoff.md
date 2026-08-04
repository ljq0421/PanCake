# 工作台初始解锁场景交付记录

更新日期：2026-08-03（Asia/Shanghai）

## 当前入口与边界

- 隔离预览：`res://scenes/main/initial_unlock_preview.tscn`。
- 可复用工作台：`res://scenes/gameplay/initial_unlock_workstation.tscn`。
- 适配器：`res://scripts/ui/initial_unlock_workstation_adapter.gd`。
- 场景继续继承正式 `workstation.tscn`，复用同一套煎饼、订单、顾客、付款和评分状态；没有建立第二套业务状态源。
- 正式新游戏入口暂未替换。当前固定订单序列仍含未解锁火腿订单，在订单池按永久成长快照过滤前直接替换会制造不可完成订单。
- 本轮未修改并行美术目录 `resources/art/workstation/expansion`、概念稿、生成记录或 `docs/workstation_expansion_asset_audit.md`。

## 当前首日视觉结构

- `WorktopArtwork` 为一张连续实体柜台，显示范围严格为 `Rect2(0, 565, 1920, 515)`，左右均接到画布边缘。
- 左侧与中央为连续、平整的旧搪瓷台面：豆浆机、蛋糕机未来直接放在台面上；鏊子也直接放在台面上，不再显示安装坑或凹槽。
- 左侧两个设备逻辑锚点和透明热区仍稳定存在，但首日不显示凹坑、框体或锁图，且不可交互。
- 右侧实体 4×3 共 12 个深金属小料盘和右下炸油条机凹槽整体收进右区；鏊子右缘与盘架之间保留连续奶油色台面。盘位热区按源图测量收紧为全局 `Rect2(1286, 582, 528, 185)`；鸡蛋、薄脆、香葱占用第一排前三盘，第四盘及其余八盘保持空置锁定。炸油条机首日显示锁定且不可交互。
- 工具区是三个 145px 高的圆筒容器，整体位于全局 `Rect2(30, 420, 330, 145)`，即收款槽左侧窄台面。摊饼勺、摊面杆和手动酱刷使用独立 `Sprite2D` 陈列节点，中心下沉至筒内 `y=18`，并由筒身前景裁片遮住柄部，形成真实插入关系。第四个铲子筒、铲子精灵及热区均不显示；折叠状态机节点仍保留，由既有步骤流程自动进入折叠，不重造业务状态。
- 三个升级工具按钮仍在 `.tscn` 中稳定存在，首日隐藏、禁用且不接收鼠标。
- `PanBase` 为 520×468，`PancakeSurface` 为 480×450；输入、配料落点和折叠路径继续按当前控件尺寸归一化到同一 128×128 模拟网格。
- 状态/说明条位于左上墙面 `Rect2(100, 145, 600, 110)`，不遮挡工作台。

## 本轮素材

- `res://resources/art/workstation/background/workstation_initial_unlock_redraw_v4.png`
  - 1672×941 RGB。
  - 左/中无凹槽；4×3 实体盘与炸油条机槽右移到右区，受保护净空采样区的深色像素比例为 0.0042。
- `res://resources/art/workstation/tools/payment_slot_tool_cups_initial_v5.png`
  - 1922×818 RGBA；四角透明，alpha 包围盒及运行时裁片为 `(335, 131, 1248, 527)`。
  - 正好三个暖米白喷漆金属圆筒，共用低矮底座；深灰内胆、棕灰描边、轻微边缘磨损及俯视角度均参考收款槽，不含工具、文字或第四筒。
- 工作台 v4 与三筒 v5 的完整提示词、来源和哈希分别记录在 `res://resources/art/prompts/workstation_initial_unlock_redraw_v4.md` 与 `res://resources/art/prompts/payment_slot_tool_cups_initial_v5.md`。

仍等待正式美术替换的插槽：

- 豆浆机、鸡蛋仔/蛋糕机、炸油条机的 `EquipmentArt`。
- 右下炸油条机正式锁定盖板。
- 后续九个小料盘各成长阶段的内容物与盖板；当前前三盘已接入鸡蛋、薄脆和香葱库存纹理。
- 宽头摊饼器、自动酱刷、压饼神器的正式首见/购买后陈列状态。

## 验证

### 自动化 / headless

- `initial_unlock_workstation_self_check.gd`：通过。覆盖 1920×1080 三段布局、右侧实体盘像素净空、按源图测量的 4×3 盘位边界、前三个基础小料按钮与实体盘重合、收款槽左侧三个工具筒、工具下沉遮挡及完整热区、第四铲子位不存在、3 个设备锚点、首日工具所有权、鏊子输入/配料/折叠映射以及资源加载。
- `tools/run_workstation_expansion_checks.ps1`：通过。
- `tools/run_checks.ps1`：全部现有回归通过。
- 每次直接 headless 调用均使用独立可写 `--log-file`；批量脚本为每个检查生成 GUID 日志名。
- Windows 根证书读取警告仍存在，但所有检查退出码为 0，且不是资源加载错误。

### GPU / 非 headless

- Godot 4.6.1，D3D12 Forward Mobile，NVIDIA GeForce RTX 5070，窗口 1920×1080。
- `initial_unlock_workstation_gpu_smoke.gd`：通过。
- 截图：`res://tmp/validation/initial_unlock_workstation_gpu_1920x1080.png`。
- 真实 GUI 事件验证：倒面糊、鏊子边缘拖动、鸡蛋拖放和 4×3 盘位几何均通过。
- 视觉检查：鏊子右缘与料盘之间存在连续台面净空；三个暖米白金属筒完整位于收款槽左侧，摊饼勺、摊面杆和酱刷的柄部进入筒内并由前壁遮挡；无第四筒或铲子；鸡蛋、薄脆、香葱分别完整位于第一排前三盘且不跨行；右侧实体盘保持 4×3；右下锁定槽清晰；状态条未遮台面。

### 人工鼠标 / 人工视觉

尚未完成。GPU 自动 GUI 事件和代理截图检查不等同于真人产品验收，仍需真人确认工具点击手感、筒口辨识度、连续操作疲劳和鏊子最外缘容错。

## 豆浆机首次解锁的最小接口

1. 进入场景时把 `WorkstationProgressionService.snapshot()` 交给 `%InitialUnlockAdapter.apply_progression_snapshot(snapshot)`。
2. 日结购买继续使用现有 `purchase(UPGRADE_SOY_BASIC)` 与 `begin_next_business_day()`，不新增设备状态字段。
3. 适配器从现有 `ExpansionProductionService.machine_snapshot(DEVICE_SOY_MILK)` 得到 `owned/state`；拥有后启用固定 `InteractionArea`，并给 `EquipmentArt` 绑定经美术审计批准的豆浆机纹理。
4. 设备操作只适配现有 `load_input / perform_action / start / collect`；渲染使用 `machine_snapshot()`。
5. 正式切换新游戏入口前，让订单池读取成长快照并排除未解锁火腿及扩展商品。
