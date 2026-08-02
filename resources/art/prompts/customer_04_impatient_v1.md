# customer_04_impatient_v1

## 用途

P1 第四名顾客接近耗尽耐心时的半身 `Sprite2D` 状态。与修正后的 customer_04 中性稿共用身份、画布和锚点，仅通过面部表情表达不耐烦。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：以 `customer_04_neutral_v1_chromakey.png` 为精确编辑目标
- 背景：纯品红抠像背景
- 后处理：技能自带 `remove_chroma_key.py`

## 完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake P1 customer_04 half-body Sprite2D expression state, impatient
Input images: Image 1 is the approved corrected customer_04_neutral_v1 magenta chroma-key source and exact edit target. Preserve this exact middle-aged man; do not redesign, redraw, reframe, widen or rescale him.
Primary request: change only the facial expression to restrained, clearly readable impatience as his patience is nearly depleted.
Expression change only: angle both eyebrows slightly downward toward the center, narrow the open eyes mildly while preserving the same dark-brown eye color and placement, and change the mouth into a small restrained downward curve. Reduce the friendly cheek impression. The emotion should read as impatient and dissatisfied, not furious, aggressive, shouting or sad.
Absolute identity invariants: preserve exactly the same middle-aged man identity, warm medium-brown skin, broad softly angular face, jaw, nose, short dense tightly curled dark hair, every curl, both visible ears, navy-blue short-sleeve polo, ochre collar trim, two blank buttons and brick-brown lower garment. Preserve the exact hands, fingers, arms, shoulders, torso, corrected 505-pixel-wide silhouette, pose, body proportions, bold line weight, colors, shadows and highlights.
Absolute geometry invariants: preserve the original 1535 x 1024 canvas, character scale, centered placement, complete alpha-subject silhouette, top/side/bottom padding, waist lower edge, approximate alpha bounding box (508,81)-(1013,976), and counter pivot near (760,975). Do not move any body part or change the external silhouette. Keep every curl, both ears, both shoulders, both forearms, both hands and waist fully visible and uncropped.
Background: preserve a perfectly uniform solid chroma-key magenta background RGB 255,0,255 edge to edge. No gradient, texture, vignette, shadow, floor plane or lighting variation. Do not use magenta inside the character.
Style invariants: approved ProjectCake V8 simple 2D cartoon, bold clean deep-brown outlines, large matte flat color blocks, at most base plus one shadow and one highlight, crisp readable silhouette. No style drift or added facial detail.
Must not include: beard, moustache, clenched fists, crossed arms, body lean, tears, sweat, steam, anger marks, comic icons, speech bubble, UI, patience bar, order card, payment, workstation, props, food, cast shadow, contact shadow, text, letters, numbers, logo, brand, watermark, extra limbs, cropped curls or hidden hands.
Output intent: one exact-alignment chroma-key expression variant suitable for remove_chroma_key.py and direct Sprite2D texture swapping with the neutral state.
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

首稿通过视觉与 alpha 检查，无需定向重生成。最终透明图未裁切、未缩放、未调色。
