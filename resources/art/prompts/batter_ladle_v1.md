# batter_ladle_v1

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake movable gameplay tool sprite, batter ladle, chroma-key source for transparent PNG
Input images: Image 1 is the approved V8 style reference only, not an edit target
Primary request: create one sturdy Chinese street-food batter ladle viewed from the same fixed near-top-down angle as Image 1. A shallow round stainless-steel bowl with a long warm-brown wooden handle, simple practical proportions, clearly readable when scaled down. The handle points diagonally down-right and the bowl sits upper-left; show the complete object with generous padding.
Style/medium: exact V8 visual language—simple hand-drawn 2D cartoon, bold clean deep-brown outline, large flat color blocks, at most base plus one shadow and one highlight, minimal texture, crisp silhouette.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal. Background must be one uniform color with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Object constraints: one ladle only; fully separated from background; no batter inside bowl; no cast shadow, contact shadow or reflection; do not use #00ff00 anywhere in the object; no hand, customer, griddle, counter, other tools, ingredients or UI.
Constraints: no text, letters, numbers, logo, brand or watermark; no photorealism, glossy 3D, thin outlines, painterly detail or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。

