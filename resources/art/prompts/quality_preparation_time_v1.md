# quality_preparation_time_v1

## 用途

P1 评价界面的“制作时间”图标。以完整度徽章作为系列外框参考，只替换中心象形符号。

## 完整提示词

```text
Use case: precise game UI icon variant edit.
Input image: the approved ProjectCake circular quality badge reference.
Asset type: P1 quality metric icon, preparation time.
Primary request: preserve exactly the same outer circular badge, canvas size, placement, scale, cream face, orange-gold inner rim, bold dark-brown outer outline, matte flat style, and uniform magenta background. Replace only the central pictogram.
New center pictogram: remove the pancake disc and grain dots. Draw one large simple analog clock face centered inside the inner badge circle. The clock has a warm cream circular face, one bold dark-brown circumference, exactly four short orange-gold tick marks at top, right, bottom and left, and two thick dark-brown hands meeting at one small center hub. Set the longer hand pointing straight up and the shorter hand pointing diagonally toward the upper-right. No numbers. Add one small restrained orange motion arc outside the upper-right edge of the clock face to indicate timely completion without implying panic. Make it readable at 48 to 64 pixels.
Composition: exactly one centered opaque circular badge, same bounding box and alignment as input. No cast shadow, glow, bevel, ribbon, stopwatch buttons, bells, or additional decoration.
Style: approved ProjectCake V8 simple 2D cartoon UI, large flat color blocks, thick clean dark-brown lines, at most three value layers.
Background: preserve perfectly uniform chroma-key magenta RGB 255,0,255 edge to edge.
Must not include: pancake, ingredients, hourglass, numbers, letters, words, score, stars, check marks, X marks, arrows, faces, hands holding the clock, tools, extra icons, logo, brand, watermark, cropped badge.
Output: one clean chroma-key bitmap suitable for remove_chroma_key.py and same-position TextureRect swapping.
```

## 处理记录

使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。首稿通过，无需定向重生成。
