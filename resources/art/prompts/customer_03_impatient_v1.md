# customer_03_impatient_v1

## 用途

P1 第三名顾客接近耗尽耐心时的半身 `Sprite2D` 状态。与 customer_03 中性稿共用身份、画布和锚点，仅通过面部表情表达不耐烦。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：以 `customer_03_neutral_v1_chromakey.png` 为精确编辑目标
- 背景：纯品红抠像背景
- 后处理：技能自带 `remove_chroma_key.py`

## 完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake P1 customer_03 half-body Sprite2D expression state, impatient
Input images: Image 1 is the approved customer_03_neutral_v1 magenta chroma-key source and exact edit target. Preserve this exact older woman; do not redesign, redraw, reframe or rescale her.
Primary request: change only the facial expression to restrained, clearly readable impatience as her patience is nearly depleted.
Expression change only: angle both eyebrows slightly downward toward the center, narrow the open eyes mildly while preserving the same dark-brown eye color, placement and subtle age lines, and change the mouth into a small compressed or gently downward curve. The emotion should read as mildly stern and impatient, not furious, shouting, cruel or sad.
Absolute identity invariants: preserve exactly the same older adult woman identity, mature softly rectangular face, skin tone, nose, eye-corner age lines, silver-gray swept-back hair, complete side-rear low bun, hair silhouette, both visible ears, faded teal short-sleeve cardigan, warm cream V-neck blouse, muted terracotta waistband and lower garment. Preserve the exact cardigan seams and buttons, hands, fingers, arms, shoulders, torso, pose, body proportions, bold line weight, colors, shadows and highlights.
Absolute geometry invariants: preserve the original 1535 x 1024 canvas, character scale, centered placement, complete alpha-subject silhouette, top/side/bottom padding, waist lower edge, approximate alpha bounding box (511,87)-(1002,982), and counter pivot near (756,981). Do not move any body part or change the external silhouette. Keep every hair edge, the complete bun, both ears, both shoulders, both forearms, both hands and waist fully visible and uncropped.
Background: preserve a perfectly uniform solid chroma-key magenta background RGB 255,0,255 edge to edge. No gradient, texture, vignette, shadow, floor plane or lighting variation. Do not use magenta inside the character.
Style invariants: approved ProjectCake V8 simple 2D cartoon, bold clean deep-brown outlines, large matte flat color blocks, at most base plus one shadow and one highlight, crisp readable silhouette. No style drift or added facial detail.
Must not include: clenched fists, crossed arms, body lean, tears, sweat, steam, anger marks, comic icons, speech bubble, UI, patience bar, order card, payment, workstation, props, food, cast shadow, contact shadow, text, letters, numbers, logo, brand, watermark, extra limbs, cropped bun or hidden hands.
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
