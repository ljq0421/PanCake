# sweet_flour_sauce_texture_v1

## 用途与命名边界

作为 P1 两种基础酱料之一的候选 RGB 平铺纹理。设计文档只规定“2 种酱料”，未锁定名称；“甜面酱”是基于煎饼摊常见酱料做出的暂定美术命名，不等同于已确认的业务数据。

## 初次生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake seamless tileable sweet flour sauce RGB surface texture for a future sauce-color layer
Primary request: create a square seamless top-down texture of thick Chinese sweet flour sauce spread in a thin layer. Deep warm red-brown base, a few broad smooth brush swirls, restrained darker overlap bands and small soft warm highlights. It should read as sticky savory sauce, not chocolate, mud or burnt pancake.
Style/medium: simple clean 2D cartoon game texture matching the approved V8 large-flat-color baseline; large restrained color fields, at most base plus one darker overlap tone and one soft highlight tone, minimal detail, no photorealism.
Composition: uniform edge-to-edge material texture, orthographic top-down, no focal point, no container, brush, spoon, pancake outline, plate, griddle or background scene.
Tileability: all four edges must join seamlessly; avoid a central swirl, strong directional flow or unique edge marks.
Constraints: full square opaque RGB texture; no ingredients, sesame, scallion, chili pieces, bubbles, drips outside an object, text, letters, numbers, logo, brand or watermark; no black majority, plastic 3D gloss, sharp reflections, deep shadows, heavy gradients, photographic noise or dense microtexture.
```

## 定向简化提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake sweet flour sauce tileable RGB texture simplification
Input images: Image 1 is the sweet flour sauce texture edit target
Primary request: simplify only the surface rendering. Reduce the number and brightness of white glossy highlights by about 70 percent, reduce small curved ridges and brush streaks by about 55 percent, and merge them into broader flatter red-brown color areas. Keep only a few soft wide overlap bands and very restrained warm highlights so the result matches a simple 2D cartoon game rather than glossy realistic liquid.
Tileability invariant: preserve the seamless edge-to-edge square texture, uniform distribution and lack of focal point; do not add a central swirl, border or unique edge marks.
Absolute invariants: preserve the deep warm red-brown sweet flour sauce identity and full square opaque RGB format; keep no container, brush, spoon, pancake outline, plate, griddle, ingredients, sesame, scallion or chili pieces.
Constraints: no text, letters, numbers, logo, brand or watermark; no black majority, sharp reflections, plastic 3D gloss, deep directional shadows, photographic noise, dense microtexture or heavy gradients.
```

