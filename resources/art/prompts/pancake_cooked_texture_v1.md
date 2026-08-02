# pancake_cooked_texture_v1

## 用途

供 `resources/shaders/pancake_surface.gdshader` 的 `cooked_texture` 使用；提供正常熟化面饼的基础色与低频烘烤细节，熟度混合仍由运行时字段控制。

## 初次生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake seamless tileable cooked jianbing RGB surface texture for the shader uniform cooked_texture
Primary request: create a square seamless top-down texture of a normally cooked multigrain jianbing surface. Warm golden-tan base, restrained toasted speckles, small soft pores and a few broad irregular cooked patches. It should read as cooked and dry enough to fold, but not burnt, blackened or covered in toppings.
Style/medium: simple clean 2D cartoon game texture matching a bold flat-color street-food game—large restrained color fields, at most base plus one toasted shadow tone and one soft highlight tone, low-to-medium contrast, minimal detail, no photorealism.
Composition: uniform edge-to-edge material texture, orthographic top-down, no focal point, no directional lighting, no object silhouette, no pancake outline, no border, no plate, no griddle.
Tileability: all four edges must join seamlessly; distribute pores and toasted speckles evenly without a central hotspot or unique edge marks.
Constraints: full square opaque RGB texture; no raw wet batter pools, no heavy char, no sauce, egg, scallion or toppings, no text, letters, numbers, logo, brand or watermark; no 3D gloss, deep shadows, large bubbles, heavy gradients, photographic grain or high-frequency noise.
```

## 定向简化提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake cooked pancake shader texture simplification
Input images: Image 1 is the cooked pancake texture edit target
Primary request: simplify only the surface detail to match a clean flat 2D cartoon game. Reduce small pores, pinholes, toasted dots and micro-patches by roughly 60 to 70 percent. Replace dense high-frequency texture with broader smooth golden-tan color fields and a small number of soft irregular toasted patches. Keep enough sparse pores and speckles to read as cooked multigrain jianbing.
Tileability invariant: preserve a seamless edge-to-edge square texture and even distribution; no focal center, border, directional lighting or unique edge marks.
Absolute invariants: keep the warm golden-tan cooked color, normally cooked dry surface identity, full square opaque RGB texture; no raw wet batter pools, heavy char, black areas, sauce, egg, scallion, toppings, pancake outline, plate or griddle.
Style constraints: simple flat 2D cartoon material, at most base plus one toasted shadow tone and one soft highlight tone; no photorealistic pores, photographic grain, high-frequency noise, heavy gradients, text, letters, numbers, logo, brand or watermark.
```

