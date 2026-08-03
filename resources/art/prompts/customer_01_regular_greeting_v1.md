# customer_01_regular_greeting_v1

## 用途

P3 熟客特殊问候状态。保持 `customer_01` 身份，只替换表情和右臂挥手姿势。

## 最终生成提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake P3 familiar-customer special greeting state, magenta chroma-key source
Input images: Image 1 is customer_01_neutral_v1 and the exact identity, canvas, scale, line-weight and placement reference.
Primary request: change only the expression and right-arm pose into a warm familiar-customer greeting state. Preserve the exact same young man identity, face proportions, skin tone, hair, green T-shirt, navy trousers, body scale and fixed slightly elevated frontal viewpoint. Give him bright recognizing eyes, slightly lifted friendly eyebrows and a broader closed-mouth smile. Raise his right forearm into a small relaxed shoulder-height wave with an open hand and five clear fingers; keep the entire hand inside the existing silhouette width. Keep his left arm and left hand relaxed at his side.
Composition: same full half-body framing, same canvas, complete hair, ears, shoulders, both hands and waist, same lower counter pivot.
Style: exact ProjectCake V8 2D cartoon style, bold deep-brown outlines, matte flat colors, one shadow and one highlight maximum.
Background: perfectly flat solid #ff00ff chroma-key edge to edge; no shadows, gradients, texture, reflections or floor. Do not use #ff00ff in the character.
Constraints: no accessory, food, money, UI, order card, speech bubble, text, logo, brand, watermark, extra limbs, fused fingers, crop, photorealism, glossy 3D or painterly texture.
```

## 处理

- 使用技能自带 `remove_chroma_key.py` 抠图。
- 从一次生成的高分辨率源图统一为现有 `customer_01` 的 1427×1102 运行画布。
