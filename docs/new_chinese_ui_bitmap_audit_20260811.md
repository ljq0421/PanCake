# 新中国风 UI 位图真实审计（2026-08-11）

## 审计边界与运行链路

本审计只统计当前正式入口可达且会被玩家看见的 UI 位图：

`project.godot -> scenes/main/start_menu.tscn -> scenes/main/main.tscn -> scenes/gameplay/four_area_workstation.tscn -> scenes/gameplay/initial_unlock_workstation.tscn`

同时核对 `scripts/main/start_menu.gd`、`scripts/gameplay/workstation.gd` 的 `preload/load`，以及 1920×1080 GPU 截图。`docs/` 概念图、`tmp/`、`.godot/imported/`、未被场景或脚本引用的历史资源不计入运行时清单。

## 当前真正可见的 UI 位图

| 优先级 | 资源 / 状态 | 玩家用途与界面 | 文件契约 | 运行时契约 |
| --- | --- | --- | --- | --- |
| P0 | `start_menu_background_morning_mobile_cart_v3_chinese.png`，已接入且风格已更新 | 开始页全屏背景 | 1672×941，RGB，不透明 | 全屏 `TextureRect`；全锚；`expand_mode=1`、`stretch_mode=6`；不是九宫格或 AtlasTexture |
| P0 | `order_card_multi_dish_v3.png`，本轮替换为 `order_card_multi_dish_v4_chinese_ui.png` | 营业中右上订单卡底图 | 旧 1131×1391 RGBA；新 1129×1393 RGBA | `TextureRect` 绝对坐标 `(1240,190)-(1540,560)`，逻辑尺寸 300×370；`expand_mode=1`、`stretch_mode=5`；不是九宫格或 AtlasTexture；卡内菜品、材料、心形填充和耐心条仍由既有节点覆盖 |
| P0 | `ingredient_slot_locked_cover_v1.png`，本轮替换为 `ingredient_slot_locked_cover_v2_chinese_ui.png` | 营业中底部未解锁配料槽锁盖 | 旧 512×512 RGBA；新 1254×1254 RGBA，主体保持低矮宽牌比例 | 18 个同纹理 `TextureRect`；每格 89×89；`stretch_mode=5` 居中等比；交互由透明 Button 层承担；不是九宫格或 AtlasTexture |
| P0 | `currency_coin_v1.png`，本轮替换为 `currency_coin_v2_chinese_ui.png` | 订单卡顶部金额图标 | 旧/新均为 1254×1254 RGBA | 脚本 `preload`；订单卡内 22×22 `TextureRect`，`stretch_mode=5`；不是 AtlasTexture |
| P1 | `quality_heat_uniformity_v1_five_area_v2.png`，本轮替换为 `quality_heat_requirement_v2_chinese_ui.png` | 需要加热的成品饮品订单要求 | 旧 256×256 RGBA；新 1254×1254 RGBA | 脚本 `preload`；订单材料格内 28×28 `TextureRect`，外层 44×40 状态框由 `StyleBoxFlat` 绘制；不是 AtlasTexture |
| P1 | `quality_*_v1.png` 共 9 张 | 单笔评价详情：完整度、厚薄、火候、鸡蛋、酱料、配料、折叠、订单正确、用时 | 每张 1254×1254 RGBA | 结果面板 3 列网格；每个图标 `TextureRect` 最小 72×72，`stretch_mode=5`；不是 AtlasTexture |
| P1 | `coin_1/2/5/10/20_v1.png` 共 5 张 | 顾客付款飞行与点击收款 | 每张 256×256 RGBA | 脚本动态复制 `TextureRect`；起始 82×82，落入收款槽后 48×48；点击语义不属于图片 |
| P2 | `payment_cash_small_v1.png` | 单笔评价中的付款展示 | 1536×1024 RGBA | 唯一使用 AtlasTexture 的 UI 位图；裁切区域 `Rect2(281,390,1020,259)`；结果面板显示行最小高度 72 |

## 明确排除

