# order_card_base_v1

## 用途

P1 顾客订单卡的独立空白底板。Godot 在三个圆形槽和两行要求槽中动态叠加配料图标、品质条件与文字；本图不包含任何烘焙内容。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 参考图：`visual_style_anchor_v8.png`
- 背景：纯品红抠像背景
- 后处理：技能自带 `remove_chroma_key.py`

## 完整提示词

```text
Use case: isolated game UI asset derived from the approved ProjectCake V8 style reference.
Asset type: P1 blank customer order card frame for Godot Control / NinePatchRect use.
Primary request: create one compact near-square blank order card matching the small card to the customer's upper-right in the V8 reference. Isolate only the card. Warm cream paper panel, softly rounded corners, bold clean dark-brown outer outline, one restrained orange-brown rim/accent, flat matte colors, minimal depth. Front-facing orthographic UI view with no perspective tilt.
Internal layout must be empty placeholders only: one top row containing exactly three equal small circular icon wells; below it, exactly two horizontal requirement rows. Each requirement row has one small rounded-square icon well on the left and one longer rounded rectangular empty field on the right. All wells are shallow outlined recesses in a slightly darker cream; no content inside them. Keep generous internal padding and make the shapes readable when the card is displayed at roughly 110 x 100 pixels in a 1920 x 1080 scene.
Composition: one centered opaque card occupying about 45% of the canvas width and 60% of canvas height, with generous clean background around it. Symmetrical, crisp, production-ready silhouette. No cast shadow or glow; runtime may add shadow separately.
Background: perfectly uniform solid chroma-key magenta RGB 255,0,255 edge to edge. No gradient, texture, vignette, checkerboard, or transparency.
Style: approved ProjectCake V8 simple 2D cartoon, large flat color blocks, thick dark-brown lines, at most three value layers, warm street-stall palette.
Must not include: customer, workstation, wall, patience bar, ingredients, food, payment, text, letters, numbers, currency symbols, check marks, stars, faces, pictograms, logo, brand, watermark, decorative pins, tape, paper curl, drop shadow, extra cards, cropped border.
Output: one clean chroma-key image suitable for remove_chroma_key.py; all text and dynamic icons will be drawn separately in Godot.
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

首稿的卡片画布占比高于提示中的 45%，但轮廓、槽位结构与留白完整；作为独立可缩放 UI 素材不影响使用，因此未重生成。
