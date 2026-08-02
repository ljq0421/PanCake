# scallion_scattered_v1

## 撒开状态提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake scattered scallion ingredient-state sprite
Input images: Image 1 is the compact chopped scallion pile edit target
Primary request: rearrange the same scallion material into exactly twelve large chopped rings and short curved pieces scattered loosely across a wider horizontal oval area. Leave clear gaps between most pieces with only two small overlaps, so the asset reads as scallions sprinkled over a pancake rather than a tray pile. Keep all pieces fully visible and centered with generous padding.
Style invariants: preserve Image 1's two green tones, pale centers, bold clean deep-brown outlines, flat 2D cartoon rendering, chunky readable piece size and minimal texture.
Chroma invariant: preserve the perfectly flat solid #ff00ff background for local removal; no shadows, gradients, texture, reflections or floor plane; do not use #ff00ff in the scallions.
Constraints: exactly twelve pieces; no dense confetti, tiny particles, bowl, tray, knife, cutting board, other vegetables, sauce, pancake, text, letters, numbers, logo, brand, watermark or cropped pieces.
```

## 数量修正提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake scattered scallion sprite count correction
Input images: Image 1 is the scattered scallion edit target
Primary request: remove exactly one piece only: delete the small dark-green scallion piece partially hidden directly behind the pale-yellow ring near the upper center. Fill that removed area with the same perfectly flat #ff00ff chroma-key background. The final image must contain exactly twelve scallion pieces.
Absolute invariants: preserve every other scallion piece exactly in its current position, orientation, size, shape, colors, outline and overlap; preserve the same wide scattered composition and generous padding; do not move, add, duplicate or redesign anything else.
Background invariant: keep the entire background perfectly flat solid #ff00ff with no shadows, gradients, texture, reflections or floor plane.
Constraints: no bowl, tray, knife, cutting board, other vegetables, sauce, pancake, text, letters, numbers, logo, brand, watermark or cropped pieces.
```

## 透明处理

葱花主体为绿色，因此使用品红抠像背景。使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。

