# ProjectCake 美术资源清单

## 清晨移动摊车底板 v1（2026-08-03）

- `status`: generated; imported; runtime-integrated; human review pending
- `purpose`: 替换初始营业场景的全局橙黄固定摊位观感，建立约 7:00 的清晨早餐时段与小型移动煎饼车语义；后续成长再过渡到半固定、固定摊位。
- `final_file`: `res://resources/art/workstation/background/workstation_backplate_morning_mobile_cart_v1.png`
- `source_file`: `tmp/imagegen/morning_mobile_cart_v1/workstation_backplate_morning_mobile_cart_v1_builtin_source.png`
- `edit_target`: `res://resources/art/workstation/background/workstation_backplate_v2.png`
- `prompt_file`: `res://resources/art/prompts/workstation_backplate_morning_mobile_cart_v1.md`
- `generator`: Codex 内置 `image_gen`，`lighting-weather` + `precise-object-edit`。
- `size`: 1671 x 941 px，RGB PNG。
- `sha256`: `FA8A0C9E5B219A8E0F67B77FEEDA0EDEF86B6A51125CE77DB422DBB3EE33783F`
- `visual_check`: passed — 上部顾客区改为冷灰蓝清晨街面，车体改为米白珐琅、旧青绿与少量砖红，下缘增加克制的便携车架/把手线索；无全局橙黄夕照、人物、文字、UI、鏊子、食物或支付物。
- `composition_check`: passed — 保留长收款托盘、十二个槽、中央鏊子安装区、底部控制底座、右侧酱瓶与植物的构图位置；正式运行场景仍使用原有节点坐标。
- `godot_import`: passed — Godot 4.7.1 已生成正式 PNG 的 `.png.import` 旁车，并可作为 `Texture2D` 加载。
- `runtime_scene_check`: passed — `workstation.tscn` 已切换资源引用；完整 `tools/run_checks.ps1` 通过，Forward Mobile / D3D12 在 NVIDIA GeForce RTX 5070 上生成完整 P1 截图，P95 16.85 ms。
- `human_review`: pending — 仍需人工确认早餐时间感、移动摊车辨识度及带完整 UI/顾客后的整体色彩平衡。

## 清晨移动摊车开始页背景 v1（2026-08-03）

- `status`: generated; imported; runtime-integrated; human review pending
- `purpose`: 将开始页从琥珀橙固定档口调整为与初始营业场景一致的清晨户外移动煎饼车，并同步收敛菜单、设置与确认弹窗色板。
- `final_file`: `res://resources/art/ui/start_menu/start_menu_background_morning_mobile_cart_v1.png`
- `source_files`: `tmp/imagegen/start_menu_morning_mobile_cart_v1/start_menu_background_morning_mobile_cart_v1_builtin_source.png`、`start_menu_background_morning_mobile_cart_v1_corrected_builtin_source.png`
- `edit_target`: `res://resources/art/ui/start_menu/start_menu_background_v1.png`
- `palette_reference`: `res://resources/art/workstation/background/workstation_backplate_morning_mobile_cart_v1.png`
- `prompt_file`: `res://resources/art/prompts/start_menu_background_morning_mobile_cart_v1.md`
- `generator`: Codex 内置 `image_gen`；先执行 `lighting-weather` + `precise-object-edit`，再执行一次定点文化语义修正。
- `size`: 1672 x 941 px，RGB PNG。
- `sha256`: `EADA97E7F0BDDDD3CF60222F069DA4AA222C7ED460ACFC0BFD4B5AE4C60EDD63`
- `visual_check`: passed — 左侧菜单安全区保持低细节，右侧为米白珐琅、旧青绿、冷灰蓝清晨街面的移动早餐摊；中央背板已恢复干净留白，预留给后续游戏名称，灯具关闭，无全局橙黄泛光。
- `cultural_check`: passed — 招财猫及其展示架已移除；留白区不放置海报或替代吉祥物；保留蒸笼、筷筒、锅铲、酱瓶和搪瓷材质等中式早餐摊线索；未加入日式文字、门帘、灯笼、达摩、文字、价格或伪书法。
- `godot_import`: passed — Godot 4.7.1 已生成 `.png.import` 旁车并可作为 `Texture2D` 加载。
- `runtime_scene_check`: passed — `start_menu.tscn` 已切换到新背景，并将菜单、按钮、设置页和确认弹窗改为深青灰/米白色板；完整 `tools/run_checks.ps1` 已通过，海报回退后又通过 `start_menu_self_check.gd` 与 Forward Mobile `run_start_menu_smoke.ps1`。
- `human_review`: pending — 仍需人工确认中式早餐摊辨识度、清晨氛围和标题/按钮视觉层级。

## 固定摊位分层装饰 v1（2026-08-02）

- `status`: art-complete-alpha-audit-passed-preview-checked-runtime-integration-pending-human-review-pending
- `scope`: 仅新增 5 张固定摊位装饰透明层；未修改玩法、场景业务逻辑、存档、经济、配料或工具。
- `generator`: Codex 内置 `image_gen`，每层单独生成；`workstation_backplate_v1.png` 为几何权威，`workstation_backplate_upgrade_v1.png` 仅作升级母题参考，`visual_style_anchor_v8.png` 为批准画风参考。
- `background_removal`: imagegen 技能 `remove_chroma_key.py`，border auto-key、soft matte、thresholds 12/220、despill。
- `deterministic_build_and_audit`: `tools/build_workstation_decor_assets.py`
- `audit_report`: `tmp/validation/workstation_decor_v1/workstation_decor_audit_v1.json`
- `contact_sheet`: `tmp/validation/workstation_decor_v1/workstation_decor_contact_sheet_v1.png`
- `stage_previews`: `tmp/validation/workstation_decor_v1/workstation_decor_stage_00_v1.png` 至 `workstation_decor_stage_05_v1.png`；另有 `workstation_decor_stage_05_full_1920x1080_v1.png`。
- `canvas_contract`: 5 张正式层均为 1671 x 941 RGBA，统一左上角锚点 `(0,0)`；1920 x 1080 预览只做整画布缩放。
- `safety_audit`: 顾客、订单卡、中央操作区和底部控制区禁画矩形内可见像素均为 0；任意两装饰层的可见像素交叠为 0；四角 alpha 均为 0；不透明品红/绿色键色残留为 0。
- `content_exclusions`: 无文字、伪文字、数字、价格、按钮、人物、食物、配料、工具、鏊子、动态订单内容、Logo 或水印。
- `godot_import`: 本纯美术任务未运行；没有手工修改 `.godot/imported` 或 `.png.import`。
- `runtime_integration`: pending；素材已生成不等于升级功能已实现。
- `human_review`: pending；仍需在真实游戏缩放并带顾客、订单卡和控制层时确认。

| 层 | 升级语义 | 正式文件 | alpha bbox | 透明占比 | SHA-256 |
| --- | --- | --- | --- | ---: | --- |
| A | 配料架扩建：两侧青绿/黄铜外支架，不填充 12 个槽内 | `res://resources/art/workstation/decor/tier_01_ingredient_rack/ingredient_rack_support_v1.png` | `(110,480)-(1550,820)` | 0.949623 | `85ae7b9f1095fa7c25ad341d7de2ba27d9222fb723c7591f19558f5a4347549c` |
| B | 储料改善：短挂架与 3 枚完全空白收纳标签 | `res://resources/art/workstation/decor/tier_02_storage/storage_label_rail_v1.png` | `(120,150)-(540,305)` | 0.967973 | `12213d819588c72290c8e25df2f26a37392c25c0bac1698a1cd7f1dc6bc6afd8` |
| C | 清晰订单板：右上小型完全空白夹板底图 | `res://resources/art/workstation/decor/tier_03_order/blank_order_clipboard_v1.png` | `(1415,140)-(1565,352)` | 0.981104 | `ab47c7a5b3cf8c34d556f767c29f4c1779873a4569301def74e5dc2a1eb52e90` |
| D | 候餐与遮雨：顶部短雨棚边饰和两盏外侧不发光小灯 | `res://resources/art/workstation/decor/tier_04_shelter/awning_side_lamps_v1.png` | `(20,0)-(1655,225)` | 0.919382 | `a354d1d0fdee51ee8d4f85de760aa9e77d6813029a3a2afb1e7f8552fa5e85b0` |
| E | 整体翻新：长托盘空心包边与 3 枚无脸无字熟客照片夹 | `res://resources/art/workstation/decor/tier_05_finish/tray_trim_customer_clips_v1.png` | `(321,150)-(1348,475)` | 0.960945 | `26ce39126da8db832bfa5301a53ce4b33df6c6659e31a99724a6304cee87fb52` |

完整提示词与源图对应记录：

- `res://resources/art/prompts/workstation_decor_ingredient_rack_support_v1.md`
- `res://resources/art/prompts/workstation_decor_storage_label_rail_v1.md`
- `res://resources/art/prompts/workstation_decor_blank_order_clipboard_v1.md`
- `res://resources/art/prompts/workstation_decor_awning_side_lamps_v1.md`
- `res://resources/art/prompts/workstation_decor_tray_trim_customer_clips_v1.md`

## 记录约定

- 所有文字均由 Godot 排版，不写入 AI 图片。
- `status: review` 表示仅完成生成与本地视觉检查，尚未完成人工方向确认。
- `godot_import: pending` 与人工视觉确认是两个独立验收项。
- 内置 `image_gen` 未向本次任务暴露具体模型名，因此不推测模型版本。

## 顾客基础三态完成审计（2026-08-02）

- `design_scope`: `docs/game_design.md` 首版范围与 `docs/development_plan.md` P2 范围均明确为 3 名顾客；当前磁盘已经形成 `customer_01` 至 `customer_10` 的扩展阵容。设计文档、资产清单和磁盘均没有 `customer_11` 或更高编号需求，因此不得仅按连续编号继续外推新顾客。
- `completed_files`: `customer_01` 至 `customer_10` 的 `neutral`、`impatient`、`satisfied` 共 30 张最终 RGBA PNG 全部存在；对应的 30 个最终键控源、30 份提示词和 30 个 `.png.import` sidecar 全部存在。
- `pixel_audit`: passed 30/30 — 四角 alpha 全部为 0，四条画布边缘非透明像素全部为 0，透明占比为 78.75% 至 83.49%，最终非透明区域中的强绿色/强品红键色残留全部为 0；30 个当前 SHA-256、尺寸和 alpha 边界框均与各自条目一致。
- `composition_audit`: passed 30/30 — 接触表逐项复核确认完整头发和发梢、双耳、双肩、前臂、双手与腰部下缘均未裁切；三态身份、服装、人物尺度、画布和建议锚点保持稳定；未发现工作台、订单卡、耐心条、付款物、文字、品牌、水印或烘焙投影。
- `audit_contact_sheet`: `tmp/imagegen/customer_audit_matrix.png`
- `audit_script`: `res://tmp/customer_texture_audit.gd`
- `godot_texture_load`: passed 30/30 — `D:\Godot\Godot_v4.7.1-stable_win64_console.exe` 逐张加载全部最终 PNG 为 `Texture2D`，并读取图像尺寸与 alpha 类型；退出码 0，日志为 `tmp/godot-customer-textures-1785635274267.log`。Windows 系统根证书读取失败是独立环境告警，不影响本地纹理加载结果。
- `human_review_boundary`: accepted 30/30 — 用户于 2026-08-02 查看完整三态接触表和完成矩阵后明确回复“确认。”；该确认作为 `customer_01` 至 `customer_10` 全部中性、不耐烦、满意基础状态的真人视觉验收。像素检查、Godot 加载和真人视觉确认仍是三类独立证据。

| 顾客 | 中性 | 不耐烦 | 满意 | 像素检查 | Godot 4.7.1 加载 | 真人视觉状态 |
|---|---|---|---|---|---|---|
| `customer_01` | complete | complete | complete | passed | passed | 三态 accepted |
| `customer_02` | complete | complete | complete | passed | passed | 三态 accepted |
| `customer_03` | complete | complete | complete | passed | passed | 三态 accepted |
| `customer_04` | complete | complete | complete | passed | passed | 三态 accepted |
| `customer_05` | complete | complete | complete | passed | passed | 三态 accepted |
| `customer_06` | complete | complete | complete | passed | passed | 三态 accepted |
| `customer_07` | complete | complete | complete | passed | passed | 三态 accepted |
| `customer_08` | complete | complete | complete | passed | passed | 三态 accepted |
| `customer_09` | complete | complete | complete | passed | passed | 三态 accepted |
| `customer_10` | complete | complete | complete | passed | passed | 三态 accepted |

## pancake_raw_texture_v1

- `status`: review
- `purpose`: P0/P1 面饼 Shader 的未熟面糊 RGB 基础纹理；覆盖度、厚度与湿度由运行时字段控制，不烘焙进图片。
- `final_file`: `res://resources/art/workstation/textures/pancake_raw_texture_v1.png`
- `source_file`: `tmp/imagegen/pancake_textures_v1/pancake_raw_texture_v1_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/pancake_raw_texture_v1.md`
- `rejected_attempt`: `tmp/imagegen/pancake_textures_v1/pancake_raw_texture_v1_attempt1_too_detailed.png`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGB，全矩形不透明纹理。
- `sha256`: `2BAC9F6F5586D48D850C09D44EA08596A1FE8A7D3DF8FD8A12AF18B76672FFEC`
- `processing`: 首次生成后因微粒与湿亮细节过密，使用内置编辑进行一次定向简化；最终源文件无损复制，未裁切、未缩放、未调色。
- `seam_check`: 边缘平均绝对误差：左右 0.0038、上下 0.0040；该数值支持无明显接缝，但不能替代真实 Shader 重复采样检查。
- `visual_check`: 通过。暖奶油色生面糊、稀疏杂粮颗粒与宽缓湿润色块可读；无饼边、器皿、配料、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and an 814,554-byte `CompressedTexture2D` cache.
- `runtime_shader_check`: passed — 2026-08-01，在 `workstation.tscn` 的 `PancakeVisual` ShaderMaterial 中作为 `raw_texture` 运行；Godot 4.7.1 Forward Mobile 实机冒烟与截图通过。
- `human_review`: pending

## egg_spread_material_v1

- `status`: review-runtime-integrated
- `purpose`: Shader material for the thin egg-white film, yolk drag streaks, bubbles, and set speckles during continuous T-spreader input.
- `final_file`: `res://resources/art/workstation/textures/egg_spread_material_v1.png`
- `source_file`: `C:/Users/Administrator/.codex/generated_images/019fbfe6-fb7b-7ea1-a941-efa775f2502e/exec-340363fa-1274-4d6a-8778-3f3fe47d5b49.png`
- `prompt_file`: `res://resources/art/prompts/egg_spread_material_v1.md`
- `generator`: Codex built-in `image_gen`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGB
- `sha256`: `76c3f10c55194a275ae9b8dd8c51f00143dde09c2c987f0e698c285d6e43dd15`
- `runtime_integration`: shader parameter `egg_surface_texture`
- `human_review`: pending

## pancake_fold_back_texture_v1

- `status`: review-runtime-integrated
- `purpose`: Textured underside used by the dynamically deformed left and right pancake flaps after they cross the fold midpoint.
- `final_file`: `res://resources/art/workstation/textures/pancake_fold_back_texture_v1.png`
- `source_file`: `C:/Users/Administrator/.codex/generated_images/019fbfe6-fb7b-7ea1-a941-efa775f2502e/exec-f17f310d-3046-49d2-8508-716f3bff0632.png`
- `prompt_file`: `res://resources/art/prompts/pancake_fold_back_texture_v1.md`
- `generator`: Codex built-in `image_gen`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGB
- `sha256`: `27a4e1d68b47a939e49082fa2da7e60fb8740265088ec5eab2fde59ce90acd82`
- `runtime_integration`: `PancakeFoldOverlay.pancake_back_texture`
- `human_review`: pending

## pancake_cooked_texture_v1

- `status`: review
- `purpose`: P0/P1 面饼 Shader 的正常熟化 RGB 基础纹理；与生面糊、焦化纹理由熟度字段混合。
- `final_file`: `res://resources/art/workstation/textures/pancake_cooked_texture_v1.png`
- `source_file`: `tmp/imagegen/pancake_textures_v1/pancake_cooked_texture_v1_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/pancake_cooked_texture_v1.md`
- `rejected_attempt`: `tmp/imagegen/pancake_textures_v1/pancake_cooked_texture_v1_attempt1_too_detailed.png`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGB，全矩形不透明纹理。
- `sha256`: `DC93955DF0784F01C47D2BE341B8EBCBED3FE5353BAC055B3FF0E3D0420C257C`
- `processing`: 首次生成后因孔洞和微小烘烤斑过密，使用内置编辑进行一次定向简化；最终源文件无损复制，未裁切、未缩放、未调色。
- `seam_check`: 边缘平均绝对误差：左右 0.0126、上下 0.0109；该数值支持低可见接缝，但必须继续在真实 Shader 重复采样中验收。
- `visual_check`: 通过。金黄色熟面饼、少量孔洞与宽缓烘烤斑清晰；无焦黑、配料、饼边、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 1,181,064-byte `CompressedTexture2D` cache.
- `runtime_shader_check`: passed — 2026-08-01，在 `workstation.tscn` 的 `PancakeVisual` ShaderMaterial 中作为 `cooked_texture` 运行；Godot 4.7.1 Forward Mobile 实机冒烟与熟化状态截图通过。
- `human_review`: pending

## pancake_charred_texture_v1

- `status`: review-detail-density
- `purpose`: P0/P1 面饼 Shader 的过熟/焦化 RGB 基础纹理；现有 Shader 将其作为食物颜色纹理混合，而不是灰度遮罩。
- `final_file`: `res://resources/art/workstation/textures/pancake_charred_texture_v1.png`
- `source_file`: `tmp/imagegen/pancake_textures_v1/pancake_charred_texture_v1_builtin_source.png`
- `first_success_file`: `tmp/imagegen/pancake_textures_v1/pancake_charred_texture_v1_attempt1_too_busy.png`
- `prompt_file`: `res://resources/art/prompts/pancake_charred_texture_v1.md`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `attempts`: 10；第九次首次成功，第十次定向简化编辑未返回图片。
- `size`: 1254 x 1254 px
- `pixel_format`: RGB，全矩形不透明纹理。
- `sha256`: `526F16914979FDFC289696F8B082E71253ACE209BCCCD560D999DFD5CA7057BE`
- `processing`: 第九次成功结果无损复制到项目最终目录；未裁切、未缩放、未调色。第十次定向简化没有产生输出，未替换候选。
- `seam_check`: 边缘平均绝对误差：左右 0.0061、上下 0.0078；支持低可见接缝，但仍需真实 Shader 重复采样确认。
- `tone_check`: 平均亮度 0.2563，明显低于正常熟面纹理的 0.7840；焦化层级清楚且未变成大面积纯黑。
- `visual_check`: 有条件通过。暖中棕底、深棕焦斑与少量近炭色痕迹能清楚表达过熟；无器皿、配料、火焰、烟、文字、品牌或水印。但焦斑数量和小尺度细节高于 V8 理想简化目标，人工确认前保留 `review-detail-density` 状态。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 1,176,014-byte `CompressedTexture2D` cache.
- `runtime_shader_check`: passed — 2026-08-01，在 `workstation.tscn` 的 `PancakeVisual` ShaderMaterial 中作为 `charred_texture` 运行；Godot 4.7.1 Forward Mobile 冒烟与材质状态截图通过，细节密度仍待人工确认。
- `human_review`: pending

## customer_01_neutral_v1

