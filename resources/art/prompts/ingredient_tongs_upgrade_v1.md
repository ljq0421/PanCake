# ingredient_tongs_upgrade_v1

## 生成提示词

```text
Use case: precise-object-edit.
Edit target: the provided ProjectCake ingredient_tongs_v1.png, an existing transparent metal food-tongs sprite.
Primary request: create its clearly upgraded P2 version while preserving the exact same single tongs identity, near-top-down diagonal orientation from upper-left hinge to lower-right gripping tips, centered composition, fully open uncropped silhouette, and generous padding. Keep brushed stainless-steel arms; add muted-teal heat-resistant grip insets on both arms, a compact warm brass hinge cap, and broad warm-cream food-safe silicone scalloped gripping pads on both tips. Preserve the open center gap and manual spring-tongs function; no motor, locking gadget, screen, or extra objects.
Style: match ProjectCake's approved simple hand-drawn 2D cartoon style, bold clean deep-brown outline, large flat color blocks, at most one shadow and one highlight per material, crisp readable silhouette, warm grounded street-stall palette.
Background: perfectly flat uniform solid #00ff00 chroma-key background in every corner and edge, no shadows, gradients, texture, reflections, floor plane, halo, or lighting variation. Do not use #00ff00 in the object.
Constraints: exactly one upgraded pair of tongs only; no ingredient, hand, griddle, counter, other tools, cast shadow, contact shadow, text, letters, numbers, logo, brand, watermark, photorealism, glossy 3D, thin outlines, excessive detail, or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。
