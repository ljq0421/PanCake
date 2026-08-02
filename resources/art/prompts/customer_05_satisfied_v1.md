# customer_05_satisfied_v1

## 用途

P1 第五名顾客的满意半身 `Sprite2D` 状态。以已确认的 customer_05 中性绿色键控源为唯一身份和构图基准，只改变眉眼、嘴型与极轻微面颊暖色。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：`precise-object-edit`
- 输入：`tmp/imagegen/customers_v5/customer_05_neutral_v1_chromakey.png`
- 背景：纯绿色抠像背景 RGB (0,255,0)
- 后处理：技能自带 `remove_chroma_key.py`

## 完整提示词

```text
Use case: precise-object-edit. Edit the supplied customer_05 neutral chroma-key sprite into the SATISFIED expression state.

Change ONLY the facial expression:
- eyes become relaxed closed upward arcs,
- eyebrows relax naturally,
- mouth becomes a modest warm closed smile,
- add only very subtle warm cheek color if needed,
- emotion reads as genuinely satisfied and friendly, not exaggerated or laughing.

Hard identity and geometry lock:
- preserve the exact same young adult woman, narrow oval face, skin tone, straight dark chin-length bob, straight bangs, hair tucked behind both ears,
- preserve every hair tip, both ears, both shoulders, both forearms, both hands, and the complete lower waist edge with no cropping,
- preserve the exact dusty plum square-neck short-sleeve blouse, cream waistband/skirt top, slim silhouette, pose, hand positions, line weight, proportions, and flat-color rendering,
- the plum blouse must stay a perfectly clean simple flat color area with at most the existing broad cel-shading; absolutely no speckles, grain, stippling, microtexture, noisy pixels, freckles, mottling, or chroma contamination on the fabric,
- preserve original 1535 x 1024 canvas and placement; visible silhouette approximately bbox x=536..987, y=86..977, width about 451 px; keep suggested lower-center pivot approximately (761,976),
- preserve the same thick dark-brown outlines, 2D warm street-stall cartoon style, simple large color blocks, maximum about three value levels.

Background:
- preserve a perfectly uniform flat chroma-key green background RGB (0,255,0), edge-to-edge, including all four corners,
- no shadow, no floor, no background elements.

Do not add or change posture, clothing, accessories, props, order card, patience bar, payment object, text, numbers, logos, watermark, comic symbols, motion marks, hearts, sparkles, or background projection.
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

首次生成即通过身份、构图、服装纯净度和键控检查；最终图未裁切、未缩放、未调色。

