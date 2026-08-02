# pancake_raw_texture_v1

## 用途

供 `resources/shaders/pancake_surface.gdshader` 的 `raw_texture` 使用；提供未熟面糊的基础色与低频表面细节，覆盖度、厚度和湿度仍由运行时字段控制。

## 初次生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake seamless tileable raw multigrain batter RGB surface texture for the shader uniform raw_texture
Primary request: create a square seamless top-down texture of freshly spread Chinese multigrain jianbing batter before cooking. Warm pale cream-beige base, very subtle tiny grain flecks, a few faint soft wet patches and restrained broad spreading streaks. Low contrast so the game's coverage, thickness and wetness fields remain readable.
Style/medium: simple clean 2D cartoon game texture, large restrained color fields, at most base plus one gentle shadow tone and one soft highlight tone, minimal detail, no photorealism.
Composition: uniform edge-to-edge material texture, orthographic top-down, no focal point, no directional lighting, no object silhouette, no border, no pancake edge, no plate, no griddle.
Tileability: all four edges must join seamlessly; avoid large unique marks near edges, avoid a bright or dark center, distribute subtle grain evenly.
Constraints: full square opaque RGB texture; no cooked brown areas, no char, no sauce, no egg, no toppings, no large bubbles, no text, letters, numbers, logo, brand or watermark; no 3D gloss, heavy gradients or photographic grain.
```

## 定向简化提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake raw batter shader texture simplification
Input images: Image 1 is the raw batter texture edit target
Primary request: simplify only the surface detail to match a clean 2D cartoon game. Reduce the density of tiny grain dots, small flecks, wet streaks and micro-highlights by roughly 50 to 60 percent. Merge nearby detail into broader soft flat color areas. Lower local contrast while preserving the warm pale cream-beige batter color and a small restrained amount of multigrain flecks.
Tileability invariant: preserve the seamless edge-to-edge square texture and uniform distribution; do not create a focal center, border, directional light or unique edge marks.
Absolute invariants: keep a full square opaque RGB texture; keep the same raw uncooked batter identity; no cooked brown areas, char, sauce, egg, toppings, large bubbles, pancake outline, plate or griddle.
Style constraints: simple flat 2D cartoon material texture, at most base plus one gentle shadow tone and one soft highlight tone; no photorealistic wet gloss, photographic grain or high-frequency noise; no text, letters, numbers, logo, brand or watermark.
```

