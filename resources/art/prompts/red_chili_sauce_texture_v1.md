# red_chili_sauce_texture_v1

## 用途与命名边界

作为 P1 两种基础酱料之一的候选 RGB 平铺纹理。设计文档只规定“2 种酱料”，未锁定名称；“辣酱”是为了与深棕酱料形成明确视觉区分的暂定美术命名。

## 初次生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake seamless tileable red chili sauce RGB surface texture for a future sauce-color layer
Primary request: create a square seamless top-down texture of thick Chinese red chili sauce spread in a thin layer. Muted warm brick-red base clearly brighter and redder than sweet flour sauce, a few broad soft spreading bands, sparse darker-red chili-fiber speckles and restrained orange-red highlights. It should read as savory chili sauce, not ketchup, blood, tomato soup or glossy paint.
Style/medium: simple clean 2D cartoon game texture matching the approved V8 large-flat-color baseline; large restrained color fields, at most base plus one darker red overlap tone and one soft orange-red highlight tone, minimal detail, no photorealism.
Composition: uniform edge-to-edge material texture, orthographic top-down, no focal point, no container, brush, spoon, pancake outline, plate, griddle or background scene.
Tileability: all four edges must join seamlessly; avoid a central swirl, strong directional flow or unique edge marks.
Constraints: full square opaque RGB texture; no whole chilies, seeds, scallion, sesame, garlic chunks, bubbles, drips outside an object, text, letters, numbers, logo, brand or watermark; no black majority, white glossy reflections, plastic 3D gloss, deep shadows, heavy gradients, photographic noise or dense microtexture.
```

## 定向简化提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake red chili sauce tileable RGB texture simplification
Input images: Image 1 is the red chili sauce texture edit target
Primary request: simplify only the surface detail. Remove roughly 70 to 80 percent of the tiny dark-red speckles, small pits, fiber fragments and micro-ridges. Merge dense detail into broad flat muted brick-red areas, retaining only a small number of soft darker-red fiber marks and wide orange-red spreading bands so it remains distinguishable as chili sauce.
Tileability invariant: preserve the seamless edge-to-edge square texture, uniform distribution and lack of focal point; no central swirl, border, strong directional flow or unique edge marks.
Absolute invariants: preserve the muted warm brick-red chili sauce identity, clearly redder and brighter than sweet flour sauce, and full square opaque RGB format; keep no container, brush, spoon, pancake outline, plate, griddle, whole chilies, seeds, scallion, sesame or garlic chunks.
Style constraints: simple flat 2D cartoon game texture matching the approved V8 large-color-block baseline, at most base plus one darker red tone and one soft orange-red highlight; no text, letters, numbers, logo, brand, watermark, photographic noise, dense microtexture, white reflections, plastic gloss, deep shadows or heavy gradients.
```

