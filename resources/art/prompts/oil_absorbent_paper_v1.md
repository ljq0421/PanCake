# oil_absorbent_paper_v1

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake movable gameplay repair item sprite, single oil-absorbing paper sheet, chroma-key source for transparent PNG
Input images: Image 1 is the approved ProjectCake food tongs sprite and style reference only, not an edit target
Primary request: create one clean rectangular sheet of food-safe oil-absorbing paper viewed from the same fixed near-top-down angle and matching Image 1. Warm off-white paper, slightly thick cartoon edge, gently rounded corners, one simple shallow crease and a few very faint broad absorbent-paper fibers. The full sheet is angled diagonally, mostly flat and fully visible with generous padding; clear silhouette when scaled down.
Style/medium: simple hand-drawn 2D cartoon, bold clean deep-brown outline matching Image 1, large flat color blocks, at most base plus one soft shadow tone and one highlight tone, minimal paper texture, crisp silhouette.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal. Background must be uniform with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Object constraints: exactly one separate paper sheet; no stack, box, dispenser, food, grease stain, sauce or printed pattern; fully separated from background; no cast shadow, contact shadow or reflection; do not use #00ff00 in the object; no hand, customer, griddle, counter, other tools, ingredients or UI.
Constraints: no text, letters, numbers, logo, brand or watermark; no photorealism, glossy 3D, thin outlines, painterly fibers, transparency, torn edges or cropped corners.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。

