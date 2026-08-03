# supplier_01_neutral_v1

## 用途

P3 供应商事件角色中性状态；角色、事件面板和文字分别成层。

## 最终生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P3 supplier-event character neutral half-body sprite, magenta chroma-key source
Input images: Image 1 is the approved V8 gameplay composition and visual-style reference; Image 2 is an existing customer sprite used only for canvas occupancy, half-body framing and lower counter-pivot scale. Do not copy the identity.
Primary request: create one clearly distinct everyday ingredient supplier: a capable Chinese woman in her late forties with warm tan skin, a softly square face, attentive dark eyes, subtle smile lines and a calm businesslike closed-mouth expression. Dark hair gathered into a low practical bun fully visible inside canvas, no hat. Wear a muted brick-red work jacket over a cream shirt and a faded-teal waist apron with one completely blank rectangular pocket patch. Both forearms and relaxed open hands fully visible. Straight frontal pose, slightly elevated fixed gameplay viewpoint.
Style: exact ProjectCake V8 simple hand-drawn 2D cartoon, bold clean deep-brown outlines, large matte flat color blocks, one shadow and one highlight maximum, minimal hair and fabric texture, grounded street-stall feeling.
Composition: one centered half-body character on a broad landscape canvas, complete hair with generous top padding, full shoulders, arms, hands and waist, similar occupancy and lower-edge pivot to the reference customer.
Background: perfectly flat solid #ff00ff chroma-key edge to edge; no shadow, gradient, texture, floor or reflection; do not use #ff00ff in the subject.
Constraints: no crate, clipboard, food, money, vehicle, counter, UI, speech bubble, readable text, letters, numbers, logo, brand, watermark, extra limbs, crop, photorealism, glossy 3D, anime or painterly detail.
```

## 处理

- 使用技能自带 `remove_chroma_key.py` 抠图。
- 等比缩放后放入 1535×1024 顾客标准画布，建议柜台枢轴 y≈976。
