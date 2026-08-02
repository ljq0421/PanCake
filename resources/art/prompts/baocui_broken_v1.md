# baocui_broken_v1

## 编辑提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake broken baocui ingredient-state sprite
Input images: Image 1 is the intact baocui edit target
Primary request: change the single intact cracker into exactly two large broken pieces from the same original rectangular sheet. Add one irregular diagonal fracture line and separate the two pieces by a small clear gap. Keep both pieces close together as one grouped gameplay sprite, preserve their combined overall scale and slight diagonal orientation, and show both completely with generous padding.
Absolute style invariants: preserve the same golden base color, two broad toasted patches, sparse shallow bubbles, bold clean deep-brown outline, flat 2D cartoon rendering and low detail from Image 1. Do not redesign the material.
Chroma invariant: preserve the perfectly flat solid #00ff00 background for local removal; no shadows, gradients, texture, reflections or floor plane; do not use #00ff00 in the cracker pieces.
Constraints: exactly two large pieces, no third piece, no tiny crumbs, no wrapper, plate, bowl, pancake, sauce, toppings, text, letters, numbers, logo, brand or watermark; no photorealism, burned black areas or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。

