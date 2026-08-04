# 工作台扩展素材审计与首批生产清单

更新时间：2026-08-03（Asia/Shanghai）

本文件先于本轮生成建立，用来区分设计需求、磁盘已有素材、Godot 导入、运行时引用和人工视觉验收。权威设计为 `workstation_expansion_plan.md`、`game_design.md`、`development_plan.md`、`workstation_expansion_concept_v3_1920x1080.png` 与 `workstation_expansion_overlay.svg`。

## 1. 实际空间与输出规格

| 项目 | 已测量事实 | 本轮素材规格 |
| --- | --- | --- |
| 基准画布 | 1920×1080；目标横向分区为左 620、中 520、右 540，区间各留 20 px | 独立 Sprite 不烘焙文字或布局；由场景按目标区缩放 |
| 当前鏊子 | `PanBase` 为 650×585；`PancakeSurface` 为 600×555 | 扩展布局仍按文档把操作面缩到约 480 px；本轮不改场景 |
| 当前旧配料架 | `IngredientRack` 为 480×530；现有交互槽约 190×105，只实现 2×3 | 新 4×3 盘目标外框 512×240；单槽运行显示约 120×68，食材图标源图 512×512 RGBA |
| 左侧设备位 | 概念与文档给豆浆机、鸡蛋仔机各约 588×180 的“设备主体＋原料扩展位” | 机器源图 1024×512 RGBA，保留宽横向轮廓与四周透明边距 |
| 右下设备位 | 炸油条机约 517×133 | 机器源图 1024×384 RGBA，保留横向油槽、捞取区和透明边距 |
| 工具 | 当前工具按钮约 190×105；工具源图多为 1672×941 RGBA 并在场景缩放 | 新工具规范化为 1024×1024 RGBA，实际显示建议 96–150 px |
| 小料盒 | 目标单格约 110×100；概念稿为了 4×3 排布使用约 120×68 | 容量盒源图 512×512 RGBA；三等级保持同一视角、锚点与占地 |

所有新图：PNG、RGBA、透明四角、无文字、无 emoji、无水印、无地面投影；使用左上方暖晨光、深棕约 4–6 px 等效轮廓、米白珐琅/旧青绿/黄铜/不锈钢配色，匹配 V8 风格基准。

## 2. 现有素材审计

| 设计需求 | 现有正式文件 | 已生成 | 已导入 | 已接入运行时 | 人工视觉确认 | 结论 |
| --- | --- | :---: | :---: | :---: | :---: | --- |
| 基础摊饼器 | `resources/art/workstation/tools/batter_spreader_v1.png` | 是 | 是 | 是 | 待确认 | 复用，不重复生成 |
| 宽头摊饼器 | `resources/art/workstation/tools/batter_spreader_upgrade_v1.png` | 是 | 是 | 否 | 待确认 | 可直接作为宽头档；不重复生成 |
| 手动酱刷 | `resources/art/workstation/tools/sauce_brush_v1.png` | 是 | 是 | 是 | 待确认 | 复用，不重复生成 |
| 既有“酱刷升级” | `resources/art/workstation/tools/sauce_brush_upgrade_v1.png` | 是 | 是 | 否 | 待确认 | 仍是宽头手动刷，不可冒充自动酱刷 |
| 鸡蛋/薄脆/火腿/葱花补货容器 | `resources/art/workstation/restock/*.png` | 是 | 是 | 是 | 待确认 | 复用为容量盒风格与材质参考；不是三档小料盒 |
| 旧配料支架装饰 | `resources/art/workstation/decor/tier_01_ingredient_rack/ingredient_rack_support_v1.png` | 是 | 是 | 否 | 待确认 | 为旧左右 2×3 结构；新 4×3 盘需重做 |
| 肉松、里脊、火腿等既有配料 | `resources/art/ingredients/**` | 是 | 是 | 部分 | 待确认 | 可占用新 4×3 槽，不重复生成相同食材 |
| 豆浆机三档 | `resources/art/workstation/expansion/machines/soy_milk_machine_tier_*_v1.png` | 是 | 是 | 否 | 待确认 | 2/2/4 杯外观齐全；高级严格 2×2 共 4 杯 |
| 炸油条机三档 | `resources/art/workstation/expansion/machines/youtiao_fryer_tier_*_v1.png` | 是 | 是 | 否 | 待确认 | 2/2/4 根外观齐全；只有高级有无限保温结构 |
| 鸡蛋仔机器三档 | `resources/art/workstation/expansion/machines/egg_waffle_machine_tier_*_v1.png` | 是 | 是 | 否 | 待确认 | 1/1/2 工位齐全；高级为双工位手动保温盖 |
| 压饼神器（永久设备；稳定英文 ID 可沿用 `single_press_spreader`） | `resources/art/workstation/expansion/tools/single_press_spreader_v1.png` | 是 | 是 | 否 | 待确认 | 玩家可见名称已统一为“压饼神器” |
| 自动酱刷 | `resources/art/workstation/expansion/tools/automatic_sauce_brush_v1.png` | 是 | 是 | 否 | 待确认 | 独立机械购买模块 |
| 4×3 小料盘 | `resources/art/workstation/expansion/trays/ingredient_tray_4x3_v1.png` | 是 | 是 | 否 | 待确认 | 严格 4 列×3 行共 12 个空槽 |
| 未解锁槽盖板/剪影 | `resources/art/workstation/expansion/trays/ingredient_slot_locked_cover_v1.png` | 是 | 是 | 否 | 待确认 | 单槽实体锁浮雕盖板 |
| 小料盒基础/中级/高级容量外观 | `resources/art/workstation/expansion/bins/small_ingredient_box_tier_*_v1.png` | 是 | 是 | 否 | 待确认 | 同占地，以壁高和 1/2 层加固边框表达 6/10/14 |
| 豆浆/油条/鸡蛋仔首批原料与成品图标 | `resources/art/ingredients/{soybean,beans,youtiao,egg_waffle,sauces}/`、`resources/art/products/` | 是 | 是 | 否 | 待确认 | 6 张默认链路图标与 12 张首轮口味变体齐全 |

