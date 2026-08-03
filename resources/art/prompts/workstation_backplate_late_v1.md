# workstation_backplate_late_v1

## 用途

P3 后期固定摊位候选底板。奖牌、收藏品和固定灯具表达长期成长，核心操作区域保持不变。

## 最终生成提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake P3 late-stage fixed-stall full rectangular backplate
Input images: Image 1 is the exact edit target and geometry reference.
Primary request: upgrade only fixed decorative architecture into a polished late-career version of the same street pancake stall, visibly more prestigious but still handmade and grounded. Preserve the cream-and-faded-teal awning and blank centered sign while adding a refined carved dark-teal and warm-brass counter trim, one small medal rail with three simple non-text medallions high on the rear wall, a tasteful blank framed recipe showcase, two small collectible figurines on narrow wall shelves, coordinated ceramic plant pots, and built-in warm bulb fixtures with bulbs unlit. Keep decorations sparse and readable.
Absolute geometry invariants: exact same canvas dimensions, camera, crop, rear counter boundary, long empty payment tray, exact twelve empty ingredient wells and their coordinates, central empty griddle mounting area, lower-left tool mat, holder recesses, heat-control plate, bottom utility structure, countertop edges and every interactive coordinate. Do not cover, move, resize, add, remove or redesign interactive areas.
Dynamic exclusions: no customer, patience bar, order card, griddle, pancake, ingredient, sauce portion, movable tool, payment, hand, particle, weather, glow, festival decoration or UI control.
Style: exact source style, simple hand-drawn 2D cartoon game art, bold clean deep-brown outlines, large matte flat color shapes, one shadow and one highlight maximum, warm cream, mustard, terracotta, faded teal, dark wood and restrained brass.
Output: full rectangular opaque image, same resolution and framing.
Constraints: every sign and frame completely blank; no readable text, letters, numbers, price, currency, brand, logo or watermark; no luxury palace look, photorealism, glossy 3D, painterly texture, camera drift, zoom or crop.
```

## 处理

- 生成方式：Codex 内置 `image_gen` 精确对象编辑。
- 编辑目标：`workstation_backplate_upgrade_v1.png`。
- 最终图未裁切、未缩放、未调色。
