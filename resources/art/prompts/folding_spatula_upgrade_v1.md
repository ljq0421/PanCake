# folding_spatula_upgrade_v1

## 生成提示词

```text
Use case: precise-object-edit.
Edit target: the provided ProjectCake folding_spatula_v1.png, an existing transparent wide jianbing folding spatula sprite.
Primary request: create its clearly upgraded P2 version while preserving the exact same single spatula identity, near-top-down diagonal orientation from upper-left blade to lower-right handle, centered composition, complete uncropped silhouette, broad rounded rectangular blade, and generous padding. Upgrade the blade to brushed stainless steel with a slightly thinner rounded leading edge and two broad shallow reinforcement channels; replace the plain wood handle with a muted-teal heat-resistant ergonomic grip and warm-cream inset; add a warm brass collar and one brass rivet. It should suggest easier controlled folding while remaining fully manual, with no motor or automation.
Style: match ProjectCake's approved simple hand-drawn 2D cartoon style, bold clean deep-brown outline, large flat color blocks, at most one shadow and one highlight per material, crisp readable silhouette, warm grounded street-stall palette.
Background: perfectly flat uniform solid #00ff00 chroma-key background in every corner and edge, no shadows, gradients, texture, reflections, floor plane, halo, or lighting variation. Do not use #00ff00 in the object.
Constraints: exactly one upgraded spatula only; no food, hand, griddle, counter, other tools, cast shadow, contact shadow, text, letters, numbers, logo, brand, watermark, holes in blade, photorealism, glossy 3D, thin outlines, painterly detail, or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。
