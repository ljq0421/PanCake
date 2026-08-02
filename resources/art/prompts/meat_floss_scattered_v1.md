# meat_floss_scattered_v1 生成提示词

## 最终生成提示词

```text
Use case: game-asset
Asset type: ProjectCake P2 ingredient interaction-state sprite, sprinkled meat floss
Primary request: create an isolated top-down scattering of exactly fourteen distinct small fluffy clumps of Chinese pork floss (rou song). The clumps must be visibly separate, irregular in size and spacing, and distributed across a broad roughly circular area so the sprite can show uneven sprinkling on a pancake.
Style/medium: match the established ProjectCake 2D cartoon food assets—bold clean deep-brown contour accents, large flat warm color shapes, minimal internal fiber marks, at most one shadow tone and one highlight tone, crisp readable silhouette at gameplay scale.
Composition/framing: exactly 14 separate clumps, no touching chain and no single merged mound; wide distribution with deliberate gaps; centered group with generous transparent-safe margin; near-top-down view; no crop and no cast shadow.
Color/material: warm toasted ochre and golden brown, dry matte fine fibers.
Background: solid uniform vivid magenta chroma-key background #FF00FF, flat and untextured.
Constraints: no thick noodles, shrimp shapes, meat chunks, container, utensil, pancake, plate, text, letters, numbers, brand, logo, watermark, hands, other ingredients, photorealism, 3D gloss, gradients, thin outlines, or baked ground shadow.
```

## 处理

- 生成方式：Codex 内置 `image_gen`
- 去背方式：技能自带 `remove_chroma_key.py`
- 设计用途：表达撒料后的空间分布，不代表运行时碰撞点或评分阈值
