# quality_thickness_uniformity_v1

## 用途

P1 评价界面的“厚度均匀度”图标。以完整度徽章作为系列外框参考，只替换中心象形符号。

## 完整提示词

```text
Use case: precise game UI icon variant edit.
Input image: the approved ProjectCake circular quality badge reference.
Asset type: P1 quality metric icon, thickness uniformity.
Primary request: preserve exactly the same outer circular badge, canvas size, placement, scale, cream face, orange-gold inner rim, bold dark-brown outer outline, matte flat style, and pure magenta background. Replace only the central intact-pancake pictogram.
New center pictogram: a simple side-view horizontal golden pancake strip with a perfectly constant height from left edge to right edge, outlined in dark brown. Place exactly three short dark-brown vertical measurement ticks underneath it, all identical height and evenly spaced. Add one thin straight dark-brown horizontal guide line below the ticks. The flat strip and equal ticks must clearly communicate even, uniform thickness. Keep the symbol large and readable at 48 to 64 pixels. Do not include numbers, letters, rulers, arrows, check marks, or perspective.
Composition: exactly one centered opaque circular badge, same bounding box and alignment as input. No shadow, glow, bevel, ribbon, or additional decoration.
Style: approved ProjectCake V8 simple 2D cartoon UI, large flat color blocks, thick clean dark-brown lines, at most three value layers.
Background: preserve perfectly uniform chroma-key magenta RGB 255,0,255 edge to edge.
Must not include: the previous pancake disc and grain dots, words, score, stars, faces, hands, tools, ingredients, fire, smoke, extra icons, logo, brand, watermark, cropped badge.
Output: one clean chroma-key bitmap suitable for remove_chroma_key.py and same-position TextureRect swapping.
```

## 处理记录

使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。首稿通过，无需定向重生成。
