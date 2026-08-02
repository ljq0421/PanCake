# customer_04_neutral_v1

## 用途

P1 第四名顾客的中性半身 `Sprite2D` 确认稿。人物以暖棕肤色、紧密短卷发、较宽中年男性体型和海军蓝 Polo 与前三名顾客区分；耐心条、订单卡、付款内容、工作台和阴影均由独立层提供。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：先参考 V8 与前三名顾客生成新身份，再对过宽首稿进行一次精确比例修正
- 背景：纯品红抠像背景
- 后处理：技能自带 `remove_chroma_key.py`

## 初始生成完整提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P1 customer_04 neutral half-body gameplay sprite, magenta chroma-key source for transparent PNG
Input images: Image 1 is the approved V8 gameplay composition and visual-style reference; use only its fixed slightly elevated frontal customer viewpoint, bold deep-brown line weight, flat-color rendering and warm street-stall palette, not its workstation or UI. Images 2, 3 and 4 are the approved neutral sources for customer_01 through customer_03; use them only as canvas occupancy, complete half-body framing, established 450-to-491-pixel silhouette width range, lower-edge position and counter-pivot references. Do not copy any existing identity, face, hairstyle, age presentation, clothing cut or clothing colors.
Primary request: create one clearly different, friendly middle-aged man customer as an isolated neutral half-body character from the complete top of his hair to just below the waist. Give him warm medium-brown skin, a broad softly angular face, dark brown attentive eyes, a strong but relaxed jaw, and a calm small closed-mouth smile. His hair is short, dense, tightly curled and dark brown-black with a clean rounded silhouette; keep every curl fully inside the canvas and keep both complete ears exposed. No facial hair. Dress him in a faded navy-blue short-sleeve polo shirt with a simple warm ochre collar edge and two small blank buttons, plus a muted brick-brown waistband or trouser top at the lower edge. Both shoulders, upper arms, forearms and relaxed open hands must be fully visible; arms hang naturally beside the torso. Straight frontal pose, same slightly elevated fixed gameplay viewpoint as V8.
Composition/framing: one centered character on the established 1535 x 1024-style broad landscape canvas; complete hair and every curl visible with at least 90 pixels of uniform background above; generous side padding around both elbows and hands; no crop through hair, ears, shoulders, hands, waist or clothing. Keep the waist-level lower termination centered and flat for placement behind the service counter. Target an approximately 465-to-485-pixel visible silhouette width, similar character height to customer_02 and customer_03, and a lower-edge pivot near y=970-to-980 while preserving the broader masculine silhouette.
Style/medium: exact approved ProjectCake V8 language—simple hand-drawn 2D cartoon, bold clean deep-brown outlines of comparable thickness, large matte flat color blocks, base color plus at most one shadow and one highlight, minimal hair and fabric texture, crisp readable silhouette, friendly grounded everyday street-stall feeling. Clearly middle-aged adult proportions; not bodybuilder, not chibi, not anime.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background edge to edge for local background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, vignette or lighting variation. Do not use #ff00ff anywhere in the character.
Neutral-state constraint: relaxed eyebrows, open attentive eyes and restrained friendly closed-mouth smile; no impatience, exaggerated happiness, laughter, wink or dramatic pose.
Absolute constraints: one customer only; no beard, moustache, glasses, hat, jewelry, counter, workstation, griddle, order card, patience bar, payment tray, money, food, tools, props, cast shadow, contact shadow, reflection, glow, speech bubble, comic symbol or UI. No text, letters, numbers, logo, brand or watermark. No extra limbs, fused fingers, hidden hands, cropped curls, cropped ears or cropped body. No photorealism, glossy 3D, painterly rendering, thin outlines, heavy gradients or noisy detail.
Output intent: one clean opaque chroma-key source suitable for remove_chroma_key.py, later transparent Sprite2D use, and identity-locked expression-state edits.
```

## 定向比例修正完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake customer_04 neutral sprite proportion correction
Input images: Image 1 is the customer_04 neutral chroma-key draft and exact edit target.
Primary request: correct only the character's excessive width and lower-edge placement. Preserve the exact same middle-aged man identity, face, skin tone, eyes, neutral closed-mouth smile, short dense dark curls, both exposed ears, navy polo design, ochre collar trim, buttons, brick-brown lower garment, colors, line weight, lighting and flat V8 rendering.
Targeted geometry change only: reduce the horizontal width of the shoulders, torso, sleeves and arm placement so the complete alpha silhouette is approximately 490 to 510 pixels wide instead of about 570 pixels. Keep a naturally broad middle-aged masculine build, but not oversized. Bring both arms and relaxed hands inward proportionally without hiding, cropping or changing the hands. Keep the head and hairstyle at their current natural proportions; do not make the face thin. Move the complete character upward about 12 to 16 pixels so the visible waist lower edge ends near y=975 to y=979 on the unchanged 1535 x 1024 canvas. Preserve roughly the current character height and at least 75 pixels of magenta padding above the hair.
Absolute invariants: same person, same age, same expression, same straight frontal slightly elevated viewpoint, same complete hair, both ears, both shoulders, forearms, hands and waist; same perfectly uniform solid magenta RGB 255,0,255 background; same centered alignment and simple bold-outlined V8 style. Do not add, remove or redesign clothing details. Do not change facial features or expression.
Must not include: counter, workstation, UI, order card, patience bar, payment, props, shadow, reflection, text, symbols, logo, watermark, extra limbs, cropped curls, hidden hands, thin outlines, painterly texture or 3D rendering.
Output intent: corrected chroma-key neutral anchor suitable for remove_chroma_key.py and later identity-locked expression edits.
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

初稿 alpha 宽 570 px，超出既有顾客范围，保留为 rejected attempt。定向修正稿宽 505 px、底边 y=975，通过本地视觉与 alpha 检查。最终透明图未裁切、未缩放、未调色。
