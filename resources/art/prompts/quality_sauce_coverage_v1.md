# quality_sauce_coverage_v1

## 用途

P1 评价界面的“酱料覆盖和浓度”图标。以完整度徽章作为系列外框参考，只替换中心象形符号。

## 完整提示词

```text
Use case: precise game UI icon variant edit.
Input image: the approved ProjectCake circular quality badge reference.
Asset type: P1 quality metric icon, sauce coverage and concentration.
Primary request: preserve exactly the same outer circular badge, canvas size, placement, scale, cream face, orange-gold inner rim, bold dark-brown outer outline, matte flat style, and uniform magenta background. Replace only the central pictogram.
New center pictogram: keep one simple top-down golden pancake disc with a continuous dark-brown circumference. Remove the three grain dots. Across the disc place exactly three broad smooth brick-red sauce brush bands, arranged horizontally from left to right and evenly spaced vertically. Each band should have soft rounded ends and nearly equal width, with small natural but simple waviness. The three evenly distributed sauce bands must communicate good sauce coverage without showing a brush or bottle. Keep the symbol large and readable at 48 to 64 pixels.
Composition: exactly one centered opaque circular badge, same bounding box and alignment as input. No cast shadow, glow, bevel, ribbon, drips outside the pancake, or additional decoration.
Style: approved ProjectCake V8 simple 2D cartoon UI, large flat color blocks, thick clean dark-brown lines, at most three value layers.
Background: preserve perfectly uniform chroma-key magenta RGB 255,0,255 edge to edge.
Must not include: grain dots, tools, brush, bottle, bowl, ingredients, flames, heat waves, words, letters, numbers, score, stars, check marks, arrows, faces, hands, extra icons, logo, brand, watermark, cropped badge.
Output: one clean chroma-key bitmap suitable for remove_chroma_key.py and same-position TextureRect swapping.
```

## 处理记录

使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。首稿通过，无需定向重生成。
