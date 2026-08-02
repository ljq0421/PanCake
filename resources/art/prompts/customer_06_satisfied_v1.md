# customer_06_satisfied_v1

## 用途

P1 第六名顾客的满意半身 `Sprite2D` 状态。以最终 customer_06 中性品红键控源为身份、服装和构图基准，只改变眉毛、眼睑与嘴型。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：`precise-object-edit`
- 输入：`tmp/imagegen/customers_v6/customer_06_neutral_v1_chromakey.png`
- 背景：纯品红抠像背景 `#ff00ff`
- 后处理：技能自带 `remove_chroma_key.py`

## 完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake customer_06 satisfied half-body gameplay sprite.

Input images:
- Image 1 is the exact approved customer_06 neutral magenta chroma-key source, edit target, identity anchor, clothing anchor, and geometry anchor.

Primary request:
Change ONLY the facial expression into a warm restrained satisfied state:
- relax the silver-gray eyebrows naturally,
- close the eyes into gentle upward arcs while preserving their original position and spacing,
- change the mouth into a modest warm closed-mouth smile,
- allow only a very subtle warm cheek tone if necessary,
- keep the expression calm, dignified, and genuinely satisfied, not laughing, exuberant, childish, surprised, or exaggerated.

Absolute identity invariants:
Preserve the exact same elderly man identity, long softly rectangular face, warm light-medium skin, gently prominent nose, high receding hairline, short combed-back silver-gray hair, thick silver eyebrows, both exposed ears, subtle original age lines, lean build, and adult proportions. Preserve all face dimensions and feature positions except the stated eyebrow, eyelid, mouth, and optional subtle cheek-color changes. No facial hair and no glasses.

Absolute clothing and body invariants:
Preserve the exact powder-blue short-sleeve collared shirt, warm mustard-ochre sleeveless V-neck vest, brick-red trouser waistband, neckline, seams, broad shading, shoulders, arms, forearms, hands, fingers, pose, silhouette, colors, and bold deep-brown outline thickness. Keep shirt and vest as clean broad matte color blocks with no grain, speckles, knit microtexture, noisy pixels, scratches, or mottling.

Geometry lock:
Preserve the unchanged 1535 x 1024 canvas and the complete character placement. Match the neutral subject boundary approximately x=529..999 and y=56..974, 470 pixels wide, with the lower waist edge and suggested pivot near (764,973). Preserve every silver hair tip, full high forehead, both ears, both shoulders, both forearms, both hands, all fingers, and the complete waist lower edge with no cropping. Do not scale, stretch, narrow, widen, translate, rotate, or change the pose.

Style invariants:
Approved ProjectCake V8 simple hand-drawn 2D cartoon, bold clean deep-brown outlines, crisp readable silhouette, large matte flat color blocks, base color plus at most one broad shadow and one broad highlight. No photorealism, 3D gloss, painterly rendering, thin outlines, excessive gradients, or noisy detail.

Background:
Preserve a perfectly uniform flat solid #ff00ff chroma-key background edge to edge, including all four corners. No gradient, texture, lighting variation, vignette, halo, floor, reflection, cast shadow, or contact shadow. Do not use magenta inside the character.

Do not add:
No change to posture, clothing, hairstyle, anatomy, nose shape, age lines, accessories, props, UI, counter, workstation, griddle, order card, patience bar, payment object, food, tools, text, letters, numbers, logo, brand, watermark, speech bubble, comic symbol, motion mark, heart, sparkle, shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One clean opaque customer_06 satisfied magenta chroma-key source suitable for remove_chroma_key.py and transparent Sprite2D use.
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

首次生成即通过身份、表情、构图、服装纯净度和键控检查；最终图未裁切、未缩放、未调色。