- `status`: review
- `purpose`: P1 第一名顾客的独立半身 Sprite2D；耐心条、订单卡和付款内容由独立 UI/素材叠加。
- `final_file`: `res://resources/art/customers/customer_01/customer_01_neutral_v1.png`
- `source_file`: `tmp/imagegen/customers_v1/customer_01_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_01_neutral_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1427 x 1102 px
- `pixel_format`: RGBA
- `alpha_bbox`: (483, 101) - (934, 971)
- `suggested_counter_pivot`: 约 (708, 970)，位于腰部下缘中央；放置时用此点贴近顾客区后沿。
- `sha256`: `76871333A3FB4319F35AF4776FFF0A7E7A1A679A03DC734D8DDEE5561B778692`
- `alpha_check`: 通过。四角完全透明；透明占比 0.8051；不透明占比 0.1921；自动色偏检测命中 5423 个像素，但原尺寸复核未发现可见品红边，命中主要来自人物自身暖肤色和深色抗锯齿区域。
- `visual_check`: 通过。完整头发及所有发梢、双耳、双肩、前臂和双手均在画布内；身份、绿衣、正面半身比例与 V8 顾客一致；无工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 289,104-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 P1 `CustomerPortrait` 默认状态接入；订单、耐心条与人物保持独立场景节点，Forward Mobile 接单截图通过。
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_01_impatient_v1

- `status`: review
- `purpose`: P1 第一名顾客接近耗尽耐心时的半身 Sprite2D 状态；与中性状态进行纹理切换，耐心条仍由独立 UI 表示。
- `final_file`: `res://resources/art/customers/customer_01/customer_01_impatient_v1.png`
- `source_file`: `tmp/imagegen/customers_v1/customer_01_impatient_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_01_impatient_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1427 x 1102 px
- `pixel_format`: RGBA
- `alpha_bbox`: (484, 101) - (934, 972)
- `alignment_check`: 与中性状态的 alpha 边界相比仅左侧和底部各偏移 1 px，适合同锚点纹理切换。
- `suggested_counter_pivot`: 约 (709, 971)，位于腰部下缘中央；运行时宜复用中性状态锚点并目视确认 1 px 差异。
- `sha256`: `9470E838A0D8980E29DF49AF04E1CF00636268A32D6468FFB9EDA149177DF64D`
- `alpha_check`: 通过。四角完全透明；透明占比 0.8058；半透明占比 0.0028；不透明占比 0.1913；未检测到残留品红像素。
- `visual_check`: 通过。人物身份、发型、服装、比例和完整裁切保持一致；眉头内压、眼睛轻微眯起、小幅下弯嘴清楚表达不耐烦，但没有怒吼、符号化蒸汽或夸张变形；无 UI、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 292,998-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 P1 顾客耐心低于 30% 或低分评价状态接入，同锚点纹理切换路径通过自动检查。
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_01_satisfied_v1

- `status`: review
- `purpose`: P1 第一名顾客成功拿到订单后的满意半身 Sprite2D 状态；用于完成订单和收款阶段的正反馈。
- `final_file`: `res://resources/art/customers/customer_01/customer_01_satisfied_v1.png`
- `source_file`: `tmp/imagegen/customers_v1/customer_01_satisfied_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_01_satisfied_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1427 x 1102 px
- `pixel_format`: RGBA
- `alpha_bbox`: (484, 102) - (934, 971)
- `alignment_check`: 与中性状态相比左侧和顶部各偏移 1 px，右侧和底部一致，适合同锚点纹理切换。
- `suggested_counter_pivot`: 约 (709, 970)，位于腰部下缘中央；运行时宜直接复用中性状态锚点。
- `sha256`: `0F2AAE6ACF069FCA535EC59AFA0399A135DF183405922C29846960CCF0CB40D7`
- `alpha_check`: 通过。四角完全透明；透明占比 0.8060；半透明占比 0.0029；不透明占比 0.1912；未检测到残留品红像素。
- `visual_check`: 通过。人物身份、发型、服装、比例和完整裁切保持一致；闭眼弧线、放松眉形与微笑形成明确满意反馈，但没有爱心、星光、手势或夸张动作；无 UI、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 296,584-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 P1 70 分及以上评价状态接入；出餐评价与收款路径通过自动检查和 Forward Mobile 截图。
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_02_neutral_v1

- `status`: review
- `purpose`: P1 第二名顾客的独立中性半身 Sprite2D 确认稿；耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_02/customer_02_neutral_v1.png`
- `source_file`: `tmp/imagegen/customers_v2/customer_02_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_02_neutral_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (532, 80) - (982, 965)
- `suggested_counter_pivot`: 约 (757, 964)，位于腰部下缘中央；后续表情状态必须复用此画布、主体边界和锚点。
- `sha256`: `30930A932E19B68AA73186B37C3A7CC2090C2E3A0E4A2657013BE01768B6F7FC`
- `processing`: 内置生成纯品红抠像源；使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角完全透明；透明占比 0.7957；半透明占比 0.0027；不透明占比 0.2017；画布边缘无非透明像素；未检测到残留品红像素。
- `visual_check`: 通过。成年女性身份、肩长深栗色波浪发、砖红上衣、奶油色圆领和芥末色腰部与 customer_01 明显不同；完整头发及所有发梢、双耳、双肩、前臂、双手和腰部下缘均在画布内；主体约 450 px 宽，与 customer_01 约 451 px 的宽度接近；粗深棕轮廓、暖色大色块和三层以内明暗符合 V8。无工作台、UI、订单卡、耐心条、付款物、背景投影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 336,624-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; it separately reported user-level root-certificate and editor-settings save warnings after asset import completed.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_02_impatient_v1

- `status`: review
- `purpose`: P1 第二名顾客接近耗尽耐心时的半身 Sprite2D 状态；与中性稿进行纹理切换，耐心条仍由独立 UI 表示。
- `final_file`: `res://resources/art/customers/customer_02/customer_02_impatient_v1.png`
- `source_file`: `tmp/imagegen/customers_v2/customer_02_impatient_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_02_impatient_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (532, 80) - (982, 964)
- `alignment_check`: 与中性状态相比左右和顶部完全一致，仅底部内缩 1 px，适合同锚点纹理切换。
- `suggested_counter_pivot`: 复用中性状态约 (757, 964)；本状态可见底边约为 y=963。
- `sha256`: `3298947640C3619595AEA28EF7596FEC152A2AC58EBF9E956DECCCB39A5AE166`
- `processing`: 内置精确编辑纯品红源；使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7964；半透明占比 0.0026；不透明占比 0.2010；未检测到残留品红像素。
- `visual_check`: 通过。人物身份、发型、服装、比例、双手与完整裁切保持一致；内压眉形、轻微眯眼和小幅下弯嘴清楚表达耐心接近耗尽，没有怒吼、泪水、蒸汽、漫画符号或身体姿态变化；无 UI、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 330,910-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; it separately reported user-level root-certificate and editor-settings save warnings after asset import completed.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_02_satisfied_v1

- `status`: review
- `purpose`: P1 第二名顾客成功拿到订单后的满意半身 Sprite2D 状态；用于完成订单后的正反馈。
- `final_file`: `res://resources/art/customers/customer_02/customer_02_satisfied_v1.png`
- `source_file`: `tmp/imagegen/customers_v2/customer_02_satisfied_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_02_satisfied_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (532, 80) - (981, 964)
- `alignment_check`: 与中性状态相比左侧和顶部一致，右侧与底部各内缩 1 px，适合同锚点纹理切换。
- `suggested_counter_pivot`: 复用中性状态约 (757, 964)；本状态可见底边约为 y=963。
- `sha256`: `F300BD4AF5AB89478755F5C4CDCBDA41DB6CB297796F64A55AC234660FB33696`
- `processing`: 内置精确编辑纯品红源；使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7964；半透明占比 0.0026；不透明占比 0.2010；未检测到残留品红像素。
- `visual_check`: 通过。人物身份、发型、服装、比例、双手与完整裁切保持一致；闭眼弧线、放松眉形、小幅闭嘴微笑和轻微暖脸颊形成明确满意反馈，没有张嘴大笑、爱心、星光、手势或夸张动作；无 UI、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 324,206-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; it separately reported user-level root-certificate and editor-settings save warnings after asset import completed.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_03_neutral_v1

- `status`: review
- `purpose`: P1 第三名顾客的独立中性半身 Sprite2D 确认稿；耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_03/customer_03_neutral_v1.png`
- `source_file`: `tmp/imagegen/customers_v3/customer_03_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_03_neutral_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (511, 87) - (1002, 982)
- `suggested_counter_pivot`: 约 (756, 981)，位于腰部下缘中央；后续表情状态必须复用此画布、主体边界和锚点。
- `sha256`: `7249BBA3C5A5E80DBF68545FEC0212E5EBB84679BD68B1528F47D11E18CC835A`
- `processing`: 内置生成纯品红抠像源；使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7926；半透明占比 0.0027；不透明占比 0.2048；未检测到残留品红像素。
- `visual_check`: 通过。年长女性身份、银灰侧后盘发、较成熟脸型、褪色蓝绿色短袖外套、暖米色内搭和陶土色腰部与前两名顾客明显不同；完整头发、盘发、双耳、双肩、前臂、双手和腰部下缘均在画布内；约 491 px 的较宽轮廓来自外套与年长体型，比 customer_02 宽约 9%，作为身份差异保留；粗深棕轮廓、暖色大色块和有限明暗符合 V8。无工作台、UI、订单卡、耐心条、付款物、背景投影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 353,446-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; it separately reported user-level root-certificate and editor-settings save warnings after asset import completed.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_03_impatient_v1

- `status`: review
- `purpose`: P1 第三名顾客接近耗尽耐心时的半身 Sprite2D 状态；与中性稿进行纹理切换，耐心条仍由独立 UI 表示。
- `final_file`: `res://resources/art/customers/customer_03/customer_03_impatient_v1.png`
- `source_file`: `tmp/imagegen/customers_v3/customer_03_impatient_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_03_impatient_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (511, 88) - (1001, 982)
- `alignment_check`: 与中性状态相比左侧和底部一致，顶部下移 1 px、右侧内缩 1 px，适合同锚点纹理切换。
- `suggested_counter_pivot`: 复用中性状态约 (756, 981)。
- `sha256`: `10ED93777659C0FAC32F95DB66EE292CD6ACDE16A06D5F06F365F6DECAEB998A`
- `processing`: 内置精确编辑纯品红源；使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7933；半透明占比 0.0026；不透明占比 0.2040；未检测到残留品红像素。
- `visual_check`: 通过。年长身份、银灰盘发、服装、宽轮廓、双手与完整裁切保持一致；内压眉形、轻微眯眼和压平嘴形表达严肃催促与耐心接近耗尽，没有怒吼、泪水、蒸汽、漫画符号或身体姿态变化；无 UI、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 353,182-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; it separately reported user-level root-certificate and editor-settings save warnings after asset import completed.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_03_satisfied_v1

- `status`: review
- `purpose`: P1 第三名顾客成功拿到订单后的满意半身 Sprite2D 状态；用于完成订单后的正反馈。
- `final_file`: `res://resources/art/customers/customer_03/customer_03_satisfied_v1.png`
- `source_file`: `tmp/imagegen/customers_v3/customer_03_satisfied_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_03_satisfied_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (511, 88) - (1001, 982)
- `alignment_check`: 与中性状态相比左侧和底部一致，顶部下移 1 px、右侧内缩 1 px；与不耐烦状态边界完全一致，适合同锚点纹理切换。
- `suggested_counter_pivot`: 复用中性状态约 (756, 981)。
- `sha256`: `F611AB9AD4771CDB65CB80DCA7BB91BC4A4A9A5F426EB5CA24E4E68153A69E21`
- `processing`: 内置精确编辑纯品红源；使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7932；半透明占比 0.0025；不透明占比 0.2043；未检测到残留品红像素。
- `visual_check`: 通过。年长身份、银灰盘发、服装、宽轮廓、双手与完整裁切保持一致；闭眼弧线、放松眉形、克制闭嘴微笑与保留的年长面部线条形成明确满意反馈，没有年轻化、张嘴大笑、爱心、星光、手势或夸张动作；无 UI、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 349,884-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; it separately reported user-level root-certificate and editor-settings save warnings after asset import completed.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_04_neutral_v1

- `status`: review
- `purpose`: P1 第四名顾客的独立中性半身 Sprite2D 确认稿；耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_04/customer_04_neutral_v1.png`
- `source_file`: `tmp/imagegen/customers_v4/customer_04_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_04_neutral_v1.md`
- `rejected_attempts`: `tmp/imagegen/customers_v4/customer_04_neutral_v1_attempt1_too_broad_chromakey.png`、`tmp/imagegen/customers_v4/customer_04_neutral_v1_attempt1_too_broad_alpha.png`
- `generator`: Codex 内置 `image_gen` 新身份生成及一次精确比例修正，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (508, 81) - (1013, 976)
- `suggested_counter_pivot`: 约 (760, 975)，位于腰部下缘中央；后续表情状态必须复用此画布、主体边界和锚点。
- `sha256`: `A77507B22E772C840B47DAB68CFC5BE2768AD93030E0D354B0845CF6A2FA86C3`
- `processing`: 首稿 alpha 宽 570 px、底边 y=990，因明显超出既有顾客尺寸范围而拒绝；内置精确编辑收窄肩线、躯干和双臂并整体上移约 15 px；最终纯品红源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7877；半透明占比 0.0028；不透明占比 0.2095；未检测到残留品红像素。
- `visual_check`: 通过。中年男性身份、暖棕肤色、紧密深色短卷发、较宽角形脸、海军蓝 Polo、赭色领边和砖棕腰部与前三名顾客明显不同；完整卷发、双耳、双肩、前臂、双手和腰部下缘均在画布内；修正后 505 px 宽，保留较宽男性体型但不再明显超出 customer_03；粗深棕轮廓、暖色大色块和有限明暗符合 V8。无工作台、UI、订单卡、耐心条、付款物、背景投影、文字、品牌或水印。
- `godot_import`: passed for texture — Godot 4.7.1 generated the `.png.import` sidecar and a 332,154-byte `CompressedTexture2D` cache with alpha. The same project scan separately reported existing `workstation.gd` parse errors for undeclared methods, plus user-level root-certificate and editor-settings warnings; these did not prevent this texture cache from being written.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_04_impatient_v1

- `status`: review
- `purpose`: P1 第四名顾客接近耗尽耐心时的半身 Sprite2D 状态；与中性稿进行纹理切换，耐心条仍由独立 UI 表示。
- `final_file`: `res://resources/art/customers/customer_04/customer_04_impatient_v1.png`
- `source_file`: `tmp/imagegen/customers_v4/customer_04_impatient_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_04_impatient_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (508, 81) - (1012, 976)
- `alignment_check`: 与中性状态相比左侧、顶部和底部一致，仅右侧内缩 1 px，适合同锚点纹理切换。
- `suggested_counter_pivot`: 复用中性状态约 (760, 975)。
- `sha256`: `3A0DE2E30BFFA47F277006CEDBA84C9BB8D4E3BF9804FE78B02A4999447A6342`
- `processing`: 内置精确编辑纯品红源；使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7880；半透明占比 0.0028；不透明占比 0.2092；未检测到残留品红像素。
- `visual_check`: 通过。中年男性身份、肤色、卷发、Polo、修正后的宽轮廓、双手与完整裁切保持一致；内压眉形、轻微眯眼和小幅下弯嘴清楚表达耐心接近耗尽，没有怒吼、泪水、蒸汽、漫画符号或身体姿态变化；无 UI、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 333,122-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; it separately reported user-level root-certificate and editor-settings save warnings after asset import completed.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_04_satisfied_v1

- `status`: review
- `purpose`: P1 第四名顾客成功拿到订单后的满意半身 Sprite2D 状态；用于完成订单后的正反馈。
- `final_file`: `res://resources/art/customers/customer_04/customer_04_satisfied_v1.png`
- `source_file`: `tmp/imagegen/customers_v4/customer_04_satisfied_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_04_satisfied_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (508, 81) - (1012, 976)
- `alignment_check`: 与中性状态相比左侧、顶部和底部一致，仅右侧内缩 1 px；与不耐烦状态边界完全一致，适合同锚点纹理切换。
- `suggested_counter_pivot`: 复用中性状态约 (760, 975)。
- `sha256`: `3BA04C29155FAD9BB203BE1CC1F265A668607AD3949379A6CB9CB44CFF741553`
- `processing`: 内置精确编辑纯品红源；使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7882；半透明占比 0.0028；不透明占比 0.2090；未检测到残留品红像素。
- `visual_check`: 通过。中年男性身份、肤色、卷发、Polo、修正后的宽轮廓、双手与完整裁切保持一致；闭眼弧线、放松眉形、克制闭嘴微笑和轻微暖脸颊形成明确满意反馈，没有张嘴大笑、爱心、星光、手势或夸张动作；无 UI、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 326,470-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; it separately reported user-level root-certificate and editor-settings save warnings after asset import completed.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_05_neutral_v1

- `status`: review
- `purpose`: P1 第五名顾客的独立中性半身 Sprite2D 确认稿；耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_05/customer_05_neutral_v1.png`
- `source_file`: `tmp/imagegen/customers_v5/customer_05_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_05_neutral_v1.md`
- `rejected_attempts`: `tmp/imagegen/customers_v5/customer_05_neutral_v1_attempt1_magenta_chromakey.png`、`tmp/imagegen/customers_v5/customer_05_neutral_v1_attempt1_noisy_alpha.png`
- `generator`: Codex 内置 `image_gen` 新身份生成及一次键色/布料技术清理，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (536, 86) - (987, 977)
- `suggested_counter_pivot`: 约 (761, 976)，位于腰部下缘中央；后续表情状态必须复用此画布、主体边界和锚点。
- `sha256`: `8A99AB7821176F32282FFD182CB5AF286A812BD46C65BA105E55BF272E5C3E8E`
- `processing`: 初稿使用品红键色，去背后灰紫上衣出现细小深色噪点而被拒绝；内置精确编辑清理布料微噪点并把背景改为纯绿色；最终源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill --force` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.8094；半透明占比 0.0027；不透明占比 0.1879；未检测到残留绿色像素。
- `visual_check`: 通过。年轻成年女性身份、窄椭圆脸、齐刘海齐下巴直短发、灰紫方领上衣、暖米色腰部和 451 px 纤细轮廓与前四名顾客明显不同；完整头发、刘海、双耳、双肩、前臂、双手和腰部下缘均在画布内；上衣已清除细小深色噪点，恢复 V8 大色块与有限明暗；无工作台、UI、订单卡、耐心条、付款物、背景投影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 288,540-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; it separately reported user-level root-certificate and editor-settings save warnings after asset import completed.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_05_impatient_v1

- `status`: review
- `purpose`: P1 第五名顾客的不耐烦半身 Sprite2D 状态；只改变眉眼和嘴型，耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_05/customer_05_impatient_v1.png`
- `source_file`: `tmp/imagegen/customers_v5/customer_05_impatient_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_05_impatient_v1.md`
- `generator`: Codex 内置 `image_gen` 对最终中性绿色键控源进行一次身份锁定精确编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (536, 87) - (987, 977)
- `alignment`: 相对中性稿仅顶部内缩 1 px，左右边界和腰部下缘一致；保留 451 px 主体宽度。
- `suggested_counter_pivot`: 约 (761, 976)，位于腰部下缘中央，与中性稿共用。
- `sha256`: `C8931486A21712F73F9F4A2175126D5CDE4928AEFF3E7C8D44B7E3307F6A1E4A`
- `processing`: 从 `customer_05_neutral_v1_chromakey.png` 独立生成；最终绿色键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.8097；半透明占比 0.0026；不透明占比 0.1877；未检测到残留绿色像素。
- `visual_check`: 通过。同一年轻成年女性身份、窄椭圆脸、齐刘海齐下巴直短发、双耳、梅紫方领上衣、暖米色腰部、姿势和手位均保持；轻微压低眉心、略收窄眼睛和克制下弯嘴型清楚表达不耐烦但不愤怒；完整头发、双肩、前臂、双手和腰部下缘均未裁切；上衣无微噪点；无工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 296,176-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; user-level root-certificate and editor-settings save warnings are recorded separately from texture validation.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_05_satisfied_v1

- `status`: review
- `purpose`: P1 第五名顾客的满意半身 Sprite2D 状态；只改变眉眼、嘴型和极轻微面颊暖色，订单 UI、工作台和阴影保持独立。
- `final_file`: `res://resources/art/customers/customer_05/customer_05_satisfied_v1.png`
- `source_file`: `tmp/imagegen/customers_v5/customer_05_satisfied_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_05_satisfied_v1.md`
- `generator`: Codex 内置 `image_gen` 对最终中性绿色键控源进行一次身份锁定精确编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (535, 85) - (987, 977)
- `alignment`: 相对中性稿左侧和顶部各外扩 1 px，右边界和腰部下缘一致；外扩处属于抗锯齿轮廓。
- `suggested_counter_pivot`: 约 (761, 976)，位于腰部下缘中央，与中性稿共用。
- `sha256`: `F07741862A3CADF4483C7B3DCF0A157344F8E40A33F95E61EC2F59441AD101C6`
- `processing`: 从 `customer_05_neutral_v1_chromakey.png` 独立生成，未从不耐烦稿串联编辑；最终绿色键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.8090；半透明占比 0.0026；不透明占比 0.1884；未检测到残留绿色像素。
- `visual_check`: 通过。同一年轻成年女性身份、窄椭圆脸、齐刘海齐下巴直短发、双耳、梅紫方领上衣、暖米色腰部、姿势和手位均保持；放松眉形、闭合上弯眼和克制闭口微笑清楚表达满意且不过度夸张；完整头发、双肩、前臂、双手和腰部下缘均未裁切；上衣无微噪点；无爱心、闪光、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 298,624-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; user-level root-certificate and editor-settings save warnings are recorded separately from texture validation.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_06_neutral_v1

- `status`: review
- `purpose`: P1 第六名顾客的独立中性半身 Sprite2D 单张确认稿；耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_06/customer_06_neutral_v1.png`
- `source_file`: `tmp/imagegen/customers_v6/customer_06_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_06_neutral_v1.md`
- `rejected_attempts`: `tmp/imagegen/customers_v6/customer_06_neutral_v1_attempt1_overscale_chromakey.png`、`tmp/imagegen/customers_v6/customer_06_neutral_v1_attempt1_overscale_alpha.png`、`tmp/imagegen/customers_v6/customer_06_neutral_v1_attempt2_scaled_chromakey.png`、`tmp/imagegen/customers_v6/customer_06_neutral_v1_attempt2_scaled_alpha.png`
- `generator`: Codex 内置 `image_gen` 生成新身份，并进行两次有针对性的比例/位置精确编辑；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (529, 56) - (999, 974)
- `suggested_counter_pivot`: 约 (764, 973)，位于腰部下缘中央；后续表情状态必须复用此画布、主体边界和锚点。
- `sha256`: `4F2716AD3FA5F44C0685F14FD066214A69A5DFB8083C5010EB587D8319873293`
- `processing`: 初稿边界 `(511,58)-(1008,982)`、宽 497 px，比例偏大；第一次修正稿边界 `(535,90)-(989,938)`，被生成器过度缩小并上移；最终稿从第二稿进行针对性比例和位置校正。最终品红键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill --force` 去背；最终图未由本地脚本裁切、缩放或调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.8051；半透明占比 0.0030；不透明占比 0.1918；未检测到残留品红像素。
- `visual_check`: 通过但保留一项真人确认。偏瘦老年男性身份、长矩形脸、高额角后梳银发、浅蓝短袖衬衫、暖芥末色 V 领背心和砖红腰部与 customer_01–05 明显不同；470 px 轮廓与 y=973 腰部底边进入既有顾客区间；完整头发、双耳、双肩、前臂、双手和腰部下缘均在画布内；服装保持粗深棕轮廓和干净大色块；无工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。顶部透明留白为 56 px，少于提示词理想值 78 px，但头发及抗锯齿边界完整且未触碰画布，需要真人确认该纵向尺度是否接受。
- `godot_import`: passed — Godot 4.7.1 explicitly reimported the PNG, generated the `.png.import` sidecar, and wrote a 339,680-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; user-level root-certificate and editor-settings save warnings are recorded separately from texture validation.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认老年男性身份、芥末色背心、头顶留白及三态表现。

## customer_06_impatient_v1

- `status`: review
- `purpose`: P1 第六名顾客的不耐烦半身 Sprite2D 状态；只改变眉毛、眼睑和嘴型，耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_06/customer_06_impatient_v1.png`
- `source_file`: `tmp/imagegen/customers_v6/customer_06_impatient_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_06_impatient_v1.md`
- `rejected_attempts`: `tmp/imagegen/customers_v6/customer_06_impatient_v1_attempt1_angry_chromakey.png`
- `generator`: Codex 内置 `image_gen` 对最终中性品红键控源进行身份锁定精确编辑，并进行一次表情强度修正；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (529, 57) - (997, 974)
- `alignment`: 相对中性稿顶部内缩 1 px、右边界内缩 2 px；左边界和腰部下缘完全一致，属于抗锯齿轮廓差异。
- `suggested_counter_pivot`: 约 (764, 973)，与中性稿共用。
- `sha256`: `309BE19E6BABFAAA11FBE2BCD613068DBAA42139D85FB2B62C83B61B0517D106`
- `processing`: 从 `customer_06_neutral_v1_chromakey.png` 独立生成；初稿眉角过陡并新增眉心紧绷线，读感偏愤怒，随后进行一次单点表情软化修正。最终品红键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.8062；半透明占比 0.0030；不透明占比 0.1908；未检测到残留品红像素。
- `visual_check`: 通过。同一老年男性身份、高额角后梳银发、长矩形脸、突出鼻型、原有年龄线、浅蓝衬衫、芥末色背心、砖红腰部、手位和姿势均保持；平缓微收的眉眼和浅下弯嘴型表达轻度等候疲惫，而非愤怒；完整头发、双耳、双肩、前臂、双手和腰部下缘未裁切；无新增眉心紧绷线、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 explicitly reimported the PNG, generated the `.png.import` sidecar, and wrote a 323,246-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; user-level root-certificate and editor-settings save warnings are recorded separately from texture validation.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_06_satisfied_v1

- `status`: review
- `purpose`: P1 第六名顾客的满意半身 Sprite2D 状态；只改变眉毛、眼睑和嘴型，订单 UI、工作台和阴影保持独立。
- `final_file`: `res://resources/art/customers/customer_06/customer_06_satisfied_v1.png`
- `source_file`: `tmp/imagegen/customers_v6/customer_06_satisfied_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_06_satisfied_v1.md`
- `generator`: Codex 内置 `image_gen` 对最终中性品红键控源进行一次身份锁定精确编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (529, 58) - (998, 974)
- `alignment`: 相对中性稿顶部内缩 2 px、右边界内缩 1 px；左边界和腰部下缘完全一致，属于抗锯齿轮廓差异。
- `suggested_counter_pivot`: 约 (764, 973)，与中性稿共用。
- `sha256`: `4BDD5C4264DD652D67498B9210E251A759BE84891AEF827B3C23829E700D5CB9`
- `processing`: 从 `customer_06_neutral_v1_chromakey.png` 独立生成，未从不耐烦稿串联编辑；最终品红键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.8063；半透明占比 0.0031；不透明占比 0.1906；未检测到残留品红像素。
- `visual_check`: 通过。同一老年男性身份、高额角后梳银发、长矩形脸、突出鼻型、原有年龄线、浅蓝衬衫、芥末色背心、砖红腰部、手位和姿势均保持；放松眉形、闭合上弯眼和克制闭口微笑表达平静满意；完整头发、双耳、双肩、前臂、双手和腰部下缘未裁切；无爱心、闪光、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 explicitly reimported the PNG, generated the `.png.import` sidecar, and wrote a 328,594-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; user-level root-certificate and editor-settings save warnings are recorded separately from texture validation.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_07_neutral_v1

- `status`: review
- `purpose`: P1 第七名顾客的独立中性半身 Sprite2D 单张确认稿；耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_07/customer_07_neutral_v1.png`
- `source_file`: `tmp/imagegen/customers_v7/customer_07_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_07_neutral_v1.md`
- `rejected_attempts`: `tmp/imagegen/customers_v7/customer_07_neutral_v1_attempt1_overscale_chromakey.png`、`tmp/imagegen/customers_v7/customer_07_neutral_v1_attempt1_overscale_alpha.png`
- `generator`: Codex 内置 `image_gen` 生成新身份并进行一次有针对性的整体比例/位置精确编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (489, 110) - (1030, 977)
- `suggested_counter_pivot`: 约 (760, 976)，位于腰部下缘中央；后续表情状态必须复用此画布、主体边界和锚点。
- `sha256`: `9019DD9DEE840903E6705CC037006DDFB70AB19FB0FA1292729E2B62CF8D29A2`
- `processing`: 初稿边界 `(476,79)-(1049,1015)`，宽 573 px、高 936 px，主体过宽且腰部过低；内置精确编辑对完整人物进行统一比例与位置修正。最终品红键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未由本地脚本裁切、缩放或调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7875；半透明占比 0.0026；不透明占比 0.2099；未检测到残留品红像素。
- `visual_check`: 通过。丰润中年女性身份、圆方脸、铜红短层次发、少量明确雀斑、暖金色船领上衣和深青绿腰部与 customer_01–06 明显不同；最终 541 px 较宽轮廓为有意身份设计，867 px 高度和 y=976 腰部底边回到既有顾客区间；完整头发、双耳、双肩、前臂、双手和腰部下缘均在画布内；服装保持粗深棕轮廓和干净大色块；无工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 explicitly reimported the PNG, generated the `.png.import` sidecar, and wrote a 330,574-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; user-level root-certificate and editor-settings save warnings are recorded separately from texture validation.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认丰润体型、铜红短发、雀斑密度、暖金色上衣及三态表现。

## customer_07_impatient_v1

- `status`: review
- `purpose`: P1 第七名顾客的不耐烦半身 Sprite2D 状态；只改变眉形、眼睑和嘴型，耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_07/customer_07_impatient_v1.png`
- `source_file`: `tmp/imagegen/customers_v7/customer_07_impatient_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_07_impatient_v1.md`
- `generator`: Codex 内置 `image_gen` 对最终中性品红键控源进行一次身份/雀斑锁定精确编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (489, 110) - (1029, 977)
- `alignment`: 相对中性稿仅右边界内缩 1 px；顶部、左边界和腰部下缘完全一致，属于抗锯齿轮廓差异。
- `suggested_counter_pivot`: 约 (760, 976)，与中性稿共用。
- `sha256`: `716F6F49BCE4FE3F08511CE3A61772706CA57C84089B84208DDA2356284D6210`
- `processing`: 从 `customer_07_neutral_v1_chromakey.png` 独立生成；最终品红键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7883；半透明占比 0.0026；不透明占比 0.2092；未检测到残留品红像素。
- `visual_check`: 通过。同一丰润中年女性身份、圆方脸、铜红短层次发、雀斑范围、暖金色船领上衣、深青绿腰部、手位和姿势均保持；轻微下压眉形、略收窄眼睛和浅下弯嘴型表达轻度不耐烦而非愤怒；完整头发、双耳、双肩、前臂、双手和腰部下缘未裁切；无新增皱纹、汗滴、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 explicitly reimported the PNG, generated the `.png.import` sidecar, and wrote a 313,396-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; user-level root-certificate and editor-settings save warnings are recorded separately from texture validation.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_07_satisfied_v1

