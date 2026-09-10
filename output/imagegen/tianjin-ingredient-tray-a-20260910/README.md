# 天津鸡蛋／香葱共用 A 型托盘

- 日期：2026-09-10
- 生成工具：内置 image_gen；未调用外部 API / CLI。
- 画风参考：`resource/art/TianJin/早餐铺风格锚点图-v5.png`
- 几何规则：`docs/天津托盘统一角度规则.md`
- 绿底定稿：`tray-a-green.png`（1254×1254）。
- 目标交付：512×512 RGBA 透明 PNG，空盘，用于鸡蛋／香葱。
- image_gen 去背景尝试返回了 RGB 棋盘格图片，未选为交付。用户已明确允许使用项目已有 PowerShell 脚本抠图、缩放。
- 交付：`resource/art/TianJin/鸡蛋香葱托盘-A型-v1.png`，512×512，Format32bppArgb，真实透明通道。
- 使用 `tools/prepare_tianjin_stock_ui.ps1` 去绿，`-Width 456` 输出 456×193 的 `tray-a-cutout.png`。将其按原尺寸放到 512×512 透明画布的 (28,159) 位置。
- 缩放后仅对半透明边缘进行残留绿色抑制：当 `G > max(R,B)` 时将 `G` 限制为 `max(R,B)`，保留 alpha；全透明像素 RGB 清零。
- 像素验证结果见 `qa.json`；深浅底目视检查图见 `qa-light-dark.png`。
- 未覆盖旧有通用托盘，也未修改场景或游戏逻辑。

## 首次生成提示词

```text
Use case: stylized-concept
Asset type: one reusable empty ingredient tray sprite for the Tianjin breakfast cooking game. This is Tray A shared by eggs and chopped scallions; draw ONLY the EMPTY tray, no ingredients.
Input image: the supplied breakfast shop illustration is a STYLE REFERENCE ONLY. Match its warm friendly hand-drawn 2D cartoon game art, dark brown slightly organic outlines, rounded shapes, cream and honey-ochre colors, restrained soft cel shading. Do not copy the scene or its round bowls.
Primary request: draw a single shallow rounded rectangular cream-yellow tray with a pale cream rim, warm pale golden interior, amber/ochre shallow exterior wall, and dark brown outline. Clean, spacious empty interior with simple structure, no handles or divisions. One tray centered and fully visible in a square canvas, intended final output 512 x 512.
Scene/backdrop: uniform solid chroma-key green #00FF00 across every background pixel. This green will be removed in a subsequent step. No ground plane, no ground shadow, no background gradient, no green reflections on the tray.
MANDATORY PERSPECTIVE from Tianjin production rules: ALL front and rear horizontal edges are horizontal at 0 degrees, within 0.5 degree; no sprite rotation. This tray is on the right half of a fixed game workbench: moving from its FRONT (lower on the image) to its REAR (higher on the image), BOTH depth sides move LEFT toward the scene center. Use an overall backward-left shear of about 5 degrees relative to the screen vertical, with only very mild taper: REAR edge width is 96% of FRONT edge width. Never make a symmetric isosceles trapezoid with two sides leaning in opposite directions, and never make the back edge move right.
Geometry guidance in a 512-square: virtual top-plane FRONT corners approximately (44,318) and (476,318); virtual top-plane REAR corners approximately (39,162) and (454,162). Round these corners elegantly. This makes top depth 156 px for width 432 px (~0.36), rear width 415 px (~96%) and the rear midpoint shifted 13.5 px LEFT (~5 degree overall shear). Draw the shallow FRONT WALL only about 27 px high below the front rim (~15% of the total object height). The interior is a shallow plate, not a deep box. Preserve horizontal front/rear edges and this leftward geometry above all.
Lighting/mood: warm soft light from upper left, subtle broad hand-painted cel shading, cream highlight on rim, simple amber occlusion inside, flat and readable at game icon size. Match the reference's illustrated linework rather than a photorealistic or plastic 3D render.
Constraints: exactly one EMPTY tray. No eggs, no scallions, no other food, no text, no letters, no watermark, no logos, no decorative pattern, no people, no scene elements. No checkerboard. Keep generous green space above and below the wide shallow tray. Crisp clean silhouette.
```

