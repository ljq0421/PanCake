# ProjectCake 美术资源清单

## 记录约定

- 所有文字均由 Godot 排版，不写入 AI 图片。
- `status: review` 表示仅完成生成与本地视觉检查，尚未完成人工方向确认。
- `godot_import: pending` 与人工视觉确认是两个独立验收项。
- 内置 `image_gen` 未向本次任务暴露具体模型名，因此不推测模型版本。

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending — 请重点确认老年男性方向、芥末色背心以及 56 px 头顶留白是否可接受；确认后再制作不耐烦与满意状态。

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending — 请重点确认丰润体型、铜红短发、雀斑密度和暖金色上衣是否可接受；确认后再制作不耐烦与满意状态。

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
- `human_review`: pending

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
- `human_review`: pending

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
- `human_review`: pending — 请确认当前眉眼压低程度是否符合“轻度不耐烦”而不是过于严肃。

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
- `human_review`: pending — 请确认闭眼微笑的满意程度是否合适，或是否希望眼睛保持微睁。

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
