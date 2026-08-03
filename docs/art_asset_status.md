# ProjectCake 美术素材状态总表

## 2026-08-02：固定摊位分层装饰补充

- 新增 5 张 1671×941 RGBA 正式透明装饰层，统一使用左上角 `(0,0)` 锚点：配料架支架、空白收纳标签挂架、空白订单夹板、短雨棚与外侧小灯、长托盘包边与空白熟客夹。
- 素材已完成内置 ImageGen 生成、技能脚本去背、确定性归位、安全矩形审计、层间零交叠审计，以及 1671×941 / 1920×1080 阶段预览视觉检查。
- 本批次没有生成或修改火腿肠、肉松、里脊、吸油纸、定量面糊勺或其他工具；也没有修改任何配料解锁、金币消费、升级总数或成长数值。
- 本批次只完成美术素材，不代表运行时升级功能、购买逻辑、存档、经济数据或场景绑定已完成；真实游戏缩放下的人工验收仍为 pending。
- 详见 `resources/art/ASSET_MANIFEST.md` 的“固定摊位分层装饰 v1”章节，以及 `tmp/validation/workstation_decor_v1/workstation_decor_contact_sheet_v1.png`。
- 由于当前工作树同时存在其他未提交美术批次，本任务没有重算或覆盖下方既有全局 PNG 统计，避免把并行资产错误归入本批次。

更新时间：2026-08-02（Asia/Shanghai）

本文件是 `resources/art/ASSET_MANIFEST.md` 的精简索引。单张素材的提示词、哈希、透明通道、Godot 导入和视觉检查证据仍以 Manifest 为准。

## 1. 当前结论

- 项目正式美术目录共有 87 张 PNG；87 张均已有 Godot `.png.import` 旁车。
- P1 美术生产计划列出的工作台、鏊子、面饼纹理、工具、4 种基础配料、顾客、订单卡和品质图标均已有生成结果。
- 本次提前完成了 `docs/development_plan.md` 列出的 P2 美术：肉松与里脊的基础/操作状态、金币/口碑/升级图标、一个固定摊位升级背板和无文字日结面板底图，共新增 9 张正式 PNG。
- 在文档原定“1 项工具升级”之外，按项目负责人本次扩展要求新增 8 张独立工具升级图：T 形刮板、温控器、酱刷、加固纸套、面糊勺、折叠铲、配料夹和吸油纸。该扩展不能反向解释为原 P2 文档已经规定了 8 项升级。
- 顾客 01–09 均有中性、不耐烦、满意三态，共 27 张。P2 的“再增加 2 名顾客”数量目标已被既有扩充覆盖，但哪些顾客进入正式 P2 池仍应由数据配置决定。
- “P2 美术已生成并导入”不等于“P2 功能已完成”。新配料数据、撒料/厚重损伤判定、工具升级数据与换图、摊位状态切换、营业日服务和日结场景绑定仍未接入。
- 资产“已生成/已导入”也不等于“人工美术验收通过”；Manifest 当前仍有 80 条 `human_review: pending`。

## 2. 已生成素材

| 分类 | PNG 数量 | 内容 | 当前状态 |
| --- | ---: | --- | --- |
| 顾客 | 27 | customer_01–09，每名中性/不耐烦/满意三态 | 已生成、已去背、已导入；正式顾客池仍由数据配置决定 |
| 配料 | 13 | P1 鸡蛋、薄脆、火腿肠、葱花；P2 肉松与里脊各两种状态 | 已生成、已去背、已导入；P2 四图尚未接入配料数据和交互 |
| 工作台与工具 | 24 | 基础背板、P2 升级背板、前唇、鏊子、6 个基础工具、8 个升级件、4 种面饼纹理、2 种酱料纹理 | 已生成、已导入；工具升级数据、换图和升级背板状态尚未接入 |
| UI | 14 | 订单卡、9 个品质图标、P2 金币/口碑/升级图标、日结底板 | 已生成、已去背、已导入；P2 UI 尚未绑定数据和场景 |
| 支付 | 1 | 小额现金组合 | 已生成、已去背、已导入并接入 P1 收款反馈 |
| 风格基准 | 8 | visual_style_anchor_v1–v8 | V8 为当前批准基准；旧版保留作演进记录，不应当作并列最终资产 |

合计：87 张正式 PNG。

## 3. 本次完成的 P2 美术

### 配料与操作状态

