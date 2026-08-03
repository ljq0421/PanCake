# batter_ladle_upgrade_v1

## 生成提示词

```text
Use case: precise-object-edit.
Edit target: the provided ProjectCake batter_ladle_v1.png, an existing transparent jianbing batter ladle sprite.
Primary request: create its clearly upgraded P2 version while preserving the exact same single ladle identity, near-top-down diagonal orientation from upper-left bowl to lower-right handle, centered composition, full uncropped silhouette, empty round bowl, and generous padding. Keep a brushed stainless-steel bowl with a slightly clearer measured inner rim but no markings or numbers; replace the plain wood handle with a muted-teal heat-resistant ergonomic grip; add a short warm brass collar at the neck and a small cream end cap. It must remain a fully manual ladle with no motor, pump, display, buttons, or extra objects.
Style: match ProjectCake's approved simple hand-drawn 2D cartoon style, bold clean deep-brown outline, large flat color blocks, at most one shadow and one highlight per material, crisp readable silhouette, warm grounded street-stall palette.
Background: perfectly flat uniform solid #00ff00 chroma-key background in every corner and edge, no shadows, gradients, texture, reflections, floor plane, halo, or lighting variation. Do not use #00ff00 in the object.
Constraints: exactly one clean empty upgraded ladle only; no batter, hand, griddle, counter, other tools, cast shadow, contact shadow, text, letters, numbers, logo, brand, watermark, photorealism, glossy 3D, thin outlines, painterly detail, or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。
