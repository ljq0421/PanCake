# 天津成品盘

- 画风参考：`resource/art/TianJin/早餐铺风格锚点图-v5.png`
- 透视规则：`docs/天津托盘统一角度规则.md`
- 生成工具：内置 image_gen。
- 交付要求：512×512，真实透明 PNG，空盘；横边水平，纵深向后左偏约 4°，顶面深宽比 0.28～0.32。
- 绿底候选：`tray-green.png`。
- 去背景尝试输出为 RGB 棋盘格，未作为交付。

## 初始生成提示词

```text
Use case: stylized-concept.
Create ONE new standalone 2D game sprite: an EMPTY finished-food serving tray (天津成品盘), for a cozy Chinese breakfast-shop management game. Canvas 512x512, square. This first pass MUST have a perfectly uniform vivid chroma-green background #00FF00, opaque, absolutely no gradient or ground shadow. The green will be removed in the next step.

STYLE REFERENCE: the breakfast-shop anchor image already shown in this conversation, 早餐铺风格锚点图-v5.png. Match its friendly hand-drawn 2D cartoon language: bold dark warm-brown outlines, large simple warm color areas, softly rounded corners, restrained highlights, very low detail, cream and caramel/ochre wooden utensil colors. Use the existing serving tray only as context for an empty low-sided warm wooden tray; correct its old perspective according to the numeric rules below. NOT photorealistic, not 3D, not glossy plastic or metal.

SUBJECT: one clean empty shallow horizontal rounded-rectangle wooden serving tray, low broad rim, spacious flat clear interior, light honey/cream interior, warm caramel outer front wall and warm pale ochre rim. Minimal wood detail, at most two faint broad horizontal grain accents. No handles, no feet, no food, no drinks, no contents, no compartment divisions, no slots, no text, no symbols. No glow, no external drop shadow.

CRITICAL PERSPECTIVE from 天津托盘统一角度规则.md:
- Entire sprite rotation zero. ALL front and rear horizontal edges perfectly level (0 degrees).
- Right side of a workbench, so BOTH left and right depth edges lean LEFT going from front to back, approx 4 degrees from screen vertical. Both must slope in the SAME direction, a subtle left-sheared parallel perspective, NOT a centered symmetrical trapezoid.
- Top surface depth / tray width = 0.30 (allowed 0.28-0.32), distinctly shallow in the image, NOT a tall open box or a top-down rectangle.
- Back and front edges nearly equal length, near-parallel weak perspective.
- Useful guide on a 512 canvas BEFORE rounding: back-left (31,181), back-right (469,181), front-left (40,312), front-right (478,312). This gives 438px horizontal width, 131px visible depth, and 9px leftward displacement towards the back, i.e. ~4 degrees. Front wall continues down only to about y=333. Round the corners gently while retaining these implied straight edge directions. These numbers are construction guidance, do not draw numbers or guides.
- Inner tray contour follows the SAME perspective as outer contour.
- Front wall thin and low, about 12-16% of total subject height, not boxlike.
- Full tray centered vertically and horizontally on the square canvas with generous empty green space above and below. Entire outline visible, no cropping.

FINAL IMAGE: just this ONE empty warm cartoon shallow tray on solid #00FF00. No surrounding breakfast shop, no table, no props, no labels, no borders, no checkerboard.
```

## 透视修正提示词

```text
Use case: precise-object-edit.
Edit the FIRST image, the empty wooden serving tray on green. The SECOND image is a supporting PERSPECTIVE REFERENCE: its left and right depth sides lean left towards the back. Match that kind of geometry while keeping the FIRST image's warm wooden tray colors and style.
CHANGE THE TRAY GEOMETRY ONLY. The first image's symmetric narrowing toward the back is incorrect. Make the top face nearly a PARALLELOGRAM: extend its back-left corner far to the LEFT, also extend its back-right corner to the RIGHT, so its BACK EDGE IS AS WIDE AS ITS FRONT EDGE. Shift the entire BACK edge just slightly LEFT of the front edge. Both side edges must point slightly LEFT when followed toward the back (up the image). Keep the front and rear edges PERFECTLY HORIZONTAL.

Use these target virtual corners as percent of the whole square canvas (before rounding):
BACK LEFT: x=6%, y=35%.
BACK RIGHT: x=92%, y=35%.
FRONT LEFT: x=7.8%, y=61%.
FRONT RIGHT: x=93.8%, y=61%.
Front wall bottom y=65%.
Thus the two horizontal edges are BOTH 86% canvas wide and the back is 1.8% canvas LEFT of the front. Top depth is 26% canvas, 30% of tray width. This is a ~4 degree back-left shear.
Round the corners softly. Apply the same geometry to the recessed interior and rim. Make the front wall low and shallow, ONLY 4% canvas high, not the input's thick wall.
Keep one empty tray centered on a perfectly flat pure green #00FF00 background. Preserve the light honey interior, caramel-brown exterior, warm cream rim highlights, dark-brown outline, simple cartoon coloring. No added objects, food, handles, text, guide lines, numbers, shadows, checkerboard or labels. Square canvas.
```

```text
Edit this tray. Correct ONLY its top-plane perspective by MOVING ITS TWO BACK CORNERS. Keep the FRONT LEFT and FRONT RIGHT corners fixed.
The back edge is still too narrow.
1. Move the BACK LEFT corner 45 pixels LEFT.
2. Move the BACK RIGHT corner 85 pixels RIGHT.
3. Move the entire back rim 55 pixels UP to slightly increase the visible top surface depth.
Modify the connected side rims and inside contours consistently.

On this 1254x1254 input, exact target implied sharp top-plane corners BEFORE rounding:
BACK LEFT (45,403), BACK RIGHT (1155,403).
FRONT LEFT (68,733), FRONT RIGHT (1178,733).
These are two EQUAL 1110px-wide horizontal edges. Back top depth is 330px, which is 30% of its width. Back is exactly 23px LEFT of front (~4 degrees). BOTH sides run down and slightly RIGHT. No symmetrical taper. No opposite slant on the left edge. Do not rotate the image.
Smooth rounded corners, but do not let rounding change the implied straight-edge geometry.
The front wall below the front rim should only be 47 pixels tall (bottom remains y=780). Keep it shallow. Preserve the light honey empty wooden interior, cream rim, caramel outer wall, dark-brown cartoon outlines, overall graphic style, centered square canvas and SOLID GREEN background. Keep everything else. No added objects or text.
```

## 去背景尝试（未得到透明通道）

```text
Use case: background-extraction.
Prepare this empty wooden game tray for delivery as a genuinely TRANSPARENT RGBA PNG, 512x512 canvas.
First correct two small rim geometry errors: extend the rear-left corner LEFT by 50 pixels, and extend the rear-right corner RIGHT by 45 pixels in the 1254-pixel input. Preserve the front edge in place. The resulting two long depth edges must both slope DOWN AND RIGHT, as in a near-parallelogram. Front and back long horizontal edges stay exactly horizontal. This gives a subtle overall backward-left 4 degree shear. Keep the whole tray centered.
Then remove ALL green background to actual zero-alpha transparency. No checkerboard pixels, no white background, no replacement background.
Preserve all illustrated artwork: same empty light-honey wooden interior, cream edge highlights, shallow caramel front wall, warm brown outlines, simple warm 2D cartoon style. No new design details. The tray stays fully opaque, only silhouette antialiasing may have fractional alpha. No green fringe. Output exactly 512x512.
```