## 3. 首批生产优先级与状态

| 优先级 | 素材 | 目标命名 | 目标尺寸 | 当前状态 |
| --- | --- | --- | --- | --- |
| P0 | 豆浆机基础/中级/高级 | `soy_milk_machine_tier_1_v1.png` … `tier_3` | 1024×512 RGBA | 已生成、已导入；未接入；待人工确认 |
| P0 | 炸油条机基础/中级/高级 | `youtiao_fryer_tier_1_v1.png` … `tier_3` | 1024×384 RGBA | 已生成、已导入；未接入；待人工确认 |
| P0 | 鸡蛋仔机器基础/中级/高级 | `egg_waffle_machine_tier_1_v1.png` … `tier_3` | 1024×512 RGBA | 已生成、已导入；未接入；待人工确认 |
| P0 | 压饼神器 | `single_press_spreader_v1.png` | 1024×1024 RGBA | 已生成、已导入；未接入；待人工确认；英文稳定 ID 保持兼容 |
| P0 | 自动酱刷 | `automatic_sauce_brush_v1.png` | 1024×1024 RGBA | 已生成、已导入；未接入；待人工确认 |
| P0 | 4×3 小料盘外框 | `ingredient_tray_4x3_v1.png` | 1024×512 RGBA；规范化到 512×240 | 已生成、已导入；未接入；待人工确认 |
| P0 | 未解锁槽盖板 | `ingredient_slot_locked_cover_v1.png` | 512×512 RGBA | 已生成、已导入；未接入；待人工确认 |
| P1 | 小料盒三档容量 | `small_ingredient_box_tier_1_v1.png` … `tier_3` | 512×512 RGBA | 已生成、已导入；未接入；待人工确认 |
| P1 | 首批默认配方原料/成品 | 黄豆、原味豆浆、原味面胚、原味油条、原味面糊、原味鸡蛋仔 | 512×512 RGBA | 已生成、已导入；未接入；待人工确认 |

红豆、黑豆、芝麻/葱香油条、草莓/巧克力鸡蛋仔变体已按用户锁定顺序随上一批完成。花生、绿豆、五谷、糯米、杂粮、夹心、抹茶、芝麻粒和果干碎已进入第二批绘制，预生成审计与稳定命名见第 6 节。

### 本轮实际生产结果

| 素材 | 已生成 | 已导入 | 已接入运行时 | 人工视觉确认 | 备注 |
| --- | :---: | :---: | :---: | :---: | --- |
| 豆浆机基础级 | 是 | 是 | 否 | 待确认 | 最大 2 杯；低宽比例第二稿通过 |
| 豆浆机中级 | 是 | 是 | 否 | 待确认 | 最大 2 杯；只增加 12 秒加速硬件 |
| 豆浆机高级 | 是 | 是 | 否 | 待确认 | 最大 4 杯；最终稿严格 2×2 共 4 杯；6 杯错误稿继续保留为拒绝记录 |
| 炸油条机基础级 | 是 | 是 | 否 | 待确认 | 2 槽、12 秒语义；无保温盖 |
| 炸油条机中级 | 是 | 是 | 否 | 待确认 | 2 槽、9 秒加速硬件；无保温盖 |
| 炸油条机高级 | 是 | 是 | 否 | 待确认 | 4 槽、9 秒、手动保温盖；未画自动投料/捞取 |
| 鸡蛋仔机器三档 | 是 | 是 | 否 | 待确认 | 基础/中级单工位，高级双工位；只有高级表达无限保温；无自动化模块 |
| 压饼神器 | 是 | 是 | 否 | 待确认 | 稳定文件 ID 为 `single_press_spreader_v1` |
| 自动酱刷 | 是 | 是 | 否 | 待确认 | 明确为固定机械模块，不冒充宽头手动酱刷 |
| 4×3 小料盘 | 是 | 是 | 否 | 待确认 | 4 列×3 行，严格 12 个空槽；无文字、图标或配料 |
| 未解锁槽盖板 | 是 | 是 | 否 | 待确认 | 单槽盖板，实体锁浮雕；无文字按钮 |
| 小料盒三档 | 是 | 是 | 否 | 待确认 | 同占地、壁高递增，正式容量语义为 6/10/14 |
| 默认配方原料/成品图标 | 是 | 是 | 否 | 待确认 | 黄豆/豆浆、原味面胚/油条、原味面糊/鸡蛋仔共 6 张 |
| 首轮口味变体图标 | 是 | 是 | 否 | 待确认 | 红豆/黑豆、芝麻/葱香、草莓/巧克力的原料与成品共 12 张 |

