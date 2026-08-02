# quality_ingredient_distribution_v1

## 用途

P1 评价界面的“配料分布”图标。以完整度徽章作为系列外框参考，只替换中心象形符号。

## 完整提示词

```text
Use case: precise game UI icon variant edit.
Input image: the approved ProjectCake circular quality badge reference.
Asset type: P1 quality metric icon, ingredient distribution.
Primary request: preserve exactly the same outer circular badge, canvas size, placement, scale, cream face, orange-gold inner rim, bold dark-brown outer outline, matte flat style, and uniform magenta background. Replace only the central pictogram.
New center pictogram: keep one simple top-down golden pancake disc with a continuous dark-brown circumference. Remove the original three grain dots. Inside the disc place exactly six small flat ingredient pieces, evenly distributed with clear space between all pieces and no cluster. Use three simple green scallion-ring pieces and three small coral-red sausage-round pieces, alternating around the disc in a balanced pattern. Every piece should be a large simplified symbol with a dark-brown outline, readable at 48 to 64 pixels. The even spacing must communicate good ingredient distribution.
Composition: exactly one centered opaque circular badge, same bounding box and alignment as input. No cast shadow, glow, bevel, ribbon, or additional decoration.
Style: approved ProjectCake V8 simple 2D cartoon UI, large flat color blocks, thick clean dark-brown lines, at most three value layers.
Background: preserve perfectly uniform chroma-key magenta RGB 255,0,255 edge to edge.
Must not include: extra ingredient pieces, ingredient pile, overlapping pieces, sauce bands, heat waves, tools, bowl, words, letters, numbers, score, stars, check marks, arrows, faces, hands, logo, brand, watermark, cropped badge.
Output: one clean chroma-key bitmap suitable for remove_chroma_key.py and same-position TextureRect swapping.
```

## 处理记录

使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。首稿通过，无需定向重生成。