## 第一轮透视修正提示词

```text
Use case: precise-object-edit.
Edit the provided empty yellow tray. Keep its warm cream/yellow colors, dark brown outline, illustration style, shallow front wall, horizontal front and back edges, clean empty interior and solid chroma-green background.
CHANGE ONLY THE PERSPECTIVE. The current symmetrical trapezoid is WRONG. Make the tray top a NEAR PARALLELOGRAM SHEARED TO THE LEFT AT THE BACK. Looking UP the image from the near/front edge to the far/back edge, BOTH the left and right side edges must lean LEFT. The entire back half of the tray is shifted LEFT, not centered over the front half. The back edge must be almost the SAME WIDTH as the front edge: 96%, not the visibly narrowed back edge in the input.
Use these geometric construction points expressed in percent of canvas size for the rim top plane BEFORE rounding the corners:
far/back LEFT corner = (7.6%,31.6%).
far/back RIGHT corner = (88.7%,31.6%).
near/front LEFT corner = (8.6%,62.1%).
near/front RIGHT corner = (93.0%,62.1%).
Thus the far left corner is LEFT of the near left corner, and the far right corner is LEFT of the near right corner. Keep the four corners rounded, but do not change their perspective. The backward midpoint shift is 2.65% canvas width LEFT over 30.5% canvas depth, equivalent to a backward-left 5 degree shear. Horizontal edges are level, no overall rotation.
The back straight horizontal rim should extend almost as far left as the front, and its right end should visibly end to the LEFT of the front right end. Minimal trapezoid, maximum faithful mild left shear. Do not generate the symmetric trapezoid of the input again.
Keep one centered empty tray, no handles, no food, no patterns, no typography. Solid uniform green #00FF00 outside the silhouette. Output square image.
```

## 定稿透视修正提示词

```text
Edit this exact tray image. Make just ONE localized perspective correction: extend the BACK RIGHT corner about 90 pixels to the RIGHT in this 1254-by-1254 image, including the connected back rim, inner back wall, and right-side rim. Keep the BACK LEFT, FRONT LEFT, and FRONT RIGHT corners fixed. Keep all horizontal edges level. Do not shift the whole tray.
The rear edge is currently too narrow and the right depth side leans too strongly. The completed tray's rear width must be 96% of its front width. The back midpoint should be only 34 pixels left of the front midpoint, over about 390 pixels of depth: a subtle 5-degree overall backwards-left shear.
Ideal virtual top-plane corners in this input's 1254-square coordinates before rounding:
BACK LEFT (90,374), BACK RIGHT (1130,374), FRONT LEFT (100,763), FRONT RIGHT (1188,763).
Round the corners just like the input. These coordinates mean the left side is nearly vertical and the right side only slightly slanted. Both sides shift LEFT when going from front to back. This is almost a parallelogram, with minimal taper.
Keep the cream and honey-yellow cartoon artwork, all other details, shallow front wall, exact empty interior, and solid green backdrop. One tray. No new objects, labels or decorations.
```

## 去背景尝试提示词（未得到真实透明通道）

```text
Use case: background-extraction.
Remove ONLY the solid green background from this image and return an actual RGBA transparent-background PNG, exactly 512 x 512 pixels. Uniformly downsample the whole square image to 512 x 512; keep the identical framing and margins.
Preserve the tray exactly as drawn: its silhouette and proportions, subtle backward-left shear, level horizontal edges, colors, dark-brown outlines, cream rim, empty golden interior, shallow front wall, all shading and details. This is a clean cutout and resize, not a redraw.
Every pixel outside the tray must have alpha 0. Preserve antialiasing at the silhouette without any green fringe or green contamination. The tray itself stays fully opaque except fractional alpha on the antialiased silhouette boundary. Do not add a checkerboard pattern, white backdrop, gray backdrop, replacement color, floor, shadow, text or any objects. Deliver genuine transparency in PNG alpha.
```
