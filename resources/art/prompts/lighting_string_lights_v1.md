# lighting_string_lights_v1

## 用途

P3 夜间灯串与轻微光晕独立层。全屏夜色应由 Godot 颜色遮罩实现，不烘焙进底板。

## 最终生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P3 evening-light independent full-frame decoration overlay, magenta chroma-key source
Input images: Image 1 is the exact 1671 x 941 workstation composition reference, used only to align the overlay; do not reproduce the stall.
Primary request: create only one tasteful warm string-light fixture layer for the upper stall band: a gently curved dark-brown cable spanning across the upper quarter, eleven evenly spaced small round bulbs, alternating warm cream and soft amber. Bulbs are lit with very restrained small flat-color halos. Add two tiny matching corner lamp caps aligned near the upper side walls. Keep customer center, signboard, order UI zones and all workstation interaction regions unobstructed.
Style: exact ProjectCake V8 simple hand-drawn 2D cartoon, bold deep-brown outlines, matte flat colors, one highlight, sparse readable shapes.
Composition: exact same broad 16:9-style full-frame canvas and framing as Image 1, but containing only cable, bulbs, halos and lamp caps.
Background: perfectly flat solid #ff00ff chroma-key edge to edge; no gradient, texture, stall, wall, counter or floor; do not use #ff00ff in the lights.
Constraints: no night sky, dark full-screen wash, lanterns, festival symbols, characters, UI, text, letters, numbers, logo, watermark, photorealism, glossy 3D or painterly scenery.
```

## 处理

- 使用技能自带 `remove_chroma_key.py` 抠图。
- 从高分辨率源图一次统一到 1671×941 运行画布。
