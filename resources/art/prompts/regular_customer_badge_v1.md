# regular_customer_badge_v1

## 用途

P3 熟客独立胸章附件；不烘焙进人物，可由 Godot 控制显示与位置。

## 最终生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P3 familiar-customer independent lapel-badge attachment, magenta chroma-key source
Primary request: one small round loyalty lapel badge viewed straight-on, designed as an independent Sprite2D attachment. Warm brass outer rim, faded-teal enamel center, simple non-text pancake spiral with one tiny steam curl, deep-brown bold outline. Opaque clean shape only.
Style: exact ProjectCake V8 simple hand-drawn 2D cartoon, large matte flat color blocks, one shadow and one highlight maximum, crisp readable silhouette at 48 pixels.
Composition: single centered badge, generous padding, perfectly front-facing, no perspective, no pin backing visible.
Background: perfectly flat solid #ff00ff chroma-key edge to edge, no gradient, shadow, floor, texture or reflection; do not use #ff00ff in the badge.
Constraints: no letters, numbers, rating stars, logo, brand, watermark, character, clothing, hand, food realism, glow, cast shadow, glossy 3D, thin outlines or extra objects.
```

## 处理

- 使用技能自带 `remove_chroma_key.py` 抠图。
- 未裁切，保留 1254×1254 方形附件画布。