本工作台扩展素材集正式入库共 34 张，其中本次继续批次新增 27 张。Godot 4.7.1 资源加载自检为 `WORKSTATION EXPANSION ASSET SELF-CHECK PASS: 34 textures`；`tools/run_checks.ps1` 完整检查通过。接触表在 `tmp/validation/workstation_expansion_v1/workstation_expansion_contact_sheet_v1.png`，尺寸、alpha bbox、导入旁车与 SHA-256 审计在同目录 JSON。

## 4. 已锁定设备规格（素材语义边界）

- 所有容量都是最大容量；投入至少 1 份即可启动，不要求装满。同一批只能使用一种主配方，已有原料时不得混入另一种豆类、面胚或面糊。
- 豆浆机：基础/中级/高级最大容量 2/2/4 杯，加工时间 16/12/12 秒；所有等级完成后都不变质，但成品持续占用容量。
- 炸油条机：最大容量 2/2/4 根，加工时间 12/9/9 秒；基础和中级完成后有 5 秒安全期，之后品质下降；高级无限期保温。
- 鸡蛋仔机器（蛋糕机）：最大容量 1/1/2 份，加工时间 20/15/15 秒；基础和中级完成后有 5 秒安全期，之后品质下降；高级无限期保温。
- 自动投料、自动开盖、自动取出等自动化是独立购买模块，不随基础/中级/高级设备外观免费出现。本轮三级设备图只表达速度、容量和高级保温结构。
- 小料盒三档容量正式锁定为每格 6/10/14 份；本轮外观用高度、深度与加固边框表达，避免扩大 4×3 盘的固定占地。

## 5. 状态口径

- **已生成**：最终 PNG 已放入 `resources/art`，并有来源图、提示词、哈希和 alpha 检查记录。
- **已导入**：Godot 4.7.1 已生成 `.png.import` 且资源可加载。
- **已接入运行时**：场景、脚本或数据确实引用该文件；仅存在于磁盘不算接入。
- **人工视觉确认**：必须由人检查真实游戏缩放下的透视、识别度、边缘和遮挡；自动检查不能替代。

上一批是美术生产任务，没有修改设备玩法、升级数据、存档或业务状态机。原 34 张清单内图片当前均为“已生成/已导入/未接入运行时/待人工视觉确认”。

## 6. 第二批扩展配方预生成审计（2026-08-04）

### 6.1 语义与运行时边界

- 权威设计已明确：花生、绿豆、五谷混合是豆浆机主配方；糯米、杂粮、夹心是油条主面胚；抹茶是鸡蛋仔主面糊；芝麻粒和果干碎是出炉后添加的小料。
- `scripts/data/workstation_expansion_catalog.gd` 当前只定义到红豆/黑豆、芝麻/葱香油条、草莓/巧克力酱，尚未定义本节 9 种扩展。因此本批允许“生成、入库、Godot 导入”，但不修改玩法数据，也不能标记为“已接入运行时”。
- “夹心”尚未锁定具体馅味。为避免把未确认的豆沙、肉馅或奶油写进设计，本批使用通用 `filled` 稳定 ID；画面仅表达密封夹心结构和中性暖棕馅心截面，不宣称具体口味。
- 磁盘、Manifest 与现有 34 张扩展素材中未发现以下目标文件；不会重复生成既有黄/红/黑豆、原味/芝麻/葱香油条或原味/草莓/巧克力鸡蛋仔。

### 6.2 缺失素材、规格、命名与生成前状态

