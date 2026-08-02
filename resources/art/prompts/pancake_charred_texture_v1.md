# pancake_charred_texture_v1

## 用途

计划供 `resources/shaders/pancake_surface.gdshader` 的 `charred_texture` 使用。现有 Shader 将其作为 RGB 焦化食物表面与熟面饼纹理混合，并非灰度遮罩。

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake seamless tileable overcooked jianbing RGB surface texture for the shader uniform charred_texture
Primary request: create a square seamless top-down texture of an overcooked to lightly charred multigrain jianbing surface. Deep golden-brown base, broad irregular dark-brown toasted patches, sparse near-charcoal speckles and a few short soft broken scorch streaks. It must clearly read darker and drier than the cooked texture while retaining visible brown food color rather than becoming mostly black.
Style/medium: simple clean 2D cartoon game texture, large flat color areas, at most a deep-brown base plus one darker scorch tone and one restrained warm highlight tone, low high-frequency detail, no photorealism.
Composition: uniform edge-to-edge material texture, orthographic top-down, no focal point, no circular pancake outline, border, plate, griddle, smoke or flame.
Tileability: all four edges must join seamlessly; distribute scorch patches without a dominant center or unique edge marks.
Constraints: full square opaque RGB texture; no raw batter, sauce, egg, scallion, toppings, holes or damage tears; no pure-black majority, no text, letters, numbers, logo, brand or watermark; no 3D gloss, deep directional shadows, photographic soot noise, heavy gradients or dense microtexture.
```

## 当前状态

截至 2026-08-01 共使用 Codex 内置 `image_gen` 请求十次。前八次未返回图片；第九次使用下方简化提示成功返回焦化候选；第十次针对“斑块过多、细节偏碎”进行精确简化编辑，但长时间无图片或错误返回后主动终止。第九次结果已作为有条件通过的正式候选入库，未改用 CLI/API。

## 第九次成功提示词

```text
Create a square seamless tileable texture for a 2D cartoon cooking game. Material: clearly overcooked Chinese jianbing surface, top-down and edge-to-edge. Use exactly three main color families: warm medium-brown dry base, broad irregular deep-brown toasted areas, and sparse muted near-charcoal scorch marks. Large simple color blocks, very low detail, matte, no gloss. The result must be substantially darker than a normal golden cooked pancake but still mostly warm brown food, not black or gray. Even distribution with no central focal point. All four edges must tile seamlessly.
Do not draw a circular pancake, rim, border, plate, pan, griddle, utensils, ingredients, sauce, holes, tears, flames, smoke, object shadows, dense noise, photorealistic crumbs, text, symbols, logo, brand, or watermark. Full square opaque RGB texture only, simple ProjectCake V8 flat cartoon style.
```

## 第十次定向简化提示词

```text
Use case: precise texture simplification edit.
Edit the input overcooked jianbing texture without changing its square dimensions, top-down view, seamless edge-to-edge coverage, warm brown palette, or overall charred material identity.
Simplify it strongly for the ProjectCake V8 large-flat-block style: merge the many dark blotches into only about 8 to 12 much larger, broad, softly irregular toasted regions across the entire tile. Remove most small brown flecks and nearly all tiny charcoal clusters; retain only 6 to 10 sparse small muted charcoal accents total. Reduce high-frequency mottling and make the warm medium-brown base calmer and more continuous. Preserve clear contrast from normally cooked golden batter, but make the result less visually noisy and less uniformly burned than the input. Keep at most three main tone families.
Maintain seamless tileability on all four edges with no unique edge feature or central focal point.
Do not add a circular pancake outline, border, plate, pan, griddle, ingredients, sauce, holes, tears, flame, smoke, gloss, directional shadows, text, symbols, logo, brand, or watermark. Full square opaque RGB texture only.
```

第十次编辑未返回图片，因此最终候选仍使用第九次结果。该候选颜色、视角和接缝指标通过，但深色斑块数量高于理想简化目标，需结合真实 Shader 和人工视觉继续确认。
