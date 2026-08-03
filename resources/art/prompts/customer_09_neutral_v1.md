# customer_09_neutral_v1

## 用途

P1 第九名顾客的中性半身 `Sprite2D` 单张确认稿。人物采用成年女性、深暖棕肤色、蓝黑长侧辫、珊瑚橙立领裹襟上衣和深靛蓝腰部，与 customer_01—08 区分；耐心条、订单卡、付款内容、工作台和阴影均由独立层提供。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 背景：纯绿色抠像背景 `#00ff00`
- 后处理：技能自带 `remove_chroma_key.py`
- 迭代：初稿身份合格但过大且下缘裁切；前三次构图修正分别仍有裁切或尺度偏差，全部保留为 rejected；最终从具备完整半身下缘的稿件进行一次轻微整体放大，得到最终源。

## 初始生成完整提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P1 customer_09 neutral half-body gameplay Sprite2D confirmation draft on a removable chroma-key background.

Input images:
- Image 1 is the authoritative V8 gameplay composition and visual-style anchor. Use only its fixed slightly elevated frontal customer viewpoint, bold deep-brown outlines, warm simple color treatment, and grounded street-stall cartoon language. Do not reproduce its counter, griddle, UI, background, or existing young male identity.
- Images 2 through 5 are approved customer sprites used only for complete half-body framing, canvas occupancy, line thickness, lower waist-edge placement, clean matte finish, and adult proportions. Do not copy any existing identity, face, hairstyle, clothing design, age presentation, body silhouette, or exact color combination.

Primary request:
Create one clearly new, friendly adult woman customer, approximately 30 to 40 years old, with a balanced medium adult build and a calm neutral waiting expression. She has deep warm brown skin, a softly heart-shaped adult face with a defined jaw and high cheekbones, dark brown attentive eyes, gently arched black brows, a broad nose, and a restrained closed-mouth friendly smile. She must not read as teenage, childlike, elderly, anime, or caricatured.

Hair:
Gloss-free blue-black hair, sleek at the crown with a clean off-center part. Both sides are tucked fully behind the ears so both complete ears remain visible. The hair continues into one long, thick, simple three-section side braid that rests naturally over one shoulder and ends around the upper chest. The complete crown, braid silhouette, and braid tip must all stay inside the canvas with generous clearance. Use broad clean hair masses and only a few simple braid divisions, not many fine strands. No bun, bob, pixie, loose shoulder waves, tight curls, silver hair, blond hair, or twin braids.

Clothing:
A muted coral-orange short-sleeve blouse with a small simple mandarin collar and one broad clean diagonal wrap seam across the upper torso, with no visible fasteners. A deep desaturated indigo-blue skirt or trouser waistband appears at the lower edge. Keep clothing as clean matte large color blocks with base color plus at most one broad shadow and one broad highlight. No green anywhere in the character. No pattern, print, logo, text, pocket, button row, vest, apron, scarf, jewelry, or accessory.

Pose and anatomy:
Straight front-facing relaxed pose in the same slightly elevated fixed gameplay viewpoint as V8. Both shoulders, upper arms, complete forearms, relaxed open hands, fingers, and the complete waist-level lower edge are fully visible. Arms hang naturally beside the torso without hiding the blouse. Exactly two arms and two hands. Adult proportions and balanced medium build without an oversized head, chibi body, exaggerated curves, or fashion-model posing.

Composition/framing:
One centered character on a 1536 x 1024 landscape canvas, shown from the complete top of the hair through the complete lower waist edge. Target visible silhouette approximately 465 to 490 pixels wide and 870 to 890 pixels tall, centered near x=768. Place the highest hair point near y=78 to 92 and the unbroken lower waist edge near y=968 to 976. Preserve all hair and the full braid tip, both ears, both shoulders, both forearms, both complete hands and fingertips, and the full lower edge with generous key-color padding. Keep the character fully detached from all four canvas edges. No table or counter in front.

Style/medium:
Exact approved ProjectCake V8 language: polished clean hand-drawn 2D cartoon game illustration, bold smooth deep-brown outer contours comparable to the approved customers, confident simple internal lines, crisp readable silhouette, large matte color shapes, and no more than about three value levels per material. Warm everyday street-stall atmosphere. Avoid thin outlines, grain, speckles, fabric texture, skin texture, complex gradients, glossy rendering, painterly detail, photorealism, 3D, or excessive hair strands.

