# supplier_event_panel_base_v1

## 用途

P3 供应商事件弹窗空白底板。头像、事件文本和选项均由 Godot 动态渲染。

## 最终生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P3 supplier-event popup panel base, magenta chroma-key source
Input images: Image 1 is the current ProjectCake day-summary panel used only as border language, line weight, palette and flat rendering reference.
Primary request: create one blank supplier-event popup panel base with a strong horizontal layout. Thick rounded cream parchment body, deep-brown outline, warm brass corner fasteners and restrained faded-teal trim. Include one large blank portrait window on the left, one wide completely blank event-title plate at top right, one large blank description area below, and two equal blank choice-button recesses along the bottom right. Every content area must be empty and high contrast for Godot-rendered text and portraits.
Composition: one centered panel with generous padding and a clean rectangular silhouette; no baked shadow.
Style: exact ProjectCake V8 2D cartoon UI, bold deep-brown outlines, matte flat colors, one shadow and one highlight maximum, practical and readable.
Background: perfectly flat solid #ff00ff chroma-key edge to edge; no gradient, texture, floor or reflection; do not use #ff00ff in the panel.
Constraints: no characters, icons, food, coins, arrows, checkmarks, text, letters, numbers, currency signs, logo, brand, watermark, glow, cast shadow, photorealism, glossy 3D or painterly texture.
```

## 处理

- 使用技能自带 `remove_chroma_key.py` 抠图。
- 面板内部保持空白，不含 AI 文字。
