# workstation_backplate_upgrade_v1 生成提示词

## 最终生成提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake P2 fixed-stall upgraded-state full rectangular backplate
Input images: Image 1 is the current workstation_backplate_v1 and exact geometry reference
Primary request: create one visibly upgraded but still modest street-stall state by changing only fixed decorative architecture. Add a neat warm-cream and faded-teal striped awning across the upper stall band, one blank centered hanging signboard with no writing, two small blank decorative picture frames on the rear wall, cleaner teal-and-brass edge trim, and slightly healthier fixed plants. The upgrade should feel practical, welcoming, and earned rather than luxurious.
Absolute layout invariants: preserve the exact canvas dimensions, fixed near-top-down camera, crop, rear counter boundary, long empty payment tray, exact twelve empty ingredient wells, their positions and sizes, central empty griddle mounting area, lower-left tool mat, all holder recesses, heat-control base plate, bottom utility structure, countertop edges and interaction coordinates. Do not move, resize, add, remove, cover, or redesign any interactive area.
Dynamic-layer exclusions: no customer, patience bar, order card, griddle, pancake, ingredient, sauce portion, movable tool, payment, coin, banknote, hand, particle, UI button or baked object shadow.
Style/medium: match the source exactly—simple hand-drawn 2D cartoon game art, bold clean deep-brown outlines, large flat color shapes, at most one shadow and one highlight, warm cream/mustard/terracotta/faded-teal palette, minimal texture.
Output: full rectangular opaque image at exactly the same resolution and framing as the input.
Constraints: all signs and frames completely blank; no readable text, letters, numbers, price, currency symbols, brands, logos, watermark, magical effects, photorealism, glossy 3D, painterly rendering, thin outlines, camera drift, zoom, crop, or new workstation equipment.
```

## 处理

- 生成方式：Codex 内置 `image_gen` 精确对象编辑
- 后处理：无裁切、无缩放、无调色、无透明处理
- 结构约束：最终图必须与基础背板尺寸完全相同；运行时交互坐标仍以场景节点为准
