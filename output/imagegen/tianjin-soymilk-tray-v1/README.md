# 豆浆托盘 v1

- 最终文件：`resource/art/TianJin/豆浆托盘-v1.png`
- 尺寸：512×512，RGBA PNG。
- 生成方式：内置 image_gen；先生成纯绿背景，再通过内置 image_gen 去除背景，最后使用 System.Drawing 等比缩小至 512×512。
- 风格参考：`resource/art/TianJin/早餐铺风格锚点图-v5.png`
- 角度规则：`docs/天津托盘统一角度规则.md`
- 结构辅助参考：`resource/art/TianJin/鸡蛋香葱托盘-A型-v1.png`
- 绿底定稿：`soy-tray-green.png`。
- 透明原尺寸定稿：`soy-tray-transparent-source.png`。

## 首次生成提示词

Use case: stylized-concept.
Create one production sprite for the Tianjin chapter of the supplied cozy 2D Chinese breakfast shop game. The supplied reference image is STYLE AND MATERIAL reference only. Draw ONLY the EMPTY small wooden SOY MILK SERVING TRAY seen at the right of that reference, remove all cups. No whole scene.
Style: faithfully match the anchor's warm honey/caramel brown wooden tray, thick dark warm brown outline, rounded corners, broad simple color regions, restrained soft cel shading and a few subtle warm highlights. Cheerful hand-drawn 2D casual cooking-game prop, low detail. Simple shallow raised rounded rim and uncluttered blank wooden interior. No metal, no realistic grain, no handles, no feet.
CRITICAL CAMERA / GEOMETRY: fixed tabletop screen-space weak perspective, right side of a game workbench. Front and back long edges perfectly HORIZONTAL (0 degrees); NEVER rotate the sprite. Both short depth edges lean to the LEFT when going from front to back, a shared LEFT shear approximately 6.5 degrees from screen vertical. This is a shallow near-parallelogram tray, NOT a symmetric trapezoid with its own vanishing point. Back edge nearly equal to front width; use virtually parallel depth edges so BOTH shear LEFT. Broad shallow top surface: visible top depth is 0.30 times tray width. Thin front wall is about 13 percent of total tray height.
On a 512x512 square canvas, approximate PLAN CORNERS before rounding: back-left (37,183), back-right (459,183), front-left (52,311), front-right (474,311). These unmarked construction coordinates enforce the leftward rear shear and level front/back edges. Front wall extends down about 20px. Draw this geometry naturally as a cohesive rounded wooden tray. Entire tray centered in canvas, complete and uncropped, generous clear padding above and below.
Background for this FIRST STEP MUST be perfectly uniform opaque bright chroma key GREEN RGB(0,255,0), not transparent and not black. No shadow on the green background, no glow, no green spill or green reflections inside the tray. Later the green will be removed. Output one square image, 512x512 if available. No cups, no drinks, no food, no markings, no slots, no circular recesses, no labels, no text, no border, no watermark.

## 透视修正提示词

Edit target: image 1, the brown empty tray on green. Image 2 is a STRUCTURAL PERSPECTIVE REFERENCE, a correctly sheared cream/yellow tray. Correct ONLY the geometry of image 1 to follow image 2.
The brown tray in image 1 is WRONG because its left edge slants opposite to its right edge. Change its outline to a shallow PARALLELOGRAM like image 2, BOTH side edges leaning the SAME direction. In the image plane the BACK/top of the tray shifts LEFT relative to the FRONT/bottom. The left edge runs from upper-LEFT to lower-RIGHT. The right edge ALSO runs from upper-LEFT to lower-RIGHT. Both depth edges about 6.5 degrees relative to vertical. The back-left corner MUST be farther LEFT than the front-left corner. The back-right corner MUST be farther LEFT than the front-right corner. Do not create any symmetric trapezoid. Do not make back edge much shorter. Keep the top and bottom long edges level horizontal, zero rotation.
Use image 2's outline geometry, but make the top surface slightly shallower (depth 30% of width). Keep the caramel-brown wooden material, dark brown outline, simple shallow rounded rim, warm highlights and blank interior from image 1, no yellow cream colors from image 2. Thin low front wall, about 13% of full object height. Preserve the square canvas, full tray centered, broad horizontal shape.
Keep solid opaque bright chroma GREEN #00FF00 background. No shadows on green, no text, no cups, no food, no handles, no feet, no added objects.

## 右侧纵深边修正提示词

Edit this brown tray sprite on green. Preserve its exact style, colors, left edge, horizontal front edge, framing and empty interior. Correct the RIGHT depth edge only: it currently slants much too much (about 17 degrees). Make the right depth edge PARALLEL TO THE LEFT DEPTH EDGE, both about 6 to 7 degrees from vertical, with the top leaning left very slightly. Achieve this by moving the UPPER RIGHT corner to the RIGHT, expanding the rear/top horizontal edge. The upper right must still be a little left of the lower right. All nested rim lines and inner right wall must follow this corrected right-edge geometry. Final overall top-plane shape is a near-parallelogram with left and right side edges parallel; the horizontal rear edge must be almost the SAME LENGTH as the horizontal front edge. Retain perfectly level horizontal long edges. Do NOT mirror the left edge to make a symmetrical trapezoid. Preserve left edge leaning upper-left to lower-right. The top and bottom are shifted laterally relative to each other. No added objects. Keep perfectly solid opaque bright green RGB 0,255,0 background, square canvas.

## 去背景提示词

Use case: background-extraction. Remove ONLY the bright green background from this completed brown empty soy milk serving tray sprite. Return a PNG with GENUINE TRANSPARENT BACKGROUND, actual alpha=0 outside the object, NOT a black or white filled backdrop and NOT a painted checkerboard. Preserve the brown tray EXACTLY: shape, parallel side edges sheared left toward the rear, horizontal front and back edges, warm brown palette, rim, outlines, highlights, interior, thin front wall, position and full uncropped square framing. Do not redraw or alter the tray. Clean antialiased alpha edges with no green fringe or halo. Remove all green background pixels. No cast shadow outside the object. Deliver a square 512x512 transparent PNG if possible.

