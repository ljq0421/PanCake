# weather_rain_v1

## 用途

P3 雨天独立叠加层；底板、角色、UI 和雨层分别渲染。

## 最终生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P3 rainy-weather independent full-frame overlay, magenta chroma-key source
Input images: Image 1 is the exact 1671 x 941 workstation composition reference, used only to align an overlay; do not reproduce the stall.
Primary request: create only a sparse stylized rain overlay for the fixed stall scene. Place clean pale-blue-gray diagonal rain streaks primarily in the upper background/customer zone, with a few small cartoon splash crowns along the awning top edge and outside far side margins. Keep the central customer silhouette zone, payment tray, central griddle area, ingredient wells, tools and bottom controls visually unobstructed. Rain must remain readable but not dense.
Style: exact ProjectCake V8 simple hand-drawn 2D cartoon, bold clean deep-brown accent outlines only where needed, flat pale blue-gray shapes, restrained detail.
Composition: exact same broad 16:9-style full-frame canvas and framing as Image 1, but containing only weather marks.
Background: perfectly flat solid #ff00ff chroma-key edge to edge; no gradient, texture, floor, stall, wall, counter or reflection; do not use #ff00ff in the rain marks.
Constraints: no cloud, lightning, umbrella, character, building, food, UI, text, letters, numbers, logo, watermark, heavy fog, photorealism, glossy 3D or painterly background. No large opaque wash.
```

## 处理

- 使用 `remove_chroma_key.py --edge-contract 1` 清理品红边缘。
- 从高分辨率源图一次统一到 1671×941 运行画布。
