# upgrade_v1 生成提示词

## 最终生成提示词

```text
Use case: game-asset
Asset type: ProjectCake P2 economy UI icon, stall upgrade
Primary request: create one compact circular golden badge containing a simple faded-teal wrench crossed visually with one clear orange upward arrow. The icon must read immediately as equipment or stall upgrade without text.
Style/medium: match ProjectCake's simple hand-drawn 2D cartoon UI—bold clean deep-brown outlines, large flat shapes, at most one shadow and one highlight, warm restrained palette, crisp high contrast at 48 to 64 pixels.
Composition/framing: one centered badge only, complete silhouette, generous empty margin, no crop, no cast shadow and no surrounding UI panel.
Background: solid uniform vivid magenta chroma-key background #FF00FF, perfectly flat and untextured.
Constraints: one wrench and one upward arrow; no hammer, gear cluster, construction scene, text, letters, numbers, currency symbols, logo, brand, watermark, photorealism, glossy 3D, gradients, thin outlines, or baked ground shadow.
```

## 处理

- 生成方式：Codex 内置 `image_gen`
- 去背方式：技能自带 `remove_chroma_key.py`
- 小尺寸检查：以 64px 实际预览复核
