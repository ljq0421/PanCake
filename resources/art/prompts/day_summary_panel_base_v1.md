# day_summary_panel_base_v1 生成提示词

## 最终生成提示词

```text
Use case: game-asset
Asset type: ProjectCake P2 day-summary UI decorative panel base, text-free layered asset
Primary request: create one large centered end-of-day summary panel shell for a warm Chinese street-food management game. Include one blank top ribbon/title plate, exactly four empty circular metric wells in a single row, two clean empty mid-level content panels, and one wide empty bottom hint panel. Leave every information area blank so Godot can place localized text, numbers, icons, progress, and buttons dynamically.
Style/medium: match ProjectCake's simple hand-drawn 2D cartoon UI—bold clean deep-brown outlines, large flat warm-cream and mustard surfaces, terracotta and faded-teal accents, at most one shadow and one highlight, subtle paper-and-stall motif, crisp readable hierarchy, no glossy 3D.
Composition/framing: full 16:9 transparent canvas; the panel occupies the safe central area with balanced margins; complete uncropped silhouette; title ribbon at top, exactly four circular wells below, two content panels in the middle, one bottom hint panel; no baked button because button labels and interaction states belong in Godot.
Background: solid uniform vivid magenta chroma-key outside the panel, perfectly flat and untextured for transparent removal.
Constraints: all fields blank; no text, pseudo-text, letters, numbers, prices, currency symbols, stars inside the metric wells, icons, charts, logos, brands, watermark, customer, food, hands, photorealism, painterly texture, gradients, thin outlines, excessive decoration, or cast shadow touching the canvas edge.
```

## 处理

- 生成方式：Codex 内置 `image_gen`
- 去背方式：技能自带 `remove_chroma_key.py`
- UI 合同：标题、四项指标、两块明细、提示文字与按钮均由 Godot 动态渲染
