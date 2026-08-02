# quality_egg_spread_v1

## 用途

P1 评价界面的摊蛋均匀度图标。该维度由当前 `PancakeScorer` 独立评分并占总分 8%；运行时分数和状态色由 Godot 叠加。

## 完整提示词

```text
Use case: stylized-concept
Asset type: ProjectCake game UI quality score icon, independent egg-spreading dimension
Input images: Image 1 is the mandatory style and badge-geometry reference only; do not copy its center symbol
Primary request: Create one centered circular badge icon for “egg spread uniformity”. Preserve the same thick dark-brown outer outline, warm cream ring, golden-yellow flat-color palette, simple chunky 2D cartoon rendering, proportions, padding, and near-top-down visual language as Image 1. Replace only the center pictogram with a clearly spread egg layer: a broad pale-cream egg-white shape covering most of a small golden pancake disc, a flattened orange-yellow yolk at the center, and three short evenly spaced dark-brown radial smear marks that communicate uniform spreading. The pictogram must remain recognizable at 48–64 px.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background for local background removal
Composition/framing: single centered icon, symmetric visual weight, generous padding, complete silhouette, no cropping
Style/medium: simplified large color blocks, thick clean outlines, minimal layers, no painterly detail, no realistic texture
Constraints: background must be one uniform #ff00ff color with no shadows, gradients, texture, reflections, floor plane, or lighting variation; crisp opaque icon edges; no cast shadow; no contact shadow; do not use #ff00ff anywhere in the icon; no text; no letters; no numbers; no logo; no brand; no watermark
Avoid: fried crispy egg, eggshell, whole unspread egg, utensils, ingredients other than egg, thin lines, tiny details, photorealism, 3D rendering, glossy plastic
```

## 处理记录

- 生成方式：Codex 内置 `image_gen`，以 `quality_integrity_v1.png` 作为徽章风格与几何参考。
- 透明处理：`remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。
- 首稿通过，无需定向重生成。
