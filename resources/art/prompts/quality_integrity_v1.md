# quality_integrity_v1

## 用途

P1 评价界面的“面饼完整度”图标。运行时数值、等级和颜色状态由 Godot 单独叠加。

## 完整提示词

```text
Use case: isolated game UI icon.
Asset type: ProjectCake P1 quality metric icon, pancake integrity.
Primary request: create one compact circular quality badge representing an intact, unbroken jianbing pancake. The badge has a warm cream circular face, a bold clean dark-brown outer outline, and one restrained orange-gold inner rim. Center pictogram: a simple top-down golden pancake disc with a clearly continuous unbroken dark-brown circumference and exactly three large subtle grain dots. The continuous intact rim is the meaning; do not use text or a check mark. Make the pictogram readable at 48 to 64 pixels.
Composition: exactly one centered opaque circular badge occupying about 55% of a square canvas, perfectly front-facing and symmetrical, with generous empty background around it. No cast shadow, glow, bevel, ribbon, or extra decoration.
Style: approved ProjectCake V8 simple 2D cartoon UI, thick dark-brown outlines, large flat color blocks, at most three value layers, warm matte street-stall palette, crisp silhouette.
Background: perfectly uniform solid chroma-key magenta RGB 255,0,255 edge to edge; no gradient, texture, vignette, checkerboard, or transparency.
Must not include: words, letters, numbers, score, stars, check marks, arrows, faces, hands, utensils, ingredients, fire, smoke, cracks, torn edge, additional icons, logo, brand, watermark, floor shadow, cropped badge.
Output: one clean chroma-key bitmap suitable for remove_chroma_key.py and Godot TextureRect use.
```

## 处理记录

使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。首稿通过，无需定向重生成。
