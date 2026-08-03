# customer_09_impatient_v1

## 用途

P1 第九名顾客的不耐烦半身 `Sprite2D` 状态。直接从已确认的中性绿幕源独立编辑，只改变眉形、眼睑和嘴型；身份、肤色、侧辫、服装、完整轮廓、尺寸和锚点保持锁定。

## 初始完整提示词

```text
Use case: identity-preserve
Asset type: ProjectCake customer_09 impatient half-body gameplay Sprite2D expression state.

Input images:
- Image 1 is the approved customer_09 neutral green chroma-key source and the sole edit target and identity anchor.

Primary request:
Change ONLY the facial expression from neutral to mildly impatient while waiting. Use subtly lowered and slightly inward-angled brows, slightly narrowed forward-looking eyes with gently lowered upper eyelids, and a small closed mouth that is nearly flat with only a shallow downward curve. Keep the expression controlled and everyday, not angry, hostile, sad, exhausted, disgusted, or enraged.

Absolute identity invariants:
Preserve the exact same adult woman identity, deep warm brown skin, softly heart-shaped face, defined jaw, high cheekbones, broad nose, ear shapes, dark brown eye color, black brows, blue-black sleek off-center-parted hair, both exposed ears, exact long thick side braid and braid tip, balanced medium build, coral-orange short-sleeve mandarin-collar wrap-seam blouse, deep indigo short lower garment with its complete gently rounded edge, hands, fingers, pose, proportions, colors, outlines, shading, and V8 finish. Do not change age, skin tone, hairstyle, braid placement, braid length, clothing, body silhouette, or hand pose.

Composition and alignment invariants:
Preserve the exact 1536x1024 canvas, original character scale, horizontal position, full silhouette, and lower anchor. Keep the visible boundary as close as possible to the neutral source boundary x=540..978 and y=75..958. Preserve every hair edge, full braid and tip, both complete ears, both shoulders, both complete forearms, both complete hands and fingertips, and the finished lower garment edge. No cropping or independent resizing of the head, face, torso, arms, braid, or clothing. Preserve the green padding below the complete lower edge.

Style invariants:
Preserve the approved ProjectCake V8 clean 2D cartoon treatment: bold deep-brown outer contour, smooth simple internal linework, large matte color blocks, and no more than about three value levels per material. Keep skin and fabric clean; do not add pores, blush, eye bags, forehead creases, wrinkles, sweat, tears, grain, speckles, fabric texture, glossy highlights, or new facial lines.

Scene/backdrop:
Preserve a perfectly flat uniform solid #00ff00 chroma-key green background edge to edge, including all four corners and the full strip below the character. No shadow, gradient, texture, floor, reflection, glow, halo, vignette, or lighting variation. Do not introduce green into the character.

Do not add:
No crossed arms, clenched fists, pose change, head tilt, looking away, closed eyes, teeth, open mouth, anger vein, sweat drop, tear, comic symbol, motion mark, speech bubble, prop, counter, workstation, griddle, order card, patience bar, payment item, food, tool, UI, text, letter, number, logo, brand, watermark, cast shadow, contact shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One identity-locked customer_09 impatient green chroma-key source suitable for remove_chroma_key.py and exact Sprite2D state swapping with the approved neutral asset.
```

## 表情强度修正完整提示词

```text
Use case: identity-preserve
Asset type: ProjectCake customer_09 impatient expression intensity correction.

Input images:
- Image 1 is the exact impatient edit target; its identity, body, clothing, braid, scale, position, and background are correct, but its expression is too angry.
- Image 2 is the approved neutral identity reference.

Primary request:
Change ONLY the expression intensity in Image 1 from angry-looking to mild restrained impatience. Reduce the brow tension by about 40 percent: keep the eyebrows only slightly lowered and very gently angled inward, remove the strong pinched center-brow look, and do not add a vertical brow crease. Open the eyes slightly more while retaining a subtly lowered upper lid. Make the closed mouth almost flat with only the faintest downward turn at the corners. The result should read as polite but clearly tired of waiting, not anger, hostility, sadness, or disappointment.

Absolute invariants:
Preserve exactly the Image 1 face identity, skin tone, nose, jaw, cheekbones, ear shapes, hair, off-center part, full side braid and tip, coral wrap blouse, indigo lower garment, body silhouette, arms, hands, fingers, pose, exact 1536x1024 canvas, scale, position, visible boundary, lower edge, green padding, colors, outlines, and shading. Change only eyebrow angle, upper eyelid openness, and mouth curvature.

Background and exclusions:
Preserve the perfectly flat solid #00ff00 background. No gradient, texture, shadow, reflection, glow, halo, or green inside the character. No sweat, anger vein, wrinkle, frown crease, eye bag, tear, blush, teeth, open mouth, comic mark, UI, prop, text, logo, watermark, pose change, crop, or new detail.

Output intent:
One softened identity-locked customer_09 impatient green chroma-key source suitable for remove_chroma_key.py and exact Sprite2D state swapping.
```

## 处理记录

最终源：`tmp/imagegen/customers_v9/customer_09_impatient_v1_chromakey.png`。

Rejected：`tmp/imagegen/customers_v9/customer_09_impatient_v1_rejected_too_angry_chromakey.png`，眉间和嘴角张力过强，读作生气而非轻度不耐烦。

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

最终图未在本地裁切、缩放或调色。
