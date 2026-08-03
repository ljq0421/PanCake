# customer_10_neutral_v1

## 用途

P1 第十名顾客的中性半身 `Sprite2D` 单张确认稿。人物采用结实宽体中年男性、完整秃顶轮廓、窄侧后发茬、分离式小胡子与短山羊胡、暗酒红敞领衬衫、米色内搭和暖卡其腰部，与 customer_01—09 区分；耐心条、订单卡、付款内容、工作台和阴影均由独立层提供。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 背景：纯绿色抠像背景 `#00ff00`
- 后处理：技能自带 `remove_chroma_key.py`
- 迭代：初稿身份合格但占画过大；进行一次只调整整体比例和位置的身份锁定修正。

## 初始生成完整提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P1 customer_10 neutral half-body gameplay Sprite2D confirmation draft on a removable chroma-key background.

Input images:
- Image 1 is the authoritative V8 gameplay composition and visual-style anchor. Use only its fixed slightly elevated frontal customer viewpoint, bold deep-brown outlines, warm simple color treatment, and grounded street-stall cartoon language. Do not reproduce its counter, griddle, UI, background, or young male identity.
- Images 2 through 5 are approved customer sprites used only for complete half-body framing, scale range, line thickness, lower-edge placement, adult proportions, and clean matte finish. Do not copy any existing identity, face, hairstyle, clothing design, age presentation, body silhouette, facial hair design, or exact color combination.

Primary request:
Create one clearly new, friendly middle-aged man customer, approximately 40 to 50 years old, with a sturdy broad adult build and calm neutral waiting expression. He has warm medium-light olive skin, a broad rounded-rectangular adult face, strong jaw, slightly heavy cheeks, dark hazel attentive eyes, thick gently curved dark brows, a wide rounded nose, and a restrained closed-mouth friendly smile. He must not read as young, elderly, childlike, anime, exaggeratedly muscular, obese caricature, or a copy of customer_04 or customer_06.

Hair and facial hair:
A clean-shaven bald crown with a smooth complete scalp silhouette, plus a very narrow band of short dark-brown side and back stubble beginning above and behind both ears. Both complete ears must remain fully visible. Add one neat simple dark-brown mustache separated clearly from a small short rounded goatee under the lower lip and chin; no full beard, no sideburns extending onto the cheeks, no beard shadow, and no individual hair texture. Keep facial hair as clean broad cartoon shapes. Entire scalp, stubble edge, ears, mustache, and goatee must stay inside the canvas.

Clothing:
A muted deep burgundy short-sleeve camp-collar overshirt, worn open only at the upper chest to reveal a small warm cream crew-neck undershirt triangle. The camp collar has two simple broad lapels and no buttons, pockets, pattern, logo, or text. A warm muted khaki-brown trouser waistband appears at the lower edge. Keep clothing as clean matte large color blocks with base color plus at most one broad shadow and one broad highlight. No green anywhere in the character. No polo collar, Henley placket, sweater vest, V-neck vest, apron, scarf, jewelry, glasses, hat, or accessory.

Pose and anatomy:
Straight front-facing relaxed pose in the same slightly elevated fixed gameplay viewpoint as V8. Both broad shoulders, upper arms, complete forearms, relaxed open hands, fingers, and the complete waist-level lower edge are fully visible. Arms hang naturally beside the torso without hiding the shirt. Exactly two arms and two hands. Sturdy broad adult proportions without inflated muscles, hunched posture, clenched fists, oversized head, chibi body, or fashion pose.

Composition/framing:
One centered character on a 1536 x 1024 landscape canvas, shown from the complete top of the bald scalp through the complete lower waist edge. Target visible silhouette approximately 500 to 525 pixels wide and 865 to 890 pixels tall, centered near x=768. Place the highest scalp point near y=80 to 95 and the complete unbroken lower waistband edge near y=968 to 976. Preserve the entire scalp, stubble band, both ears, both shoulders, both forearms, both complete hands and fingertips, and the full lower edge with generous green padding. Keep the character fully detached from all four canvas edges. No table or counter in front.

Style/medium:
Exact approved ProjectCake V8 language: polished clean hand-drawn 2D cartoon game illustration, bold smooth deep-brown outer contours comparable to the approved customers, confident simple internal lines, crisp readable silhouette, large matte color shapes, and no more than about three value levels per material. Warm everyday street-stall atmosphere. Avoid thin outlines, skin texture, stubble dots, pores, grain, speckles, fabric texture, complex gradients, glossy rendering, painterly detail, photorealism, 3D, or excessive facial detail.

