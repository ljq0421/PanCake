# meat_floss_pile_v1 生成提示词

## 最终生成提示词

```text
Use case: game-asset
Asset type: ProjectCake P2 ingredient sprite, compact meat-floss source portion
Primary request: create one isolated small loose mound of Chinese pork floss (rou song), clearly recognizable as very fine dry fluffy fibers rather than noodles, shrimp, shredded vegetables, or thick meat strips. The mound should feel light, airy, irregular, and easy to pinch and sprinkle.
Style/medium: match the established ProjectCake 2D cartoon food assets—bold clean deep-brown outline around the overall silhouette, large flat warm color shapes, restrained inner detail, at most one simple shadow and one highlight, crisp mobile-game readability, not painterly and not 3D.
Composition/framing: one centered mound only, three-quarter near-top-down view consistent with the workstation, generous empty margin on every side, no crop, no container, no utensil, no cast shadow.
Color/material: warm toasted ochre, light golden brown and a small amount of darker brown fiber separation; dry matte surface, no gloss, no sauce.
Background: solid uniform vivid magenta chroma-key background #FF00FF, perfectly flat and untextured.
Constraints: extremely fine short fibers and soft wispy edges; no thick rope-like strands, no rectangular slices, no whole meat, no plate, bowl, tray, label, text, letters, numbers, logo, watermark, hands, extra ingredients, photorealism, gradients, thin outlines, or baked floor shadow.
```

## 修正说明

首次结果的丝状结构过粗，容易被误读为虾仁或粗面条；最终版本通过强调 `very fine dry fluffy fibers`、`light airy mound` 与禁止 `thick rope-like strands` 重新生成。

## 处理

- 生成方式：Codex 内置 `image_gen`
- 去背方式：技能自带 `remove_chroma_key.py`，使用边缘自动取色、软遮罩与去溢色
- UI 文字：不写入图片，由 Godot 单独排版
