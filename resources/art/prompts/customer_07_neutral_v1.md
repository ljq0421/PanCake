# customer_07_neutral_v1

## 用途

P1 第七名顾客的中性半身 `Sprite2D` 单张确认稿。人物采用丰润中年女性、铜红短层次发、圆方脸与少量雀斑、暖金色上衣和深青绿腰部，与 customer_01–06 区分；耐心条、订单卡、付款内容、工作台和阴影均由独立层提供。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：先以 V8 与既有顾客作构图/风格参考生成新身份，再进行一次有针对性的整体比例与位置精确编辑
- 背景：纯品红抠像背景 `#ff00ff`
- 后处理：技能自带 `remove_chroma_key.py`

## 初始生成完整提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P1 customer_07 neutral half-body gameplay Sprite2D confirmation draft on a removable chroma-key background.

Input images:
- Image 1 is the approved V8 gameplay composition and visual-style anchor. Use only its fixed slightly elevated frontal customer viewpoint, bold deep-brown outlines, warm flat-color treatment, and grounded street-stall cartoon language. Do not reproduce its counter, griddle, UI, background, or existing young male identity.
- Images 2 through 5 are approved customer sprites. Use them only as references for complete half-body framing, scale range, canvas occupancy, line thickness, lower waist-edge placement, and simple large color blocks. Do not copy any existing identity, face, hairstyle, clothing design, age presentation, body silhouette, or exact color combination.

Primary request:
Create one clearly different, friendly middle-aged woman customer as an isolated neutral half-body character from the complete top of her hair to just below the waist. She has a comfortably full, sturdy adult build; a softly rounded-square face; warm fair-to-light skin; dark hazel attentive eyes; gently arched copper-brown eyebrows; a broad but restrained closed-mouth friendly smile; and only a small, clearly intentional scattering of simple freckles across the nose and upper cheeks. She should read as approximately 45 to 55 years old, not elderly, not young, not teenage, not childlike.

Hair:
Short layered copper-red pixie hair with a distinct softly swept side fringe and slightly feathered crown, neatly tapered above the nape. Both sides are tucked back so both complete ears remain exposed. Every hair tip and the entire crown must stay inside the canvas. The hairstyle must not resemble customer_01's tousled dark hair, customer_02's shoulder-length waves, customer_03's silver low bun, customer_04's tight curls, customer_05's straight bob, or customer_06's receding silver hair. Keep the copper hair as clean broad color shapes with minimal strand detail.

Clothing:
A muted warm sunflower-gold short-sleeve blouse with a simple wide rounded boat neckline and a single broad darker-gold lower fold, plus a deep desaturated teal trouser or skirt waistband at the lower edge. No vest, cardigan, polo collar, square neckline, Peter Pan collar, pattern, print, logo, text, pocket, button row, scarf, apron, jewelry, or accessory. Keep all cloth surfaces as clean matte large color blocks with no grain, speckles, weave texture, stains, dots, scratches, or mottling. Do not use magenta anywhere in the character.

Pose and anatomy:
Straight frontal pose, same slightly elevated fixed gameplay viewpoint as V8. Both shoulders, upper arms, forearms, relaxed open hands, fingers, and the complete waist-level lower edge are fully visible. Arms hang naturally beside the torso without hiding the blouse. Exactly two arms and two hands. Adult proportions and a comfortably full silhouette without caricature, obesity exaggeration, chibi proportions, or anime styling.

Composition/framing:
One centered character on a 1535 x 1024 broad landscape canvas. Preserve approximately 75 to 90 pixels of perfectly uniform background above the highest hair point. Keep generous background padding around both ears, shoulders, elbows, hands, and waist. No crop through hair, ears, shoulders, forearms, hands, waist, or clothing. Target a visible silhouette approximately 500 to 515 pixels wide, centered near x=760, with the flat lower waist edge ending near y=972 to 978 for a suggested counter pivot near (760,976). Maintain similar head size and overall height to approved customer_03 and customer_04 while keeping this woman's fuller torso visually distinct.

Style/medium:
Exact approved ProjectCake V8 visual language: simple hand-drawn 2D cartoon, bold clean deep-brown outlines of comparable thickness, crisp readable silhouette, large matte flat color areas, base color plus at most one broad shadow and one broad highlight, warm everyday street-stall atmosphere. Freckles must be sparse, simple, deliberate facial marks rather than noisy texture. Avoid glossy rendering, complex textile detail, gradients, painterly texture, photorealism, 3D, thin outlines, excessive hair strands, and excessive facial detail.