- `status`: review
- `purpose`: P1 第七名顾客的满意半身 Sprite2D 状态；只改变眉形、眼睑和嘴型，订单 UI、工作台和阴影保持独立。
- `final_file`: `res://resources/art/customers/customer_07/customer_07_satisfied_v1.png`
- `source_file`: `tmp/imagegen/customers_v7/customer_07_satisfied_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_07_satisfied_v1.md`
- `generator`: Codex 内置 `image_gen` 对最终中性品红键控源进行一次身份/雀斑锁定精确编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (489, 110) - (1029, 977)
- `alignment`: 相对中性稿仅右边界内缩 1 px；顶部、左边界和腰部下缘完全一致，属于抗锯齿轮廓差异。
- `suggested_counter_pivot`: 约 (760, 976)，与中性稿共用。
- `sha256`: `F84CAE3B76D6685C2FA802ACC34CDC654C7E8072CAA563DF09CB19F659380F91`
- `processing`: 从 `customer_07_neutral_v1_chromakey.png` 独立生成，未从不耐烦稿串联编辑；最终品红键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未裁切、未缩放、未调色。
- `alpha_check`: 通过。四角和全部画布边缘完全透明；透明占比 0.7882；半透明占比 0.0025；不透明占比 0.2093；未检测到残留品红像素。
- `visual_check`: 通过。同一丰润中年女性身份、圆方脸、铜红短层次发、雀斑范围、暖金色船领上衣、深青绿腰部、手位和姿势均保持；放松眉形、闭合上弯眼和克制闭口微笑表达满意；雀斑没有被腮红覆盖或扩散；完整头发、双耳、双肩、前臂、双手和腰部下缘未裁切；无爱心、闪光、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 explicitly reimported the PNG, generated the `.png.import` sidecar, and wrote a 340,468-byte `CompressedTexture2D` cache with alpha. Headless import exited with code 0; user-level root-certificate and editor-settings save warnings are recorded separately from texture validation.
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认。

## customer_08_neutral_v1

- `status`: review
- `purpose`: P1 第八名顾客的独立中性半身 Sprite2D 单张确认稿；耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_08/customer_08_neutral_v1.png`
- `source_file`: `tmp/imagegen/customers_v8/customer_08_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_08_neutral_v1.md`
- `rejected_attempts`: `tmp/imagegen/customers_v8/customer_08_neutral_v1_rejected_bottom_crop_chromakey.png`（裤腰下缘被画布底边裁切）
- `generator`: Codex 内置 `image_gen` 生成新身份并进行一次仅针对整体比例/位置的身份锁定编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `visible_bounds`: `(556,84)-(959,968)`，宽 403 px、高 884 px；最下方可见像素 y=967，四周均与画布边缘分离。
- `suggested_counter_pivot`: 约 `(758,967)`；后续表情状态必须共用同一画布、人物尺度、可见边界和该锚点。
- `sha256`: `28369A804F952448A230D19FB0AB58F87847C066CEEA714DF1372332EAB31965`
- `processing`: 最终品红键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未在本地裁切、缩放或调色。
- `alpha_check`: 通过。四角 alpha 均为 0，顶部/底部/左侧/右侧非透明边缘像素均为 0；透明 1,312,115 px（83.4220%），半透明 4,475 px（0.2845%），不透明 256,274 px（16.2935%）；非透明区域中近品红和强品红残留均为 0 px；源图尺寸和最终图尺寸均为 1536 x 1024。
- `visual_check`: 通过。与 customer_01—07 不重复的偏瘦年轻成年男性身份清晰；窄长柔和棱角脸、浅蜂蜜金及肩直发、完整发梢和双耳、炭灰两扣 Henley、暖赤褐色腰部及放松双手均清楚；粗深棕轮廓、大色块和约三层以内明暗符合 V8。无头发、肩、前臂、手指或腰部下缘裁切，无工作台、UI、订单卡、耐心条、付款物、背景投影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 明确扫描并导入最终 PNG，生成 `.png.import` sidecar 和 303,380-byte、保留 alpha 通道的 `CompressedTexture2D` 缓存；headless 导入退出码为 0。系统根证书读取失败和用户级 editor settings 无法写入是沙箱用户目录告警，与该纹理导入结果分开记录。
- `human_review`: accepted for identity lock — 用户在查看中性稿后要求继续，已据此从中性品红源独立制作不耐烦与满意状态。

## customer_08_impatient_v1

- `status`: review
- `purpose`: P1 第八名顾客的不耐烦半身 Sprite2D 状态；只改变眉形、眼睑和嘴型，耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_08/customer_08_impatient_v1.png`
- `source_file`: `tmp/imagegen/customers_v8/customer_08_impatient_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_08_impatient_v1.md`
- `generator`: Codex 内置 `image_gen` 对已确认的中性品红源进行一次身份锁定表情编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `visible_bounds`: `(556,85)-(958,968)`，宽 402 px、高 883 px；相对中性稿四边差异为 `(0,+1,-1,0)`，最大 1 px。
- `suggested_counter_pivot`: `(758,967)`，与中性稿共用同一画布和锚点。
- `sha256`: `13270F610C1395AB0FF07CDE4F8DB5E01CFF2642637A78BD0A8BED4CB96041B0`
- `processing`: 从 `customer_08_neutral_v1_chromakey.png` 独立生成；最终品红源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未在本地裁切、缩放或调色。
- `alpha_check`: 通过。四角 alpha 均为 0，顶部/底部/左侧/右侧非透明边缘像素均为 0；透明 1,313,218 px（83.4922%），半透明 4,159 px（0.2644%），不透明 255,487 px（16.2434%）；非透明区域中近品红和强品红残留均为 0 px。
- `visual_check`: 通过。同一偏瘦年轻成年男性身份、窄长脸、浅蜂蜜金及肩直发、完整发梢、双耳、炭灰两扣 Henley、暖赤褐色腰部、手位和姿势均保持；压低眉形、半收眼睑和浅下弯闭口表达克制不耐烦而非愤怒。无新增皱纹、汗滴、漫画符号、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 明确扫描并导入最终 PNG，生成 `.png.import` sidecar 和 300,018-byte、保留 alpha 通道的 `CompressedTexture2D` 缓存；headless 导入退出码为 0。系统根证书读取和用户级 editor settings 写入告警与纹理结果分开记录。
- `human_review`: accepted — 用户在查看 customer_08 两个表情状态后要求继续下一名顾客。

## customer_08_satisfied_v1

- `status`: review
- `purpose`: P1 第八名顾客的满意半身 Sprite2D 状态；只改变眉形、眼睑和嘴型，订单 UI、工作台和阴影保持独立。
- `final_file`: `res://resources/art/customers/customer_08/customer_08_satisfied_v1.png`
- `source_file`: `tmp/imagegen/customers_v8/customer_08_satisfied_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_08_satisfied_v1.md`
- `generator`: Codex 内置 `image_gen` 对已确认的中性品红源进行一次独立身份锁定表情编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `visible_bounds`: `(556,86)-(958,970)`，宽 402 px、高 884 px；相对中性稿四边差异为 `(0,+2,-1,+2)`，最大 2 px。
- `suggested_counter_pivot`: `(758,967)`，与中性稿共用同一画布和锚点。
- `sha256`: `FBAB1F18B7C79B2558DF6886EBC71B2BEBF21E3889D2C5FA8C39B01BD86D6C83`
- `processing`: 从 `customer_08_neutral_v1_chromakey.png` 独立生成，未从不耐烦稿串联编辑；最终品红源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未在本地裁切、缩放或调色。
- `alpha_check`: 通过。四角 alpha 均为 0，顶部/底部/左侧/右侧非透明边缘像素均为 0；透明 1,313,047 px（83.4813%），半透明 4,207 px（0.2675%），不透明 255,610 px（16.2512%）；非透明区域中近品红和强品红残留均为 0 px。
- `visual_check`: 通过。同一偏瘦年轻成年男性身份、窄长脸、浅蜂蜜金及肩直发、完整发梢、双耳、炭灰两扣 Henley、暖赤褐色腰部、手位和姿势均保持；放松眉形、闭合上弯眼和加宽闭口微笑表达温和满意。无牙齿、腮红、爱心、闪光、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 明确扫描并导入最终 PNG，生成 `.png.import` sidecar 和 291,904-byte、保留 alpha 通道的 `CompressedTexture2D` 缓存；headless 导入退出码为 0。系统根证书读取和用户级 editor settings 写入告警与纹理结果分开记录。
- `human_review`: accepted — 用户在查看 customer_08 两个表情状态后要求继续下一名顾客。

## customer_09_neutral_v1

- `status`: review
- `purpose`: P1 第九名顾客的独立中性半身 Sprite2D 单张确认稿；耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_09/customer_09_neutral_v1.png`
- `source_file`: `tmp/imagegen/customers_v9/customer_09_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_09_neutral_v1.md`
- `rejected_attempts`: `tmp/imagegen/customers_v9/customer_09_neutral_v1_rejected_overscale_bottom_crop_chromakey.png`（过大且下缘裁切）、`customer_09_neutral_v1_rejected_attempt2_bottom_crop_chromakey.png`（位置过低且下缘裁切）、`customer_09_neutral_v1_rejected_attempt3_underscale_fullskirt_chromakey.png`（过小且接近全身裙装）、`customer_09_neutral_v1_rejected_attempt4_underscale_chromakey.png`（完整但占画略小）。
- `generator`: Codex 内置 `image_gen` 生成新身份，并围绕比例、垂直位置和完整下缘进行有针对性的身份锁定构图修正，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `visible_bounds`: `(540,75)-(979,959)`，宽 439 px、高 884 px；最下方可见像素 y=958，四周均与画布边缘分离。
- `suggested_counter_pivot`: 约 `(760,958)`；后续表情状态必须共用同一画布、人物尺度、可见边界和该锚点。
- `sha256`: `1A601D35C194421FC02AA09CFC1333A760EA3E96396FB0FDE4E92081E9C6D7B8`
- `processing`: 最终绿色键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未在本地裁切、缩放或调色。
- `alpha_check`: 通过。四角 alpha 均为 0，顶部/底部/左侧/右侧非透明边缘像素均为 0；透明 1,293,404 px（82.2324%），半透明 3,413 px（0.2170%），不透明 276,047 px（17.5506%）；非透明区域中近绿色和强绿色残留均为 0 px；源图和最终图均为 1536 x 1024。
- `visual_check`: 通过。成年女性身份、深暖棕肤色、柔和心形脸、蓝黑长侧辫、完整辫梢和双耳、珊瑚橙立领裹襟上衣、深靛蓝腰部与 customer_01—08 明显区分；439 px 宽、884 px 高的中等体型进入既有顾客占画区间；粗深棕轮廓、干净大色块和有限明暗符合 V8。完整头发、双肩、前臂、双手和下装下缘均未裁切；无工作台、UI、订单卡、耐心条、付款物、背景投影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 已识别最终 PNG，生成 `.png.import` sidecar 和 281,934-byte、保留 alpha 通道的 `CompressedTexture2D` 缓存；headless 导入退出码为 0。系统根证书读取和用户级 editor settings 写入告警与纹理结果分开记录。
- `human_review`: accepted for identity lock — 用户在查看中性稿后要求继续，已据此从最终中性绿幕源独立制作不耐烦与满意状态。

## customer_09_impatient_v1

- `status`: review
- `purpose`: P1 第九名顾客的不耐烦半身 Sprite2D 状态；只改变眉形、眼睑和嘴型，耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_09/customer_09_impatient_v1.png`
- `source_file`: `tmp/imagegen/customers_v9/customer_09_impatient_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_09_impatient_v1.md`
- `rejected_attempts`: `tmp/imagegen/customers_v9/customer_09_impatient_v1_rejected_too_angry_chromakey.png`（眉间与嘴角张力过强，读作生气）
- `generator`: Codex 内置 `image_gen` 从中性绿幕源进行身份锁定表情编辑，并进行一次只降低表情张力的定向修正，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `visible_bounds`: `(541,76)-(979,959)`，宽 438 px、高 883 px；相对中性稿四边差异为 `(+1,+1,0,0)`，最大 1 px。
- `suggested_counter_pivot`: `(760,958)`，与中性稿共用同一画布和锚点。
- `sha256`: `10020ABD756B1A2589F78A10B62943EAEB7775BF2A398D414C3174835D5DC1A6`
- `processing`: 从 `customer_09_neutral_v1_chromakey.png` 独立生成；最终绿色键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未在本地裁切、缩放或调色。
- `alpha_check`: 通过。四角 alpha 均为 0，顶部/底部/左侧/右侧非透明边缘像素均为 0；透明 1,294,020 px（82.2716%），半透明 3,193 px（0.2030%），不透明 275,651 px（17.5254%）；非透明区域中近绿色和强绿色残留均为 0 px。
- `visual_check`: 通过。同一成年女性身份、深暖棕肤色、心形脸、蓝黑长侧辫、珊瑚橙裹襟上衣、深靛蓝下装、手位和完整轮廓均保持；略压眉形、稍收眼睑和近乎平直的闭口表达克制不耐烦，不再读作愤怒。无眉间皱纹、汗滴、漫画符号、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 已识别最终 PNG，生成 `.png.import` sidecar 和 283,622-byte、保留 alpha 通道的 `CompressedTexture2D` 缓存；headless 导入退出码为 0。系统根证书读取和用户级 editor settings 写入告警与纹理结果分开记录。
- `human_review`: accepted — 用户在查看 customer_09 两个表情状态后要求继续下一名顾客。

## customer_09_satisfied_v1

- `status`: review
- `purpose`: P1 第九名顾客的满意半身 Sprite2D 状态；只改变眉形、眼睑和嘴型，订单 UI、工作台和阴影保持独立。
- `final_file`: `res://resources/art/customers/customer_09/customer_09_satisfied_v1.png`
- `source_file`: `tmp/imagegen/customers_v9/customer_09_satisfied_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_09_satisfied_v1.md`
- `generator`: Codex 内置 `image_gen` 从最终中性绿幕源独立进行一次身份锁定表情编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `visible_bounds`: `(541,76)-(979,959)`，宽 438 px、高 883 px；相对中性稿四边差异为 `(+1,+1,0,0)`，最大 1 px。
- `suggested_counter_pivot`: `(760,958)`，与中性稿共用同一画布和锚点。
- `sha256`: `3163C3DF4D73227C8526061B51220AA2788C71CD1A08B8DF3203EDB0747F2F8B`
- `processing`: 从 `customer_09_neutral_v1_chromakey.png` 独立生成，未从不耐烦稿串联编辑；最终绿色键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未在本地裁切、缩放或调色。
- `alpha_check`: 通过。四角 alpha 均为 0，顶部/底部/左侧/右侧非透明边缘像素均为 0；透明 1,294,069 px（82.2747%），半透明 3,300 px（0.2098%），不透明 275,495 px（17.5155%）；非透明区域中近绿色和强绿色残留均为 0 px。
- `visual_check`: 通过。同一成年女性身份、深暖棕肤色、心形脸、蓝黑长侧辫、珊瑚橙裹襟上衣、深靛蓝下装、手位和完整轮廓均保持；放松眉形、闭合上弯眼和加宽闭口微笑表达温和满意。无腮红、牙齿、爱心、闪光、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 已识别最终 PNG，生成 `.png.import` sidecar 和 283,376-byte、保留 alpha 通道的 `CompressedTexture2D` 缓存；headless 导入退出码为 0。系统根证书读取和用户级 editor settings 写入告警与纹理结果分开记录。
- `human_review`: accepted — 用户在查看 customer_09 两个表情状态后要求继续下一名顾客。

## customer_10_neutral_v1

- `status`: review
- `purpose`: P1 第十名顾客的独立中性半身 Sprite2D 单张确认稿；耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_10/customer_10_neutral_v1.png`
- `source_file`: `tmp/imagegen/customers_v10/customer_10_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_10_neutral_v1.md`
- `rejected_attempts`: `tmp/imagegen/customers_v10/customer_10_neutral_v1_rejected_overscale_chromakey.png`（身份合格但人物占画过大）
- `generator`: Codex 内置 `image_gen` 生成新身份并进行一次只调整整体比例/位置的身份锁定修正，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `visible_bounds`: `(507,82)-(1018,960)`，宽 511 px、高 878 px；最下方可见像素 y=959，四周均与画布边缘分离。
- `suggested_counter_pivot`: 约 `(762,959)`；后续表情状态必须共用同一画布、人物尺度、可见边界和该锚点。
- `sha256`: `BBDB2AB3EDA2814FFCB927B9AD3D3717946861D8994D1ABF72E94432305D40D5`
- `processing`: 最终绿色键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未在本地裁切、缩放或调色。
- `alpha_check`: 通过。四角 alpha 均为 0，顶部/底部/左侧/右侧非透明边缘像素均为 0；透明 1,250,023 px（79.4743%），半透明 3,234 px（0.2056%），不透明 319,607 px（20.3201%）；非透明区域中近绿色和强绿色残留均为 0 px；源图和最终图均为 1536 x 1024。
- `visual_check`: 通过。结实宽体中年男性身份、暖橄榄肤色、完整秃顶轮廓、窄侧后发茬、分离式深色小胡子与短山羊胡、暗酒红短袖敞领衬衫、米色内搭和暖卡其腰部与 customer_01—09 明显区分；511 px 宽、878 px 高的宽体轮廓进入既有顾客区间；粗深棕轮廓、干净大色块和有限明暗符合 V8。完整头部、双耳、双肩、前臂、双手和腰部下缘均未裁切；无工作台、UI、订单卡、耐心条、付款物、背景投影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 明确重新导入最终 PNG，生成 `.png.import` sidecar 和 310,102-byte、保留 alpha 通道的 `CompressedTexture2D` 缓存；headless 导入退出码为 0。系统根证书读取和用户级 editor settings 写入告警与纹理结果分开记录。
- `human_review`: accepted for identity lock — 用户在查看中性稿后要求继续，已据此从最终中性绿幕源独立制作不耐烦与满意状态。

## customer_10_impatient_v1

- `status`: review
- `purpose`: P1 第十名顾客的不耐烦半身 Sprite2D 状态；只改变眉形、眼睑和嘴型，耐心条、订单卡、付款内容、工作台和阴影由独立 UI/素材层提供。
- `final_file`: `res://resources/art/customers/customer_10/customer_10_impatient_v1.png`
- `source_file`: `tmp/imagegen/customers_v10/customer_10_impatient_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_10_impatient_v1.md`
- `rejected_attempts`: `tmp/imagegen/customers_v10/customer_10_impatient_v1_rejected_too_angry_chromakey.png`（眉峰内压和眼神张力过强，读作生气而非轻度等待不耐烦）
- `generator`: Codex 内置 `image_gen` 从中性绿幕源进行身份锁定表情编辑；首稿过怒后，又从同一中性源独立进行一次只降低眉眼张力的定向修正，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `visible_bounds`: `(507,83)-(1018,959)`，宽 511 px、高 876 px；相对中性稿四边差异为 `(0,+1,0,-1)`，最大 1 px。
- `suggested_counter_pivot`: `(762,959)`，与中性稿共用同一画布和锚点。
- `sha256`: `6F9AFFF9931F18C7C0692C26BA950CF931748E58C303ECB39038E813F9EDDBB0`
- `processing`: 从 `customer_10_neutral_v1_chromakey.png` 独立生成；最终绿色键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未在本地裁切、缩放或调色。
- `alpha_check`: 通过。四角 alpha 均为 0，顶部/底部/左侧/右侧非透明边缘像素均为 0；透明 1,250,981 px（79.5352%），半透明 3,007 px（0.1912%），不透明 318,876 px（20.2736%）；非透明区域中近绿色和强绿色残留均为 0 px。
- `visual_check`: 通过。同一结实宽体中年男性身份、完整秃顶轮廓、窄侧后发茬、分离式小胡子与短山羊胡、暗酒红敞领衬衫、米色内搭、暖卡其腰部、手位和完整轮廓均保持；近水平略低眉形、轻收上眼睑和近乎平直的闭口表达克制的不耐烦。无怒眉 V 形、眉间皱纹、汗滴、漫画符号、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 已重新导入最终 PNG，生成 1,012-byte `.png.import` sidecar 和 311,756-byte、保留 alpha 通道的 `CompressedTexture2D` 缓存；headless 导入退出码为 0。系统根证书读取和用户级 editor settings 写入告警与纹理结果分开记录。
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认当前轻度不耐烦强度。

## customer_10_satisfied_v1

- `status`: review
- `purpose`: P1 第十名顾客的满意半身 Sprite2D 状态；只改变眉形、眼睑和嘴型，订单 UI、工作台和阴影保持独立。
- `final_file`: `res://resources/art/customers/customer_10/customer_10_satisfied_v1.png`
- `source_file`: `tmp/imagegen/customers_v10/customer_10_satisfied_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_10_satisfied_v1.md`
- `generator`: Codex 内置 `image_gen` 从最终中性绿幕源独立进行一次身份锁定表情编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `visible_bounds`: `(507,83)-(1018,959)`，宽 511 px、高 876 px；相对中性稿四边差异为 `(0,+1,0,-1)`，最大 1 px。
- `suggested_counter_pivot`: `(762,959)`，与中性稿共用同一画布和锚点。
- `sha256`: `32D46E27F6F25F8232E95568F0E1E2860AFD046247DDA15B3EF5412B1B9BAD17`
- `processing`: 从 `customer_10_neutral_v1_chromakey.png` 独立生成，未从不耐烦稿串联编辑；最终绿色键控源使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；最终图未在本地裁切、缩放或调色。
- `alpha_check`: 通过。四角 alpha 均为 0，顶部/底部/左侧/右侧非透明边缘像素均为 0；透明 1,250,715 px（79.5183%），半透明 2,946 px（0.1873%），不透明 319,203 px（20.2944%）；非透明区域中近绿色和强绿色残留均为 0 px。
- `visual_check`: 通过。同一结实宽体中年男性身份、完整秃顶轮廓、窄侧后发茬、分离式小胡子与短山羊胡、暗酒红敞领衬衫、米色内搭、暖卡其腰部、手位和完整轮廓均保持；放松眉形、闭合上弯眼和胡须下方的闭口微笑表达温和满意。无腮红、牙齿、爱心、闪光、工作台、UI、订单卡、耐心条、付款物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 已重新导入最终 PNG，生成 1,012-byte `.png.import` sidecar 和 309,830-byte、保留 alpha 通道的 `CompressedTexture2D` 缓存；headless 导入退出码为 0。系统根证书读取和用户级 editor settings 写入告警与纹理结果分开记录。
- `human_review`: accepted — 用户于 2026-08-02 查看完整三态接触表后确认闭眼轻笑和胡须下方闭口笑线。

## payment_cash_small_v1

- `status`: review
- `purpose`: P1 长收款托盘上的一组可点击付款 Sprite2D，用于强化玩家收钱反馈。
- `final_file`: `res://resources/art/payments/payment_cash_small_v1.png`
- `source_file`: `tmp/imagegen/payments_v1/payment_cash_small_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/payment_cash_small_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (281, 390) - (1301, 649)
- `suggested_pivot`: 约 (791, 519)，位于付款组合中心。
- `sha256`: `9724A259A133E73C84A188F5B2F3226D917ED761DF96A470466CE190500B656B`
- `alpha_check`: 通过。四角完全透明；透明占比 0.8817；不透明占比 0.1165；452 个自动检测疑似品红边缘像素在原尺寸视觉检查中不可见。
- `visual_check`: 通过。恰好一张青色空白纸币和三枚金色硬币，横向紧凑、适合长托盘；没有文字、数字、货币符号、国家标识、投影、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 162,002-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，接入 P1 评价与收款反馈；付款素材与评分、下一订单业务状态保持独立。
- `human_review`: pending

## payment_coin_denominations_v1

- `status`: runtime-integrated; human review pending
- `purpose`: P1 收款槽中的独立可堆叠金币，支持 1、2、5、10、20 五种面额、单笔多枚付款、跨订单累积与一次收取。
- `final_files`: `res://resources/art/payments/coin_{1,2,5,10,20}_v1.png`
- `source_files`: `tmp/imagegen/payment_denominations_v1/coin_{1,2,5,10,20}_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/payment_coin_denominations_v1.md`
- `generator`: Codex 内置 `image_gen`，每个面额独立生成；随后使用技能自带 `remove_chroma_key.py` 去背并以 Lanczos 缩放。
- `generated_on`: 2026-08-03 (Asia/Shanghai)
- `size`: 每张 256 x 256 px
- `pixel_format`: RGBA
- `variants`:
  - `coin_1_v1.png`: 铜橙；alpha bbox `(44, 39) - (210, 210)`；SHA-256 `958E7F452963472A5474A99A9B8E955FABA65CAC73BE5EBE3F0D7B6C73F98360`
  - `coin_2_v1.png`: 银蓝；alpha bbox `(38, 35) - (217, 218)`；SHA-256 `FEE0A1A5FD0F5EADFF2AD1C74EDF2758C670A45017923EFB2A4CB25BB4E84F47`
  - `coin_5_v1.png`: 金黄；alpha bbox `(34, 32) - (220, 222)`；SHA-256 `090103D0903A70F701C0E43C84A6F4A37395D901E4284AF29CCC38D49CFC151A`
  - `coin_10_v1.png`: 玫瑰铜；alpha bbox `(31, 30) - (224, 225)`；SHA-256 `0AFCFDCC66EF858485EC9BE2DC2A36CFAEB03A07778A21BB957F9F0EE5A8BFE2`
  - `coin_20_v1.png`: 紫色；alpha bbox `(30, 27) - (226, 229)`；SHA-256 `AE44AE382EDB90E99E342CE6FEE00000A782E3CD3729143977437321248C37F3`
