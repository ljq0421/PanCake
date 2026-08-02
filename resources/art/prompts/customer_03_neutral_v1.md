# customer_03_neutral_v1

## 用途

P1 第三名顾客的中性半身 `Sprite2D` 确认稿。人物以年长身份、银灰盘发和蓝绿色外套与 customer_01、customer_02 区分；耐心条、订单卡、付款内容、工作台和阴影均由独立层提供。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：使用 V8、customer_01 与 customer_02 作为不同职责的参考图进行新角色生成
- 背景：纯品红抠像背景
- 后处理：技能自带 `remove_chroma_key.py`

## 完整提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P1 customer_03 neutral half-body gameplay sprite, magenta chroma-key source for transparent PNG
Input images: Image 1 is the approved V8 gameplay composition and visual-style reference; use only its fixed slightly elevated frontal customer viewpoint, bold deep-brown line weight, flat-color rendering and warm street-stall palette, not its workstation or UI. Images 2 and 3 are customer_01 and customer_02 neutral chroma-key sources; use them only as canvas occupancy, complete half-body framing, approximate 450-pixel subject width, lower-edge position and counter-pivot references. Do not copy either identity, face, hairstyle, age presentation, clothing cut or clothing colors.
Primary request: create one clearly different, friendly older adult woman customer as an isolated neutral half-body character from the complete top of her hair to just below the waist. Give her a mature softly rectangular face, warm medium-light skin, dark brown attentive eyes, subtle age lines beside the eyes and a calm small closed-mouth smile. Her silver-gray hair is swept back into one neat rounded low bun that remains fully visible, with both complete ears exposed and no loose hair crossing the face. Dress her in a faded teal short-sleeve cardigan worn over a warm cream blouse with a simple V neckline, plus a muted terracotta waistband at the lower edge. Both shoulders, upper arms, forearms and relaxed open hands must be fully visible; arms hang naturally beside the torso. Straight frontal pose, same slightly elevated fixed gameplay viewpoint as V8.
Composition/framing: one centered character on a broad landscape-style canvas matching the established customer sprites; complete hair, bun and every hair tip visible with at least 90 pixels of uniform background above; generous side padding around both elbows and hands; no crop through hair, bun, ears, shoulders, hands, waist or clothing. Keep the waist-level lower termination centered and flat for placement behind the service counter. Target approximately the same visible character height, 450-pixel body-and-hair width, lower-edge position and pivot near y=964 as customer_02 while preserving a distinct older silhouette.
Style/medium: exact approved ProjectCake V8 language—simple hand-drawn 2D cartoon, bold clean deep-brown outlines of comparable thickness, large matte flat color blocks, base color plus at most one shadow and one highlight, minimal hair and fabric texture, crisp readable silhouette, friendly grounded everyday street-stall feeling. Clearly older adult proportions but not frail, not chibi, not anime.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background edge to edge for local background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, vignette or lighting variation. Do not use #ff00ff anywhere in the character.
Neutral-state constraint: relaxed eyebrows, open attentive eyes and restrained friendly closed-mouth smile; no impatience, exaggerated happiness, laughter, wink or dramatic pose.
Absolute constraints: one customer only; no glasses, hat, jewelry, counter, workstation, griddle, order card, patience bar, payment tray, money, food, tools, props, cast shadow, contact shadow, reflection, glow, speech bubble, comic symbol or UI. No text, letters, numbers, logo, brand or watermark. No extra limbs, fused fingers, hidden hands, cropped bun, cropped ears or cropped body. No photorealism, glossy 3D, painterly rendering, thin outlines, heavy gradients or noisy detail.
Output intent: one clean opaque chroma-key source suitable for remove_chroma_key.py, later transparent Sprite2D use, and identity-locked expression-state edits.
```

## 处理记录

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

首稿通过本地视觉与 alpha 检查，未进行定向重生成。最终透明图保持内置生成结果原始尺寸，未裁切、未缩放、未调色。主体约 491 px 宽，比 customer_02 宽约 9%；该差异来自外套和年长体型轮廓，作为人物差异保留。