Neutral-state constraint:
Relaxed eyebrows, open attentive eyes looking forward, calm restrained closed-mouth smile, symmetrical relaxed stance. No impatience, anger, exaggerated happiness, laughter, wink, surprise, dramatic pose, or comic expression.

Scene/backdrop:
Perfectly flat solid #00ff00 chroma-key green background edge to edge, including all four corners, for local background removal. The background must be one uniform color with no shadow, gradient, texture, reflection, floor plane, vignette, halo, glow, or lighting variation. Do not use green anywhere inside the character.

Absolute constraints:
One customer only. No counter, workstation, griddle, order card, patience bar, payment tray, money, food, tools, props, cast shadow, contact shadow, reflection, speech bubble, comic symbol, motion mark, UI, text, letters, numbers, logo, brand, or watermark. No cropped body part, hidden hand, extra limb, fused arm, malformed hand, glasses, hat, earring, necklace, apron, or accessory.

Output intent:
One clean opaque green chroma-key source suitable for remove_chroma_key.py, later transparent Sprite2D use, and identity-locked expression-state edits after human approval.
```

## 比例与位置修正完整提示词

```text
Use case: identity-preserve
Asset type: ProjectCake customer_10 neutral sprite scale-and-position correction.

Input images:
- Image 1 is the exact customer_10 neutral green chroma-key edit target and sole identity anchor.
- Image 2 is the authoritative V8 gameplay scale and framing reference.

Primary request:
Correct ONLY the uniform overall scale and framing of Image 1. Uniformly scale the complete character down to approximately 92% as one rigid coherent unit, without stretching or changing proportions. Keep him horizontally centered near x=768. Position the result so the highest bald scalp point is near y=78 to 88 and the complete lower waist edge ends near y=950 to 965, leaving at least 55 pixels of uniform green background below it.

Absolute identity invariants:
Preserve the exact same sturdy middle-aged man identity, warm medium-light olive skin, broad rounded-rectangular face, strong jaw, heavy cheeks, dark hazel eyes, thick curved brows, wide rounded nose, restrained neutral smile, complete bald crown, narrow dark-brown side/back stubble band, both exposed ears, exact separated mustache and rounded goatee shapes, broad build, deep burgundy short-sleeve camp-collar overshirt, warm cream undershirt triangle, khaki-brown lower garment, hands, fingers, pose, colors, outlines, and shading. Do not change age presentation, scalp shape, stubble, facial hair, face, expression, clothing, body silhouette, or color palette.

Uniform scaling rule:
Scale the entire opaque character together. Do not independently resize, narrow, widen, stretch, move, redraw, or distort the head, face, ears, mustache, goatee, torso, shoulders, arms, hands, or lower garment. Preserve the full scalp, both ears, both shoulders, both complete forearms, both hands and fingertips, and the complete lower waist edge inside the canvas. Target an overall visible silhouette approximately 510 to 535 pixels wide and 865 to 890 pixels tall.

Style invariants:
Preserve the approved ProjectCake V8 clean 2D cartoon language, bold deep-brown outlines, large matte color blocks, and limited broad shading. Keep scalp, skin, facial hair, and clothing free of pores, stubble dots, individual hairs, grain, random speckles, fabric texture, noisy pixels, glossy effects, and excessive detail.

Background:
Preserve a perfectly uniform flat solid #00ff00 chroma-key green background edge to edge, including all four corners and the full strip below the character. No gradient, texture, lighting variation, vignette, halo, floor, reflection, cast shadow, or contact shadow. Do not use green inside the character.

Do not add:
No new person, prop, accessory, glasses, hat, jewelry, apron, UI, counter, workstation, griddle, order card, patience bar, payment object, food, tool, text, letters, numbers, logo, brand, watermark, comic symbol, motion mark, shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One corrected customer_10 neutral green chroma-key source suitable for remove_chroma_key.py and later identity-locked expression edits.
```

## 处理记录

最终源：`tmp/imagegen/customers_v10/customer_10_neutral_v1_chromakey.png`。

Rejected：`tmp/imagegen/customers_v10/customer_10_neutral_v1_rejected_overscale_chromakey.png`，身份合格但人物占画过大。

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

最终图未在本地裁切、缩放或调色。