- `alpha_check`: passed — 五张图四角 alpha 均为 0，非透明 bbox 完整位于画布内；透明像素分别为 43,631 / 40,422 / 38,364 / 36,510 / 35,292，半透明边缘分别为 1,627 / 1,755 / 1,805 / 1,876 / 1,944 px。
- `visual_check`: passed — 五个阿拉伯数字均清晰，颜色可区分；每张只有一枚正面圆币，无托盘、额外硬币、货币符号、品牌、水印或残留绿色背景。
- `godot_import`: passed — Godot 4.7.1 已生成五个 `.png.import` 旁车，五张纹理均可作为 `Texture2D` 加载。
- `runtime_scene_check`: passed — `PaymentCoinLayer` 按订单金额动态拆分并渲染多枚硬币；待收金币独立于当前 `P1Session`，下一位顾客不等待收款。
- `human_review`: pending

## order_card_base_v1

- `status`: review
- `purpose`: P1 最基础订单卡空白底板；三个配料槽与两行要求槽供 Godot 动态叠加图标和文字。
- `final_file`: `res://resources/art/ui/order/order_card_base_v1.png`
- `source_file`: `tmp/imagegen/ui_order_v1/order_card_base_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/order_card_base_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (170, 147) - (1089, 1053)
- `suggested_pivot`: 约 (629, 600)，位于卡片外轮廓中心；运行时按 V8 约 110 x 100 px 先行试摆。
- `sha256`: `CA4BB3F46BA37744BD92D6C3FEA96B81124A42CA8D1EC241AFAF7F3CD894FACA`
- `alpha_check`: 通过。四角完全透明；透明占比 0.4762；半透明占比 0.0022；不透明占比 0.5215；未检测到残留品红像素。
- `visual_check`: 通过。完整近方形圆角卡片、三枚等尺寸圆形槽以及两组“小方槽 + 长字段槽”结构清楚；无文字、图标、数值、投影、品牌或水印。生成器未遵守 45% 画布占比，但不影响独立缩放使用。
- `nine_patch_note`: 外框和内部槽位共存于同一图片，不适合任意非等比拉伸；优先作为等比 `TextureRect` 使用。若后续需要 NinePatch，应另做无内部槽位的纯底板版本。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 477,344-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 P1 固定订单卡底板接入；标题、配料、双酱与火候要求继续由 Godot 动态排版。
- `human_review`: pending

## quality_integrity_v1

- `status`: review
- `purpose`: P1 评价界面的面饼完整度图标；分数、等级与状态颜色由 Godot 动态叠加。
- `final_file`: `res://resources/art/ui/quality/quality_integrity_v1.png`
- `source_file`: `tmp/imagegen/ui_quality_v1/quality_integrity_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/quality_integrity_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (261, 253) - (993, 1004)
- `suggested_pivot`: 约 (627, 628)，位于圆形徽章中心；建议以 48 至 64 px 等比显示。
- `sha256`: `0A0DCB74DDB8A399DED587C41374A8CA3618D30098D1C8EDE8AC429CEC7FDDEB`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7259；半透明占比 0.0016；不透明占比 0.2725；未检测到残留品红像素。
- `visual_check`: 通过。连续深棕圆周和三个杂粮点能表达完整未破的面饼；缩小后轮廓仍清楚；无文字、数字、勾选、投影、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 333,164-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## quality_thickness_uniformity_v1

- `status`: review
- `purpose`: P1 评价界面的厚度均匀度图标；与完整度图标共用统一徽章视觉。
- `final_file`: `res://resources/art/ui/quality/quality_thickness_uniformity_v1.png`
- `source_file`: `tmp/imagegen/ui_quality_v1/quality_thickness_uniformity_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/quality_thickness_uniformity_v1.md`
- `generator`: Codex 内置 `image_gen` 参考图编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (261, 255) - (993, 1004)
- `alignment_check`: 与完整度徽章相比仅顶部偏移 2 px，左右和底部一致，适合并排或同位换图。
- `suggested_pivot`: 约 (627, 629)，位于圆形徽章中心；建议以 48 至 64 px 等比显示。
- `sha256`: `3DFE7FB2102ABAFC2DCEA5EEDC4008CE6F46A12BA6B4C4267A78AC271C9C79B2`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7268；半透明占比 0.0015；不透明占比 0.2716；未检测到残留品红像素。
- `visual_check`: 通过。等厚横条、三个等高刻度和水平基线能表达厚度均匀；徽章外框与完整度图标一致；无文字、数字、箭头、投影、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 330,494-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## quality_heat_uniformity_v1

- `status`: review
- `purpose`: P1 评价界面的火候均匀度图标；与完整度图标共用统一徽章视觉。
- `final_file`: `res://resources/art/ui/quality/quality_heat_uniformity_v1.png`
- `source_file`: `tmp/imagegen/ui_quality_v1/quality_heat_uniformity_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/quality_heat_uniformity_v1.md`
- `generator`: Codex 内置 `image_gen` 参考图编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (261, 254) - (993, 1005)
- `alignment_check`: 与完整度徽章相比顶部偏移 1 px、底部延伸 1 px，左右一致，适合并排或同位换图。
- `suggested_pivot`: 约 (627, 629)，位于圆形徽章中心；建议以 48 至 64 px 等比显示。
- `sha256`: `AC4C0650E8439F1BC0270B8CE1AD12E01FB59195D34E68F22976B16D6F1E6BB0`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7261；半透明占比 0.0016；不透明占比 0.2722；未检测到残留品红像素。
- `visual_check`: 通过。三个等高、等距的橙红热浪在完整面饼内清楚表达均匀受热，没有使用火焰或焦糊符号；无文字、数字、投影、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 341,910-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## quality_sauce_coverage_v1

- `status`: review
- `purpose`: P1 评价界面的酱料覆盖和浓度图标；与完整度图标共用统一徽章视觉。
- `final_file`: `res://resources/art/ui/quality/quality_sauce_coverage_v1.png`
- `source_file`: `tmp/imagegen/ui_quality_v1/quality_sauce_coverage_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/quality_sauce_coverage_v1.md`
- `generator`: Codex 内置 `image_gen` 参考图编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (262, 254) - (992, 1005)
- `alignment_check`: 与完整度徽章相比左右各内缩 1 px、顶部偏移 1 px、底部延伸 1 px，适合并排或同位换图。
- `suggested_pivot`: 约 (627, 629)，位于圆形徽章中心；建议以 48 至 64 px 等比显示。
- `sha256`: `04554CAF5B8033862B6A8203A677A24C8741DFE2DF1E4FB7A769D1192BC547E2`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7272；半透明占比 0.0016；不透明占比 0.2713；未检测到残留品红像素。
- `visual_check`: 通过。三条宽度接近、纵向均匀分布的砖红酱带清楚表达覆盖质量；无刷子、瓶子、文字、数字、投影、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 348,868-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## quality_ingredient_distribution_v1

- `status`: review
- `purpose`: P1 评价界面的配料分布图标；与完整度图标共用统一徽章视觉。
- `final_file`: `res://resources/art/ui/quality/quality_ingredient_distribution_v1.png`
- `source_file`: `tmp/imagegen/ui_quality_v1/quality_ingredient_distribution_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/quality_ingredient_distribution_v1.md`
- `generator`: Codex 内置 `image_gen` 参考图编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (262, 255) - (992, 1004)
- `alignment_check`: 与完整度徽章相比左右各内缩 1 px、顶部偏移 2 px，底部一致，适合并排或同位换图。
- `suggested_pivot`: 约 (627, 629)，位于圆形徽章中心；建议以 48 至 64 px 等比显示。
- `sha256`: `56D0CE1EF25DCBD6510F7CB0E25959EE4333CF681C1282691AA17945EAC18369`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7272；半透明占比 0.0016；不透明占比 0.2712；未检测到残留品红像素。
- `visual_check`: 通过。三枚绿色葱圈与三枚珊瑚红肠片均匀交替、互不重叠，能表达配料分布；无文字、数字、投影、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 376,990-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## quality_fold_stability_v1

- `status`: review
- `purpose`: P1 评价界面的折叠结构稳定性图标；与完整度图标共用统一徽章视觉。
- `final_file`: `res://resources/art/ui/quality/quality_fold_stability_v1.png`
- `source_file`: `tmp/imagegen/ui_quality_v1/quality_fold_stability_v1_chromakey.png`
- `rejected_attempts`: `tmp/imagegen/ui_quality_v1/quality_fold_stability_v1_attempt1_envelope_like.png`、`quality_fold_stability_v1_attempt2_gradient_key.png`
- `prompt_file`: `res://resources/art/prompts/quality_fold_stability_v1.md`
- `generator`: Codex 内置 `image_gen` 参考图编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (261, 253) - (993, 1005)
- `alignment_check`: 与完整度徽章相比底部延伸 1 px，其余边界一致，适合并排或同位换图。
- `suggested_pivot`: 约 (627, 629)，位于圆形徽章中心；建议以 48 至 64 px 等比显示。
- `sha256`: `BE15B2B30D62F30F7BFF5F3C72526888969E835FAFF2D3D354D63510054A8404`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7260；半透明占比 0.0016；不透明占比 0.2724；未检测到残留品红像素。
- `visual_check`: 通过。第三稿以左右折片、较宽中央折片、闭合竖缝和两处烘烤斑表达稳定折叠；已移除初稿的信封式 V 线；无文字、数字、投影、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 354,006-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## quality_order_correctness_v1

- `status`: review
- `purpose`: P1 评价界面的订单正确性图标；以订单卡和成品相同的配料序列表达匹配。
- `final_file`: `res://resources/art/ui/quality/quality_order_correctness_v1.png`
- `source_file`: `tmp/imagegen/ui_quality_v1/quality_order_correctness_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/quality_order_correctness_v1.md`
- `generator`: Codex 内置 `image_gen` 参考图编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (261, 254) - (992, 1005)
- `alignment_check`: 与完整度徽章相比右侧内缩 1 px、顶部偏移 1 px、底部延伸 1 px，适合并排或同位换图。
- `suggested_pivot`: 约 (627, 629)，位于圆形徽章中心；建议以 48 至 64 px 等比显示。
- `sha256`: `A48939C670376B85605193BFAB32167D44BFE17E7CC74B3100A90CE47A2FBAC4`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7260；半透明占比 0.0016；不透明占比 0.2724；未检测到残留品红像素。
- `visual_check`: 通过。订单卡和成品均使用绿—红—绿三枚相同配料点，并由短线连接，能在无文字和勾号条件下表达订单匹配；无数字、投影、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 343,040-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## quality_preparation_time_v1

- `status`: review
- `purpose`: P1 评价界面的制作时间图标；与完整度图标共用统一徽章视觉。
- `final_file`: `res://resources/art/ui/quality/quality_preparation_time_v1.png`
- `source_file`: `tmp/imagegen/ui_quality_v1/quality_preparation_time_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/quality_preparation_time_v1.md`
- `generator`: Codex 内置 `image_gen` 参考图编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (262, 255) - (992, 1005)
- `alignment_check`: 与完整度徽章相比左右各内缩 1 px、顶部偏移 2 px、底部延伸 1 px，适合并排或同位换图。
- `suggested_pivot`: 约 (627, 630)，位于圆形徽章中心；建议以 48 至 64 px 等比显示。
- `sha256`: `0CD2DFB8809D1171C0B644AC1EA11878FDA376F1FA5E653FB3AC8268FC3A1A36`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7271；半透明占比 0.0015；不透明占比 0.2713；未检测到残留品红像素。
- `visual_check`: 通过。无数字钟面、四个方位刻度、双指针与一条克制动势弧能表达制作时间；无文字、数字、投影、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 343,112-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## quality_egg_spread_v1

- `status`: review
- `purpose`: P1 评价界面的摊蛋均匀度图标；当前运行时评分器将其作为独立第九项并赋予 8% 权重。
- `final_file`: `res://resources/art/ui/quality/quality_egg_spread_v1.png`
- `source_file`: `tmp/imagegen/ui_quality_v1/quality_egg_spread_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/quality_egg_spread_v1.md`
- `generator`: Codex 内置 `image_gen` 参考图编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (202, 173) - (1050, 1039)
- `suggested_pivot`: 约 (626, 606)，位于圆形徽章中心；建议以 48 至 64 px 等比显示。
- `sha256`: `183C2C53CA7D27DB15F1A9EE3F0FF85E335CE86351DE53A83C7E0627B626301B`
- `alpha_check`: 通过。四角完全透明；透明像素 995730/1572516；半透明像素 2796/1572516；未见明显品红边缘。
- `visual_check`: 通过。奶油色蛋液、扁平蛋黄和三条等距摊开标记能表达摊蛋均匀度；粗轮廓在 48 至 64 px 下仍可辨认；无文字、数字、投影、品牌或水印。
- `design_note`: `docs/game_design.md` 仍列八项评价维度，但当前 `PancakeScorer` 和单元测试明确保留独立摊蛋维度；本资产与结算 UI 忠实呈现运行时事实，未修改评分逻辑。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 443,418-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 九枚图标已作为固定场景节点接入结算面板，实时绑定当前评分器九项数值；P1 交互自检通过。
- `visual_runtime_check`: passed — 1920×1080 Forward Mobile 截图中九项以 3×3 排列，可见徽章直径约 49 px；反馈、标签、收款图与下一单按钮无溢出或遮挡。
- `human_review`: pending

## egg_whole_v1

- `status`: review
- `purpose`: P1 可拖拽完整鸡蛋 Sprite2D，供取料与打蛋前状态使用。
- `final_file`: `res://resources/art/ingredients/egg/egg_whole_v1.png`
- `source_file`: `tmp/imagegen/ingredients_v1/egg_whole_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/egg_whole_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (318, 204) - (936, 1022)
- `suggested_pivot`: 约 (627, 613)，位于蛋体中心。
- `sha256`: `6735D8490026A1BB4B5F63F2BA8C7D2A348B0A166FFF7CF5D509A28023527357`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7503；不透明占比 0.2484；疑似绿色边缘像素 9。
- `visual_check`: 通过。完整浅棕蛋壳、粗轮廓和少层次清晰；无蛋托、裂纹、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 309,318-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## egg_cracked_raw_v1

- `status`: review-runtime-material-needed
- `purpose`: P1 打到饼面后、被刮散前的生蛋状态 Sprite2D。
- `final_file`: `res://resources/art/ingredients/egg/egg_cracked_raw_v1.png`
- `source_file`: `tmp/imagegen/ingredients_v1/egg_cracked_raw_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/egg_cracked_raw_v1.md`
- `rejected_attempt`: `tmp/imagegen/ingredients_v1/egg_cracked_raw_v1_attempt1_too_fried.png`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (137, 203) - (1137, 1025)
- `suggested_pivot`: 约 (637, 614)，位于蛋黄和蛋白整体视觉中心。
- `sha256`: `A0AAEEB885D5FDE9D8F9CE5D30929A7301D4516BDC578A133ADC9271EFFB4339`
- `alpha_check`: 通过。四角完全透明；透明占比 0.6300；不透明占比 0.3684；疑似绿色边缘像素 0。
- `visual_check`: 有条件通过。一次修正后蛋黄更扁、蛋白轮廓更松散且无焦边；为保持深浅背景可读性，蛋白仍是不透明浅奶油色，真实生蛋半透明感应由运行时材质补充。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 398,200-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 P1 翻面前鸡蛋拖放结果接入 `IngredientLayer`；落点业务数据与动态 Sprite 分离。
- `human_review`: pending

## egg_cracked_raw_v2

- `status`: review
- `purpose`: P1 完整鸡蛋落到饼面后的短暂生蛋状态；首次有效 T 形摊蛋采样后淡出，由逻辑网格与 Shader 接管连续形状。
- `final_file`: `res://resources/art/ingredients/egg/egg_cracked_raw_v2.png`
- `source_file`: `tmp/imagegen/egg_spread_v1/egg_cracked_raw_v2_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/egg_cracked_raw_v2.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (177, 204) - (1135, 1050)
- `suggested_pivot`: 约 (656, 627)，位于蛋黄和蛋白整体视觉中心。
- `sha256`: `73C5F57B5C6CB023D4F73A0B0515A26C69469F77B125AF0D194DAC34205B037F`
- `processing`: v1 为编辑目标、完整鸡蛋为色彩与画风参考；内置生成平坦绿色抠像源；使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 去背；未缩放、未裁切、未调色。
- `alpha_check`: 通过。四角完全透明；透明像素占比 0.6203；半透明像素 539 个；主体未接触画布边缘。
- `visual_check`: 通过。单枚完整蛋黄、宽松不规则浅奶油色蛋白、蛋白外缘无深棕熟边；无蛋壳、器皿、工具、文字、品牌或水印。蛋白为保证抠像稳定仍保持较高不透明度，连续生蛋质感由运行时 Shader 表现。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 402,282-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，`EggButton` 与拖动预览使用完整鸡蛋，`EggCrackArtwork` 使用本图表现落蛋瞬间；首次有效摊蛋采样后切换到鸡蛋字段 Shader。Forward Mobile 实际渲染与专用摊蛋截图通过。
- `human_review`: pending

## baocui_intact_v1

- `status`: review
- `purpose`: P1 可拖拽完整薄脆 Sprite2D，用于摆放和折叠阻力表现。
- `final_file`: `res://resources/art/ingredients/baocui/baocui_intact_v1.png`
- `source_file`: `tmp/imagegen/ingredients_v1/baocui_intact_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/baocui_intact_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (116, 200) - (1168, 1036)
- `suggested_pivot`: 约 (642, 618)，位于薄脆中心。
- `sha256`: `19D3A647A24137251402982F8C99C13E7D741410258503CB4DCC184DE16C077E`
- `alpha_check`: 通过。四角完全透明；透明占比 0.6521；不透明占比 0.3464；疑似绿色边缘像素 0。
- `visual_check`: 通过。完整矩形薄片、轻微不规则边缘、少量大气泡和两块烘烤色斑清楚；无碎片、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 498,556-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 P1 薄脆托盘图与饼面放置图接入；结构负载参与对应折片评估。
- `human_review`: pending

## baocui_broken_v1

- `status`: review
- `purpose`: P1 薄脆受损或折断后的两块式状态 Sprite2D；不包含难以操作的小碎屑。
- `final_file`: `res://resources/art/ingredients/baocui/baocui_broken_v1.png`
- `source_file`: `tmp/imagegen/ingredients_v1/baocui_broken_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/baocui_broken_v1.md`
- `generator`: Codex 内置 `image_gen` 编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (116, 209) - (1153, 1033)
- `suggested_pivot`: 约 (635, 621)，位于两块碎片组合中心。
- `sha256`: `BFFCE7B3B5B5479762ABE35898499878DEA8415D921DB55733A4E4C0BE4A1285`
- `alpha_check`: 通过。四角完全透明；透明占比 0.6797；不透明占比 0.3183；疑似绿色边缘像素 0。
- `visual_check`: 通过。恰好两块大碎片、断面间距与原完整薄脆材质关系清楚；无第三块、细碎屑、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 464,828-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## ham_sausage_whole_v1

- `status`: review
- `purpose`: P1 可拖拽完整去皮熟火腿肠 Sprite2D。
- `final_file`: `res://resources/art/ingredients/ham_sausage/ham_sausage_whole_v1.png`
- `source_file`: `tmp/imagegen/ingredients_v1/ham_sausage_whole_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/ham_sausage_whole_v1.md`
- `rejected_attempt`: `tmp/imagegen/ingredients_v1/ham_sausage_whole_v1_attempt1_too_glossy.png`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (195, 301) - (1071, 953)
- `suggested_pivot`: 约 (633, 627)，位于肠体中心。
- `sha256`: `930250A5FEE8AB319A0932B552865C1FA990F896DDC98E20A749AC43D514A6C3`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7980；不透明占比 0.2009；疑似绿色边缘像素 0。
- `visual_check`: 有条件通过。定向修正后高光减弱、颜色改为珊瑚粉熟肉色；完整态仍较抽象，需与五片切片态共同确认火腿肠识别度。
- `godot_import`: passed for texture — Godot 4.7.1 generated the `.png.import` sidecar and a 234,446-byte `CompressedTexture2D` cache with alpha. The same project scan reported an unrelated existing `PancakeSpace.is_inside_round_pan()` script compile error.
- `human_review`: pending

## ham_sausage_slices_v1

- `status`: review
- `purpose`: P1 火腿肠切片后的五片式放置状态 Sprite2D。
- `final_file`: `res://resources/art/ingredients/ham_sausage/ham_sausage_slices_v1.png`
- `source_file`: `tmp/imagegen/ingredients_v1/ham_sausage_slices_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/ham_sausage_slices_v1.md`
- `generator`: Codex 内置 `image_gen` 编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (135, 369) - (1127, 909)
- `suggested_pivot`: 约 (631, 639)，位于五片组合中心。
- `sha256`: `C45D052FFDB1B81080D5A944D0F2056739915F2A461FB68489071D3090497F1C`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7386；不透明占比 0.2603；疑似绿色边缘像素 0。
- `visual_check`: 通过。恰好五片斜切厚片、切面与侧壁区分明确；无完整肠、包装、烤痕、阴影、文字、品牌或水印。
- `godot_import`: passed for texture — Godot 4.7.1 generated the `.png.import` sidecar and a 347,376-byte `CompressedTexture2D` cache with alpha. The same project scan reported an unrelated existing `PancakeSpace.is_inside_round_pan()` script compile error.
- `runtime_scene_check`: passed — 2026-08-01，作为 P1 火腿肠拖放与饼面放置状态接入；订单正确性和折片结构负载读取同一配料模型。
- `human_review`: pending

## scallion_pile_v1

- `status`: review
- `purpose`: P1 可拖拽单份葱花堆 Sprite2D，用于从固定配料槽取料。
- `final_file`: `res://resources/art/ingredients/scallion/scallion_pile_v1.png`
- `source_file`: `tmp/imagegen/ingredients_v1/scallion_pile_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/scallion_pile_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (225, 280) - (1048, 977)
- `suggested_pivot`: 约 (636, 629)，位于葱花堆中心。
- `sha256`: `A0EB1ACCDB4E65B665B82F0CEB11049B33793A344D9AA1A78F9828D9FD87A98F`
- `alpha_check`: 通过。使用品红背景；四角完全透明；透明占比 0.7493；不透明占比 0.2478；278 个自动检测疑似品红边缘像素在原尺寸视觉检查中不可见。
- `visual_check`: 通过。约十二至十六个粗大葱圈和短段组成紧凑一份，深浅绿与浅色内芯清楚；无托盘、刀具、阴影、文字、品牌或水印。
- `godot_import`: passed for texture — Godot 4.7.1 generated the `.png.import` sidecar and a 409,504-byte `CompressedTexture2D` cache with alpha. The same project scan reported an unrelated existing `PancakeSpace.is_inside_round_pan()` script compile error.
- `human_review`: pending

## scallion_scattered_v1

- `status`: review
- `purpose`: P1 撒到饼面后的葱花分布 Sprite2D；保持十二块大颗粒以避免细碎视觉噪声。
- `final_file`: `res://resources/art/ingredients/scallion/scallion_scattered_v1.png`
- `source_file`: `tmp/imagegen/ingredients_v1/scallion_scattered_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/scallion_scattered_v1.md`
- `rejected_attempt`: `tmp/imagegen/ingredients_v1/scallion_scattered_v1_attempt1_thirteen_pieces.png`
- `generator`: Codex 内置 `image_gen` 编辑，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1536 x 1024 px
- `pixel_format`: RGBA
- `alpha_bbox`: (103, 144) - (1432, 889)
- `suggested_pivot`: 约 (768, 516)，位于撒布区域中心。
- `sha256`: `5210D2B22DC5842F1659179E76496E205D5A323B2D32F1111D07A1B90DB8F96A`
- `alpha_check`: 通过。使用品红背景；四角完全透明；透明占比 0.7984；不透明占比 0.1975；1037 个自动检测疑似品红边缘像素在原尺寸视觉检查中不可见。
- `visual_check`: 通过。第一次生成 13 块，经精确删除后为 12 块；分布宽、间距清晰，只有右下两块重叠；无细碎粒子、托盘、阴影、文字、品牌或水印。
- `godot_import`: passed for texture — Godot 4.7.1 generated the `.png.import` sidecar and a 397,736-byte `CompressedTexture2D` cache with alpha. The same project scan reported an unrelated existing `PancakeSpace.is_inside_round_pan()` script compile error.
- `runtime_scene_check`: passed — 2026-08-01，作为 P1 葱花托盘与饼面分布图接入；配料位置参与分布评分。
- `human_review`: pending

## batter_ladle_v1

