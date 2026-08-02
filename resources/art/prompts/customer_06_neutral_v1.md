# customer_06_neutral_v1

## 用途

P1 第六名顾客的中性半身 `Sprite2D` 单张确认稿。人物采用偏瘦老年男性、高额角后梳银发、长矩形脸、浅蓝衬衫与暖芥末色背心，与 customer_01–05 区分；耐心条、订单卡、付款内容、工作台和阴影均由独立层提供。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：先以 V8 和既有顾客作构图/风格参考生成新身份，再进行两次有针对性的比例与位置精确编辑
- 背景：纯品红抠像背景 `#ff00ff`
- 后处理：技能自带 `remove_chroma_key.py`

## 初始生成完整提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P1 customer_06 neutral half-body gameplay Sprite2D confirmation draft on a removable chroma-key background.

Input images:
- Image 1 is the approved V8 gameplay composition and visual-style anchor. Use only its fixed slightly elevated frontal customer viewpoint, bold deep-brown outlines, warm flat-color treatment, and grounded street-stall cartoon language. Do not reproduce its counter, griddle, UI, background, or existing young male identity.
- Images 2, 3, and 4 are approved customer sprites. Use them only as references for complete half-body framing, scale range, canvas occupancy, line thickness, lower waist-edge placement, and simple large color blocks. Do not copy any identity, face, hairstyle, clothing design, body width, age presentation, or colors.

Primary request:
Create one clearly different, friendly elderly man customer as an isolated neutral half-body character from the complete top of his hair to just below the waist. He has a lean adult build, a long softly rectangular face, warm light-medium skin, a gently prominent nose, dark brown attentive eyes, thick silver-gray eyebrows, subtle age lines at the eye corners and beside the mouth, and a restrained small closed-mouth friendly smile. No facial hair and no glasses.

Hair:
Short silver-gray hair with a clearly receding high hairline, smoothly combed back and slightly fuller at both sides, with a neat rounded back silhouette. Both complete ears must remain exposed. Preserve every hair tip and the entire high forehead inside the canvas. This hairstyle must not resemble customer_03's swept low bun, customer_04's dense dark curls, customer_05's bob, or customer_01's tousled hair.

Clothing:
A faded powder-blue short-sleeve collared shirt under a simple warm mustard-ochre sleeveless knit vest, with a muted dark brick-red trouser waistband at the lower edge. The vest has a clean shallow V neckline and no pattern, logo, text, pockets, badge, or decorative motif. Keep all cloth surfaces as clean broad matte color blocks with no grain, speckles, knit microtexture, noisy pixels, or mottling. Do not use magenta anywhere in the character.

Pose and anatomy:
Straight frontal pose, same slightly elevated fixed gameplay viewpoint as V8. Both shoulders, upper arms, forearms, relaxed open hands, fingers, and the complete waist-level lower edge are fully visible. Arms hang naturally beside the torso without touching or hiding the vest. Exactly two arms and two hands. Adult proportions, not chibi, not childlike, not anime.

Composition/framing:
One centered character on a 1535 x 1024 broad landscape canvas. Preserve at least 78 pixels of perfectly uniform background above the highest hair point. Keep generous background padding around both ears, shoulders, elbows, hands, and waist. No crop through hair, ears, shoulders, forearms, hands, waist, or clothing. Target a lean visible silhouette approximately 470 to 490 pixels wide, centered near x=760, with the flat lower waist edge ending near y=972 to 978 for a suggested counter pivot near (760,976).

Style/medium:
Exact approved ProjectCake V8 visual language: simple hand-drawn 2D cartoon, bold clean deep-brown outlines of comparable thickness, crisp readable silhouette, large matte flat color areas, base color plus at most one broad shadow and one broad highlight, warm everyday street-stall atmosphere. Avoid glossy rendering, complex textile detail, gradients, painterly texture, photorealism, 3D, thin outlines, and excessive facial detail.

Neutral-state constraint:
Relaxed eyebrows, open attentive eyes, calm restrained closed-mouth smile, symmetrical relaxed stance. No impatience, anger, exaggerated happiness, laughter, wink, surprise, dramatic pose, or comic expression.

Scene/backdrop:
Perfectly flat solid #ff00ff chroma-key background edge to edge, including all four corners, for local background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, vignette, halo, glow, or lighting variation.

Absolute constraints:
One customer only. No counter, workstation, griddle, order card, patience bar, payment tray, money, food, tools, props, cast shadow, contact shadow, reflection, speech bubble, comic symbol, motion mark, UI, text, letters, numbers, logo, brand, or watermark. No cropped body part, hidden hand, extra limb, fused arm, malformed hand, facial hair, glasses, hat, jewelry, apron, or accessories.

