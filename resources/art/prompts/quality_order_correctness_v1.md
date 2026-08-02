# quality_order_correctness_v1

## 用途

P1 评价界面的“订单正确性”图标。以完整度徽章作为系列外框参考，用相同配料序列表达订单与成品匹配。

## 完整提示词

```text
Use case: precise game UI icon variant edit.
Input image: the approved ProjectCake circular quality badge reference.
Asset type: P1 quality metric icon, order correctness / order-to-food match.
Primary request: preserve exactly the same outer circular badge, canvas size, placement, scale, cream face, orange-gold inner rim, bold dark-brown outer outline, matte flat style, and uniform magenta background. Replace only the central pictogram.
New center pictogram: remove the round pancake disc and grain dots. Draw two simple side-by-side objects fully inside the inner badge circle. On the left, one small upright warm-cream order card with a dark-brown rounded outline and exactly three large colored circular ingredient dots arranged vertically: green, coral-red, green. On the right, one small golden top-down pancake disc with a dark-brown circumference and the exact same three colored ingredient dots in the same vertical order: green, coral-red, green. Place one short dark-brown horizontal connector line between the card and pancake. The repeated ingredient pattern must communicate that the finished pancake matches the order. Make all elements large and readable at 48 to 64 pixels.
Composition: exactly one centered opaque circular badge, same bounding box and alignment as input. No cast shadow, glow, bevel, ribbon, or additional decoration.
Style: approved ProjectCake V8 simple 2D cartoon UI, large flat color blocks, thick clean dark-brown lines, at most three value layers.
Background: preserve perfectly uniform chroma-key magenta RGB 255,0,255 edge to edge.
Must not include: words, letters, numbers, score, stars, check marks, X marks, equals sign, arrows, hands, tools, extra ingredient dots, sauce, heat waves, faces, extra icons, logo, brand, watermark, cropped badge.
Output: one clean chroma-key bitmap suitable for remove_chroma_key.py and same-position TextureRect swapping.
```

## 处理记录

使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。首稿通过，无需定向重生成。