- `status`: review
- `purpose`: P0/P1 独立面糊勺 Sprite2D；当前 P0 作为桌面上的自动定量倒面入口，点击后在鏊心生成固定面糊团。
- `final_file`: `res://resources/art/workstation/tools/batter_ladle_v1.png`
- `source_file`: `tmp/imagegen/tools_v1/batter_ladle_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/batter_ladle_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1671 x 941 px
- `pixel_format`: RGBA
- `alpha_bbox`: (423, 93) - (1264, 809)
- `suggested_grip_pivot`: 约 (1185, 742)，位于木柄末端内侧；必须在真实鼠标操作中校准。
- `sha256`: `8176387DE0152D860A7A9EB131EC7C494459676B30692891645BD152BDC5944A`
- `alpha_check`: 通过。四角完全透明；透明占比 0.8895；不透明占比 0.1090；84 个自动检测的疑似绿色边缘像素在原尺寸视觉检查中不可见。
- `visual_check`: 通过。浅圆金属勺头、长木柄、粗深棕轮廓和三层以内色阶清晰；无面糊、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 200,468-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 `LeftRack/LadleButton/Artwork` 接入背景右侧六格托盘的左上格；节点路径保留，透明按钮覆盖整格盘子，点击仍走自动倒面业务路径。
- `human_review`: pending

## batter_spreader_v1

- `status`: review
- `purpose`: P0/P1 独立 T 形摊面刮板 Sprite2D，用于连续推挤面糊厚度场。
- `final_file`: `res://resources/art/workstation/tools/batter_spreader_v1.png`
- `source_file`: `tmp/imagegen/tools_v1/batter_spreader_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/batter_spreader_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1672 x 941 px
- `pixel_format`: RGBA
- `alpha_bbox`: (401, 113) - (1297, 798)
- `suggested_grip_pivot`: 约 (585, 748)，位于短柄末端内侧；必须在真实鼠标操作中校准。
- `sha256`: `2B7E0CBBA1E0B76D7383F205B11F80CE5E28EEB60D0CCCE74D3FC0D83128DA46`
- `alpha_check`: 通过。四角完全透明；透明占比 0.9112；不透明占比 0.0871；155 个自动检测的疑似绿色边缘像素在原尺寸视觉检查中不可见。
- `visual_check`: 通过。T 形轮廓、长摊面横杆和短握柄清晰；与面糊勺木色和线宽统一；无面糊、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 180,546-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 `PancakeSurface/SpreaderArtwork` 接入；等比缩放为 0.27，横杆接触中心与鼠标、模拟采样点对齐，并随椭圆半径旋转；P0.2 交互自检与 Forward Mobile 制作截图通过。
- `runtime_selection_check`: passed — 2026-08-01，同一素材作为 `LeftRack/ScraperButton/Artwork` 放入背景右侧六格托盘的右上格；节点路径保留，整格盘子作为点击区域。
- `human_review`: pending

## sauce_brush_v1

- `status`: review
- `purpose`: P0/P1 独立宽酱刷 Sprite2D；宽刷头对应设计文档中少量大幅轨迹完成覆盖的操作要求。
- `final_file`: `res://resources/art/workstation/tools/sauce_brush_v1.png`
- `source_file`: `tmp/imagegen/tools_v1/sauce_brush_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/sauce_brush_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1672 x 941 px
- `pixel_format`: RGBA
- `alpha_bbox`: (375, 77) - (1240, 857)
- `suggested_grip_pivot`: 约 (1172, 790)，位于木柄末端内侧；必须在真实鼠标操作中校准。
- `sha256`: `96F1F591C2FC0B32DAEAB8FD6AB23B521B4C4931F89602A3E57551C252305C06`
- `alpha_check`: 通过。四角完全透明；透明占比 0.8755；不透明占比 0.1231；疑似绿色边缘像素 13。
- `visual_check`: 通过。宽浅色刷毛、金属箍和木柄层次清晰；空刷无酱料与滴落，无阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 219,352-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 `RightRack/SauceBrushButton/Artwork` 接入背景右侧六格托盘的右中格；整格盘子用于选取酱刷，酱瓶补充则直接点击背景底板中可见的瓶体热区。
- `human_review`: pending

## folding_spatula_v1

- `status`: review
- `purpose`: P0/P1 独立宽翻折铲 Sprite2D，用于铲起薄饼和辅助折叠。
- `final_file`: `res://resources/art/workstation/tools/folding_spatula_v1.png`
- `source_file`: `tmp/imagegen/tools_v1/folding_spatula_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/folding_spatula_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1672 x 941 px
- `pixel_format`: RGBA
- `alpha_bbox`: (356, 76) - (1271, 844)
- `suggested_grip_pivot`: 约 (1192, 775)，位于木柄末端内侧；必须在真实鼠标操作中校准。
- `sha256`: `F8244E52D5D101DCD1D209305D11BC25812373B69A44077CDD48DA96026B6B30`
- `alpha_check`: 通过。四角完全透明；透明占比 0.8650；不透明占比 0.1337；94 个自动检测的疑似绿色边缘像素在原尺寸视觉检查中不可见。
- `visual_check`: 通过。宽梯形金属铲面、木柄与粗轮廓清楚；无槽孔、食物残留、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 213,122-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 `LeftRack/FoldButton/Artwork` 接入背景右侧六格托盘的左中格；节点路径保留，整格盘子作为点击区域并继续使用现有折叠信号和状态路径。
- `human_review`: pending

## ingredient_tongs_v1

- `status`: review
- `purpose`: P1 独立配料夹 Sprite2D，用于重新整理鸡蛋、薄脆、火腿肠和葱花等配料。
- `final_file`: `res://resources/art/workstation/tools/ingredient_tongs_v1.png`
- `source_file`: `tmp/imagegen/tools_v1/ingredient_tongs_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/ingredient_tongs_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1672 x 941 px
- `pixel_format`: RGBA
- `alpha_bbox`: (391, 126) - (1282, 810)
- `suggested_grip_pivot`: 约 (500, 260)，位于弹簧弯折和木质握片之间；必须在真实鼠标操作中校准。
- `sha256`: `7C76CD43E8BAED55690182A47A45EF1733CD517B6FAD1D634DFEE017888DC33A`
- `alpha_check`: 通过。四角完全透明；透明占比 0.8893；不透明占比 0.1087；69 个自动检测的疑似绿色边缘像素在原尺寸视觉检查中不可见。
- `visual_check`: 通过。夹臂、弹性弯折、木质握片和张开的夹头完整；无食物、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 218,688-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## oil_absorbent_paper_v1

- `status`: review
- `purpose`: P0/P1 独立吸油纸 Sprite2D，供修补或吸除局部多余油脂；污渍和变形应在运行时叠加。
- `final_file`: `res://resources/art/workstation/tools/oil_absorbent_paper_v1.png`
- `source_file`: `tmp/imagegen/tools_v1/oil_absorbent_paper_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/oil_absorbent_paper_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1672 x 941 px
- `pixel_format`: RGBA
- `alpha_bbox`: (393, 68) - (1279, 850)
- `suggested_pivot`: 约 (836, 459)，位于纸片中心；拖拽时可按接触点另行偏移。
- `sha256`: `DC619AC19959DF6285130820F3CD02EC216C79421CE57C26E298DF69F2820BCC`
- `alpha_check`: 通过。四角完全透明；透明占比 0.7667；不透明占比 0.2320；疑似绿色边缘像素 14。
- `visual_check`: 通过。单张暖米白纸片、圆角、轻折线和低纹理清楚；无纸堆、盒子、油污、阴影、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 311,188-byte `CompressedTexture2D` cache with alpha.
- `human_review`: pending

## pancake_edge_texture_v1

- `status`: review
- `purpose`: P0/P1 面饼 Shader 的饼边明暗细节纹理；现有 Shader 只采样红通道，实际饼边位置仍由运行时覆盖场决定。
- `final_file`: `res://resources/art/workstation/textures/pancake_edge_texture_v1.png`
- `source_file`: `tmp/imagegen/pancake_textures_v1/pancake_edge_texture_v1_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/pancake_edge_texture_v1.md`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGB，全矩形不透明纹理；Shader 只使用红通道。
- `sha256`: `420D6435487011D611E232FFBA133CA79D6EC97AC1295F327E80CCFC4B332998`
- `processing`: 内置生成后无损复制，未裁切、未缩放、未调色或重写通道。
- `seam_check`: 边缘平均绝对误差：左右 0.0033、上下 0.0038；仍需真实 Shader 重复采样验收。
- `visual_check`: 通过。暖灰中值底、少量宽缓暗斑和稀疏断续纹理符合简化基准；无圆形饼轮廓、透明破洞、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and an 894,744-byte `CompressedTexture2D` cache.
- `runtime_shader_check`: passed — 2026-08-01，在 `workstation.tscn` 的 `PancakeVisual` ShaderMaterial 中作为 `edge_texture` 运行；Godot 4.7.1 Forward Mobile 实机冒烟与饼边采样截图通过。
- `human_review`: pending

## sweet_flour_sauce_texture_v1

- `status`: review-provisional-name
- `purpose`: P1 两种基础酱料之一的深棕候选 RGB 平铺纹理；文档未锁定酱料名称，该名称暂用于美术区分。
- `final_file`: `res://resources/art/workstation/textures/sweet_flour_sauce_texture_v1.png`
- `source_file`: `tmp/imagegen/sauce_textures_v1/sweet_flour_sauce_texture_v1_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/sweet_flour_sauce_texture_v1.md`
- `rejected_attempt`: `tmp/imagegen/sauce_textures_v1/sweet_flour_sauce_texture_v1_attempt1_too_glossy.png`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGB，全矩形不透明纹理。
- `sha256`: `ABF46CF837A8818389BEE8E82B669BED02A83A9B9403387254146AB5721C9C21`
- `processing`: 初稿高光与细碎旋涡过多；使用内置编辑做一次定向简化，最终源无损复制，未裁切、未缩放、未调色。
- `seam_check`: 边缘平均绝对误差：左右 0.0079、上下 0.0082；仍需真实酱料遮罩重复采样验收。
- `visual_check`: 通过。深暖红棕色与少量宽缓叠涂带清晰，已移除大部分塑料高光；无器皿、刷子、配料、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 1,067,780-byte `CompressedTexture2D` cache.
- `runtime_shader_check`: passed — 2026-08-01，P1 新增甜面酱独立浓度字段与 `sweet_sauce_texture` Shader uniform；真实刷酱、评分和 Forward Mobile 截图读取同一业务数据。
- `human_review`: pending

## red_chili_sauce_texture_v1

- `status`: review-provisional-name
- `purpose`: P1 两种基础酱料之一的红色候选 RGB 平铺纹理；文档未锁定酱料名称，该名称暂用于美术区分。
- `final_file`: `res://resources/art/workstation/textures/red_chili_sauce_texture_v1.png`
- `source_file`: `tmp/imagegen/sauce_textures_v1/red_chili_sauce_texture_v1_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/red_chili_sauce_texture_v1.md`
- `rejected_attempt`: `tmp/imagegen/sauce_textures_v1/red_chili_sauce_texture_v1_attempt1_too_detailed.png`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGB，全矩形不透明纹理。
- `sha256`: `F466B8A2BAF97FB330FBB69C061D59D3E2B99650B3E0412A43DEB074D7268103`
- `processing`: 初稿辣椒纤维和微纹理过密；使用内置编辑做一次定向简化，最终源无损复制，未裁切、未缩放、未调色。
- `seam_check`: 边缘平均绝对误差：左右 0.0072、上下 0.0109；仍需真实酱料遮罩重复采样验收。
- `visual_check`: 通过。砖红底色、少量暗红纤维与宽缓橙红痕迹能和深棕候选清楚区分；无整粒配料、器皿、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and an 849,430-byte `CompressedTexture2D` cache.
- `runtime_shader_check`: passed — 2026-08-01，P1 新增辣椒酱独立浓度字段、R8 动态纹理与 `chili_sauce_texture` Shader uniform；长按右侧辣酱瓶、刷酱与评分路径通过。
- `human_review`: pending

## p0_3_pancake_placeholders

- `status`: graybox
- `purpose`: P0.3 Shader 的生面糊、熟面饼、焦化和破边临时纹理；只用于验证动态材质，不是正式美术。
- `files`: `res://resources/art/pancake/pancake_raw_placeholder.tres`、`pancake_cooked_placeholder.tres`、`pancake_charred_placeholder.tres`、`pancake_edge_placeholder.tres`
- `generator`: 未使用 AI；由 Godot 原生 `GradientTexture2D` 和确定性色值手工定义。
- `created_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 每张 64×64，运行时由 Shader 采样。
- `godot_import`: 不需要外部导入缓存；Godot 4.7.1 headless 可直接加载 `.tres`。
- `visual_check`: 通过灰盒检查；生湿、成熟、焦化三档可区分，重复采样方格已移除。
- `human_review`: pending

## workstation_backplate_v1

- `status`: review
- `purpose`: P0/P1 固定工作台静态底板；为顾客、UI、鏊子、配料、工具、钱币和前景遮挡提供分层基础。
- `final_file`: `res://resources/art/workstation/background/workstation_backplate_v1.png`
- `source_file`: `tmp/imagegen/workstation_layers_v1/workstation_backplate_v1_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/workstation_backplate_v1.md`
- `rejected_attempt`: `tmp/imagegen/workstation_layers_v1/workstation_backplate_v1_attempt1_baked_controls.png`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1671 x 941 px
- `pixel_format`: RGB，全矩形不透明背景。
- `pivot_center`: (835, 470)
- `sha256`: `7D8B0EEF17E880D5A89DF867CD8F2D8886E7CD98DC11295D3C0C65EA301EA59A`
- `processing`: 两次内置编辑；最终无损复制，未缩放、未裁切、未调色。
- `visual_check`: 通过。12 个空槽、长空收款托盘、空顾客区、空鏊子安装区和空控制底座完整；无顾客、UI、鏊子、食材、可移动工具、支付物或其残影。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 1,431,122-byte `CompressedTexture2D` cache.
- `runtime_scene_check`: passed — 2026-08-01，作为 `SafeArea/BackgroundArtwork` 的 1920×1080 安全区底层接入；16:9、16:10、超宽居中契约与 Mobile 截图通过。
- `human_review`: pending

## griddle_base_v1

- `status`: review
- `purpose`: P0/P1 独立鏊子底图，供 Sprite2D、面饼遮罩与着色层叠加。
- `final_file`: `res://resources/art/workstation/griddle/griddle_base_v1.png`
- `source_file`: `tmp/imagegen/workstation_layers_v1/griddle_base_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/griddle_base_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1254 x 1254 px
- `pixel_format`: RGBA
- `alpha_bbox`: (99, 266) - (1154, 998)
- `pivot_center`: (627, 627)
- `suggested_v8_preview`: 在 1671 x 941 基准画布上先以约 0.50 至 0.52 均匀缩放、中心约 (835, 660) 试摆，再由真实场景验收调整。
- `sha256`: `D9C5992B9432F185CF9034046021801330C65FF834CC64016D9FF0C47C7F709C`
- `alpha_check`: 通过。四角完全透明；透明占比 0.6083；不透明占比 0.3898；绿色边缘像素 0。
- `visual_check`: 通过。轮廓完整、圆度与 v8 接近、无背景投影、无文字或附属物。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 639,940-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 `PanBase/GriddleArtwork` 等比接入并位于 600×600 `PancakeSurface` 后方；有效边界比例 732/1055 写入输入、模型、Shader 和折叠共用参数，Mobile 制作、刷酱、折叠截图通过。
- `human_review`: pending

## workstation_front_lip_v1

- `status`: review
- `purpose`: P0/P1 前景桌沿遮挡层，用于遮挡越过工作台前缘的工具、手部或食物层。
- `final_file`: `res://resources/art/workstation/foreground/workstation_front_lip_v1.png`
- `source_file`: `tmp/imagegen/workstation_layers_v1/workstation_front_lip_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/workstation_front_lip_v1.md`
- `generator`: Codex 内置 `image_gen`，随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `size`: 1671 x 941 px
- `pixel_format`: RGBA
- `alpha_bbox`: (30, 431) - (1641, 559)
- `pivot_center`: (835, 470)
- `suggested_v8_preview`: 全屏透明画布按 1:1 使用时，可先将 Sprite2D 中心放在约 (835, 852)，使可见桌沿落在画面底部，再由真实场景验收调整。
- `sha256`: `C667055231C45209370FAEF8CD8125666F622790D3409C9E2DF83629665D9E7D`
- `alpha_check`: 通过。四角完全透明；透明占比 0.8701；不透明占比 0.1268；绿色边缘像素 0。
- `visual_check`: 通过。桌沿轮廓完整，无控件、工具、阴影、文字或杂点。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 113,608-byte `CompressedTexture2D` cache with alpha.
- `runtime_scene_check`: passed — 2026-08-01，作为 `SafeArea/ForegroundLip` 接入，位于动态制作内容前、引擎底部 UI 后，并设置 `mouse_filter = Ignore`；Mobile 截图通过。
- `human_review`: pending

## visual_style_anchor_v8

- `status`: approved-anchor
- `purpose`: 在 v7 基础上，将小订单卡移近顾客，并将鏊子向玩家侧桌边移动、调整为更接近圆形的近俯视轮廓。
- `final_file`: `res://resources/art/style_guides/visual_style_anchor_v8.png`
- `source_file`: `tmp/imagegen/style_anchor_v1/visual_style_anchor_v8_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/visual_style_anchor_v8.md`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `source_size`: 1671 x 941 px
- `pixel_format`: RGB，无透明通道。
- `sha256`: `1E4A69BCE0E600A2239B8C8029A4E99980F264D5B1D35BABC8B79BE89823350D`
- `processing`: 以内置编辑模式修改 v7；无损复制到项目目录；未缩放、未裁切、未调色、未执行透明处理。
- `visual_check`: 通过。订单卡位于顾客头部右侧近距离但未接触头发或肩部；鏊子向玩家侧桌边移动且纵向比例增加，轮廓比 v7 更圆；仍与长收款托盘保持明显空桌面间隔；底部边缘接近但未遮挡控制内容；其余布局无明显漂移。
- `layering_note`: 订单文字、图标、数值与支付物件由 Godot 或独立动态素材提供，本图只提供空底板和固定设施。
- `design_conflict`: `docs/game_design.md` 当前仍写着“营业台最多 8 个固定配料槽”；v8 延续 12 槽。用户确认前不修改设计文档。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 1,555,492-byte `CompressedTexture2D` cache. The sandbox also reported unrelated user-level editor-settings/root-certificate warnings after import completion.
- `human_review`: confirmed on 2026-08-01 as the visual and composition anchor for subsequent P0/P1 assets.

## visual_style_anchor_v7

- `status`: review
- `purpose`: 在 v6 基础上，仅将顾客头部右上方的订单卡宽高各缩小到约 1/2，并简化内部空占位。
- `final_file`: `res://resources/art/style_guides/visual_style_anchor_v7.png`
- `source_file`: `tmp/imagegen/style_anchor_v1/visual_style_anchor_v7_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/visual_style_anchor_v7.md`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `source_size`: 1671 x 941 px
- `pixel_format`: RGB，无透明通道。
- `sha256`: `00981D765837FC7D45E57243E51162B4A83267AFB002E409085958FEF64F1236`
- `processing`: 以内置编辑模式修改 v6；无损复制到项目目录；未缩放、未裁切、未调色、未执行透明处理。
- `visual_check`: 通过。订单卡宽高均约为 v6 的一半；内部保留 3 个空图标位和 2 行空信息位；未遮挡顾客；耐心条、长收款托盘、空桌面间隔、鏊子、半身顾客和左右各 6 槽保持完整；无文字、货币、品牌或水印。
- `layering_note`: 订单文字、图标和数值由 Godot 动态排版，本图只提供空底板。
- `design_conflict`: `docs/game_design.md` 当前仍写着“营业台最多 8 个固定配料槽”；v7 延续 12 槽。用户确认前不修改设计文档。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 1,524,978-byte `CompressedTexture2D` cache. The sandbox also reported unrelated user-level editor-settings/root-certificate warnings after import completion.
- `human_review`: pending

## visual_style_anchor_v6

- `status`: review
- `purpose`: 在 v5 的半身顾客、12 槽和长收款托盘布局上，缩小耐心条与订单卡，并把鏊子完全移出收款托盘的视觉空间。
- `final_file`: `res://resources/art/style_guides/visual_style_anchor_v6.png`
- `source_file`: `tmp/imagegen/style_anchor_v1/visual_style_anchor_v6_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/visual_style_anchor_v6.md`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `source_size`: 1671 x 941 px
- `pixel_format`: RGB，无透明通道；本图是完整矩形构图，不需要抠图。
- `sha256`: `757E71D696631C8B487F0CC7662B5B07FF066D67CB01567453BBAAB93E33768B`
- `processing`: 以内置编辑模式修改 v5；从内置生成目录无损复制，未缩放、未裁切、未调色、未执行透明处理。
- `visual_check`: 通过。耐心条约为 v5 的一半宽高；订单卡缩小并未遮挡顾客；收款托盘与鏊子之间存在清楚的空桌面带；半身顾客、完整头发、左右各 6 槽、长空托盘和底部控制条保持完整；未发现文字、货币、品牌或水印。
- `layering_note`: 耐心值、订单文字、订单图标、钱币和付款动作必须由 Godot 或独立动态素材生成；本图只提供空 UI 底板和固定收款托盘。
- `design_conflict`: `docs/game_design.md` 当前仍写着“营业台最多 8 个固定配料槽”；v6 延续 v5 的 12 槽。用户确认前不修改设计文档。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 1,505,776-byte `CompressedTexture2D` cache. The sandbox also reported unrelated user-level editor-settings/root-certificate warnings after import completion.
- `human_review`: pending

## visual_style_anchor_v5

- `status`: review
- `purpose`: 缩小工作台并扩大顾客区；顾客显示半身且站在柜台后方；鏊子约为 v4 的 77%–80%；左侧 6 个素菜槽、右侧 6 个荤菜槽；增加长收款托盘、空耐心条和空订单需求卡。
- `final_file`: `res://resources/art/style_guides/visual_style_anchor_v5.png`
- `source_file`: `tmp/imagegen/style_anchor_v1/visual_style_anchor_v5_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/visual_style_anchor_v5.md`
- `rejected_attempts`: `tmp/imagegen/style_anchor_v1/visual_style_anchor_v5_attempt1_small_griddle_short_tray.png`、`tmp/imagegen/style_anchor_v1/visual_style_anchor_v5_attempt2_griddle_below_80pct.png`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `source_size`: 1671 x 941 px
- `pixel_format`: RGB，无透明通道；本图是完整矩形构图，不需要抠图。
- `sha256`: `A7243F0FC8BA3773374B130157606D31FB1B03EAA7591CBB74EAAF33912FAE6C`
- `processing`: 以 v4 为风格与比例参考，经过一次布局重构和两次定向比例修正；最终文件从内置生成目录无损复制，未缩放、未裁切、未调色、未执行透明处理。
- `visual_check`: 通过。半身顾客与工作台由后沿明确分隔；顾客头发完整；空耐心条位于头顶；空订单卡位于头部右上方；长空收款托盘横跨筷子筒至右侧酱料区；左右各 6 个槽位；鏊子完整可见且不与槽位或底部控制条重叠；未发现文字、货币、品牌或水印。
- `layering_note`: 耐心值、订单文字、订单图标、钱币和付款动作必须由 Godot 或独立动态素材生成；本图只提供空底板和固定收款托盘。
- `design_conflict`: `docs/game_design.md` 当前仍写着“营业台最多 8 个固定配料槽”；v5 使用 12 槽。用户确认前不修改设计文档。
- `godot_import`: passed — Godot 4.7.1 generated the `.png.import` sidecar and a 1,481,698-byte `CompressedTexture2D` cache. The sandbox also reported unrelated user-level editor-settings/root-certificate warnings after import completion.
- `human_review`: pending

## visual_style_anchor_v4

- `status`: review
- `purpose`: 在已确认的 v2 画风、鏊子尺寸和工作台布局上，加入清晰上半身顾客与固定空收款托盘；作为后续 P0/P1 分层素材的最新构图锚点。
- `final_file`: `res://resources/art/style_guides/visual_style_anchor_v4.png`
- `source_file`: `tmp/imagegen/style_anchor_v1/visual_style_anchor_v4_builtin_source.png`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `source_size`: 1672 x 941 px
- `pixel_format`: RGB，无透明通道；本图是完整矩形构图，不需要抠图。
- `sha256`: `83AB63C221EB57852E8E57854BE98C9EF7033C43CFA02AC6CEAB9B351D392539`
- `processing`: 以内置编辑模式修改 v3 的顾客比例和纵向位置；从内置生成目录无损复制到项目 `tmp/imagegen` 与 `resources/art/style_guides`；未缩放、未裁切、未调色、未执行透明处理。
- `visual_check`: 通过。顾客完整头发与发梢均在画布内，顶部保留可见安全边距；顾客上半身清楚；空收款托盘位于顾客面前；鏊子仍为中央主交互面，底部控制条完整；未发现文字、品牌、货币符号或水印。
- `layering_note`: 收款托盘是固定工作台层；纸币、硬币、付款动作和阴影必须作为后续独立动态素材，不得烘焙进背景。
- `godot_import`: passed — Godot 4.7.1 headless `--import` generated the `.png.import` sidecar and a 1,422,528-byte `CompressedTexture2D` cache. The sandbox also reported unrelated user-level editor-settings/root-certificate warnings after import completion.
- `human_review`: pending

### v4 顾客裁切修正提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake gameplay composition anchor v4, customer crop correction
Input images: Image 1 is the v3 edit target
Primary request: fix only the cropped customer head. Scale the entire customer figure down slightly and move it downward enough that the complete hairstyle and every hair tip are fully visible inside the canvas, with a clear 24 to 32 pixel background margin above the highest hair point.
Customer constraints: preserve the same person, face, expression, hairstyle, muted-green shirt, pose, bold outline, flat-color style, centered alignment and upper-body readability. Do not redesign facial features or hair. Keep the customer behind the upper service counter and do not let the torso overlap the payment tray.
Absolute invariants: keep the empty payment tray in exactly the same position, size and appearance; preserve the exact canvas, crop, fixed near-top-down camera, griddle diameter and position, full bottom utility strip, left tools and batter pot, right ingredient and sauce trays, bottles, plant, counter edges, foreground lip, colors, lighting and line weight. Do not zoom, reframe, shift, resize or redraw the workstation. Change only the customer's scale and vertical placement required to reveal the full hair.
Payment-layer constraint: tray remains empty; no coins, banknotes, currency symbols, prices, hands exchanging money, labels or payment shadows.
No text, letters, numbers, signage, brands, logos, watermarks, extra people, extra props, new ingredients, magical content, photorealism, painterly texture, thin lines, or glossy 3D.
```

## ingredient_stock_states_v1

- `status`: review-runtime-integrated
- `purpose`: picture-only 1–6 portion feedback for the four P1 ingredients; no numeric stock counter is rendered.
- `final_files`: 24 RGBA PNGs under `res://resources/art/ingredients/{egg,baocui,ham_sausage,scallion}/stock/`
- `prompt_file`: `res://resources/art/prompts/ingredient_stock_states_v1.md`
- `generator`: Codex built-in `image_gen`; chroma removal with the ImageGen helper; deterministic atlas crop/normalization with `tools/build_ingredient_stock_assets.py`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 512 x 512 px RGBA per state
- `asset_check`: passed; dimensions, alpha, transparent corners, visible content, and distinct state files
- `godot_import`: passed with Godot 4.7.1
- `runtime_integration`: passed; all 24 textures are stable `.tscn` resources and the rack selects the matching current-stock image
- `human_review`: pending