| 产品线 | 输入素材与目标路径 | 成品素材与目标路径 | 尺寸/透明底 | 生成前状态 |
| --- | --- | --- | --- | --- |
| 花生豆浆 | `resources/art/ingredients/nuts/peanut_portion_v1.png` | `resources/art/products/soy_milk/peanut_soy_milk_cup_v1.png` | 两张均 512×512 RGBA | 缺失；未生成/未导入/未接入/未人工确认 |
| 绿豆豆浆 | `resources/art/ingredients/beans/mung_bean_portion_v1.png` | `resources/art/products/soy_milk/mung_bean_soy_milk_cup_v1.png` | 两张均 512×512 RGBA | 缺失；未生成/未导入/未接入/未人工确认 |
| 五谷豆浆 | `resources/art/ingredients/grains/five_grain_mix_portion_v1.png` | `resources/art/products/soy_milk/five_grain_soy_milk_cup_v1.png` | 两张均 512×512 RGBA | 缺失；未生成/未导入/未接入/未人工确认 |
| 糯米油条 | `resources/art/ingredients/youtiao/glutinous_rice_youtiao_dough_v1.png` | `resources/art/products/youtiao/glutinous_rice_youtiao_v1.png` | 两张均 512×512 RGBA | 缺失；未生成/未导入/未接入/未人工确认 |
| 杂粮油条 | `resources/art/ingredients/youtiao/multigrain_youtiao_dough_v1.png` | `resources/art/products/youtiao/multigrain_youtiao_v1.png` | 两张均 512×512 RGBA | 缺失；未生成/未导入/未接入/未人工确认 |
| 夹心油条 | `resources/art/ingredients/youtiao/filled_youtiao_dough_v1.png` | `resources/art/products/youtiao/filled_youtiao_v1.png` | 两张均 512×512 RGBA | 缺失；未生成/未导入/未接入/未人工确认 |
| 抹茶鸡蛋仔 | `resources/art/ingredients/egg_waffle/matcha_egg_waffle_batter_v1.png` | `resources/art/products/egg_waffle/matcha_egg_waffle_v1.png` | 两张均 512×512 RGBA | 缺失；未生成/未导入/未接入/未人工确认 |
| 芝麻粒鸡蛋仔 | `resources/art/ingredients/egg_waffle/sesame_topping_portion_v1.png` | `resources/art/products/egg_waffle/sesame_egg_waffle_v1.png` | 两张均 512×512 RGBA | 缺失；未生成/未导入/未接入/未人工确认 |
| 果干碎鸡蛋仔 | `resources/art/ingredients/egg_waffle/dried_fruit_topping_portion_v1.png` | `resources/art/products/egg_waffle/dried_fruit_egg_waffle_v1.png` | 两张均 512×512 RGBA | 缺失；未生成/未导入/未接入/未人工确认 |

本批共 18 张独立图标。所有来源图先生成在无阴影、无渐变的纯 `#ff00ff` 色键底上，再以 imagegen 技能脚本转为透明 RGBA；最终文件必须保持透明四角、完整轮廓、无文字、无标签、无品牌、无水印，并与既有图标使用相同视角、光向、深棕轮廓和 512×512 画布。

### 6.3 第二批实际生产与验证结果

- 18/18 张目标素材已由 Codex 内置 `image_gen` 实际生成，来源图和 alpha 中间稿保留在 `tmp/imagegen/workstation_expansion_v1/sources/`；最终 PNG 已放入上表列出的 `resources/art` 路径。
- 18/18 张均为 512×512 RGBA，透明四角为 0，alpha bbox 完整，检测到的洋红键色残留为 0；与前两批合并后，工作台扩展审计为 52/52 张通过。
- 18/18 张已由 Godot 4.7.1 生成 `.png.import` 并可作为 `Texture2D` 加载；自检输出为 `WORKSTATION EXPANSION ASSET SELF-CHECK PASS: 52 textures`。
- `tools/run_workstation_expansion_checks.ps1` 与项目完整 `tools/run_checks.ps1` 均以退出码 0 通过；完整检查输出 `All Project Cake checks passed.`。Windows 根证书读取警告仍存在，但未阻止本地纹理导入或检查执行。
- 18/18 张尚未接入运行时配方、库存、订单或场景节点；本批没有修改 `workstation_expansion_catalog.gd` 或其他玩法代码。
- 18/18 张仍待人工视觉确认。当前接触表检查已排除明显裁切、透明四角、色键残留和数量错误，但不能替代实际槽位缩放与玩家视角验收。
- 糯米油条首个洋红色键稿在软去背时令橙黄色主体发灰，未采用；拒绝来源保留为 `glutinous_rice_youtiao_v1_magenta_rejected.png`。正式稿使用内置 imagegen 重新生成纯 `#00ff00` 色键版本，并以同一透明处理参数入库。

本轮接触表与逐文件哈希审计位于 `tmp/validation/workstation_expansion_v1/workstation_expansion_contact_sheet_v1.png` 和 `workstation_expansion_asset_audit_v1.json`。