- 开始页按钮、设置框、新游戏确认框、暂停框、营业顶部条、成长卡与大多数面板均由 `StyleBoxFlat`、`ColorRect`、`ProgressBar` 和文字组成；应由主题/场景样式负责，不生成位图。
- `resources/art/ui/day_summary`、`supplier_event`、`recipe`、未接入的 `*_five_area_v2` 变体当前没有正式运行链路引用，不纳入本轮。
- `resources/art/ui/order/order_dish_*` 当前没有正式场景或脚本引用；订单中的食物与材料由产品/配料纹理动态填充，不作为 UI 框体重绘。
- 顾客、灶台、机器、食材、成品、工具、背景和前景属于角色或玩法美术，不计入 UI 位图审计。
- 临时截图、ImageGen 色键源、概念图、`.png.import` 和 `.godot/imported` 不是交付源素材。

## 第一组接入范围

本轮只接入订单卡、锁盖、订单铜钱和加热要求四张版本化资源。旧文件全部保留；不改布局、节点结构、交互、文字或业务数据。订单卡新版把底图的两个大菜品承托位改为三个，与场景既有的三个目标中心对齐；这是修正位图契约，不移动任何节点。

状态分级：

- 已生成：4/4。
- 已安全去键：4/4，均为 RGBA、四角 alpha=0，保留半透明抗锯齿边缘。
- 已写入正式资源路径：4/4。
- 已运行时引用：4/4。
- Godot 导入：Godot 4.7.1 headless 解析退出 0；`.png.import` 由 Godot 自动生成，未手改或复制。
- GPU 截图：Godot 4.7.1 / D3D12 / RTX 5070 已生成真实 1920×1080 与 1280×720 首屏，并生成含加热订单的对应分辨率截图。订单卡三菜品位、铜钱、加热标识和 18 槽锁盖均在正式场景可见，未见色键残边。
- 人工视觉确认：用户已确认第一组，允许继续 P1 质量结果图标；未自动扩展付款素材。

## 验证证据

- Headless 导入/解析：`tmp/validation/ui-core-headless-1786422813595.log`，退出 0。日志中的系统根证书读取和隔离环境存档写入警告不属于素材加载失败。
- 首屏 GPU：`tmp/validation/initial_unlock_workstation_gpu_1920x1080.png`、`tmp/validation/initial_unlock_workstation_gpu_1280x720.png`。
- 加热订单 GPU：`tmp/validation/five_area_entity_shop_gpu_1920x1080.png`、`tmp/validation/five_area_entity_shop_gpu_1280x720.png`。
- 加热订单真实指针烟测：`tmp/validation/ui-core-heated-gpu-1786422917166.log`，`PACKAGED_DRINK_WORKSTATION_POINTER_SMOKE_PASS`，退出 0。
- 开场工作台旧扩展烟测已成功截取本轮画面，但在更后面的既有辣酱相邻点击区断言处退出 1；该失败不归因于图片加载，不能把整套旧烟测报告成通过。

## 第二组接入范围：质量结果图标

本组只替换结果面板 3 列网格中实际显示的 9 枚指标图标：完整度、厚薄、火候、鸡蛋、酱料、配料、折叠、订单正确、用时。所有图标继续使用既有 72×72 `TextureRect`、`expand_mode=1`、`stretch_mode=5` 契约；不使用九宫格、AtlasTexture 或锚点偏移。本组未改结果计算、评分值、文字、面板布局、节点结构、付款行或按钮行为。

状态分级：

- 已生成：9/9，提示词记录于 `resources/art/prompts/ui_quality_chinese_v2.md`。
- 已安全去键：9/9，最终文件均为 1254×1254 RGBA，alpha 范围 0–255，四角 alpha=0，并保留 2654–3856 个半透明抗锯齿边缘像素。
- 已写入正式资源路径：9/9，文件名均为 `quality_*_v2_chinese_ui.png`；旧 `quality_*_v1.png` 全部保留。
- 已运行时引用：9/9，同时接入 `scenes/gameplay/workstation.tscn` 与正式开场链路使用的 `scenes/gameplay/initial_unlock_workstation.tscn`；仅替换 ext_resource 路径。
- Godot 导入：Godot 4.7.1 headless 编辑器导入/解析退出 0；`.png.import` 由 Godot 自动生成，未手改或复制。
- GPU 截图：Godot 4.7.1 / D3D12 / RTX 5070 运行 `result_panel_layout_self_check.gd`，退出 0 并输出 `RESULT_PANEL_LAYOUT_SELF_CHECK PASS`。真实结果面板中 9 枚图标均可见，3×3 语义轮廓互异，未见洋红色键残边，面板、付款行与关闭按钮保持原布局。
- 人工视觉确认：用户已确认第二组，允许继续顾客付款硬币与 AtlasTexture 付款现金素材。