## ingredient_restock_containers_v1

- `status`: review-runtime-integrated
- `purpose`: clickable egg carton, baocui tin, ham freshness box, and scallion enamel jar above the left-side ingredient rack.
- `final_files`: `res://resources/art/workstation/restock/egg_carton_v1.png`, `baocui_tin_v1.png`, `ham_fresh_box_v1.png`, `scallion_enamel_jar_v1.png`
- `prompt_file`: `res://resources/art/prompts/ingredient_restock_containers_v1.md`
- `generator`: Codex built-in `image_gen`; chroma removal with the ImageGen helper; normalization with `tools/build_ingredient_stock_assets.py`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 512 x 512 px RGBA per prop
- `asset_check`: passed; dimensions, alpha, transparent corners, and visible content
- `godot_import`: passed with Godot 4.7.1
- `runtime_integration`: passed; four scene-backed controls refill only their matching ingredient
- `human_review`: pending

## workstation_backplate_v2

- `status`: review-runtime-integrated
- `purpose`: remove the baked-in upper-left napkin box and chopstick holder so the four refill-container controls replace them without overlap.
- `final_file`: `res://resources/art/workstation/background/workstation_backplate_v2.png`
- `source_file`: `tmp/imagegen/ingredient_stock/backplate/workstation_backplate_v2_imagegen_source.png`
- `prompt_file`: `res://resources/art/prompts/workstation_backplate_v2.md`
- `generator`: Codex built-in `image_gen`, precise-object-edit mode; bounded deterministic regional composite with `tools/build_workstation_backplate_v2.py`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `processing`: one-pixel model canvas drift normalized; only the former napkin/chopstick region is composited; pixels outside the feathered edit mask are validated unchanged
- `godot_import`: passed with Godot 4.7.1
- `runtime_integration`: passed; `workstation.tscn` uses v2 while refill containers remain independent controls
- `human_review`: pending

## visual_style_anchor_v3

- `status`: superseded-draft
- `purpose`: 加入清晰顾客和空收款托盘的布局草案；最终候选因顾客头发越出画布而被 v4 取代。
- `file`: `res://resources/art/style_guides/visual_style_anchor_v3.png`
- `source_file`: `tmp/imagegen/style_anchor_v1/visual_style_anchor_v3_builtin_source.png`
- `rejected_attempts`: `tmp/imagegen/style_anchor_v1/visual_style_anchor_v3_layout_drift_source.png`、`tmp/imagegen/style_anchor_v1/visual_style_anchor_v3_attempt2_layout_drift_source.png`
- `rejection_notes`: 前两次尝试缩小并下移鏊子、裁切底部控制条；第三次恢复工作台布局，但顾客头顶仍被画布裁切。

## visual_style_anchor_v2

- `status`: review
- `purpose`: ProjectCake 固定近俯视操作台的视觉风格基准图与构图锚点；用于确认镜头、线宽、色板、工作台分区和鏊子比例，不直接作为已切层的运行素材。
- `final_file`: `res://resources/art/style_guides/visual_style_anchor_v2.png`
- `source_file`: `tmp/imagegen/style_anchor_v1/visual_style_anchor_v2_builtin_source.png`
- `generator`: Codex 内置 `image_gen`
- `generated_on`: 2026-08-01 (Asia/Shanghai)
- `source_size`: 1672 x 941 px
- `pixel_format`: RGB，无透明通道；本图是完整矩形构图，不需要抠图。
- `sha256`: `B964F4E7B14C403DCBDA7C9EFC3C561F71B65400854E69E213EFB0C531063234`
- `processing`: 从内置生成目录无损复制到项目 `tmp/imagegen` 与 `resources/art/style_guides`；未缩放、未裁切、未调色、未执行透明处理。
- `visual_check`: 通过。固定近俯视、单鏊子居中、鏊子横向约占画面一半、左右固定功能区、下方控制条、深棕粗轮廓、暖色大色块均清楚；未发现文字、品牌或水印。
- `known_limits`: 顶部顾客仅是无细节比例占位；右侧托盘内容仅用于构图密度参考，不代表正式 P1 配料造型或最终槽位内容。
- `godot_import`: passed — Godot 4.7.1 headless `--import` generated the `.png.import` sidecar and `CompressedTexture2D` cache. The sandbox also reported unrelated user-level editor-settings/root-certificate warnings; these did not prevent the texture import artifact from being written.
- `human_review`: confirmed on 2026-08-01 as the P0/P1 style, palette and griddle-size baseline; later customer/payment-area refinements continue in v4.

### 初始生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake game visual style benchmark and workstation composition anchor, full rectangular 16:9 gameplay view
Primary request: create one clear production-oriented 2D game concept image for a Chinese jianbing street-stall cooking game, validating the fixed gameplay camera, workstation proportions, and art style rather than presenting a cinematic illustration
Scene/backdrop: a warm, modest street-food stall; the upper band of the frame is the customer/service side with one very simple faceless customer torso silhouette only for scale, while the lower two-thirds is the player's workbench; keep the customer area visually separated and never overlapping the cooking surface
Subject: one single very large round dark iron griddle centered on the workbench, visually about 45 to 55 percent of the full frame and clearly the dominant interaction surface; stable tool area on the left with batter pot, ladle, scraper and spatula; stable ingredient and sauce trays on the right; narrow lower utility strip for heat control and currently held tool; uncluttered counter edges and a small foreground lip that could later become a separate occlusion layer
Style/medium: simple hand-drawn 2D cartoon game art, bold clean deep-brown outlines, large flat color shapes, at most base color plus one shadow and one highlight, crisp readable silhouettes, friendly grounded everyday street-stall feeling, not painterly and not 3D
Composition/framing: exact straight fixed near-top-down camera from the vendor/player side, symmetrical frontal workstation layout, no dutch angle, no isometric view, no cinematic perspective, no close-up; preserve clear empty interaction space around the griddle; 1920x1080-safe 16:9 composition
Lighting/mood: warm inviting street-stall ambience, soft unified light from upper left, calm and practical rather than dramatic
Color palette: warm cream, muted mustard, terracotta red, faded teal accents, dark brown outlines, charcoal iron griddle; restrained palette with strong value separation
Materials/textures: very limited subtle texture only—slight iron grain, simple wood grain, small food speckles; do not use noisy detail
Constraints: one griddle only; one pancake production station only; fixed object positions; no extra cooking stations; no menus or panels covering the griddle; all interface text will be added later in Godot; no readable text, no letters, no numbers, no signage, no brand, no logo, no watermark; no magical ingredients, fantasy effects, absurd toppings, crowds, detailed character design, photorealism, anime rendering, glossy 3D, painterly brushwork, thin outlines, heavy gradients, excessive props, or baked cast shadows attached to movable tools and ingredients
Output intent: a single visual anchor image that can guide later separated background, foreground occluder, griddle, tool, ingredient, and texture assets.
```

### 定向简化提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake visual style benchmark revision
Input images: Image 1: current visual style anchor and edit target
Primary request: simplify only the rendering style so the whole scene uses larger flatter color blocks, fewer small texture marks, and cleaner bolder deep-brown outlines
Constraints: preserve the exact same fixed near-top-down camera, 16:9 framing, workstation geometry, single central griddle size and position, upper customer/service band, left tool and batter area, right ingredient and sauce tray area, bottom utility strip, object count, silhouettes, and warm palette; do not move, add, remove, replace, or redesign any objects; keep the large griddle visually dominant; keep no text, letters, numbers, logos, brands, signs, or watermarks; keep movable tools and ingredients free of baked cast shadows
Targeted style change only: reduce wood grain, tile mottling, iron speckling, food micro-detail, gradients, and highlight bands; use at most base color plus one simple shadow and one simple highlight per material; retain clear material identity without painterly detail
Avoid: photorealism, 3D gloss, thin linework, extra props, extra customers, new ingredients, dramatic lighting, perspective changes.
```

## visual_style_anchor_v1

- `status`: superseded-draft
- `purpose`: 初始构图草案；因木纹、铁面与食材微纹理偏多，被 v2 的单项简化迭代取代。
- `file`: `res://resources/art/style_guides/visual_style_anchor_v1.png`
- `source_file`: `tmp/imagegen/style_anchor_v1/visual_style_anchor_v1_builtin_source.png`
- `source_size`: 1672 x 941 px
- `sha256`: `F90828A4DAAB37930973AB2E11485099E32F372F9600987B0DDD727590E2BAF3`
- `processing`: 仅无损复制；未缩放、未裁切、未调色。

## meat_floss_pile_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 肉松解锁配料的槽位/取料态；细纤维松散成堆，供后续撒料交互使用。
- `final_file`: `res://resources/art/ingredients/meat_floss/meat_floss_pile_v1.png`
- `source_file`: `tmp/imagegen/p2_ingredients_v1/meat_floss_pile_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/meat_floss_pile_v1.md`
- `generator`: Codex 内置 `image_gen`；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `alpha_bbox`: (125, 333) - (1129, 924)
- `sha256`: `7BEE81995798F8B5DDED4DBF529A0329809037E3A30293771A168CCA6E19F8E4`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed — 细、干、蓬松的肉松纤维可读；淘汰了粗条状、易误读为虾仁/面条的初稿。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 597,600-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending — 尚未加入 P2 配料数据、拖放和撒料评分路径。
- `human_review`: pending

## meat_floss_scattered_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 肉松撒料后的分散态，用于表达分布不均风险。
- `final_file`: `res://resources/art/ingredients/meat_floss/meat_floss_scattered_v1.png`
- `source_file`: `tmp/imagegen/p2_ingredients_v1/meat_floss_scattered_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/meat_floss_scattered_v1.md`
- `generator`: Codex 内置 `image_gen`；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `alpha_bbox`: (81, 287) - (1169, 938)
- `sha256`: `8F9BEF3C408C8714EE06EB47E686965F19E2850052BF3AA51005492991DD579E`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed — 恰好 14 个分离的小肉松团，覆盖范围宽且留有明显间隙。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 527,500-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## start_menu_background_v1

- `status`: integrated-runtime-verified
- `purpose`: PC 开始页 16:9 背景；提供左侧菜单留白与开摊前的安静工作台叙事。
- `final_file`: `res://resources/art/ui/start_menu/start_menu_background_v1.png`
- `source_file`: `C:/Users/Administrator/.codex/generated_images/019fc040-fcc9-78e3-a051-69679de0ef3e/exec-622d9aa3-5bb9-49c8-b375-2da4d564791e.png`
- `prompt_file`: `res://resources/art/prompts/start_menu_background_v1.md`
- `generator`: Codex 内置 `image_gen`，以 `visual_style_anchor_v8_builtin_source.png` 作为严格画风参考。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGB
- `sha256`: `C748C342E0BEE4E047A079696E7381A6426EB04F71D5E53E63A7AB546B3233E1`
- `visual_check`: passed — 暖橙、深棕粗描边与青绿色点缀和现有工作台一致；左侧 UI 留白清楚；无人物、文字、品牌或水印。
- `godot_import`: passed — Godot 4.7.1 已生成 `.png.import` 并能作为 `Texture2D` 加载。
- `runtime_integration`: passed — `start_menu.tscn` 以 cover 模式接入；D3D12 Forward Mobile 1920x1080 截图通过。
- `human_review`: pending

## P3 候选素材批次（2026-08-02）

- `stage_scope`: 本批只生成用户点名的少量 P3 候选美术，不代表 P2 评审已通过，也不代表 P3 已进入正式量产。
- `shared_generator`: Codex 内置 `image_gen`。
- `shared_style_reference`: `res://resources/art/style_guides/visual_style_anchor_v8.png` 与现有 P2 底板/顾客/UI。
- `shared_text_policy`: 所有招牌、照片、事件内容、配方信息和选项区域均为空白；文字由 Godot 动态排版。
- `shared_import_check`: Godot 4.7.1 headless editor import passed；运行时场景接入与真人视觉验收仍为 pending。

## workstation_backplate_mid_v1

- `status`: review-runtime-integration-pending
- `purpose`: P3 中期固定摊位候选外观；增加深青木饰、熟客照片夹和空白菜单架，不改变核心交互区域。
- `final_file`: `res://resources/art/workstation/background/workstation_backplate_mid_v1.png`
- `source_file`: `tmp/imagegen/p3_stall_v1/workstation_backplate_mid_v1_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/workstation_backplate_mid_v1.md`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1671 x 941 px RGB
- `sha256`: `BE86E502527361626CFA1E607D2A65860D3E6FC34D774AD1FB887103C5FF54E5`
- `geometry_check`: passed for canvas and visual layout — 12 个空配料槽、中央空操作区、收款托盘和底部控制区保留；精确交互坐标须在接入后复核。
- `visual_check`: passed — 阶段成长清楚，无顾客、配料、动态 UI、文字、品牌或水印。
- `godot_import`: passed — 生成 `.png.import` 与 1,613,100-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## workstation_backplate_late_v1

- `status`: review-runtime-integration-pending
- `purpose`: P3 后期固定摊位候选外观；增加奖牌、收藏品、配方展示框和固定灯具，不自动化核心操作。
- `final_file`: `res://resources/art/workstation/background/workstation_backplate_late_v1.png`
- `source_file`: `tmp/imagegen/p3_stall_v1/workstation_backplate_late_v1_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/workstation_backplate_late_v1.md`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1671 x 941 px RGB
- `sha256`: `213FA2386D6F6D7FC8024609CB952D9AC250A0C9A7F24B72230894B57D0E1A76`
- `geometry_check`: passed for canvas and visual layout — 12 个空配料槽、中央空操作区、收款托盘和底部控制区保留；精确交互坐标须在接入后复核。
- `visual_check`: passed — 中后期差异可读，装饰没有进入操作台核心区域；无文字、品牌或水印。
- `godot_import`: passed — 生成 `.png.import` 与 1,691,730-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## customer_01_regular_greeting_v1

- `status`: review-runtime-integration-pending
- `purpose`: P3 熟客特殊问候状态；保持 `customer_01` 身份，改为右手挥手和熟悉顾客的明亮表情。
- `final_file`: `res://resources/art/customers/customer_01/customer_01_regular_greeting_v1.png`
- `source_file`: `tmp/imagegen/p3_characters_ui_v1/customer_01_regular_greeting_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_01_regular_greeting_v1.md`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1427 x 1102 px RGBA，与现有 `customer_01` 画布一致
- `alpha_bbox`: (345, 101) - (936, 972)
- `sha256`: `C553CC4DB1683E5D98DF2AB7F43905DF613CDCCB8BDFA771BDA4897E0EAAE1ED`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红键色残留 0。
- `visual_check`: passed — 身份、服装和固定视角保留；挥手五指可读，无附件、文字或额外肢体。
- `godot_import`: passed — 生成 `.png.import` 与 342,918-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## regular_customer_badge_v1

- `status`: review-runtime-integration-pending
- `purpose`: P3 熟客独立胸章附件；由 Godot 叠加到人物层，不烘焙进角色状态图。
- `final_file`: `res://resources/art/customers/attachments/regular_customer_badge_v1.png`
- `source_file`: `tmp/imagegen/p3_characters_ui_v1/regular_customer_badge_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/regular_customer_badge_v1.md`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `alpha_bbox`: (209, 185) - (1044, 1064)
- `sha256`: `9061EB4BBABAAF12723D507A31F4E0E8A3393A635B26B6E253B05438C86DF4B7`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红键色残留 0。
- `visual_check`: passed — 黄铜、青绿珐琅和无文字煎饼符号在小尺寸下仍可辨认。
- `godot_import`: passed — 生成 `.png.import` 与 456,888-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending — 具体胸口挂点需在人物场景中校准。
- `human_review`: pending

## supplier_01_neutral_v1

- `status`: review-runtime-integration-pending
- `purpose`: P3 供应商事件角色中性状态；角色层与事件面板、文本、物品和阴影分离。
- `final_file`: `res://resources/art/suppliers/supplier_01/supplier_01_neutral_v1.png`
- `source_file`: `tmp/imagegen/p3_characters_ui_v1/supplier_01_neutral_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/supplier_01_neutral_v1.md`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px RGBA
- `alpha_bbox`: (517, 112) - (1017, 976)
- `suggested_counter_pivot`: 约 (767, 976)
- `sha256`: `4C616A44BDFADA6829141EDF7D59C943A585770B4DD07D28C794AB608684FF48`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红键色残留 0。
- `visual_check`: passed — 发髻、砖红工作外套、青绿围裙、双手和中性商务表情完整；无文字、道具或额外肢体。
- `godot_import`: passed — 生成 `.png.import` 与 374,996-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## supplier_event_panel_base_v1

- `status`: review-runtime-integration-pending
- `purpose`: P3 供应商事件空白面板；左侧头像、右侧标题/描述和两个选项由 Godot 动态填充。
- `final_file`: `res://resources/art/ui/supplier_event/supplier_event_panel_base_v1.png`
- `source_file`: `tmp/imagegen/p3_characters_ui_v1/supplier_event_panel_base_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/supplier_event_panel_base_v1.md`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGBA
- `alpha_bbox`: (91, 71) - (1581, 858)
- `sha256`: `86D384CFB33C2063F142CD2D74FFDF52632E42E1189F509E04187C284A745DB1`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红键色残留 0。
- `visual_check`: passed — 头像窗、标题区、描述区和双选项区层级清楚，内容全部空白。
- `godot_import`: passed — 生成 `.png.import` 与 599,638-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## signature_recipe_panel_base_v1

- `status`: review-runtime-integration-pending
- `purpose`: P3 招牌配方展示空白面板；成品图、六个配料图标、品质章和文字由 Godot 动态填充。
- `final_file`: `res://resources/art/ui/recipe/signature_recipe_panel_base_v1.png`
- `source_file`: `tmp/imagegen/p3_characters_ui_v1/signature_recipe_panel_base_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/signature_recipe_panel_base_v1.md`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGBA
- `alpha_bbox`: (193, 41) - (1474, 891)
- `sha256`: `9427065AAD5B1F9A52F12EE6438C6CE105E3CE83D9B3371F6CCD671898A56E1E`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红键色残留 0。
- `visual_check`: passed — 标题、成品圆窗、六个配料位、品质章和备注条均为空白，无 AI 文字。
- `godot_import`: passed — 生成 `.png.import` 与 909,976-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## weather_rain_v1

- `status`: review-runtime-integration-pending
- `purpose`: P3 雨天独立叠加层；只包含稀疏雨线和上部飞溅，不修改摊位底板。
- `final_file`: `res://resources/art/workstation/overlays/weather_rain_v1.png`
- `source_file`: `tmp/imagegen/p3_overlays_v1/weather_rain_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/weather_rain_v1.md`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1671 x 941 px RGBA
- `alpha_bbox`: (18, 7) - (1645, 416)
- `sha256`: `2089E5B79CF2E4F773965F5F64269149967EDC252998B8CA054F8448F57FFFD2`
- `alpha_check`: passed after `--edge-contract 1` — 画布边缘非透明像素 0；品红键色残留 0。
- `visual_check`: passed in composite — 雨线集中在上部背景，中央操作台与配料槽未遮挡。
- `godot_import`: passed — 生成 `.png.import` 与 62,882-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## lighting_string_lights_v1

- `status`: review-runtime-integration-pending
- `purpose`: P3 夜间灯串独立层；灯泡和轻微光晕由图层提供，全屏夜色由 Godot 遮罩控制。
- `final_file`: `res://resources/art/workstation/overlays/lighting_string_lights_v1.png`
- `source_file`: `tmp/imagegen/p3_overlays_v1/lighting_string_lights_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/lighting_string_lights_v1.md`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1671 x 941 px RGBA
- `alpha_bbox`: (13, 94) - (1660, 300)
- `sha256`: `F21FC8BFD06B5DAC9E1D7556F078D761407B5F4773951BF6A452D23B2071A6B4`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红键色残留 0；保留 19,555 个光晕抗锯齿/半透明像素。
- `visual_check`: passed in composite — 灯串位于上部，不遮挡操作台；未烘焙夜色背景。
- `godot_import`: passed — 生成 `.png.import` 与 132,124-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## festival_spring_v1

- `status`: review-runtime-integration-pending
- `purpose`: P3 春节独立装饰层；左右各两盏灯笼和角部挂结，中央招牌/顾客区留空。
- `final_file`: `res://resources/art/workstation/overlays/festival_spring_v1.png`
- `source_file`: `tmp/imagegen/p3_overlays_v1/festival_spring_v1_chromakey.png`
- `rejected_attempts`: `tmp/imagegen/p3_overlays_v1/festival_spring_v1_attempt1_obstructive_chromakey.png`、`tmp/imagegen/p3_overlays_v1/festival_spring_v1_attempt2_center_obstruction_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/festival_spring_v1.md`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1671 x 941 px RGBA
- `alpha_bbox`: (0, 0) - (1671, 221)
- `sha256`: `D4947D9A102D8FCBE7A0F0F775DC61D21DBD6B5FA221CC6AF2B7A9FA87F85E61`
- `alpha_check`: passed — 品红键色残留 0；37 个画布边缘非透明像素来自按设计贴边的顶部挂线，不是键色污染。
- `visual_check`: passed in composite after two rejected layouts — 中央招牌、顾客区、收款托盘和工作台完全无遮挡，无文字或汉字。
- `godot_import`: passed — 生成 `.png.import` 与 111,560-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## pork_tenderloin_portion_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 里脊解锁配料的槽位/取料态。
- `final_file`: `res://resources/art/ingredients/pork_tenderloin/pork_tenderloin_portion_v1.png`
- `source_file`: `tmp/imagegen/p2_ingredients_v1/pork_tenderloin_portion_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/pork_tenderloin_portion_v1.md`
- `generator`: Codex 内置 `image_gen`；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `alpha_bbox`: (126, 338) - (1133, 916)
- `sha256`: `4636081E64F7595E637D577C32CA7AAD864C43B66BD7996E72FED8AE4E124B63`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed — 不规则圆钝端部与瘦肉截面可读；淘汰了过度方正、近似午餐肉的初稿。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 298,284-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending — 尚未加入 P2 配料数据与厚重配料的面饼损伤/折叠鼓包判定。
- `human_review`: pending

## pork_tenderloin_slices_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 里脊放置后的三条厚切状态，强调重量与折叠鼓包风险。
- `final_file`: `res://resources/art/ingredients/pork_tenderloin/pork_tenderloin_slices_v1.png`
- `source_file`: `tmp/imagegen/p2_ingredients_v1/pork_tenderloin_slices_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/pork_tenderloin_slices_v1.md`
- `generator`: Codex 内置 `image_gen`；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `alpha_bbox`: (160, 230) - (1114, 1016)
- `sha256`: `E2E32FB56D485A9690260CF2E46C2B079B20F1880950C42D360040923DAEA1BC`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed — 恰好 3 条厚切熟里脊，轮廓完整，层叠关系清楚。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 519,220-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## currency_coin_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 货币/营业收入的小尺寸 UI 图标。
- `final_file`: `res://resources/art/ui/economy/currency_coin_v1.png`
- `source_file`: `tmp/imagegen/p2_ui_icons_v1/currency_coin_v1_chromakey.png`
- `rejected_attempts`: `tmp/imagegen/p2_ui_icons_v1/currency_coin_v1_attempt1_face_like_chromakey.png`、`tmp/imagegen/p2_ui_icons_v1/currency_coin_v1_attempt1_face_like_alpha.png`
- `prompt_file`: `res://resources/art/prompts/currency_coin_v1.md`
- `generator`: Codex 内置 `image_gen`；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `alpha_bbox`: (237, 304) - (1043, 998)
- `sha256`: `61984D7F39DB3EA865E82D538D631970C60787A0588C8DF5E2C9EE53EAD75D22`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at 64 px — 三枚硬币均只有一个方孔；旧版圆点在小尺寸下有脸谱误读风险，已淘汰但保留源文件。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 375,980-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## reputation_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 口碑值的小尺寸 UI 图标。
- `final_file`: `res://resources/art/ui/economy/reputation_v1.png`
- `source_file`: `tmp/imagegen/p2_ui_icons_v1/reputation_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/reputation_v1.md`
- `generator`: Codex 内置 `image_gen`；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `alpha_bbox`: (200, 193) - (1054, 1062)
- `sha256`: `4B0B00351CAB49689F4C27D314922AD31F6DCE3D7609ABFC0AE0AAF9148EC6F1`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at 64 px — 对话气泡与爱心的组合清楚，无文字和评分数字。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 453,436-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## upgrade_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 摊位/设备升级的小尺寸 UI 图标。
- `final_file`: `res://resources/art/ui/economy/upgrade_v1.png`
- `source_file`: `tmp/imagegen/p2_ui_icons_v1/upgrade_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/upgrade_v1.md`
- `generator`: Codex 内置 `image_gen`；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `alpha_bbox`: (229, 211) - (1025, 1043)
- `sha256`: `DBD1795A3151688F89A7E96D203413B3F80ED67518C3BA33E55886562CC67580`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at 64 px — 扳手与向上箭头均清楚，无文字和等级数字。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 408,270-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## workstation_backplate_upgrade_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 固定摊位的一个升级外观状态；只改变固定装饰，不应改变操作区域坐标。
- `final_file`: `res://resources/art/workstation/background/workstation_backplate_upgrade_v1.png`
- `source_file`: `tmp/imagegen/p2_environment_ui_v1/workstation_backplate_upgrade_v1_builtin_source.png`
- `prompt_file`: `res://resources/art/prompts/workstation_backplate_upgrade_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1671 x 941 px RGB，与 `workstation_backplate_v1.png` 完全一致
- `sha256`: `1EC79D5119E21C492AA418F63391536DFCA3B8781D2C948F780A16A848FD2349`
- `processing`: 无裁切、无缩放、无调色、无透明处理。
- `geometry_check`: passed for canvas size and visual layout — 保留 12 个空配料槽、中央操作区、底部控制区与既有固定镜头；精确交互坐标仍须在接入场景后验证。
- `visual_check`: passed — 新增条纹棚布、空白招牌、墙面空框、青铜色边饰与植物升级；无烘焙文字、顾客、食材或动态 UI。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 1,591,622-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending — 尚未增加摊位升级状态切换。
- `human_review`: pending

## day_summary_panel_base_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 日结界面的无文字装饰底板；数据、数字、标题和按钮由 Godot 动态渲染。
- `final_file`: `res://resources/art/ui/day_summary/day_summary_panel_base_v1.png`
- `source_file`: `tmp/imagegen/p2_environment_ui_v1/day_summary_panel_base_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/day_summary_panel_base_v1.md`
- `generator`: Codex 内置 `image_gen`；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGBA
- `alpha_bbox`: (194, 49) - (1477, 893)
- `sha256`: `6CCD8B1A264163CB5B09A9989AD6ECFD3801947A1536C0E9CB8D798AEE09CA81`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed — 一块空标题带、恰好四个圆形指标位、两块中部明细板和一块底部提示板；无烘焙文字、数字、图标或按钮。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 583,654-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending — BusinessDayService、结算字段与日结场景绑定尚未实现。
- `human_review`: pending

