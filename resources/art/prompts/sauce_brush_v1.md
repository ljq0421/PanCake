# sauce_brush_v1

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake movable gameplay tool sprite, wide sauce brush, chroma-key source for transparent PNG
Input images: Image 1 is the approved ProjectCake batter spreader sprite and style/material reference only, not an edit target
Primary request: create one wide flat food-safe sauce brush viewed from the same fixed near-top-down angle and matching Image 1. A medium-long warm-brown wooden handle, small dull-metal ferrule, and a broad short rectangular bundle of pale cream bristles. The brush head must be visibly wide for covering a pancake in a few broad strokes. Complete object angled diagonally from upper-left brush head to lower-right handle with generous padding.
Style/medium: simple hand-drawn 2D cartoon, bold clean deep-brown outline matching Image 1, large flat color blocks, at most base plus one shadow and one highlight, minimal bristle lines, crisp readable silhouette.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal. Background must be uniform with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Object constraints: one clean empty sauce brush only; no sauce on bristles, no drips; fully separated from background; no cast shadow, contact shadow or reflection; do not use #00ff00 in the object; no hand, customer, griddle, counter, other tools, ingredients or UI.
Constraints: no text, letters, numbers, logo, brand or watermark; no photorealism, glossy 3D, thin outlines, painterly detail, excessive bristle strands or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。

