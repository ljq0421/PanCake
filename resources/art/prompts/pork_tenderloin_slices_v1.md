# pork_tenderloin_slices_v1 生成提示词

## 最终生成提示词

```text
Use case: game-asset
Asset type: ProjectCake P2 ingredient interaction-state sprite, placed pork tenderloin strips
Primary request: create exactly three isolated thick cooked pork-tenderloin strips arranged as a loose overlapping serving. Each strip must look weighty and substantial, with rounded irregular ends and a small visible lighter lean-meat cut face, suitable for communicating that the topping can bulge or stress a thin folded pancake.
Style/medium: match the established ProjectCake 2D cartoon food assets—bold clean deep-brown outlines, large flat warm color shapes, minimal meat-grain detail, at most one shadow and one highlight, crisp readable gameplay silhouette.
Composition/framing: exactly 3 strips, all fully visible, loose diagonal fan arrangement with modest overlap, near-top-down view, centered group, generous empty margin, no crop, no plate, container, utensil, pancake, sauce, garnish, steam, or cast shadow.
Color/material: terracotta-brown cooked exterior with restrained rose-tan interior, matte rather than glossy.
Background: solid uniform vivid magenta chroma-key background #FF00FF, flat and untextured.
Constraints: no rectangular luncheon meat, sausage coins, bacon, raw meat, breading, bones, text, letters, numbers, brand, logo, watermark, hands, other ingredients, photorealism, 3D gloss, gradients, thin outlines, or baked ground shadow.
```

## 处理

- 生成方式：Codex 内置 `image_gen`
- 去背方式：技能自带 `remove_chroma_key.py`
- 设计用途：表达“厚重、容易造成折叠鼓包”的状态，不直接编码失败判定
