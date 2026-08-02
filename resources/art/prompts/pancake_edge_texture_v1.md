# pancake_edge_texture_v1

## 用途

供 `resources/shaders/pancake_surface.gdshader` 的 `edge_texture` 使用。Shader 只采样红通道，并用它调制运行时覆盖场所确定的饼边明暗；本图不是透明破洞遮罩。

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake seamless tileable grayscale edge-detail texture for the shader uniform edge_texture; only the red channel is sampled to vary pancake rim darkening
Primary request: create a square seamless top-down low-frequency grayscale texture for irregular jianbing edge variation. Use a medium-light warm gray base with a small number of broad soft darker patches and sparse short broken darker marks, so generated pancake rims read slightly uneven and toasted without becoming torn or noisy.
Style/medium: simple flat 2D cartoon game texture matching the approved V8 large-color-block style; broad restrained shapes, at most three grayscale values, crisp but softly irregular marks, no photographic material detail.
Composition: uniform edge-to-edge abstract material map, no focal point, no circular pancake outline, no standalone object, no border or transparent area.
Tileability: all four edges must join seamlessly; no dominant center, radial pattern or unique edge mark.
Technical constraints: full square opaque RGB image carrying equivalent grayscale values in R, G and B; keep most values medium to light so the Shader's mix(0.62, 0.82, edge_detail) remains controlled; no pure-black majority, no color tint, no alpha mask, no holes, no food toppings, no griddle, no text, letters, numbers, logo, brand or watermark; no gradients, directional lighting, dense noise or photographic grain.
```

## 检查说明

生成结果带轻微暖灰偏色，但现有 Shader 只采样红通道，因此不会把色偏带入画面。未做通道重写或调色，以保留内置生成源的可追溯性。

