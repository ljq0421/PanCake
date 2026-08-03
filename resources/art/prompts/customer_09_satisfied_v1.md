# customer_09_satisfied_v1

## 用途

P1 第九名顾客的满意半身 `Sprite2D` 状态。直接从已确认的中性绿幕源独立编辑，只改变眉形、眼睑和嘴型；身份、肤色、侧辫、服装、完整轮廓、尺寸和锚点保持锁定。

## 完整提示词

```text
Use case: identity-preserve
Asset type: ProjectCake customer_09 satisfied half-body gameplay Sprite2D expression state.

Input images:
- Image 1 is the approved customer_09 neutral green chroma-key source and the sole edit target and identity anchor.

Primary request:
Change ONLY the facial expression from neutral to clearly but calmly satisfied after receiving the correct order. Use gently relaxed slightly lifted brows, softly closed upward-curving eyes, and a modest warm closed-mouth smile that is wider than the neutral smile. The expression should read as sincere everyday satisfaction and relief, not laughter, excitement, surprise, flirtation, sleepiness, or exaggerated joy.

Absolute identity invariants:
Preserve the exact same adult woman identity, deep warm brown skin, softly heart-shaped face, defined jaw, high cheekbones, broad nose, ear shapes, balanced medium build, blue-black sleek off-center-parted hair, both exposed ears, exact long thick side braid and braid tip, coral-orange short-sleeve mandarin-collar wrap-seam blouse, deep indigo short lower garment with its complete gently rounded edge, hands, fingers, pose, proportions, colors, outlines, shading, and V8 finish. Do not change age, skin tone, hairstyle, braid placement, braid length, clothing, body silhouette, or hand pose.

Composition and alignment invariants:
Preserve the exact 1536x1024 canvas, original character scale, horizontal position, full silhouette, and lower anchor. Keep the visible boundary as close as possible to the neutral source boundary x=540..978 and y=75..958. Preserve every hair edge, full braid and tip, both complete ears, both shoulders, both complete forearms, both complete hands and fingertips, and the finished lower garment edge. No cropping or independent resizing of the head, face, torso, arms, braid, or clothing. Preserve the green padding below the complete lower edge.

Style invariants:
Preserve the approved ProjectCake V8 clean 2D cartoon treatment: bold deep-brown outer contour, smooth simple internal linework, large matte color blocks, and no more than about three value levels per material. Keep skin and fabric clean; do not add pores, blush, eye bags, wrinkles, tears, sparkles, grain, speckles, fabric texture, glossy highlights, or new facial lines.

Scene/backdrop:
Preserve a perfectly flat uniform solid #00ff00 chroma-key green background edge to edge, including all four corners and the full strip below the character. No shadow, gradient, texture, floor, reflection, glow, halo, vignette, or lighting variation. Do not introduce green into the character.

Do not add:
No raised arms, clasped hands, thumbs-up, pose change, head tilt, teeth, open mouth, tongue, wink, rosy cheeks, tears, hearts, stars, sparkle, comic symbol, motion mark, speech bubble, prop, counter, workstation, griddle, order card, patience bar, payment item, food, tool, UI, text, letter, number, logo, brand, watermark, cast shadow, contact shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One identity-locked customer_09 satisfied green chroma-key source suitable for remove_chroma_key.py and exact Sprite2D state swapping with the approved neutral asset.
```

## 处理记录

源图：`tmp/imagegen/customers_v9/customer_09_satisfied_v1_chromakey.png`

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

最终图未在本地裁切、缩放或调色。
