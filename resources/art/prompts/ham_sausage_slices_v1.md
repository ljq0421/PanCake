# ham_sausage_slices_v1

## 编辑提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake sliced ham sausage ingredient-state sprite
Input images: Image 1 is the whole ham sausage edit target and material reference
Primary request: replace the single whole sausage with exactly five thick diagonal coin slices cut from that same sausage. Arrange the five slices as a loose compact fan with small overlaps, all fully visible. Each slice has a muted coral-pink circular cut face, a slightly darker curved side wall, and a bold deep-brown outline. Keep the group centered with generous padding and readable at gameplay scale.
Style invariants: preserve Image 1's simple flat 2D cartoon rendering, muted coral-pink cooked-meat color, large color blocks, low detail and restrained highlight.
Chroma invariant: preserve the perfectly flat solid #00ff00 background for local removal, no shadows, gradients, texture, reflections or floor plane; do not use #00ff00 in the slices.
Constraints: exactly five slices; no whole sausage, wrapper, label, brand, plate, bowl, skewer, sauce, garnish, grill marks, marbling, text, letters, numbers, logo, watermark or cropped slices.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。

