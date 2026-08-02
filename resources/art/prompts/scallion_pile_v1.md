# scallion_pile_v1

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake movable ingredient portion sprite, chopped scallion pile, magenta chroma-key source for transparent PNG
Input images: Image 1 is the approved ProjectCake ham sausage slices sprite and style reference only, not an edit target
Primary request: create one compact portion of freshly chopped scallion rings viewed straight from the fixed near-top-down gameplay angle. About twelve to sixteen chunky green onion rings and short curved pieces gathered into a loose small pile, using two greens plus pale centers. Keep individual pieces large and readable rather than dense confetti, with the full pile centered and generous padding.
Style/medium: simple hand-drawn 2D cartoon matching Image 1 and V8—bold clean deep-brown outlines around the overall pieces, large flat color blocks, at most dark green, mid green and pale center, minimal texture.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background for local removal. Background must be one uniform color with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Object constraints: one grouped scallion portion only; no bowl, tray, knife, cutting board, other vegetables, sauce, pancake or garnish beyond the scallion pieces; fully separated from background; no cast shadow, contact shadow or reflection; do not use #ff00ff anywhere in the scallions.
Constraints: no text, letters, numbers, logo, brand or watermark; no photorealism, thin outlines, tiny dense particles, wet gloss, face, decoration or cropped pieces.
```

## 透明处理

葱花主体为绿色，因此使用品红抠像背景。使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。

