# sauce_brush_upgrade_v1

## 生成提示词

```text
Use case: precise-object-edit.
Edit target: the provided ProjectCake sauce_brush_v1.png, an existing transparent wide sauce brush sprite.
Primary request: create its clearly upgraded P2 version while preserving the exact same one-brush identity, near-top-down diagonal orientation, centered composition, full uncropped silhouette, broad short brush head, and generous padding. Keep the head visibly wide for a few broad manual strokes, but replace the natural bristle bundle with a clean muted-teal food-safe silicone bristle pad divided into only six broad channels; replace the plain wood handle with a warm cream and muted teal ergonomic handle; add a small brushed-steel ferrule and one warm brass rivet. The upgrade should suggest more even sauce coverage and easier cleaning while remaining a manual brush.
Style: match ProjectCake's simple hand-drawn 2D cartoon style: bold clean deep-brown outline, large flat color blocks, at most one shadow and one highlight per material, crisp readable silhouette, warm grounded street-stall palette.
Background: perfectly flat uniform solid #00ff00 chroma-key background, including every corner and edge, no shadows, gradients, texture, reflections, floor plane, halo, or lighting variation. Do not use #00ff00 in the object.
Constraints: exactly one clean empty upgraded brush only; no sauce, drips, hand, griddle, counter, other tools, cast shadow, contact shadow, text, letters, numbers, logo, brand, watermark, photorealism, glossy 3D, thin outlines, painterly detail, excessive bristle strands, or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。