Neutral-state constraint:
Relaxed eyebrows, open attentive eyes looking forward, calm restrained closed-mouth smile, symmetrical relaxed stance. No impatience, anger, exaggerated happiness, laughter, wink, surprise, dramatic pose, or comic expression.

Scene/backdrop:
Perfectly flat solid #00ff00 chroma-key green background edge to edge, including all four corners, for local background removal. The background must be one uniform color with no shadow, gradient, texture, reflection, floor plane, vignette, halo, glow, or lighting variation. Do not use green anywhere inside the character.

Absolute constraints:
One customer only. No counter, workstation, griddle, order card, patience bar, payment tray, money, food, tools, props, cast shadow, contact shadow, reflection, speech bubble, comic symbol, motion mark, UI, text, letters, numbers, logo, brand, or watermark. No cropped body part, hidden hand, extra limb, fused arm, malformed hand, glasses, hat, earrings, necklace, apron, or accessory.

Output intent:
One clean opaque green chroma-key source suitable for remove_chroma_key.py, later transparent Sprite2D use, and identity-locked expression-state edits after human approval.
```

## 第一次比例修正完整提示词

```text
Use case: identity-preserve
Asset type: ProjectCake customer_09 neutral sprite scale-and-position correction.

Input images:
- Image 1 is the exact customer_09 neutral green chroma-key edit target and sole identity anchor.
- Image 2 is the authoritative V8 style and gameplay composition reference.

Primary request:
Correct ONLY the uniform scale and framing of Image 1. Uniformly scale the complete character down to approximately 90% as one coherent unit, without stretching or changing proportions. Keep her horizontally centered. Reframe so the highest hair point is near y=78 to 88 and the complete unbroken lower skirt/waist edge ends near y=968 to 974 on the same 1536x1024 canvas. Leave at least 40 pixels of uniform green padding below the complete lower edge.

Absolute identity invariants:
Preserve the exact same adult woman identity, deep warm brown skin, softly heart-shaped face, defined jaw, high cheekbones, broad nose, dark brown eyes, black brows, restrained neutral closed-mouth smile, blue-black sleek off-center-parted hair, both exposed ears, the exact long thick side braid and complete braid tip, balanced medium build, coral-orange mandarin-collar wrap-seam blouse, deep indigo lower garment, hands, fingers, pose, colors, outlines, and shading. Do not change age presentation, face, expression, hairstyle, braid placement, clothing design, body silhouette, or color palette.

Scaling and silhouette invariants:
Scale the entire opaque character uniformly as one unit. Do not independently resize, narrow, widen, stretch, redraw, or distort the head, face, torso, shoulders, arms, hands, braid, or lower garment. Preserve every crown edge, full braid and tip, both complete ears, both shoulders, both forearms, both hands and fingertips, and the complete lower waist/skirt edge inside the canvas. Target an overall visible silhouette approximately 455 to 480 pixels wide and 875 to 895 pixels tall.

Style invariants:
Preserve the approved ProjectCake V8 clean 2D cartoon language, bold deep-brown outlines, simple large matte color blocks, and limited broad shading. Keep skin, hair, and clothing free of grain, random speckles, fabric texture, noisy pixels, glossy effects, and excessive detail.

Background:
Preserve a perfectly uniform flat solid #00ff00 chroma-key green background edge to edge, including all four corners. No gradient, texture, lighting variation, vignette, halo, floor, reflection, cast shadow, or contact shadow. Do not use green inside the character.

Do not add:
No new person, prop, accessory, earrings, necklace, glasses, hat, apron, UI, counter, workstation, griddle, order card, patience bar, payment object, food, tool, text, letters, numbers, logo, brand, watermark, comic symbol, motion mark, shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One corrected customer_09 neutral green chroma-key source suitable for remove_chroma_key.py and later identity-locked expression edits.
```

## 第二次下缘修正完整提示词

```text
Use case: identity-preserve
Asset type: ProjectCake customer_09 neutral sprite final framing correction.

