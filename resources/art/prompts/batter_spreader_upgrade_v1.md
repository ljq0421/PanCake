# batter_spreader_upgrade_v1

## 生成提示词

```text
Use case: precise-object-edit.
Edit target: the provided ProjectCake batter_spreader_v1.png, an existing transparent T-shaped jianbing batter spreader sprite.
Primary request: create its clearly upgraded P2 version while preserving the exact same single T-shaped tool identity, near-top-down diagonal orientation, centered composition, full uncropped silhouette, and generous padding. Replace the long wooden spreading bar with a slightly wider brushed stainless-steel bar with softly rounded ends; replace the plain wooden handle with a muted teal heat-resistant ergonomic grip; add one small warm brass collar at the joint. The upgrade must suggest smoother, more forgiving spreading, but must remain a fully manual T-shaped spreader with no motor, automation, screen, buttons, extra blades, or extra tools.
Style: match ProjectCake's approved simple hand-drawn 2D cartoon style: bold clean deep-brown outline, large flat color blocks, at most one shadow and one highlight per material, crisp readable silhouette, warm grounded street-stall palette.
Background: perfectly flat uniform solid #00ff00 chroma-key background, including every corner and edge, with no shadows, gradients, texture, reflections, floor plane, halo, or lighting variation. The object itself must not contain #00ff00.
Constraints: exactly one upgraded spreader only; no batter, hand, griddle, counter, other objects, cast shadow, contact shadow, text, letters, numbers, logo, brand, watermark, photorealism, glossy 3D, thin outlines, painterly detail, or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。
