# customer_10_impatient_v1

## 用途

P1 第十名顾客的不耐烦半身 `Sprite2D` 状态。直接从已确认的中性绿幕源独立编辑，只改变眉形、眼睑和嘴型；身份、秃顶与侧后发茬、分离式胡须、服装、完整轮廓、尺寸和锚点保持锁定。

## 初始完整提示词

```text
Use case: identity-preserve
Asset type: 2D game customer character sprite expression variant
Input images: Image 1 is the approved neutral identity anchor and exact composition reference.
Primary request: Change ONLY this same customer’s facial expression from neutral to mildly impatient. Keep the exact same character, pose, silhouette, clothing, canvas, placement, scale, and flat chroma-key background.
Expression: slightly lower and draw the eyebrows inward, subtly narrow the eyes, and make the visible mouth line beneath the mustache small and nearly flat. The feeling is mild waiting impatience, restrained and believable—not anger, rage, sadness, disgust, or exhaustion. Carry most of the expression through eyebrows and eyelids.
Identity invariants: preserve the exact bald crown shape; the exact narrow dark side-and-back stubble band; identical forehead, ears, nose, face shape, warm olive skin tone, body build, hands and fingers; preserve the exact separated dark mustache and rounded goatee shapes, size, placement, color, and gaps—do not redesign, curl, enlarge, shrink, merge, or shift either facial-hair element.
Clothing invariants: preserve the exact deep burgundy camp-collar overshirt, collar geometry, sleeve length and folds, cream undershirt triangle, khaki-brown waist, all colors, linework, highlights, and shading.
Style/medium: match Image 1 exactly—clean 2D cartoon game sprite, bold rough dark-brown outline, simple warm large color blocks, no more than about three shading levels, friendly warm street-stall aesthetic.
Composition/framing: exact same 1536×1024 landscape canvas and subject placement as Image 1. Keep the full scalp, side stubble, both ears, both shoulders, both forearms, both complete hands and fingers, and the lower waist edge fully visible with the same generous green padding. Keep the subject’s visible silhouette/bounding box as close as possible to x=507..1018 and y=82..960; suggested bottom-center anchor remains near (762,959). No cropping or rescaling.
Scene/backdrop: perfectly flat, uniform solid chroma-key green matching Image 1. No shadows, gradients, texture, floor plane, reflections, glow, vignette, or lighting variation in the green background. Do not use chroma green anywhere on the character.
Constraints: no forehead crease, anger vein, sweat, tears, blush, teeth, open mouth, symbols, props, food, payment object, order card, patience bar, UI, text, numbers, logos, brands, watermark, background scenery, or baked shadow. Do not alter anything except the facial expression.
```

## 表情强度修正完整提示词

```text
Use case: identity-preserve
Asset type: 2D game customer character sprite expression variant
Input images: Image 1 is the approved neutral identity anchor and exact composition reference.
Primary request: Change ONLY this same customer’s facial expression from neutral to SUBTLY, MILDLY impatient while waiting. Keep the exact same character, pose, silhouette, clothing, canvas, placement, scale, and flat chroma-key background.
Expression correction: This must look restrained and only one small step away from neutral. Keep both eyebrows mostly horizontal and close to their neutral shape; lower them only slightly, with at most a tiny inward tilt—NO sharp V shape, NO steep inner corners, NO scowl. Lower the upper eyelids very slightly so the eyes are only subtly narrower. Keep the visible mouth line beneath the mustache small, closed, and nearly flat. The emotion is quiet patience beginning to wear thin, not anger, rage, threat, sadness, disgust, or exhaustion. Carry the expression gently through eyelids; do not exaggerate the eyebrows.
Identity invariants: preserve the exact bald crown shape; the exact narrow dark side-and-back stubble band; identical forehead, ears, nose, face shape, warm olive skin tone, body build, hands and fingers; preserve the exact separated dark mustache and rounded goatee shapes, size, placement, color, and gaps—do not redesign, curl, enlarge, shrink, merge, or shift either facial-hair element.
Clothing invariants: preserve the exact deep burgundy camp-collar overshirt, collar geometry, sleeve length and folds, cream undershirt triangle, khaki-brown waist, all colors, linework, highlights, and shading.
Style/medium: match Image 1 exactly—clean 2D cartoon game sprite, bold rough dark-brown outline, simple warm large color blocks, no more than about three shading levels, friendly warm street-stall aesthetic.
Composition/framing: exact same 1536×1024 landscape canvas and subject placement as Image 1. Keep the full scalp, side stubble, both ears, both shoulders, both forearms, both complete hands and fingers, and the lower waist edge fully visible with the same generous green padding. Keep the subject’s visible silhouette/bounding box as close as possible to x=507..1018 and y=82..960; suggested bottom-center anchor remains near (762,959). No cropping or rescaling.
Scene/backdrop: perfectly flat, uniform solid chroma-key green matching Image 1. No shadows, gradients, texture, floor plane, reflections, glow, vignette, or lighting variation in the green background. Do not use chroma green anywhere on the character.
Constraints: no forehead crease, frown crease, anger vein, sweat, tears, blush, teeth, open mouth, symbols, props, food, payment object, order card, patience bar, UI, text, numbers, logos, brands, watermark, background scenery, or baked shadow. Do not alter anything except the facial expression.
```

## 处理记录

最终源：`tmp/imagegen/customers_v10/customer_10_impatient_v1_chromakey.png`。

Rejected：`tmp/imagegen/customers_v10/customer_10_impatient_v1_rejected_too_angry_chromakey.png`，眉峰内压和眼神张力过强，读作生气而不是轻度等待不耐烦。

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

最终图未在本地裁切、缩放或调色。