## batter_spreader_upgrade_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 T 形刮板升级外观；加宽不锈钢横杆与防烫握把表达更稳定的手动摊面容错，不代表自动摊面。
- `final_file`: `res://resources/art/workstation/tools/batter_spreader_upgrade_v1.png`
- `source_file`: `tmp/imagegen/p2_tool_upgrades_v1/batter_spreader_upgrade_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/batter_spreader_upgrade_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGBA
- `alpha_bbox`: (402, 105) - (1305, 817)
- `sha256`: `90074B2570DA12EA601BBDD43306025A106D5A293A4BC7EB9C4C1457187F68F1`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at contact-sheet scale — T 形轮廓、加宽钢横杆、青绿色握把与黄铜连接环均清楚；无文字和自动化部件。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 222,768-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending — 尚未加入升级数据与工具换图路径。
- `human_review`: pending

## heat_controller_upgrade_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 温控器升级外观；旋钮、冷热色刻度块和指示灯增强火候信息反馈，不自动控制烹饪。
- `final_file`: `res://resources/art/workstation/tools/heat_controller_upgrade_v1.png`
- `source_file`: `tmp/imagegen/p2_tool_upgrades_v1/heat_controller_upgrade_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/heat_controller_upgrade_v1.md`
- `generator`: Codex 内置 `image_gen`；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1671 x 941 px RGBA
- `alpha_bbox`: (498, 34) - (1171, 830)
- `sha256`: `64C5DBA185FC4BE25E1BD479472FAABA44CD7B4E7F118262E191AF9B4C1F6359`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at contact-sheet scale — 手动旋钮、红色指针、冷热色弧形刻度和短电缆可读，未误读为时钟或计时器；无文字和数字。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 476,716-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending — 尚未定义温控升级参数、购买条件和场景绑定。
- `human_review`: pending

## sauce_brush_upgrade_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 酱刷升级外观；宽硅胶刷头表达更均匀的手动覆盖与易清洁性。
- `final_file`: `res://resources/art/workstation/tools/sauce_brush_upgrade_v1.png`
- `source_file`: `tmp/imagegen/p2_tool_upgrades_v1/sauce_brush_upgrade_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/sauce_brush_upgrade_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGBA
- `alpha_bbox`: (368, 65) - (1209, 857)
- `sha256`: `FF32E967AD9AA67A5562C5DC202570C4E7260CF8A64A16DF855AD784C10B2147`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at contact-sheet scale — 宽刷头、六条粗硅胶槽、钢箍、黄铜铆钉和防滑握把可读；无酱料、文字或自动化部件。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 302,654-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending — 尚未加入升级数据与工具换图路径。
- `human_review`: pending

## reinforced_paper_sleeve_upgrade_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 加固纸套升级外观；双层开口、青绿色加固带和侧面扣件表达对轻微裂口的手动支撑。
- `final_file`: `res://resources/art/workstation/tools/reinforced_paper_sleeve_upgrade_v1.png`
- `source_file`: `tmp/imagegen/p2_tool_upgrades_v1/reinforced_paper_sleeve_upgrade_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/reinforced_paper_sleeve_upgrade_v1.md`
- `generator`: Codex 内置 `image_gen`；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGBA
- `alpha_bbox`: (500, 90) - (1167, 817)
- `sha256`: `F7B135B4E335C987F12FAD7C1DDDF68ECA5B7854FD0ECDC9FEDB3055DC2881B4`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at contact-sheet scale — 开口与内层明确，未误读为平纸、信封或封闭纸袋；无食物、文字和图案。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 380,914-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending — 尚未加入升级数据与纸套按钮换图路径。
- `human_review`: pending

## batter_ladle_upgrade_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 面糊勺升级外观；清晰内沿、黄铜连接环与防烫握把表达更稳定的手动定量取用。
- `final_file`: `res://resources/art/workstation/tools/batter_ladle_upgrade_v1.png`
- `source_file`: `tmp/imagegen/p2_tool_upgrades_v1/batter_ladle_upgrade_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/batter_ladle_upgrade_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGBA
- `alpha_bbox`: (418, 84) - (1290, 844)
- `sha256`: `E8CEBA883C6BA16ECCA6781D24447FF4F1585774A211261868F5C0F540CB2487`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at contact-sheet scale — 空圆勺、内沿、青绿色握把和端帽均清楚；无刻度文字、面糊或自动泵。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 237,080-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## folding_spatula_upgrade_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 折叠铲升级外观；薄圆前缘与两条加强槽表达更稳定的手动折叠控制。
- `final_file`: `res://resources/art/workstation/tools/folding_spatula_upgrade_v1.png`
- `source_file`: `tmp/imagegen/p2_tool_upgrades_v1/folding_spatula_upgrade_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/folding_spatula_upgrade_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGBA
- `alpha_bbox`: (357, 76) - (1267, 845)
- `sha256`: `EFE01F0B44F150EE02A0DD86198FE4B3427D0B757326B5C03A845AC0B5E4230C`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at contact-sheet scale — 宽铲头、两条加强槽、黄铜铲箍和防滑握把均清楚；无食物或自动化部件。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 265,016-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## ingredient_tongs_upgrade_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 配料夹升级外观；双防滑握区与宽硅胶夹头表达更安全的手动整理。
- `final_file`: `res://resources/art/workstation/tools/ingredient_tongs_upgrade_v1.png`
- `source_file`: `tmp/imagegen/p2_tool_upgrades_v1/ingredient_tongs_upgrade_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/ingredient_tongs_upgrade_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGBA
- `alpha_bbox`: (366, 60) - (1390, 847)
- `sha256`: `A857B7C2EE2234F296B3DD8E511EEB7D83CD452FE6A7A991784A99E56663B56A`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at contact-sheet scale — 开口夹形、黄铜铰点、双握区和浅色硅胶夹头可读；无配料或自动锁定结构。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 294,830-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## oil_absorbent_paper_upgrade_v1

- `status`: review-runtime-integration-pending
- `purpose`: P2 吸油纸升级外观；加固边、稀疏压纹、折线与拉片表达更强吸油和更易取用。
- `final_file`: `res://resources/art/workstation/tools/oil_absorbent_paper_upgrade_v1.png`
- `source_file`: `tmp/imagegen/p2_tool_upgrades_v1/oil_absorbent_paper_upgrade_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/oil_absorbent_paper_upgrade_v1.md`
- `generator`: Codex 内置 `image_gen` 精确对象编辑；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1672 x 941 px RGBA
- `alpha_bbox`: (392, 66) - (1274, 849)
- `sha256`: `06E4F09E57F536A571607F9FE3197EF52038F53E3DCCD46B1469FE3526070486`
- `alpha_check`: passed — 画布边缘非透明像素 0；品红/绿色键色残留 0。
- `visual_check`: passed at contact-sheet scale — 单张纸、青绿色加固边、稀疏压纹、两条折线和角部拉片可读，未误读为纸套或纸堆。
- `godot_import`: passed — Godot 4.7.1 生成 `.png.import` 与 382,808-byte `CompressedTexture2D` 缓存。
- `runtime_integration`: pending
- `human_review`: pending

## paper_bag_package_v1

- `status`: runtime-integrated-human-review-pending
- `purpose`: Finished normal paper-bag serving state, replacing the generated rectangle placeholder.
- `final_file`: `res://resources/art/workstation/packaging/paper_bag_package_v1.png`
- `source_file`: `tmp/imagegen/package_serving_v1/paper_bag_package_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/paper_bag_package_v1.md`
- `generator`: Codex built-in `image_gen`, then `remove_chroma_key.py`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `sha256`: `20affe2426d6bd21b2f4c7f40e1355f677fb6617427e47fd1b94cb0f3d20fd7e`
- `alpha_check`: passed; transparent corner pixels and zero green fringe pixels
- `runtime_integration`: `PancakeFoldOverlay.current_package_texture()` maps `PACKAGE_BAG` to this asset
- `human_review`: pending

## reinforced_paper_sleeve_package_v1

- `status`: runtime-integrated-human-review-pending
- `purpose`: Finished reinforced-sleeve rescue state, replacing the generated rectangle placeholder.
- `final_file`: `res://resources/art/workstation/packaging/reinforced_paper_sleeve_package_v1.png`
- `source_file`: `tmp/imagegen/package_serving_v1/reinforced_paper_sleeve_package_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/reinforced_paper_sleeve_package_v1.md`
- `generator`: Codex built-in `image_gen`, then `remove_chroma_key.py`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `sha256`: `206e01425f7ab7f42c9335d630f011e04aef4647a80f28aa797d9c76bf12b0e0`
- `alpha_check`: passed; transparent corner pixels and zero green fringe pixels
- `runtime_integration`: `PancakeFoldOverlay.current_package_texture()` maps `PACKAGE_SLEEVE` to this asset
- `human_review`: pending

## serving_tray_package_v1

- `status`: runtime-integrated-human-review-pending
- `purpose`: Finished tray rescue state for a severely torn fold, replacing the generated rectangle placeholder.
- `final_file`: `res://resources/art/workstation/packaging/serving_tray_package_v1.png`
- `source_file`: `tmp/imagegen/package_serving_v1/serving_tray_package_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/serving_tray_package_v1.md`
- `generator`: Codex built-in `image_gen`, then `remove_chroma_key.py`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `sha256`: `607ceb3d4bb646612068491e9758769c8a6807477eef61e28c22ef5c96e8fe24`
- `alpha_check`: passed; transparent corner pixels and zero green fringe pixels
- `runtime_integration`: `PancakeFoldOverlay.current_package_texture()` maps `PACKAGE_TRAY` to this asset
- `human_review`: pending

## customer_01_accepting_bag_v1

- `status`: runtime-integrated-human-review-pending
- `purpose`: Customer 01 receiving the packaged pancake after the player clicks the finished bag.
- `final_file`: `res://resources/art/customers/customer_01/customer_01_accepting_bag_v1.png`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_01_accepting_bag_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_01_accepting_bag_v1.md`
- `generator`: Codex built-in `image_gen`, then `remove_chroma_key.py`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1419 x 1108 px RGBA
- `sha256`: `372d6ed8da063f064cdcf6e14a223dec1c44943c254d099929ac7f494e9ce907`
- `alpha_check`: passed; transparent corner pixels and zero magenta fringe pixels
- `runtime_integration`: `Workstation._complete_handoff_animation()` swaps the customer portrait to the cropped action sprite
- `human_review`: pending

## customer_01_paying_coins_v1

- `status`: runtime-integrated-human-review-pending
- `purpose`: Customer 01 paying with coins immediately after receiving the packaged pancake.
- `final_file`: `res://resources/art/customers/customer_01/customer_01_paying_coins_v1.png`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_01_paying_coins_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_01_paying_coins_v1.md`
- `generator`: Codex built-in `image_gen`, then `remove_chroma_key.py`
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1422 x 1106 px RGBA
- `sha256`: `bc899842b05607d330c5c945888727c076766a2176b5b9d8812a1c3878a884a7`
- `alpha_check`: passed; transparent corner pixels and zero magenta fringe pixels
- `runtime_integration`: `Workstation._show_customer_payment()` swaps the customer portrait and moves a coin into the payment slot
- `human_review`: pending

<!-- customer-service-all-customers-v1 -->
# Customer service action portraits — all customers v1

- Scope: customer_01 through customer_10, each with `accepting_bag` and `paying_coins`.
- Batch status: 20/20 final PNGs and 20/20 cropped AtlasTextures pass pixel and Godot 4.7.1 loading checks.
- Runtime note: customer_01 is already wired into the handoff/payment flow; customer_02—10 are art-complete but runtime mapping remains pending because this art-only task does not modify business scripts or scene logic.
- Human review: pending for the full 20-image contact sheet.
- Contact sheet: `tmp/imagegen/customer_service_v1/customer_service_contact_sheet_v1.png`.
- Pixel audit: `tmp/imagegen/customer_service_v1/customer_service_pixel_audit_v1.json` (`all_pass: true`).
- Godot audit: `tmp/customer_service_texture_audit.gd`; result `png=20 cropped=20 failures=0`.

| Customer | Accepting bag | Paying coins | Pixel | Godot | Runtime | Human |
|---|---|---|---|---|---|---|
| customer_01 | complete | complete | pass | pass | integrated | pending |
| customer_02 | complete | complete | pass | pass | pending | pending |
| customer_03 | complete | complete | pass | pass | pending | pending |
| customer_04 | complete | complete | pass | pass | pending | pending |
| customer_05 | complete | complete | pass | pass | pending | pending |
| customer_06 | complete | complete | pass | pass | pending | pending |
| customer_07 | complete | complete | pass | pass | pending | pending |
| customer_08 | complete | complete | pass | pass | pending | pending |
| customer_09 | complete | complete | pass | pass | pending | pending |
| customer_10 | complete | complete | pass | pass | pending | pending |

## customer_02_accepting_bag_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer receives the completed filled paper bag with both hands.
- `final_file`: `res://resources/art/customers/customer_02/customer_02_accepting_bag_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_02/customer_02_accepting_bag_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_02_accepting_bag_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_02_accepting_bag_v1.md`
- `rejected_processing_record`: `tmp/imagegen/customer_service_v1/customer_02_accepting_bag_v1_rejected_softmatte_alpha.png`; rejected because dominance-based soft matte removed warm skin; accepted source reprocessed with hard border key
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px RGBA
- `alpha_bbox`: (545, 77) - (974, 968); cropped size 429 x 891
- `transparent_ratio`: 0.808053
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `632bbfcdbfd39b69e98f1f6fec0a3746a1d3d8f092cdccbc4dccaeea559dccf4`
- `suggested_anchor`: cropped bottom-center `(x=214.5, y=891)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_02_accepting_bag_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_02 exactly: adult woman, warm skin, shoulder-length deep chestnut wavy hair, brick-red short-sleeve top with cream rounded collar, mustard-yellow lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_02_paying_coins_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer holds the received bag under the left arm and offers exactly three coins with the right hand.
- `final_file`: `res://resources/art/customers/customer_02/customer_02_paying_coins_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_02/customer_02_paying_coins_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_02_paying_coins_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_02_paying_coins_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px RGBA
- `alpha_bbox`: (435, 70) - (1070, 962); cropped size 635 x 892
- `transparent_ratio`: 0.772299
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `b3b4ddbd74bdab536a883cf241782d44d2a8559cdf230460f49c3ce7af858674`
- `suggested_anchor`: cropped bottom-center `(x=317.5, y=892)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_02_paying_coins_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_02 exactly: adult woman, warm skin, shoulder-length deep chestnut wavy hair, brick-red short-sleeve top with cream rounded collar, mustard-yellow lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_03_accepting_bag_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer receives the completed filled paper bag with both hands.
- `final_file`: `res://resources/art/customers/customer_03/customer_03_accepting_bag_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_03/customer_03_accepting_bag_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_03_accepting_bag_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_03_accepting_bag_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `alpha_bbox`: (338, 83) - (922, 1170); cropped size 584 x 1087
- `transparent_ratio`: 0.723262
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `b934aba7ade0eb3c8e371db8f898ab964c7a2d4e7810beb8bc37b652ad75a988`
- `suggested_anchor`: cropped bottom-center `(x=292.0, y=1087)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_03_accepting_bag_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_03 exactly: older woman, warm skin, silver-gray hair swept into a side/back bun, faded teal short-sleeve outer layer, warm cream inner blouse, terracotta lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_03_paying_coins_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer holds the received bag under the left arm and offers exactly three coins with the right hand.
- `final_file`: `res://resources/art/customers/customer_03/customer_03_paying_coins_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_03/customer_03_paying_coins_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_03_paying_coins_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_03_paying_coins_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1254 x 1254 px RGBA
- `alpha_bbox`: (275, 77) - (957, 1179); cropped size 682 x 1102
- `transparent_ratio`: 0.701997
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `e69327a875a8dbeb4b25f23ea6d6523866ff10a10ce54c7be3bed3b33e78648f`
- `suggested_anchor`: cropped bottom-center `(x=341.0, y=1102)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_03_paying_coins_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_03 exactly: older woman, warm skin, silver-gray hair swept into a side/back bun, faded teal short-sleeve outer layer, warm cream inner blouse, terracotta lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_04_accepting_bag_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer receives the completed filled paper bag with both hands.
- `final_file`: `res://resources/art/customers/customer_04/customer_04_accepting_bag_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_04/customer_04_accepting_bag_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_04_accepting_bag_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_04_accepting_bag_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px RGBA
- `alpha_bbox`: (506, 79) - (1017, 977); cropped size 511 x 898
- `transparent_ratio`: 0.803453
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `f8576b416fe3cc3630f2f28a82a286ce7e1f7f8a0b7704ce81bd035e2aad39e3`
- `suggested_anchor`: cropped bottom-center `(x=255.5, y=898)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_04_accepting_bag_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_04 exactly: middle-aged man, warm brown skin, close dark curly hair, navy polo with ochre collar and sleeve trim, brick-brown lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_04_paying_coins_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer holds the received bag under the left arm and offers exactly three coins with the right hand.
- `final_file`: `res://resources/art/customers/customer_04/customer_04_paying_coins_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_04/customer_04_paying_coins_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_04_paying_coins_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_04_paying_coins_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px RGBA
- `alpha_bbox`: (422, 61) - (1097, 988); cropped size 675 x 927
- `transparent_ratio`: 0.762576
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `f1b453316eb4d96a03a0c65b128049ae3971876fe80d47cfa827228098ab546b`
- `suggested_anchor`: cropped bottom-center `(x=337.5, y=927)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_04_paying_coins_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_04 exactly: middle-aged man, warm brown skin, close dark curly hair, navy polo with ochre collar and sleeve trim, brick-brown lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_05_accepting_bag_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer receives the completed filled paper bag with both hands.
- `final_file`: `res://resources/art/customers/customer_05/customer_05_accepting_bag_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_05/customer_05_accepting_bag_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_05_accepting_bag_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_05_accepting_bag_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px RGBA
- `alpha_bbox`: (534, 75) - (995, 976); cropped size 461 x 901
- `transparent_ratio`: 0.810920
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `25e22a11503596b03df9d1bc7339372923b1d734623b8af1baefd47846a7fb35`
- `suggested_anchor`: cropped bottom-center `(x=230.5, y=901)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_05_accepting_bag_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_05 exactly: young adult woman, warm skin, narrow oval face, blunt bangs and chin-length dark bob, mauve square-neck short-sleeve top, warm cream lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_05_paying_coins_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer holds the received bag under the left arm and offers exactly three coins with the right hand.
- `final_file`: `res://resources/art/customers/customer_05/customer_05_paying_coins_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_05/customer_05_paying_coins_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_05_paying_coins_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_05_paying_coins_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px RGBA
- `alpha_bbox`: (440, 63) - (1067, 977); cropped size 627 x 914
- `transparent_ratio`: 0.778761
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `2e2b64e7e3a0dc6d240530bbd1c93e814d8055793b10b730b31de47add50c811`
- `suggested_anchor`: cropped bottom-center `(x=313.5, y=914)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_05_paying_coins_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_05 exactly: young adult woman, warm skin, narrow oval face, blunt bangs and chin-length dark bob, mauve square-neck short-sleeve top, warm cream lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_06_accepting_bag_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer receives the completed filled paper bag with both hands.
- `final_file`: `res://resources/art/customers/customer_06/customer_06_accepting_bag_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_06/customer_06_accepting_bag_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_06_accepting_bag_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_06_accepting_bag_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1448 x 1086 px RGBA
- `alpha_bbox`: (479, 45) - (988, 1068); cropped size 509 x 1023
- `transparent_ratio`: 0.779931
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `887fbd2e1b10f96a075fb8c35a745a834d3ea0b5847e0015de58ff733e0c8662`
- `suggested_anchor`: cropped bottom-center `(x=254.5, y=1023)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_06_accepting_bag_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_06 exactly: slim elderly man, long rectangular face, swept-back silver hair, light-blue shirt, mustard V-neck vest, brick-red lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_06_paying_coins_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer holds the received bag under the left arm and offers exactly three coins with the right hand.
- `final_file`: `res://resources/art/customers/customer_06/customer_06_paying_coins_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_06/customer_06_paying_coins_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_06_paying_coins_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_06_paying_coins_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px RGBA
- `alpha_bbox`: (404, 40) - (1086, 970); cropped size 682 x 930
- `transparent_ratio`: 0.767265
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `20b3c1b92a4303add398c224a569f4ce8a6c2b3826b2c9837dbdcc2febb81706`
- `suggested_anchor`: cropped bottom-center `(x=341.0, y=930)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_06_paying_coins_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_06 exactly: slim elderly man, long rectangular face, swept-back silver hair, light-blue shirt, mustard V-neck vest, brick-red lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_07_accepting_bag_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer receives the completed filled paper bag with both hands.
- `final_file`: `res://resources/art/customers/customer_07/customer_07_accepting_bag_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_07/customer_07_accepting_bag_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_07_accepting_bag_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_07_accepting_bag_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px RGBA
- `alpha_bbox`: (467, 85) - (1060, 991); cropped size 593 x 906
- `transparent_ratio`: 0.763533
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `5f69ecc9abab8240dd67170dd0223c1fb3c806d90b0b269b61caeabd5c2b5fe7`
- `suggested_anchor`: cropped bottom-center `(x=296.5, y=906)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_07_accepting_bag_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_07 exactly: full-figured middle-aged woman, warm fair skin with freckles, copper-red short layered hair, warm gold boat-neck top, deep teal lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_07_paying_coins_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer holds the received bag under the left arm and offers exactly three coins with the right hand.
- `final_file`: `res://resources/art/customers/customer_07/customer_07_paying_coins_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_07/customer_07_paying_coins_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_07_paying_coins_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_07_paying_coins_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px RGBA
- `alpha_bbox`: (398, 79) - (1100, 963); cropped size 702 x 884
- `transparent_ratio`: 0.764083
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `e7b9c758841b242cc897554be9c13327ab0b35cc593549e9be1545ae4eae5c48`
- `suggested_anchor`: cropped bottom-center `(x=351.0, y=884)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_07_paying_coins_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_07 exactly: full-figured middle-aged woman, warm fair skin with freckles, copper-red short layered hair, warm gold boat-neck top, deep teal lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_08_accepting_bag_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer receives the completed filled paper bag with both hands.
- `final_file`: `res://resources/art/customers/customer_08/customer_08_accepting_bag_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_08/customer_08_accepting_bag_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_08_accepting_bag_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_08_accepting_bag_v1.md`
- `rejected_processing_record`: `tmp/imagegen/customer_service_v1/customer_08_accepting_bag_v1_rejected_bottom_crop.png`; rejected because lower trouser edge touched the canvas; regenerated with explicit bottom margin
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px RGBA
- `alpha_bbox`: (578, 89) - (953, 863); cropped size 375 x 774
- `transparent_ratio`: 0.874565
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `1b1ba9b85e2b113c917d6c267474bb2000174195ed701d98e19dcb8d59a817ec`
- `suggested_anchor`: cropped bottom-center `(x=187.5, y=774)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_08_accepting_bag_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_08 exactly: slim young adult man, narrow face, honey-blond shoulder-length straight hair, charcoal two-button Henley, warm rust-brown trousers; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins. This is the accepted targeted composition correction: scale the complete customer-and-bag figure to about 82% canvas height and leave at least 70 pixels of clean key color below the complete lower waist/trouser edge. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_08_paying_coins_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer holds the received bag under the left arm and offers exactly three coins with the right hand.
- `final_file`: `res://resources/art/customers/customer_08/customer_08_paying_coins_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_08/customer_08_paying_coins_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_08_paying_coins_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_08_paying_coins_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px RGBA
- `alpha_bbox`: (423, 59) - (1080, 987); cropped size 657 x 928
- `transparent_ratio`: 0.773405
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `d29c116c7af178b070ff531d69bb67e76a91d9d7bea1c791391123d0c682ab0e`
- `suggested_anchor`: cropped bottom-center `(x=328.5, y=928)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_08_paying_coins_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_08 exactly: slim young adult man, narrow face, honey-blond shoulder-length straight hair, charcoal two-button Henley, warm rust-brown trousers; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_09_accepting_bag_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer receives the completed filled paper bag with both hands.
- `final_file`: `res://resources/art/customers/customer_09/customer_09_accepting_bag_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_09/customer_09_accepting_bag_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_09_accepting_bag_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_09_accepting_bag_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px RGBA
- `alpha_bbox`: (528, 60) - (985, 1007); cropped size 457 x 947
- `transparent_ratio`: 0.806113
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `644a042a726a7d338d22807c7c65aaf1cfdf77116fa25ac246637be9d853dc4a`
- `suggested_anchor`: cropped bottom-center `(x=228.5, y=947)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_09_accepting_bag_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_09 exactly: adult woman, deep warm-brown skin, heart-shaped face, blue-black long side braid, coral-orange wrap/collar top, deep indigo lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_09_paying_coins_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer holds the received bag under the left arm and offers exactly three coins with the right hand.
- `final_file`: `res://resources/art/customers/customer_09/customer_09_paying_coins_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_09/customer_09_paying_coins_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_09_paying_coins_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_09_paying_coins_v1.md`
- `rejected_processing_record`: none; first visual candidate accepted
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1530 x 1028 px RGBA
- `alpha_bbox`: (450, 67) - (1090, 977); cropped size 640 x 910
- `transparent_ratio`: 0.782324
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `e50209e71f138ae00311e96ffe2e205dad2d62b760123cd25348212a5152ac33`
- `suggested_anchor`: cropped bottom-center `(x=320.0, y=910)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_09_paying_coins_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_09 exactly: adult woman, deep warm-brown skin, heart-shaped face, blue-black long side braid, coral-orange wrap/collar top, deep indigo lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_10_accepting_bag_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer receives the completed filled paper bag with both hands.
- `final_file`: `res://resources/art/customers/customer_10/customer_10_accepting_bag_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_10/customer_10_accepting_bag_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_10_accepting_bag_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_10_accepting_bag_v1.md`
- `rejected_processing_record`: `tmp/imagegen/customer_service_v1/customer_10_accepting_bag_v1_rejected_bottom_crop.png`; rejected because lower trouser edge touched the canvas; regenerated with explicit bottom margin
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1536 x 1024 px RGBA
- `alpha_bbox`: (529, 88) - (998, 887); cropped size 469 x 799
- `transparent_ratio`: 0.841776
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `bbd74c1a7b2e16fbb8a78d7b8b81c9d70e202e877edf86b86f3380b665be03d3`
- `suggested_anchor`: cropped bottom-center `(x=234.5, y=799)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_10_accepting_bag_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_10 exactly: sturdy broad middle-aged man, warm olive skin, bald head with dark side stubble, dark mustache and short goatee, dark burgundy open-collar shirt over cream undershirt, warm khaki trousers; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins. This is the accepted targeted composition correction: scale the complete figure/action to about 82% canvas height and leave at least 70 pixels of clean key color below the complete lower trouser/waist edge. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```