Neutral-state constraint:
Relaxed eyebrows, open attentive eyes, calm restrained closed-mouth smile, symmetrical relaxed stance. No impatience, anger, exaggerated happiness, laughter, wink, surprise, dramatic pose, or comic expression.

Scene/backdrop:
Perfectly flat solid #ff00ff chroma-key background edge to edge, including all four corners, for local background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, vignette, halo, glow, or lighting variation.

Absolute constraints:
One customer only. No counter, workstation, griddle, order card, patience bar, payment tray, money, food, tools, props, cast shadow, contact shadow, reflection, speech bubble, comic symbol, motion mark, UI, text, letters, numbers, logo, brand, or watermark. No cropped body part, hidden hand, extra limb, fused arm, malformed hand, glasses, hat, jewelry, apron, or accessory.

Output intent:
One clean opaque magenta chroma-key source suitable for remove_chroma_key.py, later transparent Sprite2D use, and identity-locked expression-state edits after human approval.
```

## 比例与位置修正完整提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake customer_07 neutral sprite scale-and-position correction.

Input images:
- Image 1 is the exact customer_07 neutral magenta chroma-key edit target and sole identity anchor.
- Its measured visible subject boundary is x=476..1049 and y=79..1015 on a 1535 x 1024 canvas.

Primary request:
Correct ONLY the uniform scale and position of the complete character:
1. uniformly scale the entire character down by approximately 6 percent as one coherent unit, without stretching or changing body proportions,
2. keep the character horizontally centered near x=767,
3. move the complete waist-level lower edge upward so it ends near y=974 to 976.
Target visible subject boundary approximately x=498..1037 and y=96..976, around 539 pixels wide and 880 pixels tall. This intentionally remains somewhat wider than the other customers because she has a comfortably full, sturdy build.

Absolute identity invariants:
Preserve the exact same middle-aged woman identity, softly rounded-square face, warm fair-to-light skin, dark hazel eyes, copper eyebrows, intentional sparse freckles, broad restrained neutral closed-mouth smile, short layered copper-red pixie hair, swept side fringe, both exposed ears, full sturdy proportions, sunflower-gold boat-neck blouse, deep desaturated teal waistband, all clothing seams, colors, hands, fingers, pose, and facial features. Do not change her age presentation, expression, hairstyle, body shape, clothing design, or color palette.

Scaling rule:
Scale the complete opaque character uniformly as one unit. Do not independently resize, narrow, widen, stretch, redraw, or distort the head, face, torso, chest, shoulders, arms, hands, or lower garment. Preserve every hair tip, both complete ears, both shoulders, both forearms, both hands, every finger, and the complete lower waist edge inside the canvas.

Style invariants:
Approved ProjectCake V8 simple hand-drawn 2D cartoon, bold clean deep-brown outlines, crisp silhouette, large matte flat color blocks, base plus at most one broad shadow and one broad highlight. Preserve freckles as sparse deliberate face marks. Keep hair and clothing free of grain, random speckles, fabric texture, stains, mottling, and noisy pixels.

Background:
Preserve a perfectly uniform flat solid #ff00ff chroma-key background edge to edge, including all four corners. No gradient, texture, lighting variation, vignette, halo, floor, reflection, cast shadow, or contact shadow. Do not use magenta inside the character.

Do not add:
No new person, prop, accessory, glasses, hat, jewelry, apron, UI, counter, workstation, griddle, order card, patience bar, payment object, food, tool, text, letters, numbers, logo, brand, watermark, comic symbol, motion mark, shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One corrected customer_07 neutral magenta chroma-key source suitable for remove_chroma_key.py and later identity-locked expression edits.
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

初稿边界为 `(476,79)-(1049,1015)`，宽 573 px、高 936 px，主体过宽且腰部过低，因此作为 rejected attempt 保留。最终修正稿边界为 `(489,110)-(1030,977)`，宽 541 px、高 867 px、腰部可见底边 y=976；丰润轮廓被有意保留，纵向尺度回到既有顾客区间。最终图未由本地脚本裁切、缩放或调色。

