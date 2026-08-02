# baocui_intact_v1

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake movable ingredient sprite, intact jianbing baocui crispy cracker sheet, chroma-key source for transparent PNG
Input images: Image 1 is the approved ProjectCake cracked egg sprite and style reference only, not an edit target
Primary request: create one intact rectangular Chinese jianbing baocui fried cracker viewed from the fixed near-top-down gameplay angle. Thin golden rectangular sheet with gently irregular rounded corners, a small number of broad shallow fried bubbles and two or three simple darker toasted patches. Complete object angled slightly diagonally with generous padding, readable when scaled down and suitable for placing across a pancake.
Style/medium: simple hand-drawn 2D cartoon matching Image 1 and V8—bold clean deep-brown outline, large flat golden color blocks, at most base plus one toasted shadow and one soft highlight, minimal texture.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal. Background must be one uniform color with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Object constraints: exactly one intact cracker sheet; no broken pieces, wrapper, plate, bowl, pancake, sauce or toppings; fully separated from background; no cast shadow, contact shadow or reflection; do not use #00ff00 in the cracker.
Constraints: no text, letters, numbers, logo, brand or watermark; no photorealism, glossy 3D, thin outlines, dense pores, excessive bubbles, burned black patches or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。

