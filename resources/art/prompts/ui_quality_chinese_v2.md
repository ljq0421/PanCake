# 新中国风质量结果图标 v2

生成日期：2026-08-11

## 共用提示词

```text
Use case: precise-object-edit
Asset type: Godot quality-result icon displayed at 72 x 72 logical pixels.
Input image: edit target and semantic reference.
Style/medium: a consistent refined modern Chinese watercolor UI medallion matching the approved order card: warm rice-paper round seal, thin ink-brown outline, dry-brush pigment grain, restrained soft gray-brown edge shadow, matte and crisp at 72 pixels.
Composition/framing: one centered circular medallion and one bold simple symbol; generous even padding; front-facing.
Constraints: preserve only the named metric meaning; no text, numbers, characters, logos, watermark, glossy plastic, chrome, bright metallic gold, thick black cartoon outline, extra objects, or cast shadow outside the medallion.
Transparency workflow: isolate the medallion on a perfectly flat solid #ff00ff chroma-key background. The background must be one uniform color with no shadows, gradients, texture, reflections, or floor plane. Do not use #ff00ff anywhere in the icon.
```

## 各指标追加提示词

- `quality_integrity_v2_chinese_ui.png`: perfectly unbroken round pancake silhouette inside a continuous unbroken ink ring, three tiny evenly spaced toasted freckles, no check mark and no cracks; ivory, ochre and walnut with a stone-blue outer accent.
- `quality_thickness_uniformity_v2_chinese_ui.png`: side-profile cross-section with three horizontal layers of exactly equal thickness and two short matching measurement ticks; ivory, ochre and burnt sienna with stone-blue measurement marks.
- `quality_heat_uniformity_v2_chinese_ui.png`: round pancake with exactly three equal vermilion rising heat strokes and an evenly warm center, no flame; ivory, gamboge, rouge and burnt sienna.
- `quality_egg_spread_v2_chinese_ui.png`: centered small gamboge yolk with symmetrical pale egg wash radiating evenly to the edge, balanced rather than a fried egg; ivory, gamboge and ochre with a stone-blue rim.
- `quality_sauce_coverage_v2_chinese_ui.png`: exactly three broad, evenly spaced horizontal dry-brush sauce strokes covering a round pancake; ivory, rouge and burnt sienna.
- `quality_ingredient_distribution_v2_chinese_ui.png`: six topping marks in a balanced radial pattern, three malachite scallion rings and three rouge dots; ivory, malachite, rouge, gamboge and walnut.
- `quality_fold_stability_v2_chinese_ui.png`: neat symmetrical three-panel folded pancake parcel with aligned seams, no loose corners, firmly closed; ivory, ochre and walnut with stone-blue side accents.
- `quality_order_correctness_v2_chinese_ui.png`: small rice-paper order slip with three colored seal dots beside a round dish carrying the same three dots in the same order, joined by a thin line; no text and no check mark; ivory, stone blue, malachite, rouge and walnut.
- `quality_preparation_time_v2_chinese_ui.png`: simple round clock with two bold hands and four minimal ticks; ivory, stone-blue rim, gamboge ticks and walnut hands.

## 透明处理

所有候选均先以纯色键背景生成，再由 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 安全去键。最终文件为 RGBA，四角 alpha 为 0，并保留半透明抗锯齿边缘。原 `quality_*_v1.png` 文件全部保留。