## customer_10_paying_coins_v1

- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending
- `purpose`: Customer holds the received bag under the left arm and offers exactly three coins with the right hand.
- `final_file`: `res://resources/art/customers/customer_10/customer_10_paying_coins_v1.png`
- `cropped_resource`: `res://resources/art/customers/customer_10/customer_10_paying_coins_cropped.tres`
- `source_file`: `tmp/imagegen/customer_service_v1/customer_10_paying_coins_v1_chromakey.png`
- `prompt_file`: `res://resources/art/prompts/customer_10_paying_coins_v1.md`
- `rejected_processing_record`: `tmp/imagegen/customer_service_v1/customer_10_paying_coins_v1_rejected_bottom_crop.png`; rejected because lower trouser edge touched the canvas; regenerated with explicit bottom margin
- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha
- `generated_on`: 2026-08-02 (Asia/Shanghai)
- `size`: 1535 x 1024 px RGBA
- `alpha_bbox`: (447, 87) - (1037, 932); cropped size 590 x 845
- `transparent_ratio`: 0.809129
- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha 0
- `sha256`: `97f8d1b726e82ecdc74dcc3e31a4762fc4d6585a1865a23c823ca5c77b53475d`
- `suggested_anchor`: cropped bottom-center `(x=295.0, y=845)`; align to the existing customer waist baseline in the workstation
- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha
- `runtime_integration`: pending (art-only scope)
- `human_review`: pending
- `complete_prompt`:

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_10_paying_coins_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_10 exactly: sturdy broad middle-aged man, warm olive skin, bald head with dark side stubble, dark mustache and short goatee, dark burgundy open-collar shirt over cream undershirt, warm khaki trousers; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins. This is the accepted targeted composition correction: scale the complete figure/action to about 82% canvas height and leave at least 70 pixels of clean key color below the complete lower trouser/waist edge. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```
<!-- workstation-expansion-first-batch-v1 -->
# order_card_multi_dish_v2

- `status`: generated-imported-runtime-integration-passed-human-review-pending
- `purpose`: 顾客头顶的多菜订单 HUD 空白框架；运行时绘制金币与总价、至多两道菜、8 个原料图标和耐心进度。
- `final_file`: `res://resources/art/ui/order/order_card_multi_dish_v2.png`
- `source_file`: `res://tmp/imagegen/order_card_multi_dish_v2/order_card_multi_dish_chromakey_v2.png`
- `prompt_file`: `res://resources/art/prompts/order_card_multi_dish_v2.md`
- `generator`: Codex 内置 `image_gen`，以 `tmp/validation/workstation_hold_refill_gpu_1920x1080.png` 的最新 GPU 运行时画面为唯一画风基准；随后使用技能自带 `remove_chroma_key.py`。
- `generated_on`: 2026-08-06 (Asia/Shanghai)
- `layout_contract`: 顶部金额槽作为压住外框顶边的窄挂签；两枚无菜名的圆形菜品槽紧贴挂签下方，卡片上半部不保留大块无用途纸张；下方严格 2 行 x 4 列原料槽，左两列暖米色、右两列低饱和青绿以区分两道菜；底部为缩小的空心心形耐心槽和约原高度三分之一的细胶囊进度槽，两者上移并与下框保持均匀小内边距，第二行原料槽与其上缘的空白压缩为原来的约三分之一。所有内容均由 Godot 动态绘制。
- `processing`: `--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。
- `image_audit`: 1131 x 1391 RGBA；透明 0.448277，半透明 0.002591，不透明 0.549132；非透明像素中的强品红键色为 0；SHA-256 `282A919383F2180AECB65A22496A3F294CB6978EA7C0828C15FBA66F1949E509`。
- `godot_import`: passed — Godot 4.7.1 headless import exited 0 and generated the `.png.import` sidecar. The root-certificate and editor-settings-save messages are environment warnings after the asset import.
- `runtime_integration`: passed — `workstation.tscn` owns the two dish wells, 8 stable material widgets, coin/amount header, and compact patience widgets; `initial_unlock_workstation.tscn` places the card to the customer's right, clear of the tutorial strip. The 2026-08-06 real 1920x1080 GPU smoke run displayed the populated single-dish card and passed.
- `human_review`: pending — the GPU screenshot verifies rendering, but final art-direction acceptance remains a player-facing review.

# 工作台扩展首批独立设备与工具 v1

- `status`: generated-imported-runtime-integration-pending
- `generated_on`: 2026-08-03 (Asia/Shanghai)
- `generator`: Codex built-in `image_gen`; flat `#ff00ff` chroma-key backgrounds; local alpha removal with `C:/Users/Administrator/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py`; deterministic crop/fit/key-fringe cleanup with `tools/normalize_workstation_expansion_asset.py`
- `prompt_file`: `res://resources/art/prompts/workstation_expansion_assets_v1.md`
- `design_sources`: `docs/workstation_expansion_plan.md`, `docs/game_design.md`, `docs/development_plan.md`, `tmp/concepts/workstation_expansion_v1/workstation_expansion_concept_v3_1920x1080.png`, `tmp/concepts/workstation_expansion_v1/workstation_expansion_overlay.svg`
- `validation`: `tools/audit_workstation_expansion_assets.py`, `tests/unit/workstation_expansion_asset_self_check.gd`, `tmp/validation/workstation_expansion_v1/workstation_expansion_asset_audit_v1.json`, `tmp/validation/workstation_expansion_v1/workstation_expansion_contact_sheet_v1.png`
- `alpha_processing`: `--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`; tier-2 fryer retried with `--edge-contract 1`, then the normalizer removed only remaining forbidden magenta-key pixels.
- `godot_import`: passed with Godot 4.7.1; `WORKSTATION EXPANSION ASSET SELF-CHECK PASS: 7 textures`
- `project_checks`: passed; `tools/run_checks.ps1` ended with `All Project Cake checks passed.`
- `runtime_integration`: pending; no scene, gameplay script, progression data, save data, or device state machine was changed in this art batch.
- `human_review`: pending

| 资产 | 正式文件 | 尺寸 | alpha bbox | SHA-256 | 状态 |
| --- | --- | --- | --- | --- | --- |
| 豆浆机基础级，最大 2 杯/16 秒 | `res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_1_v1.png` | 1024×512 RGBA | `(280,28)-(743,484)` | `ce1180c29007109d022d0c126826e1b5b581c75c5fa69b1b8e1d1c267763b81a` | 已生成、已导入、未接入、待人工确认 |
| 豆浆机中级，最大 2 杯/12 秒 | `res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_2_v1.png` | 1024×512 RGBA | `(278,28)-(745,484)` | `3ac48a007048b84416d422c0291e5e54a602af370f58eb120d681832e325b0e0` | 已生成、已导入、未接入、待人工确认 |
| 炸油条机基础级，最大 2 根/12 秒 | `res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_v1.png` | 1024×384 RGBA | `(56,32)-(967,352)` | `955006ffbf1cf080857cee8c7d5f4d4a5967e4d6d863acad8baa296acdb306c2` | 已生成、已导入、未接入、待人工确认 |
| 炸油条机中级，最大 2 根/9 秒 | `res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_2_v1.png` | 1024×384 RGBA | `(56,33)-(967,351)` | `9c89aacb6cac6660dd4e4f1284c4b7975a71c65aff10ac6d929dde10caa51cd0` | 已生成、已导入、未接入、待人工确认 |
| 炸油条机高级，最大 4 根/9 秒/无限保温 | `res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_3_v1.png` | 1024×384 RGBA | `(56,25)-(967,358)` | `e41c183eb390639801a73be105bf1a3a6476489dc662cca89da74dde64822758` | 已生成、已导入、未接入、待人工确认 |
| 压饼神器（稳定 ID `single_press_spreader`） | `res://resources/art/workstation/expansion/tools/single_press_spreader_v1.png` | 1024×1024 RGBA | `(125,56)-(898,967)` | `b60021375c5687204e22e0469d3e797794d8bb77d874d530f83b863bf57067a6` | 已生成、已导入、未接入、待人工确认 |
| 自动酱刷 | `res://resources/art/workstation/expansion/tools/automatic_sauce_brush_v1.png` | 1024×1024 RGBA | `(155,56)-(869,967)` | `b371b75d0714ef1a5ddd21fc91497aa18efad9af4642a989c50179f5ed1e10ef` | 已生成、已导入、未接入、待人工确认 |

所有 7 张正式图均为 RGBA、四角 alpha 为 0、禁用的品红键色残留为 0。图中无文字、数字、emoji、logo 或水印。

## 首批当时的拒绝稿与未完成项（已由继续批次补齐）

- 豆浆机基础档第一稿为高塔比例，在目标设备位缩放后过窄，未采用；源图保留在 `tmp/imagegen/workstation_expansion_v1/sources/soy_milk_machine_tier_1_v1_chromakey.png`。
- 豆浆机高级稿错误生成 6 杯，违反最大 4 杯规格，未进入 `resources`；拒绝稿保留在 `tmp/imagegen/workstation_expansion_v1/sources/soy_milk_machine_tier_3_rejected_six_cups.png`。首批随后的“恰好 4 个空杯位”调用无产物；继续批次最终成功生成严格 4 杯正式稿。
- 鸡蛋仔基础机、4×3 小料盘和锁定槽盖板在首批调用时无产物；当时未切换到 CLI/API 备用路径，也未用手工 SVG 或占位图替代。继续批次已全部通过内置 `image_gen` 生成。
- 小料盒 6/10/14 三档、默认配方原料/成品图标以及红豆/黑豆、芝麻/葱香、草莓/巧克力变体在首批结束时尚未生成；继续批次已全部补齐。

<!-- workstation-expansion-continuation-v1 -->
# 工作台扩展继续批次 v1：设备补齐、托盘、容量盒与首批配方

本节是上方“工作台扩展首批独立设备与工具 v1”的继续记录，并取代其“未完成项”状态；原拒绝稿和无产物调用记录保留用于追溯。

- `status`: generated-imported-runtime-integration-pending-human-review-pending
- `generated_on`: 2026-08-03 (Asia/Shanghai)
- `new_asset_count`: 27；与首批 7 张合计 34 张工作台扩展素材
- `generator`: Codex built-in `image_gen`
- `prompt_file`: `res://resources/art/prompts/workstation_expansion_assets_v1.md`
- `source_pattern`: `tmp/imagegen/workstation_expansion_v1/sources/<asset_id>_chromakey.png`
- `alpha_intermediate_pattern`: `tmp/imagegen/workstation_expansion_v1/sources/<asset_id>_alpha.png`
- `alpha_processing`: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`
- `normalization`: `tools/normalize_workstation_expansion_asset.py`；机器 1024×512、托盘 512×240、盖板/容量盒/配方图标 512×512
- `validation`: `tmp/validation/workstation_expansion_v1/workstation_expansion_asset_audit_v1.json` 与 `workstation_expansion_contact_sheet_v1.png`
- `pixel_audit`: passed；34/34 RGBA，四角 alpha `[0,0,0,0]`，品红键色残留 0
- `godot_import`: passed with Godot 4.7.1；`WORKSTATION EXPANSION ASSET SELF-CHECK PASS: 34 textures`
- `project_checks`: passed；`tools/run_checks.ps1` 输出 `All Project Cake checks passed.`
- `runtime_integration`: pending；本次未修改玩法代码、场景绑定、配方数据、升级数据或存档结构
- `human_review`: pending；接触表初检不替代真实游戏缩放与玩家视角验收

## 新增设备、托盘与容量盒（9 张）

- `res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_3_v1.png`：高级豆浆机，严格 2×2 共 4 杯，单中央处理/出液组件。
- `res://resources/art/workstation/expansion/machines/egg_waffle_machine_tier_1_v1.png`：基础鸡蛋仔机，单工位、手动合盖/控温。
- `res://resources/art/workstation/expansion/machines/egg_waffle_machine_tier_2_v1.png`：中级鸡蛋仔机，单工位、加速硬件，无无限保温。
- `res://resources/art/workstation/expansion/machines/egg_waffle_machine_tier_3_v1.png`：高级鸡蛋仔机，严格双工位、手动保温盖；成品未取出仍占容量。
- `res://resources/art/workstation/expansion/trays/ingredient_tray_4x3_v1.png`：严格 4×3 共 12 个空槽。
- `res://resources/art/workstation/expansion/trays/ingredient_slot_locked_cover_v1.png`：单槽实体锁浮雕盖板。
- `res://resources/art/workstation/expansion/bins/small_ingredient_box_tier_1_v1.png`：基础 6 份容量语义。
- `res://resources/art/workstation/expansion/bins/small_ingredient_box_tier_2_v1.png`：中级 10 份容量语义，同占地、单层加固圈。
- `res://resources/art/workstation/expansion/bins/small_ingredient_box_tier_3_v1.png`：高级 14 份容量语义，同占地、双层加固圈。

## 默认配方原料与成品（6 张）

- `res://resources/art/ingredients/soybean/yellow_soybean_portion_v1.png`
- `res://resources/art/products/soy_milk/plain_soy_milk_cup_v1.png`
- `res://resources/art/ingredients/youtiao/plain_youtiao_dough_v1.png`
- `res://resources/art/products/youtiao/plain_youtiao_v1.png`
- `res://resources/art/ingredients/egg_waffle/plain_egg_waffle_batter_v1.png`
- `res://resources/art/products/egg_waffle/plain_egg_waffle_v1.png`

## 首轮口味变体原料与成品（12 张）

- `res://resources/art/ingredients/beans/red_bean_portion_v1.png`
- `res://resources/art/ingredients/beans/black_bean_portion_v1.png`
- `res://resources/art/products/soy_milk/red_bean_soy_milk_cup_v1.png`
- `res://resources/art/products/soy_milk/black_bean_soy_milk_cup_v1.png`
- `res://resources/art/ingredients/youtiao/sesame_youtiao_dough_v1.png`
- `res://resources/art/ingredients/youtiao/scallion_youtiao_dough_v1.png`
- `res://resources/art/products/youtiao/sesame_youtiao_v1.png`
- `res://resources/art/products/youtiao/scallion_youtiao_v1.png`
- `res://resources/art/ingredients/sauces/strawberry_sauce_bottle_v1.png`
- `res://resources/art/ingredients/sauces/chocolate_sauce_bottle_v1.png`
- `res://resources/art/products/egg_waffle/strawberry_egg_waffle_v1.png`
- `res://resources/art/products/egg_waffle/chocolate_egg_waffle_v1.png`

## 拒绝稿与失败调用

- `tmp/imagegen/workstation_expansion_v1/sources/soy_milk_machine_tier_3_rejected_six_cups.png`：错误 6 杯，违反最大 4 杯规格，未进入 `resources`。
- 黑豆份量、红豆豆浆与葱香成品油条各有一次内置生成调用长时间无返回，调用已终止且无产物；随后使用更聚焦的编辑提示成功生成正式文件。
- 高级豆浆机第一次归一化误把 `--margin` 当像素传入，产生单像素输出；正式文件随后以比例值 `0.055` 重新生成并覆盖，审计哈希以最终文件为准。

<!-- workstation-expansion-recipes-batch-2 -->
# 工作台扩展配方第二批：花生至果干碎

- `status`: generated-imported-runtime-integration-pending-human-review-pending
- `generated_on`: 2026-08-04 (Asia/Shanghai)
- `new_asset_count`: 18；工作台扩展专用审计总数由 34 增至 52
- `generator`: Codex built-in `image_gen`；一张图一次独立生成/编辑调用
- `prompt_file`: `res://resources/art/prompts/workstation_expansion_assets_v1.md` 的 “Second expansion recipe batch”
- `source_pattern`: `tmp/imagegen/workstation_expansion_v1/sources/<asset_id>_chromakey.png`
- `alpha_intermediate_pattern`: `tmp/imagegen/workstation_expansion_v1/sources/<asset_id>_alpha.png`
- `alpha_processing`: 默认 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`
- `normalization`: `tools/normalize_workstation_expansion_asset.py --width 512 --height 512 --margin 0.06`
- `validation`: `tmp/validation/workstation_expansion_v1/workstation_expansion_asset_audit_v1.json` 与 `workstation_expansion_contact_sheet_v1.png`
- `pixel_audit`: passed；52/52 RGBA、透明四角、检测到的洋红残留 0
- `godot_import`: passed with Godot 4.7.1；`WORKSTATION EXPANSION ASSET SELF-CHECK PASS: 52 textures`
- `project_checks`: passed；`tools/run_checks.ps1` 输出 `All Project Cake checks passed.`（根证书读取警告与通过状态分开记录）
- `runtime_integration`: pending；当前 catalog 没有本批 9 种新配方/小料 ID，本批未改玩法代码
- `human_review`: pending；接触表初检不等于真实工作台缩放验收

## 豆浆扩展（6 张）

- `res://resources/art/ingredients/nuts/peanut_portion_v1.png`
- `res://resources/art/ingredients/beans/mung_bean_portion_v1.png`
- `res://resources/art/ingredients/grains/five_grain_mix_portion_v1.png`
- `res://resources/art/products/soy_milk/peanut_soy_milk_cup_v1.png`
- `res://resources/art/products/soy_milk/mung_bean_soy_milk_cup_v1.png`
- `res://resources/art/products/soy_milk/five_grain_soy_milk_cup_v1.png`

## 油条扩展（6 张）

- `res://resources/art/ingredients/youtiao/glutinous_rice_youtiao_dough_v1.png`
- `res://resources/art/ingredients/youtiao/multigrain_youtiao_dough_v1.png`
- `res://resources/art/ingredients/youtiao/filled_youtiao_dough_v1.png`
- `res://resources/art/products/youtiao/glutinous_rice_youtiao_v1.png`
- `res://resources/art/products/youtiao/multigrain_youtiao_v1.png`
- `res://resources/art/products/youtiao/filled_youtiao_v1.png`

“夹心”只锁定了结构，尚未锁定馅味。正式图与稳定 ID `filled` 不宣称豆沙、肉馅、奶油或其他具体口味。

## 鸡蛋仔扩展（6 张）

- `res://resources/art/ingredients/egg_waffle/matcha_egg_waffle_batter_v1.png`
- `res://resources/art/ingredients/egg_waffle/sesame_topping_portion_v1.png`
- `res://resources/art/ingredients/egg_waffle/dried_fruit_topping_portion_v1.png`
- `res://resources/art/products/egg_waffle/matcha_egg_waffle_v1.png`
- `res://resources/art/products/egg_waffle/sesame_egg_waffle_v1.png`
- `res://resources/art/products/egg_waffle/dried_fruit_egg_waffle_v1.png`

## 第二批拒绝记录

- `tmp/imagegen/workstation_expansion_v1/sources/glutinous_rice_youtiao_v1_magenta_rejected.png`：绘制内容正确，但洋红软去背令金黄色主体发灰，未进入 `resources`。
- 正式 `glutinous_rice_youtiao_v1` 使用纯 `#00ff00` 色键重生成；其余 17 张使用纯 `#ff00ff` 色键。两者都使用内置 imagegen 与同一软边透明处理流程，没有改用 CLI/API、手工 SVG 或占位图。

## 2026-08-05 退役与初始工作台替换

- 本清单上方所有鸡蛋仔机器、原料、成品、草莓酱与巧克力酱条目均为历史记录；对应资源已从 `resources` 删除，不再被目录、场景或测试引用。
- `res://resources/art/workstation/background/initial_unlock_five_zone_backdrop_v5.png` 是现役初始工作台环境底图：中式煎饼铺、加深五区柜台、柜台前沿两排十二个实体小料凹槽。生成提示词与使用边界见 `resources/art/prompts/initial_unlock_five_zone_backdrop_v5.md`。

## griddle_base_compact_v2

- `status`: generated, imported, runtime-integrated, visually reviewed
- `purpose`: Compact the jianbing griddle so its charcoal-black cooking face stays within the central tabletop bay.
- `final_file`: `res://resources/art/workstation/griddle/griddle_base_compact_v2.png`
- `source_file`: `C:\Users\Administrator\.codex\generated_images\019fd495-eaf8-7242-9372-048190bfa0da\exec-92e718a0-b60c-4283-a4b1-e67e82bfb61c.png`
- `prompt_file`: `res://resources/art/prompts/griddle_base_compact_v2.md`
- `generator`: Codex built-in `image_gen`, then `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`
- `generated_on`: 2026-08-06 (Asia/Shanghai)
- `size`: 1254 x 1254 px, RGBA
- `alpha_check`: four corners are fully transparent; 844,580 of 1,572,516 pixels are transparent
- `sha256`: `192B47FCCA4D37BD79E979454D481E2662B334E6A5D56F0CA374D13398CC5DC0`
- `runtime_scene_check`: `SafeArea/PanBase/GriddleArtwork`, scale `0.41`, GPU screenshot and pointer interaction pass
- `visual_check`: agent-inspected 1920x1080 GPU screenshot; compact rim stays within the central tabletop bay
- `human_review`: pending

## griddle_base_angled_ellipse_v3

- `status`: derived, imported, runtime-integrated
- `purpose`: Correct the jianbing griddle to the user's slightly angled view: the black cooking surface is a horizontal ellipse rather than a top-down circle.
- `final_file`: `res://resources/art/workstation/griddle/griddle_base_angled_ellipse_v3.png`
- `source_file`: `res://resources/art/workstation/griddle/griddle_base_compact_v2.png`
- `reference_file`: `C:\Users\Administrator\AppData\Local\Temp\codex-clipboard-13d8ae19-3a59-430c-a74b-2566b7d64b7a.png`
- `prompt_file`: `res://resources/art/prompts/griddle_base_angled_ellipse_v3.md`
- `processing`: vertically resampled the approved v2 RGBA art to 68% around its center using Lanczos, retaining transparent corners; three built-in image-generation candidates were inspected and rejected because their perspective was less faithful to the reference.
- `generated_on`: 2026-08-06 (Asia/Shanghai)
- `size`: 1254 x 1254 px, RGBA; visible alpha bounds `955 x 665 px` (1.44:1)
- `alpha_check`: four corners are fully transparent
- `sha256`: `F7F165126CE42447604BDB4DB73C6DCF43F8492B2AD6558276995338884F037A`
- `runtime_scene_check`: `SafeArea/PanBase/GriddleArtwork`; the pancake shader, direct-ingredient drop validation, and pointer trace all use `pan_height_ratio` to stay inside the matching oval.
- `visual_check`: agent-inspected 1920x1080 GPU frames at `tmp/validation/initial_unlock_workstation_gpu_1920x1080.png` and `tmp/validation/workstation_hold_refill_gpu_1920x1080.png`; the black cook face, batter, egg, and fillings remain inside the same horizontal oval.
- `human_review`: pending
