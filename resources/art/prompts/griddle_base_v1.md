# griddle_base_v1 生成提示词与处理记录

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake independent griddle base game sprite for Sprite2D layering
Input images: Image 1 is the approved v8 visual/style and griddle-shape reference only; do not reproduce the surrounding stall
Primary request: create one isolated single dark iron jianbing griddle matching the approved v8 style and fixed near-top-down perspective. The griddle should have the same rounder near-top-down oval silhouette as v8, visually close to a circle but still slightly foreshortened vertically, with a thick clean deep-brown/dark-gray outer outline, a simple raised rim, charcoal cooking surface, one restrained highlight band and very subtle sparse iron grain.
Composition/framing: one griddle only, perfectly centered on a square or near-square canvas, occupying about 72 to 78 percent of the canvas width and about 58 to 66 percent of the canvas height, fully visible with generous padding on every side. Symmetrical horizontal alignment. No handles, legs, controls or attachments.
Style/medium: simple hand-drawn 2D cartoon game sprite, bold clean outline, large flat color shapes, at most base color plus one shadow and one highlight, minimal texture, crisp silhouette, same warm-grounded cartoon rendering as Image 1.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, color variation or lighting variation.
Separation constraints: keep the griddle fully separated from the background with crisp antialiased edges and generous padding. Do not use #00ff00 anywhere in the griddle. No cast shadow, no contact shadow, no reflection, no glow and no background-colored rim.
Content constraints: no countertop, workstation, bins, customer, UI, pancake, batter, sauce, food, smoke, steam, flame, utensils, text, letters, numbers, logo, brand or watermark. One opaque griddle base only.
```

## 本地透明处理

```text
remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
```

- 抠像键色：`#04f903`
- 透明像素：956538 / 1572516
- 半透明像素：3066 / 1572516
- 四角 alpha：0, 0, 0, 0
- 检测到的绿色边缘像素：0