- `res://resources/art/ingredients/meat_floss/meat_floss_pile_v1.png`
- `res://resources/art/ingredients/meat_floss/meat_floss_scattered_v1.png`
- `res://resources/art/ingredients/pork_tenderloin/pork_tenderloin_portion_v1.png`
- `res://resources/art/ingredients/pork_tenderloin/pork_tenderloin_slices_v1.png`

肉松散落态包含 14 个分离小团，用于表达分布不均；里脊放置态包含 3 条厚切熟肉，用于表达配料较重、容易造成面饼损伤或折叠鼓包。图片本身只提供视觉状态，不负责业务判定。

### 经济与升级图标

- `res://resources/art/ui/economy/currency_coin_v1.png`
- `res://resources/art/ui/economy/reputation_v1.png`
- `res://resources/art/ui/economy/upgrade_v1.png`

三枚图标均完成 64px 预览。金币初稿的圆点在小尺寸下可能被误读为人脸，已改成每枚硬币一个方孔；初稿仍留在 `tmp/imagegen/p2_ui_icons_v1/` 便于追溯。

### 摊位升级与日结界面

- `res://resources/art/workstation/background/workstation_backplate_upgrade_v1.png`
- `res://resources/art/ui/day_summary/day_summary_panel_base_v1.png`

升级背板与基础背板同为 1671×941，保留 12 个配料槽、中央操作区和底部控制区，只增加固定装饰。日结底板为 1672×941 RGBA，含空标题带、4 个指标位、2 块明细板和底部提示板；所有文字、数字、图标与按钮必须由 Godot 动态渲染。

### 工具升级扩展

- `res://resources/art/workstation/tools/batter_spreader_upgrade_v1.png`
- `res://resources/art/workstation/tools/heat_controller_upgrade_v1.png`
- `res://resources/art/workstation/tools/sauce_brush_upgrade_v1.png`
- `res://resources/art/workstation/tools/reinforced_paper_sleeve_upgrade_v1.png`
- `res://resources/art/workstation/tools/batter_ladle_upgrade_v1.png`
- `res://resources/art/workstation/tools/folding_spatula_upgrade_v1.png`
- `res://resources/art/workstation/tools/ingredient_tongs_upgrade_v1.png`
- `res://resources/art/workstation/tools/oil_absorbent_paper_upgrade_v1.png`

8 张均为独立透明 Sprite 资产，沿用批准的暖白、青绿、黄铜、不锈钢与深棕描边。升级外观只表达更好的容错或信息反馈，没有加入自动摊面、自动刷酱、自动折叠或自动温控装置。“其他工具”按当前运行时清单展开为面糊勺、折叠铲、配料夹和吸油纸，避免不可拆分的合成图。

## 4. 自动检查与导入结果

- `tools/audit_p2_art_assets.py`：通过。16 张透明 P2 素材画布边缘非透明像素均为 0，未检测到品红/绿色键色残留；升级背板尺寸与基础背板完全一致。
- Godot 4.7.1 headless `--import`：退出码 0；累计 17 张正式 P2 素材均生成 `.png.import` 与对应 `CompressedTexture2D` 缓存。
- Godot 4.7.1 headless 项目加载进程虽返回 0，但日志仍出现 `workstation.gd` 无法解析 `SauceBlobOverlay`、两个酱料比例无法推断类型，以及 `pancake_heatmap.gd` 读取空 `parameters` 的既有脚本错误；因此不能把本次结果写成“完整项目加载通过”。本批次未修改这些脚本。
- Godot 在退出时报告 Windows 根证书读取警告；该警告未阻止纹理导入，不应误解为运行时玩法验证通过。
- 完整提示词位于 `resources/art/prompts/`，单图哈希与审计证据位于 `resources/art/ASSET_MANIFEST.md`。

## 5. 仍待人工或运行时验收的事项

1. 在真实游戏缩放下人工确认肉松细丝、里脊厚切、三个经济图标和 8 个工具升级件的辨识度。
2. 在场景中叠加升级背板，逐一验证配料槽、鏊子、工具区与控制区的交互坐标没有视觉漂移。
3. 等 P2 日结字段与布局合同实现后，验证四个指标位、两块明细板、底部提示与按钮的实际排版。
4. `pancake_charred_texture_v1` 的焦斑细节密度，以及两种酱料的正式业务命名，仍是既有待确认项。
5. 工具升级的购买条件、参数效果、存档字段和场景换图尚未实现；本次只完成美术生产与 Godot 导入。
6. P0 连续制作 20 张煎饼与 P1 真人鼠标/视觉试玩仍未完成；本次是项目负责人明确要求下的 P2 美术提前生产，不改变这些阶段门槛的验收状态。
