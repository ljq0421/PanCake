# reputation_v1 生成提示词

## 最终生成提示词

```text
Use case: game-asset
Asset type: ProjectCake P2 economy UI icon, customer reputation
Primary request: create one compact circular golden badge containing a simple cream speech bubble with one coral-red heart inside. The icon must communicate customer goodwill and reputation without text.
Style/medium: match ProjectCake's simple hand-drawn 2D cartoon UI—bold clean deep-brown outlines, large flat shapes, at most one shadow and one highlight, warm restrained palette, high contrast and clear at 48 to 64 pixels.
Composition/framing: one centered badge only, complete silhouette, generous empty margin, no crop, no cast shadow and no surrounding UI panel.
Background: solid uniform vivid magenta chroma-key background #FF00FF, perfectly flat and untextured.
Constraints: one speech bubble and one heart only; no stars, rating numbers, thumbs-up, faces, crowns, medals, text, letters, currency symbols, logo, brand, watermark, photorealism, 3D gloss, gradients, thin outlines, or baked ground shadow.
```

## 处理

- 生成方式：Codex 内置 `image_gen`
- 去背方式：技能自带 `remove_chroma_key.py`
- 小尺寸检查：以 64px 实际预览复核
