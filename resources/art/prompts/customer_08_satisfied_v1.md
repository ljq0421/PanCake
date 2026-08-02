# customer_08_satisfied_v1

## 用途

P1 第八名顾客的满意半身 `Sprite2D` 状态。直接从已确认的中性品红源独立编辑，只改变眉形、眼睑和嘴型；人物身份、服装、完整头发、尺寸和锚点保持锁定。

## 完整提示词

```text
Use case: identity-preserve
Asset type: ProjectCake customer_08 satisfied half-body gameplay Sprite2D expression state.

Input images:
- Image 1 is the approved customer_08 neutral magenta chroma-key source and the sole edit target and identity anchor.

Primary request:
Change ONLY the facial expression from neutral to clearly but calmly satisfied after receiving the correct order. Use gently relaxed slightly lifted brows, softly closed upward-curving eyes, and a modest warm closed-mouth smile that is wider than the neutral smile. The expression should read as sincere everyday satisfaction and relief, not laughter, excitement, surprise, flirtation, sleepiness, or exaggerated joy.

Absolute identity invariants:
Preserve the exact same young adult male identity, narrow softly angular face, warm light skin, nose shape, ear shapes, slim build, long neck, pale honey-blond straight shoulder-length hair, center part, hair-tip shapes, both visible ears, charcoal-gray short-sleeve Henley shirt, camel neckline and placket, exactly two dark buttons, russet-brown trousers, hands, fingers, pose, proportions, colors, outlines, shading, and V8 finish. Do not change age, hairstyle, hair length, hair part, clothing, body silhouette, skin tone, or hand pose.

Composition and alignment invariants:
Preserve the exact 1536x1024 canvas, original character scale, horizontal position, full silhouette, and lower anchor. Keep the visible boundary as close as possible to the neutral source boundary x=556..958 and y=84..967. Preserve every hair tip, both ears, both shoulders, both complete forearms, both complete hands and fingertips, and the complete lower trouser edge. No cropping or independent resizing of the head, face, torso, arms, or clothing.

Style invariants:
Preserve the approved ProjectCake V8 clean 2D cartoon treatment: bold deep-brown outer contour, smooth internal linework, simple large matte color blocks, and no more than about three value levels per material. Keep the existing clean surface treatment and do not add texture, pores, fabric grain, hair strands, wrinkles, blush, eye bags, tears, sparkles, or new facial lines.

Scene/backdrop:
Preserve a perfectly flat uniform solid #ff00ff chroma-key background edge to edge, including all four corners. No shadow, gradient, texture, floor, reflection, glow, halo, vignette, or lighting variation. Do not introduce magenta, pink, or purple into the character.

Do not add:
No raised arms, clasped hands, thumbs-up, pose change, head tilt, teeth, open mouth, tongue, wink, rosy cheeks, tears, hearts, stars, sparkle, comic symbol, motion mark, speech bubble, prop, counter, workstation, griddle, order card, patience bar, payment item, food, tool, UI, text, letter, number, logo, brand, watermark, cast shadow, contact shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One identity-locked customer_08 satisfied magenta chroma-key source suitable for remove_chroma_key.py and exact Sprite2D state swapping with the approved neutral asset.
```

## 处理记录

源图：`tmp/imagegen/customers_v8/customer_08_satisfied_v1_chromakey.png`

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

最终图未在本地裁切、缩放或调色。