Input images:
- Image 1 is the exact customer_09 identity and edit target.
- Image 2 is the authoritative V8 gameplay scale reference.

Primary request:
Change ONLY the overall character scale and bottom framing. Uniformly shrink the entire Image 1 character by another 8 percent as one coherent unit, centered around the character's midpoint. Reconstruct and show the complete rounded horizontal bottom hem of the indigo skirt as a finished uninterrupted garment edge at y=950 to 960. Below that complete hem, show 55 to 70 pixels of uninterrupted flat green background all the way to the canvas bottom. The character must not touch or cross the bottom edge.

Required final placement on the same 1536x1024 canvas:
- highest hair point near y=80 to 95
- complete finished skirt hem near y=950 to 960
- at least 55 px of pure green below the hem
- full silhouette fully separated from every canvas edge
- target visible height about 860 to 880 px and visible width about 440 to 465 px
- centered near x=768

Absolute identity invariants:
Preserve exactly the same adult woman identity, deep warm brown skin, heart-shaped defined face, high cheekbones, broad nose, dark brown eyes, black brows, neutral closed-mouth smile, blue-black off-center-parted hair, both exposed ears, long thick side braid and its exact braid tip, coral-orange mandarin-collar wrap blouse, indigo skirt, balanced medium build, arms, hands, fingers, pose, proportions, colors, outlines, and shading. Do not redesign or alter any face, expression, hairstyle, braid, garment design, body shape, or color.

Uniform scaling rule:
Scale the whole character together. Do not resize or move the head, braid, torso, arms, hands, or skirt independently. Do not shorten the skirt by cropping. The new complete hem must be visually finished and fully visible, with green background below it.

Background:
Perfectly uniform flat solid #00ff00 across the entire background and every corner, including the full strip below the skirt hem. No gradient, texture, floor, shadow, reflection, glow, halo, or vignette. No green inside the character.

Do not add:
No person, prop, accessory, jewelry, glasses, hat, apron, UI, counter, workstation, griddle, order card, patience bar, payment, food, text, number, logo, watermark, comic symbol, shadow, reflection, extra limb, hidden hand, or crop.

Output intent:
One corrected customer_09 neutral green chroma-key source with a visibly complete skirt hem and ample green padding below, suitable for remove_chroma_key.py and identity-locked expression variants.
```

## 第三次垂直位置修正完整提示词

```text
Use case: identity-preserve
Asset type: ProjectCake customer_09 neutral half-body sprite vertical-position correction.

Input images:
- Image 1 is the exact customer_09 edit target and sole identity anchor. Its scale and body proportions are already correct, but it is positioned too low and its lower garment touches the canvas bottom.
- Images 2 and 3 are approved customer sprites used only to show the intended top and bottom padding and half-body lower-edge placement. Do not copy their identities or clothing.

Primary request:
Translate the entire Image 1 character upward by approximately 65 pixels as one rigid coherent unit on the same 1536x1024 canvas. Do NOT scale, shrink, enlarge, narrow, widen, stretch, or redesign the character. Keep the current character width, height, head size, body proportions, and horizontal center unchanged. Finish the existing indigo lower garment with one clean, complete, gently rounded horizontal cutout edge near y=955 to 965, leaving 58 to 68 pixels of perfectly uniform green background below it.

Required result:
- highest hair point near y=78 to 88
- current character scale and approximately 450-pixel-wide silhouette preserved
- complete lower garment edge near y=955 to 965
- at least 58 pixels of uninterrupted green below the entire lower edge
- all hair, braid tip, ears, shoulders, forearms, hands, fingertips, and lower edge detached from all canvas borders
- half-body game sprite comparable in occupancy to Images 2 and 3, not a small full-body figure and not a full-length skirt character

Absolute identity invariants:
Preserve exactly the same adult woman identity from Image 1: deep warm brown skin, softly heart-shaped face, defined jaw, high cheekbones, broad nose, dark brown eyes, black brows, restrained neutral closed-mouth smile, blue-black sleek off-center-parted hair, both exposed ears, exact long thick side braid and braid tip, balanced medium build, coral-orange mandarin-collar wrap-seam blouse, deep indigo lower garment, arms, hands, fingers, pose, colors, outlines, and shading. Change only vertical placement and completion of the previously cropped lower edge.

