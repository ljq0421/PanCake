# customer_05_neutral_v1

## 用途

P1 第五名顾客的中性半身 `Sprite2D` 确认稿。人物以齐刘海直短发、窄椭圆脸、灰紫方领上衣和较纤细轮廓与前四名顾客区分；耐心条、订单卡、付款内容、工作台和阴影均由独立层提供。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：先参考 V8 与既有顾客生成新身份，再进行一次背景键色与布料微噪点清理
- 背景：最终采用纯绿色抠像背景；初稿品红背景与灰紫服装色相过近
- 后处理：技能自带 `remove_chroma_key.py`

## 初始生成完整提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P1 customer_05 neutral half-body gameplay sprite, magenta chroma-key source for transparent PNG
Input images: Image 1 is the approved V8 gameplay composition and visual-style reference; use only its fixed slightly elevated frontal customer viewpoint, bold deep-brown line weight, flat-color rendering and warm street-stall palette, not its workstation or UI. Images 2, 3 and 4 are approved neutral customer sources; use them only as canvas occupancy, complete half-body framing, established silhouette range, lower-edge position and counter-pivot references. Do not copy any existing identity, face, hairstyle, age presentation, clothing cut or clothing colors.
Primary request: create one clearly different young adult woman customer as an isolated neutral half-body character from the complete top of her hair to just below the waist. Give her a narrow oval face, warm light-medium skin, dark brown attentive eyes, softly straight eyebrows, and a calm small closed-mouth smile. Her hair is straight, very dark brown-black, chin-length in a clean blunt bob with short straight bangs; both sides are neatly tucked behind the ears so both complete ears remain exposed, and every hair tip stays fully inside the canvas. Dress her in a muted dusty-plum short-sleeve blouse with a simple shallow square neckline and a warm cream waistband or skirt top at the lower edge. Both shoulders, upper arms, forearms and relaxed open hands must be fully visible; arms hang naturally beside the torso. Straight frontal pose, same slightly elevated fixed gameplay viewpoint as V8.
Composition/framing: one centered character on the established 1535 x 1024-style broad landscape canvas; complete hair, bangs and every hair tip visible with at least 85 pixels of uniform background above; generous side padding around both elbows and hands; no crop through hair, ears, shoulders, hands, waist or clothing. Keep the waist-level lower termination centered and flat for placement behind the service counter. Target an approximately 445-to-470-pixel visible silhouette width, similar character height to customer_02, and a lower-edge pivot near y=965-to-975 while preserving a slightly slimmer young-adult silhouette.
Style/medium: exact approved ProjectCake V8 language—simple hand-drawn 2D cartoon, bold clean deep-brown outlines of comparable thickness, large matte flat color blocks, base color plus at most one shadow and one highlight, minimal hair and fabric texture, crisp readable silhouette, friendly grounded everyday street-stall feeling. Adult proportions; not teenage, not childlike, not chibi, not anime.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background edge to edge for local background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, vignette or lighting variation. Keep the dusty-plum clothing clearly darker and less saturated than magenta; do not use #ff00ff anywhere in the character.
Neutral-state constraint: relaxed eyebrows, open attentive eyes and restrained friendly closed-mouth smile; no impatience, exaggerated happiness, laughter, wink or dramatic pose.
Absolute constraints: one customer only; no glasses, hat, jewelry, apron, counter, workstation, griddle, order card, patience bar, payment tray, money, food, tools, props, cast shadow, contact shadow, reflection, glow, speech bubble, comic symbol or UI. No text, letters, numbers, logo, brand or watermark. No extra limbs, fused fingers, hidden hands, cropped bangs, cropped ears or cropped body. No photorealism, glossy 3D, painterly rendering, thin outlines, heavy gradients or noisy detail.
Output intent: one clean opaque chroma-key source suitable for remove_chroma_key.py, later transparent Sprite2D use, and identity-locked expression-state edits.
```

## 技术清理完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake customer_05 neutral sprite chroma-key and fabric cleanup
Input images: Image 1 is the customer_05 neutral magenta chroma-key draft and exact edit target.
Primary request: make exactly two technical cleanup changes while preserving the character: (1) replace the full background with perfectly uniform solid chroma-key green RGB 0,255,0 edge to edge; (2) simplify the dusty-plum blouse surface into clean large flat color blocks by removing every tiny dark speck, grain, dot, scratch and noisy micro-texture. Keep only the existing broad base color, at most one broad shadow and one broad highlight.
Absolute character invariants: preserve the exact same young adult woman identity, narrow oval face, skin tone, eyes, neutral small closed-mouth smile, straight dark chin-length blunt bob, short straight bangs, both exposed ears, every hair tip, dusty-plum blouse design, shallow square neckline, cream waistband and lower garment, hands, fingers, arms, shoulders, torso, pose, scale and body proportions. Preserve the exact 1535 x 1024 canvas, centered placement, silhouette, approximate alpha subject boundary (536,86)-(987,977), waist lower edge and pivot near (761,976). Do not move, widen, narrow, crop or redraw the character.
Style invariants: approved ProjectCake V8 simple 2D cartoon, bold clean deep-brown outlines, large matte flat color blocks, base plus at most one shadow and one highlight, crisp readable silhouette. Preserve all existing outlines and clothing colors; the blouse must remain muted dusty plum and must not shift toward green.
Background constraints: one perfectly flat #00ff00 background with no gradient, texture, lighting variation, vignette, floor, shadow, reflection or halo. Do not use #00ff00 anywhere in the character.
Must not include: new clothing details, text, symbols, logo, watermark, UI, props, workstation, cast shadow, contact shadow, extra limbs, cropped hair, hidden hands, photorealism, 3D gloss, painterly texture or thin outlines.
Output intent: one clean green chroma-key source suitable for remove_chroma_key.py without damaging the dusty-plum clothing.
```

## 处理记录

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
  --force
```

初稿品红去背后，灰紫上衣出现细小深色噪点，因此作为 rejected attempt 保留。修正版改用绿色键控并清除布料微噪点；人物边界保持不变，最终图未裁切、未缩放、未调色。
