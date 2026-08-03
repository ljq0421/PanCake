# customer_10_satisfied_v1

## 用途

P1 第十名顾客的满意半身 `Sprite2D` 状态。直接从已确认的中性绿幕源独立编辑，只改变眉形、眼睑和嘴型；不从不耐烦状态串联编辑。

## 完整提示词

```text
Use case: identity-preserve
Asset type: 2D game customer character sprite expression variant
Input images: Image 1 is the approved neutral identity anchor and exact composition reference.
Primary request: Change ONLY this same customer’s facial expression from neutral to warmly satisfied. Keep the exact same character, pose, silhouette, clothing, canvas, placement, scale, and flat chroma-key background.
Expression: gently relax and lift the eyebrows, turn the eyes into softly closed upward-curving happy arcs, and create a modest warm CLOSED-MOUTH smile visible beneath the mustache. The feeling is calm satisfaction after receiving a good order—friendly and sincere, not ecstatic or theatrical.
Identity invariants: preserve the exact bald crown shape; the exact narrow dark side-and-back stubble band; identical forehead, ears, nose, face shape, warm olive skin tone, body build, hands and fingers; preserve the exact separated dark mustache and rounded goatee shapes, size, placement, color, and gaps—do not redesign, lift, curl, enlarge, shrink, merge, or shift either facial-hair element. The mustache itself must not become the smile.
Clothing invariants: preserve the exact deep burgundy camp-collar overshirt, collar geometry, sleeve length and folds, cream undershirt triangle, khaki-brown waist, all colors, linework, highlights, and shading.
Style/medium: match Image 1 exactly—clean 2D cartoon game sprite, bold rough dark-brown outline, simple warm large color blocks, no more than about three shading levels, friendly warm street-stall aesthetic.
Composition/framing: exact same 1536×1024 landscape canvas and subject placement as Image 1. Keep the full scalp, side stubble, both ears, both shoulders, both forearms, both complete hands and fingers, and the lower waist edge fully visible with the same generous green padding. Keep the subject’s visible silhouette/bounding box as close as possible to x=507..1018 and y=82..960; suggested bottom-center anchor remains near (762,959). No cropping or rescaling.
Scene/backdrop: perfectly flat, uniform solid chroma-key green matching Image 1. No shadows, gradients, texture, floor plane, reflections, glow, vignette, or lighting variation in the green background. Do not use chroma green anywhere on the character.
Constraints: no open mouth, no teeth, no tongue, no blush, no tears, no hearts, sparkles, stars, symbols, props, food, payment object, order card, patience bar, UI, text, numbers, logos, brands, watermark, background scenery, or baked shadow. Do not alter anything except the facial expression.
```

## 处理记录

最终源：`tmp/imagegen/customers_v10/customer_10_satisfied_v1_chromakey.png`。

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

最终图未在本地裁切、缩放或调色。
