# signature_recipe_panel_base_v1

## 用途

P3 招牌配方展示空白底板；配方名、成品图、配料图标、品质章与说明均由 Godot 填充。

## 最终生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P3 signature-recipe showcase panel base, magenta chroma-key source
Input images: Image 1 is the current ProjectCake day-summary panel used only as border language, line weight, palette and flat rendering reference.
Primary request: create one prestigious but handmade blank signature-recipe showcase panel. Warm cream parchment body, deep-brown bold outline, carved dark-teal and warm-brass frame. Include one completely blank centered recipe-name plate at top, one large circular empty hero-food window in the left-center, six small empty ingredient medallion recesses arranged in two rows on the right, one empty quality-seal recess near the lower right, and one wide blank notes strip across the bottom. All areas must remain empty for Godot-rendered content.
Composition: single centered landscape panel with generous padding, clean silhouette, no baked shadow.
Style: exact ProjectCake V8 simple 2D cartoon UI, matte flat colors, one shadow and one highlight maximum, celebratory but not ornate palace luxury.
Background: perfectly flat solid #ff00ff chroma-key edge to edge, no gradient, texture, floor or reflection; do not use #ff00ff in the panel.
Constraints: no pancake image, ingredient image, star, crown, ribbon text, letters, numbers, logo, brand, watermark, cast shadow, glow, photorealism, glossy 3D, thin outlines or painterly texture.
```

## 处理

- 使用技能自带 `remove_chroma_key.py` 抠图。
- 面板内部保持空白，不含 AI 文字。
