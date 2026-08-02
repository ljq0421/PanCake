# customer_07_impatient_v1

## 用途

P1 第七名顾客的不耐烦半身 `Sprite2D` 状态。以最终 customer_07 中性品红键控源为身份、服装、雀斑与构图基准，只改变眉形、眼睑和嘴型。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：`precise-object-edit`
- 输入：`tmp/imagegen/customers_v7/customer_07_neutral_v1_chromakey.png`
- 背景：纯品红抠像背景 `#ff00ff`
- 后处理：技能自带 `remove_chroma_key.py`

## 完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake customer_07 impatient half-body gameplay sprite.

Input images:
- Image 1 is the exact approved customer_07 neutral magenta chroma-key source, edit target, identity anchor, clothing anchor, freckle anchor, and geometry anchor.

Primary request:
Change ONLY the facial expression into a restrained mildly impatient state:
- angle the copper-brown eyebrows slightly downward toward the center,
- narrow the dark hazel eyes mildly while preserving their exact placement and spacing,
- change the mouth into a small shallow downward curve,
- keep the emotion mildly impatient and tired of waiting, not angry, hostile, sad, worried, shocked, or exaggerated.

Absolute face and identity invariants:
Preserve the exact same middle-aged woman identity, softly rounded-square face, warm fair-to-light skin, nose shape, dark hazel irises, copper eyebrows, short layered copper-red pixie hair, swept side fringe, both exposed ears, comfortably full sturdy build, and adult proportions. Preserve the exact small scattering, count, color, and approximate positions of the freckles across the nose and upper cheeks. Do not add, remove, multiply, darken, scatter, or move freckles. Do not add forehead creases, brow-furrow lines, tears, blush, or new age lines.

Absolute clothing and body invariants:
Preserve the exact sunflower-gold short-sleeve boat-neck blouse, deep desaturated teal waistband, neckline, sleeve bands, broad shading, shoulders, arms, forearms, hands, fingers, pose, full silhouette, colors, and bold deep-brown outline thickness. Keep hair and clothing as clean broad matte color blocks with no grain, random speckles, weave texture, stains, scratches, or mottling.

Geometry lock:
Preserve the unchanged 1535 x 1024 canvas and complete character placement. Match the neutral subject boundary approximately x=489..1030 and y=110..977, 541 pixels wide, with the lower waist edge and suggested pivot near (760,976). Preserve every copper hair tip, both ears, both shoulders, both forearms, both hands, all fingers, and the complete waist lower edge with no cropping. Do not scale, stretch, narrow, widen, translate, rotate, or change the pose.

Style invariants:
Approved ProjectCake V8 simple hand-drawn 2D cartoon, bold clean deep-brown outlines, crisp readable silhouette, large matte flat color blocks, base color plus at most one broad shadow and one broad highlight. No photorealism, 3D gloss, painterly rendering, thin outlines, excessive gradients, or noisy detail.

Background:
Preserve a perfectly uniform flat solid #ff00ff chroma-key background edge to edge, including all four corners. No gradient, texture, lighting variation, vignette, halo, floor, reflection, cast shadow, or contact shadow. Do not use magenta inside the character.

Do not add:
No change to posture, clothing, hairstyle, anatomy, body proportions, accessories, props, UI, counter, workstation, griddle, order card, patience bar, payment object, food, tools, text, letters, numbers, logo, brand, watermark, speech bubble, comic symbol, motion mark, sweat drop, shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One clean opaque customer_07 impatient magenta chroma-key source suitable for remove_chroma_key.py and transparent Sprite2D use.
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

首次生成即通过身份、表情、雀斑、服装、构图和键控检查；最终图未裁切、未缩放、未调色。

