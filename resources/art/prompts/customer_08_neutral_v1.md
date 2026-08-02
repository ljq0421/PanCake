# customer_08_neutral_v1

## 用途

P1 第八名顾客的中性半身 `Sprite2D` 单张确认稿。人物采用偏瘦年轻成年男性、浅蜂蜜金及肩直发、窄长脸、炭灰 Henley 上衣与暖赤褐色腰部，与 customer_01—07 区分；耐心条、订单卡、付款内容、工作台和阴影均由独立层提供。

## 生成方式

- 生成器：Codex 内置 `image_gen`
- 模式：先用 V8 和既有顾客作为风格/构图参考生成新身份，再进行一次仅调整整体比例和位置的身份锁定编辑
- 背景：纯品红抠像背景 `#ff00ff`
- 后处理：技能自带 `remove_chroma_key.py`

## 初始生成完整提示词

```text
Use case: stylized-concept
Asset type: standalone 2D game customer character sprite, neutral state, for a 1920x1080 Godot street-food stall scene.

Input images:
- Image 1 is the authoritative V8 visual-style and scene-composition reference. Match its warm 2D cartoon language, proportions, outline character, and near-overhead/front-facing customer presentation.
- Images 2-5 are existing customer sprites used only as scale, framing, line-weight, pose, and finish references. Do not copy any existing person's identity, hairstyle, face, clothing design, or colors.

Primary request: Create customer_08 as one clearly new, friendly young adult man, approximately 25-35 years old, with a slim adult build. Neutral waiting expression and relaxed symmetrical standing pose.

Scene/backdrop: perfectly flat, uniform solid #ff00ff chroma-key background. No floor, no horizon, no lighting variation, no texture, no gradient, no shadow, no reflection, no halo.

Subject identity:
- warm light skin
- distinctly narrow, softly angular adult face and a slightly longer neck than the existing customers
- calm dark gray-brown eyes, slim brows, small closed-mouth friendly smile
- pale honey-blond, straight shoulder-length hair, center or subtly off-center part; both sides tucked behind the ears; both ears fully visible; the entire hairstyle and every hair tip visible with generous clearance from the canvas edges
- no facial hair, glasses, jewelry, hat, or accessories
- faded charcoal-gray short-sleeve Henley shirt with a shallow round neckline and exactly two small plain dark buttons; subtle warm camel/tan trim at the neckline/placket
- muted warm russet-brown trousers or waistband visible at the waist
- do not use magenta, pink, or purple anywhere in the character

Style/medium: polished clean 2D cartoon game illustration matching Image 1; bold deep-brown outer contour; confident smooth internal linework; simple large matte color shapes; no more than about three value levels per material; restrained soft painted shading; warm street-stall atmosphere; not anime, not photorealistic, not painterly, not 3D.

Composition/framing:
- 1536x1024 landscape canvas
- a single centered character shown from full head through the lower waist edge
- adult half-body sprite, front-facing with the slight fixed near-overhead perspective of Image 1
- target visible silhouette about 455-475 px wide and 865-890 px tall, centered near x=768
- top of hair near y=75-95; lower waist edge near y=975
- fully preserve all hair and hair tips, both ears, both shoulders, both complete forearms, both complete hands including fingertips, and the entire lower waist edge
- hands relaxed beside the torso, not hidden and not cropped
- generous transparent-safe padding around the full silhouette after chroma removal
- no table or counter in front of the character

Lighting/mood: warm, clear, friendly, readable game sprite with consistent soft frontal illumination.

Constraints: one character only; neutral expression only; crisp silhouette; uniform key background; no baked shadow; no counter, worktable, order card, patience bar, payment item, food, props, scenery, UI, speech bubble, comic symbol, text, numbers, logo, brand, or watermark. Preserve a clean stable silhouette suitable for later expression variants with identical size and anchor.

Avoid: childlike proportions, oversized head, broad stocky torso, cropped hair, cropped hands, hidden ears, long sleeves, green shirt, blue polo, sweater vest, apron, duplicate characters, extra fingers, fused fingers, key-color spill, rim glow, background cast shadow.
```

## 比例与位置修正完整提示词

```text
Use case: identity-preserve
Asset type: standalone 2D game customer character sprite, neutral state.

Input images:
- Image 1 is the exact customer_08 edit target.
- Image 2 is the authoritative V8 style and scene-composition reference.

Primary request: Correct only the scale and framing of Image 1. Uniformly scale the entire character down to approximately 91% around the canvas center so the complete lower waist/trouser edge is visible above the bottom of the canvas. Keep the character centered. Place the topmost hair near y=80-90 and the complete lower edge near y=965-975 on a 1536x1024 canvas.

Identity invariants: preserve exactly the same young adult male identity, narrow softly angular face, facial proportions, warm light skin, dark gray-brown eyes, slim brows, small closed-mouth neutral smile, pale honey-blond straight shoulder-length hair with center part and visible ears, hair-tip shapes, charcoal-gray short-sleeve Henley, camel neckline/placket with exactly two dark buttons, russet-brown trousers, hand pose, slim build, colors, linework, and shading. Do not redesign, restyle, recolor, redraw the expression, add detail, change clothing, or change body proportions.

Scene/backdrop: preserve a perfectly flat uniform solid #ff00ff chroma-key background with no gradient, texture, floor, shadow, reflection, glow, or lighting variation.

Composition constraints: single centered front-facing half-body character; fully preserve all hair and hair tips, both ears, both shoulders, both complete forearms, both complete hands and fingertips, plus an unbroken complete lower waist/trouser edge with at least 35 px clear key-color padding below it. The entire silhouette must be detached from all four canvas edges.

Avoid: any crop, identity drift, pose drift, expression drift, enlarged head, hidden ears, extra fingers, magenta inside the subject, key-color spill, halos, background shadow, UI, props, text, logos, or watermark.
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

初稿完整保留于 `tmp/imagegen/customers_v8/customer_08_neutral_v1_rejected_bottom_crop_chromakey.png`，但下方裤腰越过画布底边，故判定为 rejected。最终品红源为 `tmp/imagegen/customers_v8/customer_08_neutral_v1_chromakey.png`；只进行一次有针对性的整体缩小/重排生成，未在本地裁切、缩放或调色。
