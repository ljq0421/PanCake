# customer_01_impatient_v1

## 用途

P1 第一名顾客接近耗尽耐心时的半身 `Sprite2D` 状态。与中性状态共用尺寸和近似锚点，仅切换表情，不包含耐心条或订单 UI。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：以 `customer_01_neutral_v1_chromakey.png` 为参考的精确对象编辑
- 背景：纯品红抠像背景
- 后处理：技能自带 `remove_chroma_key.py`

## 完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake P1 half-body customer Sprite2D expression state, impatient
Input image: the approved customer_01_neutral_v1 chroma-key source. Edit this exact character; do not redesign him.
Primary request: create an impatient / nearly out-of-patience expression state for the same young male customer. Preserve exactly the same identity, hairstyle, hair silhouette, skin tone, olive-green T-shirt, dark blue pants, front-facing half-body proportions, canvas dimensions, placement, scale, and thick dark-brown outline style. Keep every hair tip, both ears, both shoulders, forearms, hands, and lower torso fully inside the canvas with the same generous margins.
Expression change only: eyebrows angle slightly downward toward the center, eyes mildly narrowed but still readable, mouth becomes a small restrained downward curve, cheeks less cheerful. Convey clear impatience without rage, shouting, tears, sweat symbols, steam, comic icons, or exaggerated deformation. Allow only a very subtle tense shoulder posture; keep arms hanging down and hands visible. This must remain obviously the exact same character and align closely enough for a Sprite2D texture swap.
Composition: one isolated centered opaque character, straight-on half-body view, same bounding box and anchor position as the input.
Background: perfectly uniform solid chroma-key magenta RGB 255,0,255 edge to edge. No gradient, no texture, no vignette.
Style: approved ProjectCake V8 visual language: simple 2D cartoon, bold clean dark-brown outlines, large flat color blocks, at most three value layers, minimal highlights, crisp readable silhouette, warm street-stall palette.
Lighting/material: matte flat illustration, no glossy rendering, no photorealism.
Must not include: workstation, counter, griddle, food, tools, payment, order card, patience bar, UI, text, letters, numbers, symbols, logo, brand, watermark, speech bubble, background shadow, floor shadow, glow, additional person, cropped hair, cropped hands, cropped body, transparent/checkerboard background.
Output: one clean chroma-key image suitable for remove_chroma_key.py and later Sprite2D state swapping.
```

## 处理记录

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

首稿通过视觉检查，无需定向重生成。
