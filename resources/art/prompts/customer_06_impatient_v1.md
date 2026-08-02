# customer_06_impatient_v1

## 用途

P1 第六名顾客的不耐烦半身 `Sprite2D` 状态。以最终 customer_06 中性品红键控源为身份、服装和构图基准，只改变眉毛、眼睑与嘴型。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：`precise-object-edit`
- 输入：`tmp/imagegen/customers_v6/customer_06_neutral_v1_chromakey.png`
- 背景：纯品红抠像背景 `#ff00ff`
- 后处理：技能自带 `remove_chroma_key.py`

## 初始完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake customer_06 impatient half-body gameplay sprite.

Input images:
- Image 1 is the exact approved customer_06 neutral magenta chroma-key source, edit target, identity anchor, clothing anchor, and geometry anchor.

Primary request:
Change ONLY the facial expression into a restrained mildly impatient state:
- angle the silver-gray eyebrows slightly downward toward the center,
- narrow the eyes mildly while keeping the same dark brown irises and eye placement,
- change the mouth into a small restrained downward curve,
- keep the emotion mildly impatient and tired of waiting, not angry, hostile, sad, shocked, or exaggerated.

Absolute identity invariants:
Preserve the exact same elderly man identity, long softly rectangular face, warm light-medium skin, gently prominent nose, high receding hairline, short combed-back silver-gray hair, thick silver eyebrows, both exposed ears, subtle age lines, lean build, and adult proportions. Preserve all face dimensions and feature positions except the stated eyebrow, eyelid, and mouth expression changes. No facial hair and no glasses.

Absolute clothing and body invariants:
Preserve the exact powder-blue short-sleeve collared shirt, warm mustard-ochre sleeveless V-neck vest, brick-red trouser waistband, neckline, seams, broad shading, shoulders, arms, forearms, hands, fingers, pose, silhouette, colors, and bold deep-brown outline thickness. Keep shirt and vest as clean broad matte color blocks with no grain, speckles, knit microtexture, noisy pixels, scratches, or mottling.

Geometry lock:
Preserve the unchanged 1535 x 1024 canvas and the complete character placement. Match the neutral subject boundary approximately x=529..999 and y=56..974, 470 pixels wide, with the lower waist edge and suggested pivot near (764,973). Preserve every silver hair tip, full high forehead, both ears, both shoulders, both forearms, both hands, all fingers, and the complete waist lower edge with no cropping. Do not scale, stretch, narrow, widen, translate, rotate, or change the pose.

Style invariants:
Approved ProjectCake V8 simple hand-drawn 2D cartoon, bold clean deep-brown outlines, crisp readable silhouette, large matte flat color blocks, base color plus at most one broad shadow and one broad highlight. No photorealism, 3D gloss, painterly rendering, thin outlines, excessive gradients, or noisy detail.

Background:
Preserve a perfectly uniform flat solid #ff00ff chroma-key background edge to edge, including all four corners. No gradient, texture, lighting variation, vignette, halo, floor, reflection, cast shadow, or contact shadow. Do not use magenta inside the character.

Do not add:
No change to posture, clothing, hairstyle, anatomy, nose shape, age lines, accessories, props, UI, counter, workstation, griddle, order card, patience bar, payment object, food, tools, text, letters, numbers, logo, brand, watermark, speech bubble, comic symbol, motion mark, sweat drop, shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One clean opaque customer_06 impatient magenta chroma-key source suitable for remove_chroma_key.py and transparent Sprite2D use.
```

## 表情强度修正完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake customer_06 impatient expression softening.

Input images:
- Image 1 is the exact customer_06 impatient magenta chroma-key edit target. Preserve it completely except for the stated facial-expression intensity correction.

Primary request:
Soften ONLY the facial expression from angry-looking to mildly impatient:
- remove the newly added short vertical tension lines between the eyebrows and above the nose,
- relax the inner eyebrow angle so the brows tilt downward toward the center only slightly,
- keep the eyes only mildly narrowed, not glaring,
- soften the mouth into a smaller, shallower restrained downward curve,
- retain the original subtle age lines at the eye corners and beside the mouth without adding new wrinkles.
The final emotion must read as an elderly customer who has waited a little too long, not angry, hostile, sad, worried, shocked, or exaggerated.

Hard invariants:
Preserve the exact same elderly man identity, face dimensions, prominent nose, skin tone, eye color and placement, high receding combed-back silver hair, both exposed ears, lean body, powder-blue shirt, mustard-ochre V-neck vest, brick-red waistband, all clothing seams, shoulders, arms, forearms, hands, fingers, pose, line weight, colors, clean flat V8 shading, 1535 x 1024 canvas, placement, scale, and silhouette. Preserve the approximate subject boundary x=529..999 and y=56..974 and pivot near (764,973). Do not move, scale, stretch, crop, redraw, widen, or narrow the character.

Background:
Preserve perfectly uniform flat #ff00ff edge to edge, including all four corners, with no gradient, texture, halo, vignette, floor, shadow, reflection, or lighting variation. Do not use magenta inside the character.

Do not add or change:
No clothing texture, grain, speckles, facial hair, glasses, accessory, prop, UI, counter, order card, patience bar, payment object, text, letters, numbers, logo, watermark, comic symbol, sweat drop, motion mark, shadow, extra limb, hidden hand, or cropped body part.

Output intent:
One clean mildly impatient customer_06 magenta chroma-key source suitable for remove_chroma_key.py.
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

初稿眉角过陡并新增眉心紧绷线，读感偏愤怒，因此作为 `customer_06_impatient_v1_attempt1_angry_chromakey.png` 保留。修正稿去除新增紧绷线并降低表情强度；最终图未裁切、未缩放、未调色。