Style and background invariants:
Preserve the clean ProjectCake V8 2D cartoon language, bold deep-brown outlines, large matte color blocks, and limited broad shading. Preserve a perfectly flat uniform solid #00ff00 chroma-key background edge to edge and in the full strip below the character. No gradient, texture, floor, shadow, reflection, glow, halo, vignette, or green inside the subject.

Do not add:
No full-length body, legs, feet, long floor-length skirt, new person, prop, accessory, jewelry, glasses, hat, apron, UI, counter, order card, patience bar, payment object, food, text, logo, watermark, comic symbol, shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One corrected customer_09 neutral green chroma-key half-body source, matching approved customer occupancy and suitable for remove_chroma_key.py and identity-locked expression states.
```

## 最终轻微比例修正完整提示词

```text
Use case: identity-preserve
Asset type: ProjectCake customer_09 neutral sprite final uniform scale adjustment.

Input images:
- Image 1 is the exact complete customer_09 edit target and sole identity anchor. Its silhouette and finished lower edge are correct; it is only slightly too small.
- Image 2 is an approved customer sprite used only as an overall canvas-occupancy and height reference. Do not copy its identity, face, hair, clothing, or colors.

Primary request:
Change ONLY the uniform overall scale and placement of the complete Image 1 character. Enlarge the entire character uniformly by approximately 7 percent as one rigid coherent unit, then position it so the highest hair point is near y=82 to 92 and the complete finished indigo lower edge is near y=958 to 968. Keep at least 50 pixels of flat green background below the entire lower edge. Preserve horizontal centering near x=768.

Absolute invariants:
Preserve every pixel-level design decision of the customer_09 identity as closely as possible: same adult woman, deep warm brown skin, heart-shaped defined face, high cheekbones, broad nose, dark brown eyes, black brows, restrained neutral closed-mouth smile, blue-black off-center-parted hair, both exposed ears, exact long thick side braid and complete braid tip, coral-orange mandarin-collar wrap blouse, deep indigo short lower-garment section with its existing gently rounded complete bottom edge, balanced medium build, arms, hands, fingers, pose, proportions, colors, outlines, and shading. Do not change or redraw the face, expression, hairstyle, braid, garment design, body shape, or silhouette structure.

Uniform scaling rule:
Scale the entire complete character together. Do not resize, stretch, move, or redraw any body part or garment independently. Preserve the half-body cutout: do not extend the skirt, add legs, add feet, shorten the torso, or crop the lower edge. Keep all hair, braid, ears, shoulders, forearms, hands, fingertips, and the full lower edge detached from all canvas borders.

Background and style:
Perfectly flat uniform solid #00ff00 chroma-key background over the whole canvas, including at least 50 pixels below the character. Preserve clean ProjectCake V8 2D cartoon style, bold deep-brown outlines, large matte blocks, and limited broad shading. No gradient, texture, floor, shadow, reflection, halo, glow, vignette, or green inside the subject.

Do not add:
No new person, prop, accessory, jewelry, glasses, hat, apron, UI, counter, order card, patience bar, payment object, food, text, number, logo, watermark, comic symbol, shadow, reflection, extra limb, hidden hand, or cropped body part.

Output intent:
One final customer_09 neutral green chroma-key half-body source with approved customer-scale occupancy, a complete lower edge, and sufficient key-color padding for remove_chroma_key.py.
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

最终源：`tmp/imagegen/customers_v9/customer_09_neutral_v1_chromakey.png`。

Rejected 中间稿：

- `customer_09_neutral_v1_rejected_overscale_bottom_crop_chromakey.png`：人物过大、底部裁切。
- `customer_09_neutral_v1_rejected_attempt2_bottom_crop_chromakey.png`：纵向位置仍过低、底部裁切。
- `customer_09_neutral_v1_rejected_attempt3_underscale_fullskirt_chromakey.png`：人物过小且下装接近全身长度。
- `customer_09_neutral_v1_rejected_attempt4_underscale_chromakey.png`：完整但占画略小。

最终图未在本地裁切、缩放或调色。
