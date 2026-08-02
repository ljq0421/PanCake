# ProjectCake 美术素材状态总表

更新时间：2026-08-02（Asia/Shanghai）

本文件是 `resources/art/ASSET_MANIFEST.md` 的精简索引。单张素材的提示词、哈希、透明通道、Godot 导入和视觉检查证据仍以 Manifest 为准。

## 1. 当前结论

- 项目正式美术目录共有 76 张 PNG；76 张均已有 Godot `.png.import` 旁车。
- P1 美术生产计划列出的工作台、鏊子、面饼纹理、工具、4 种基础配料、顾客、订单卡和品质图标均已有生成结果。
- 本次提前完成了 `docs/development_plan.md` 列出的 P2 美术：肉松与里脊的基础/操作状态、金币/口碑/升级图标、一个固定摊位升级背板和无文字日结面板底图，共新增 9 张正式 PNG。
- 顾客 01–08 均有中性、不耐烦、满意三态，共 24 张。P2 的“再增加 2 名顾客”数量目标已被既有扩充覆盖，但哪些顾客进入正式 P2 池仍应由数据配置决定。
- “P2 美术已生成并导入”不等于“P2 功能已完成”。新配料数据、撒料/厚重损伤判定、摊位状态切换、营业日服务和日结场景绑定仍未接入。
- 资产“已生成/已导入”也不等于“人工美术验收通过”；Manifest 当前仍有 72 条 `human_review: pending`。

## 2. 已生成素材

| 分类 | PNG 数量 | 内容 | 当前状态 |
| --- | ---: | --- | --- |
| 顾客 | 24 | customer_01–08，每名中性/不耐烦/满意三态 | 已生成、已去背、已导入；正式顾客池仍由数据配置决定 |
| 配料 | 13 | P1 鸡蛋、薄脆、火腿肠、葱花；P2 肉松与里脊各两种状态 | 已生成、已去背、已导入；P2 四图尚未接入配料数据和交互 |
| 工作台与工具 | 16 | 基础背板、P2 升级背板、前唇、鏊子、6 个工具、4 种面饼纹理、2 种酱料纹理 | 已生成、已导入；升级背板尚未接入状态切换 |
| UI | 14 | 订单卡、9 个品质图标、P2 金币/口碑/升级图标、日结底板 | 已生成、已去背、已导入；P2 UI 尚未绑定数据和场景 |
| 支付 | 1 | 小额现金组合 | 已生成、已去背、已导入并接入 P1 收款反馈 |
| 风格基准 | 8 | visual_style_anchor_v1–v8 | V8 为当前批准基准；旧版保留作演进记录，不应当作并列最终资产 |

合计：76 张正式 PNG。

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

## 4. 自动检查与导入结果

- `tools/audit_p2_art_assets.py`：通过。8 张透明素材画布边缘非透明像素均为 0，未检测到品红/绿色键色残留；升级背板尺寸与基础背板完全一致。
- Godot 4.7.1 headless `--import`：退出码 0；9 张正式 P2 素材均生成 `.png.import` 与对应 `CompressedTexture2D` 缓存。
- Godot 在退出时报告 Windows 根证书读取警告；该警告未阻止纹理导入，不应误解为运行时玩法验证通过。
- 完整提示词位于 `resources/art/prompts/`，单图哈希与审计证据位于 `resources/art/ASSET_MANIFEST.md`。

## 5. 仍待人工或运行时验收的事项

1. 在真实游戏缩放下人工确认肉松细丝、里脊厚切和三个经济图标的辨识度。
2. 在场景中叠加升级背板，逐一验证配料槽、鏊子、工具区与控制区的交互坐标没有视觉漂移。
3. 等 P2 日结字段与布局合同实现后，验证四个指标位、两块明细板、底部提示与按钮的实际排版。
4. `pancake_charred_texture_v1` 的焦斑细节密度，以及两种酱料的正式业务命名，仍是既有待确认项。
5. P0 连续制作 20 张煎饼与 P1 真人鼠标/视觉试玩仍未完成；本次是项目负责人明确要求下的 P2 美术提前生产，不改变这些阶段门槛的验收状态。
