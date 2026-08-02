# ingredient_tongs_v1

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake movable gameplay tool sprite, food tongs, chroma-key source for transparent PNG
Input images: Image 1 is the approved ProjectCake folding spatula sprite and style/material reference only, not an edit target
Primary request: create one pair of compact stainless-steel food tongs viewed from the same fixed near-top-down angle and matching Image 1. Two simple metal arms joined at the upper-left spring bend, slightly open gripping tips toward the lower-right, with small warm-brown wooden grip pads near the hand area. Complete object angled diagonally with generous padding; clear silhouette when scaled down.
Style/medium: simple hand-drawn 2D cartoon, bold clean deep-brown outline matching Image 1, large flat color blocks, at most base plus one shadow and one highlight, minimal metal detail, crisp silhouette.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal. Background must be uniform with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Object constraints: exactly one pair of tongs; no food held in tips; no separate pieces; fully separated from background; no cast shadow, contact shadow or reflection; do not use #00ff00 in the object; no hand, customer, griddle, counter, other tools, ingredients or UI.
Constraints: no text, letters, numbers, logo, brand or watermark; no photorealism, glossy 3D, thin outlines, painterly detail, complex hinges, serrated micro-detail or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。

