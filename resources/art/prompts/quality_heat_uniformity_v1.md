# quality_heat_uniformity_v1

## 用途

P1 评价界面的“火候均匀度”图标。以完整度徽章作为系列外框参考，只替换中心象形符号。

## 完整提示词

```text
Use case: precise game UI icon variant edit.
Input image: the approved ProjectCake circular quality badge reference.
Asset type: P1 quality metric icon, heat/cooking uniformity.
Primary request: preserve exactly the same outer circular badge, canvas size, placement, scale, cream face, orange-gold inner rim, bold dark-brown outer outline, matte flat style, and uniform magenta background. Replace only the central pictogram.
New center pictogram: keep one simple top-down golden pancake disc with a continuous dark-brown circumference. Remove the three grain dots. Inside the disc place exactly three identical short orange-red heat-wave marks, evenly spaced horizontally, each made of one clean vertical S-shaped stroke of equal height and equal thickness. The three equal heat waves across one intact pancake must communicate evenly distributed cooking heat. Keep the symbol large and readable at 48 to 64 pixels.
Composition: exactly one centered opaque circular badge, same bounding box and alignment as input. No cast shadow, glow, bevel, ribbon, or additional decoration.
Style: approved ProjectCake V8 simple 2D cartoon UI, large flat color blocks, thick clean dark-brown lines, at most three value layers.
Background: preserve perfectly uniform chroma-key magenta RGB 255,0,255 edge to edge.
Must not include: grain dots, flames, fire, smoke cloud, thermometer, numbers, letters, words, score, stars, check marks, arrows, faces, hands, tools, ingredients, extra icons, logo, brand, watermark, cropped badge.
Output: one clean chroma-key bitmap suitable for remove_chroma_key.py and same-position TextureRect swapping.
```

## 处理记录

使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。首稿通过，无需定向重生成。
