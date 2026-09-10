# 天津薄脆／火腿共用 B 型空托盘

- 日期：2026-09-10
- 绘制工具：内置 image_gen。
- 画风参考：`resource/art/TianJin/早餐铺风格锚点图-v5.png`
- 同系列造型参考：`resource/art/TianJin/鸡蛋香葱托盘-A型-v1.png`
- 角度规则：`docs/天津托盘统一角度规则.md`
- 生成约束：横边水平、纵深向后左偏约 8°、轻微透视收窄；单只空盘，共用于薄脆和火腿。
- 绿底定稿：`tray-b-green.png`（1254×1254）。
- 按项目要求先生成绿底，再使用现有 `tools/prepare_tianjin_stock_ui.ps1` 在 Windows PowerShell 5.1 下抠图和等比缩放。
- 抠图主体：`tray-b-cutout.png`（456×168），置于 512×512 透明画布 (28,172)。
- 最后仅清理半透明边缘的残留绿色，并清零全透明像素 RGB；未对生成图做额外透视变形。
- 交付：`resource/art/TianJin/薄脆火腿托盘-B型-v1.png`（512×512 RGBA PNG）。
- 检查：真实 alpha 通道、四角透明、盘内不透明、无残留绿色像素；深浅底目视检查通过。详见 `qa.json`、`qa-light-dark.png`。

## 首次生成提示词

```text
Use case: stylized-concept.
Create ONE production game sprite: the EMPTY shared B-type ingredient tray for holding either crispy wonton sheets (薄脆) or ham (火腿), for the Tianjin breakfast stall game. No ingredients in it.
Reference image 1 is the original breakfast-stall art STYLE anchor only: warm hand-painted 2D casual mobile-game cartoon, bold warm dark-brown outlines, rounded forms, cream and honey-gold palette, soft restrained highlights, readable when small.
Reference image 2 is the existing A-type tray DESIGN MASTER. Preserve its exact cream-colored rim, honey-gold outer front wall, pale warm cream inner floor, rounded rectangular shape, simple uninterrupted open basin, outline thickness, shading language, relative wall height and scale. Derive a matching B-type sibling, changing only its depth perspective from leftward 5 degrees to leftward 8 degrees.
GEOMETRY IS ESSENTIAL: Front and back long edges are exactly horizontal (0 degrees). This tray belongs at the far RIGHT of the game counter. Viewed from the front toward the back, BOTH side depth edges lean LEFT together, about 8 degrees relative to image vertical. The whole back edge midpoint is slightly LEFT of the whole front edge midpoint. Do NOT produce a symmetric trapezoid. Do NOT rotate the sprite. Back width is 96% of front width. Top surface projected depth is 35% of the front width. Front outer wall height is 14% of total object height. Shallow tray, not a storage box.
On a 512x512 composition the front rim corner centers would be approximately (57,312) and (475,312), and rear rim corner centers approximately (45,165) and (446,165); rounded corners should flow naturally from those edges. Use these as perspective constraints, not visible markings. Entire object centered with generous empty space above/below, width about 450px, similar framing to reference 2.
BACKGROUND for chroma key: flat uniform pure vivid green #00FF00, no texture, no vignette, no cast shadow outside the object, no green reflections or green tints on the tray. Sharp clean anti-aliased silhouette. Fully contained, unclipped object. Square canvas. Intended final export 512x512.
No food, no crumbs, no dividers, no handles, no feet, no utensils, no labels, no writing, no watermark, no tabletop, no scene.
```

## 比例微调提示词

```text
Use case: precise-object-edit.
Make ONE geometry refinement to this exact green-background tray sprite, preserving all colors, cream rim, honey-gold walls, brown outline, clean empty interior, rendering style, and flat pure-green background.
The TOP SURFACE needs a slightly greater visible depth, and the FRONT WALL needs to be shallower, to match the approved Tianjin ingredient-tray geometry. Keep all front/back edges perfectly level.
Use these approximate construction points on this input's 1254-square canvas, before rounding its corners:
BACK LEFT (63,378), BACK RIGHT (1142,378);
FRONT LEFT (95,766), FRONT RIGHT (1219,766);
bottom of front exterior wall at y=827.
These yield a back width 96% of front width, top depth 34.5% of width, midpoint offset 54.5 pixels LEFT from front to back (8 degrees from image vertical), and a front-wall height about 14% of the total object height.
Both depth sides must go LEFT when going from front toward back. The back midpoint is left of the front midpoint. Near parallelogram with only tiny taper, not a symmetric trapezoid. Keep its round corners and cream rim. Overall tray may be shifted a few pixels left to keep comfortable margins, but do not rotate it.
Keep the exact same design as the input; do not add texture, decorations, food, shadows outside its silhouette, text, handles, or other objects. The outside is uniform vivid green #00FF00 for subsequent cutout. Square canvas.
```

