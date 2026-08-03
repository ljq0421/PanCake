# workstation_backplate_mid_v1

## 用途

P3 中期固定摊位候选底板。只升级固定装饰，不改变 12 个配料槽、中央鏊子安装区或底部控制区的交互坐标。

## 最终生成提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake P3 mid-stage fixed-stall full rectangular backplate
Input images: Image 1 is the exact edit target and geometry reference.
Primary request: upgrade only the fixed decorative architecture into a clearly established mid-career street pancake stall. Keep the existing cream-and-faded-teal awning, blank centered sign, two blank wall frames, twelve empty ingredient wells, payment tray and all counter geometry. Improve the stall with neat dark-teal painted wood trim, warm brass corner fasteners, a tidy row of small blank customer-photo clips below one wall frame, a compact folded menu-board holder with a completely blank face placed only in unused rear-wall space, and slightly more mature potted plants. Practical, welcoming, earned, not luxurious.
Absolute geometry invariants: exact same canvas dimensions, camera, crop, rear counter boundary, long empty payment tray, exact twelve empty ingredient wells and their coordinates, central empty griddle mounting area, lower-left tool mat, holder recesses, heat-control plate, bottom utility structure, countertop edges and every interactive coordinate. Do not cover, move, resize, add, remove or redesign interactive areas.
Dynamic exclusions: no customer, patience bar, order card, griddle, pancake, ingredient, sauce portion, movable tool, payment, hand, particle or UI control.
Style: exact source style, simple hand-drawn 2D cartoon game art, bold clean deep-brown outlines, large matte flat color shapes, one shadow and one highlight maximum, warm cream, mustard, terracotta, faded teal and dark wood.
Output: full rectangular opaque image, same resolution and framing.
Constraints: every sign, frame, clip card and menu face completely blank; no readable text, letters, numbers, price, currency, brand, logo or watermark; no photorealism, glossy 3D, painterly texture, camera drift, zoom or crop.
```

## 处理

- 生成方式：Codex 内置 `image_gen` 精确对象编辑。
- 编辑目标：`workstation_backplate_upgrade_v1.png`。
- 最终图未裁切、未缩放、未调色。
