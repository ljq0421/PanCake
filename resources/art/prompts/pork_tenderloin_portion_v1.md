# pork_tenderloin_portion_v1 生成提示词

## 最终生成提示词

```text
Use case: game-asset
Asset type: ProjectCake P2 ingredient sprite, cooked pork-tenderloin source portion
Primary request: create one isolated compact serving portion of cooked Chinese pork tenderloin prepared for a jianbing stall. Show a small irregular stack of thick tenderloin strips with rounded organic ends and visible lean-meat grain, clearly recognizable as cooked pork rather than luncheon meat, sausage, bacon, or a rectangular processed block.
Style/medium: match the established ProjectCake 2D cartoon food assets—bold clean deep-brown outline, large flat color shapes, restrained detail, at most base color plus one shadow and one highlight, crisp mobile-game readability, friendly grounded street-food look.
Composition/framing: one centered compact portion, three-quarter near-top-down view, generous empty margin, complete silhouette, no crop, no plate, tray, bowl, utensil, garnish, sauce, steam, or cast shadow.
Color/material: warm terracotta-brown cooked exterior, lighter rose-tan lean interior on a few cut surfaces, matte and substantial, not glossy or raw.
Background: solid uniform vivid magenta chroma-key background #FF00FF, perfectly flat and untextured.
Constraints: organic tapered meat-strip shapes; no perfect rectangle, no canned-meat slab, no ham cylinder, no breading, bone, fat cap, text, letters, numbers, logo, watermark, hands, extra ingredients, photorealism, painterly texture, gradients, thin outlines, or baked floor shadow.
```

## 修正说明

首次结果过于方正，容易被误读为午餐肉；最终版本通过强调不规则圆钝端部、瘦肉纹理与禁止加工肉块重新生成。

## 处理

- 生成方式：Codex 内置 `image_gen`
- 去背方式：技能自带 `remove_chroma_key.py`