Output intent:
One clean opaque magenta chroma-key source suitable for remove_chroma_key.py, later transparent Sprite2D use, and identity-locked expression-state edits after human approval.
```

## 第一次比例修正完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake customer_06 neutral sprite composition correction.

Input images:
- Image 1 is the exact customer_06 neutral magenta chroma-key edit target and identity anchor.

Primary request:
Correct ONLY the character scale and vertical placement. Uniformly scale the entire character down by approximately 3 percent, keep him horizontally centered, and place the complete waist-level lower edge near y=975 to 977 on the unchanged 1535 x 1024 canvas. Target the complete visible subject boundary approximately x=520..1000 and y=80..976, about 480 pixels wide and 896 pixels tall. Preserve generous uniform magenta padding above all silver hair and around both hands.

Absolute character invariants:
Preserve the exact same elderly man identity, long softly rectangular face, warm light-medium skin, prominent nose, dark eyes, silver eyebrows, age lines, restrained neutral closed-mouth smile, high receding hairline, combed-back silver-gray hair, both exposed ears, lean proportions, powder-blue short-sleeve collared shirt, mustard-ochre sleeveless V-neck vest, brick-red trouser waistband, both shoulders, forearms, hands, fingers, pose, colors, line weight, lighting, and clean flat V8 rendering. Preserve all facial features and clothing seams exactly. Change no expression, anatomy, hairstyle, clothing detail, color, or outline style.

Scaling rule:
Scale the whole opaque character as one coherent unit; do not make the head, face, torso, arms, or hands independently larger or smaller. Do not narrow or stretch the character. Do not crop any hair tip, ear, shoulder, forearm, hand, finger, waist edge, or clothing.

Background:
Preserve a perfectly uniform flat solid #ff00ff chroma-key background edge to edge, including all four corners. No gradient, texture, lighting variation, halo, vignette, floor, reflection, cast shadow, or contact shadow. Do not use magenta inside the character.

Style invariants:
Approved ProjectCake V8 simple hand-drawn 2D cartoon, bold clean deep-brown outlines, large matte flat color blocks, base plus at most one broad shadow and one broad highlight. Keep the vest and shirt free of grain, speckles, knit microtexture, mottling, and noisy pixels.

Must not include:
No new person, props, accessories, facial hair, glasses, hat, jewelry, apron, UI, counter, workstation, griddle, order card, patience bar, payment object, food, tools, text, letters, numbers, logo, brand, watermark, comic symbol, motion mark, shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One corrected customer_06 neutral magenta chroma-key source suitable for remove_chroma_key.py and later identity-locked expression-state edits.
```

## 最终比例与位置修正完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake customer_06 neutral sprite final scale-and-position correction.

Input images:
- Image 1 is the exact customer_06 neutral magenta chroma-key edit target and sole identity anchor.
- Its measured subject boundary is currently x=535..989 and y=90..938 on a 1535 x 1024 canvas.

Primary request:
Change ONLY the uniform scale and vertical position of the complete character as one unit:
1. uniformly enlarge the entire character by approximately 5 percent without stretching,
2. keep the character horizontally centered near x=767,
3. move the complete character downward so the waist-level lower edge ends at y=975 to 977.
Target visible subject boundary approximately x=529..1006 and y=86..977, around 477 pixels wide and 891 pixels tall.

Absolute invariants:
Preserve the exact same elderly man identity, face, prominent nose, skin tone, eyes, silver eyebrows, age lines, neutral closed-mouth smile, high receding combed-back silver hair, both exposed ears, lean body proportions, powder-blue shirt, mustard-ochre sleeveless V-neck vest, brick-red waistband, arms, hands, fingers, pose, clothing seams, colors, outline thickness, lighting, and clean flat V8 rendering. Scale the whole person coherently. Do not independently resize or redraw the head, face, torso, arms, or hands. Change no expression, anatomy, hairstyle, clothing design, color, or texture.

Framing:
Keep every hair tip, both ears, both shoulders, both forearms, both hands, all fingers, and the complete waist lower edge fully inside the canvas. Maintain uniform magenta padding above the hair and beside the hands. No crop, no stretch, no widening, no narrowing.

Background:
Perfectly uniform flat solid #ff00ff chroma-key background edge to edge, including all four corners. No gradient, texture, lighting variation, halo, vignette, floor, reflection, cast shadow, or contact shadow. Do not use magenta inside the character.

Style:
Approved ProjectCake V8 simple hand-drawn 2D cartoon, bold clean deep-brown outlines, large matte flat color blocks, at most one broad shadow and one broad highlight. No grain, speckles, knit microtexture, mottling, or noisy pixels on the vest or shirt.

Do not add:
No new person, prop, accessory, facial hair, glasses, hat, jewelry, apron, UI, counter, workstation, griddle, order card, patience bar, payment object, food, tool, text, letters, numbers, logo, brand, watermark, comic symbol, motion mark, shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One corrected customer_06 neutral magenta chroma-key source suitable for remove_chroma_key.py and later identity-locked expression edits.
```

## 处理记录

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
  --force
```

初稿边界为 `(511,58)-(1008,982)`，宽度 497 px 且整体偏大；第一次修正稿边界为 `(535,90)-(989,938)`，生成器过度缩小并上移，因此两者作为 rejected attempts 保留。最终修正稿边界为 `(529,56)-(999,974)`，宽度 470 px、腰部可见底边 y=973；顶部留白 56 px 少于提示词理想值，但头发和抗锯齿边缘完整且未触碰画布。最终图未裁切、未由本地脚本缩放、未调色。

