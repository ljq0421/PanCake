# customer_02_neutral_v1

## 用途

P1 第二名顾客的中性半身 `Sprite2D` 确认稿。人物与 customer_01 明显不同；耐心条、订单卡、付款内容、工作台和阴影均由独立层提供。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：使用 V8 与 customer_01 中性图作为不同职责的参考图进行新角色生成
- 背景：纯品红抠像背景
- 后处理：技能自带 `remove_chroma_key.py`

## 完整提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P1 customer_02 neutral half-body gameplay sprite, magenta chroma-key source for transparent PNG
Input images: Image 1 is the approved V8 gameplay composition and visual-style reference; use only its customer proportions, fixed slightly elevated frontal viewpoint, bold line weight, flat-color rendering and warm palette, not its workstation or UI. Image 2 is customer_01 neutral and is only a canvas occupancy, padding, lower-edge and approximate counter-pivot reference; do not copy his identity, gender presentation, face shape, short tousled hairstyle, olive-green shirt or dark-blue pants.
Primary request: create one clearly different, friendly adult woman customer as an isolated neutral half-body character, shown from the complete top of her hair to just below the waist. She has a softly rounded adult face, warm medium skin, dark brown eyes, and a calm small closed-mouth smile. Give her dark chestnut shoulder-length wavy hair with a distinct side part, neatly tucked behind both ears so both complete ears remain visible; every curl and hair tip must stay fully inside the canvas. Dress her in a warm terracotta-red short-sleeve blouse with a simple cream rounded collar and a muted mustard waistband, clearly different from customer_01. Both shoulders, upper arms, forearms and relaxed open hands must be fully visible; arms hang naturally beside the torso. Straight frontal pose, same slightly elevated fixed gameplay viewpoint as V8.
Composition/framing: one centered character on the same broad landscape-style canvas occupancy as customer_01; complete hair and every hair tip visible with at least 90 pixels of clear background above; generous clear side padding around both elbows and hands; no crop through hair, ears, shoulders, hands, waist or clothing. Keep the waist-level lower termination centered and flat enough for placement behind the service counter. Match customer_01's approximate overall character height, width, lower-edge position and suggested counter pivot while keeping a visibly different female silhouette.
Style/medium: exact approved ProjectCake V8 language—simple hand-drawn 2D cartoon, bold clean deep-brown outlines of comparable thickness, large matte flat color blocks, base color plus at most one shadow and one highlight, minimal hair and fabric texture, crisp readable silhouette, warm grounded street-stall feeling. Adult proportions; not chibi, not anime.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background edge to edge for local background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, vignette or lighting variation. Do not use #ff00ff anywhere in the character.
Neutral-state constraint: relaxed eyebrows, open attentive eyes and a restrained friendly closed-mouth smile; no impatience, exaggerated joy, laughter, wink, blush symbols or dramatic pose.
Absolute constraints: one customer only; no counter, workstation, griddle, order card, patience bar, payment tray, money, food, tools, props, jewelry, hat, cast shadow, contact shadow, reflection, glow, speech bubble, comic symbol or UI. No text, letters, numbers, logo, brand or watermark. No extra limbs, fused fingers, hidden hands, cropped hair, cropped ears or cropped body. No photorealism, glossy 3D, painterly rendering, thin outlines, heavy gradients or noisy detail.
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

首稿通过本地视觉与 alpha 检查，未进行定向重生成。最终透明图保持内置生成结果的原始尺寸，未裁切、未缩放、未调色。