第二组验证证据：

- 小尺寸联系表：`tmp/validation/quality_icons_v2_contact_sheet.png`。
- Headless 导入/解析：`tmp/validation/ui-quality-headless-1786432312516.log`，退出 0。日志中系统根证书及隔离环境编辑器设置写入警告不属于资源加载失败。
- GPU 结果面板：`tmp/validation/result_panel_layout_1210x582.png`。
- GPU 运行日志：`tmp/validation/ui-quality-gpu-1786433134807.log`，`RESULT_PANEL_LAYOUT_SELF_CHECK PASS`，退出 0。

## 第三组接入范围：顾客付款硬币与现金条

本组只替换运行时实际可见的付款素材：五枚面额硬币（1、2、5、10、20）与结果面板现金条。硬币仍由 `scripts/gameplay/workstation.gd` 的既有预加载字典按面额复制，保留 82×82 起始飞行尺寸、48×48 收款槽尺寸、逐枚点击收款和一次性结算语义。现金条仍由两个真实工作台场景的既有 `AtlasTexture` 使用，裁切区域严格保持 `Rect2(281,390,1020,259)`；未改 Atlas、节点、按钮、文字、支付数据或交互。

状态分级：

- 已生成：6/6，提示词记录于 `resources/art/prompts/ui_payment_chinese_v2.md`。
- 已安全去键：6/6。五枚硬币最终为 256×256 RGBA、四角 alpha=0，并各保留 1884–2074 个半透明抗锯齿像素。现金图最终为 1536×1024 RGBA，四角透明，非透明范围精确为 `(281,390)-(1301,649)`。
- 已写入正式资源路径：6/6，文件名为 `coin_{1,2,5,10,20}_v2_chinese_ui.png` 与 `payment_cash_small_v2_chinese_ui.png`；所有 v1 文件保留。
- 已运行时引用：五枚硬币已接入 `workstation.gd` 的支付预加载字典；两张真实工作台场景均已接入新硬币示例资源和新现金 Atlas；只替换资源路径。
- Godot 导入：Godot 4.7.1 headless 导入/解析退出 0；`.png.import` 由 Godot 自动生成，未手改或复制。
- GPU 运行：Godot 4.7.1 / D3D12 / RTX 5070 实际运行并输出 `PAYMENT_ASSETS_GPU_PREVIEW PASS`。断言确认现金条仍为 AtlasTexture、区域未变、新图已被 Atlas 引用；五枚待收硬币均为 48×48 且使用各自 v2 资源。截图中结果详情显示现金条；关闭详情后，五枚硬币按游戏原收款槽位置显示，未为了合屏而改变层级或位置。随后向其中一枚可见硬币发送真实鼠标按下/释放事件，确认仍会一次性收取全部待付款。
- 人工视觉确认：用户已确认第三组。按本审计的正式运行时清单，当前可见且需要重绘的 UI 位图已全部覆盖；不再自动生成被排除或未接入的候选素材。

第三组验证证据：

- 小尺寸联系表：`tmp/validation/payment_assets_v2_contact_sheet.png`。
- Headless 导入/解析：`tmp/validation/ui-payment-headless-1786444076843.log`，退出 0。日志中的系统根证书与隔离环境编辑器设置写入警告不属于资源加载失败。
- GPU 现金条：`tmp/validation/payment_assets_gpu_1920x1080.png`。
- GPU 待收硬币：`tmp/validation/payment_coins_gpu_1920x1080.png`。
- GPU 运行与真实点击：`tmp/validation/ui-payment-gpu-1786446021212.log`，`PAYMENT_ASSETS_GPU_PREVIEW PASS`，退出 0。

## 收尾结论

本轮已完成审计中所有正式运行时可见且应由位图承担的 UI 素材：第一组 4 张核心订单/槽位/状态素材、第二组 9 张结果指标图标、第三组 6 张付款素材，共 19 张版本化资源。开始页背景为此前已接入的新中国风资源；其余审计排除项仍分别由主题样式、文字、代码绘制、玩法美术或未接入资源承担，不应为追求数量而额外生成。三组均已获用户人工视觉确认；未创建提交。
