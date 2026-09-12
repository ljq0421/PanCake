# 武汉双勺棕色粗描边（2026-09-12）

使用内置 imagegen 编辑两张原勺素材，以 `武汉-热干面-豆皮-蛋液-v1.png` 为画风参考。先生成不透明绿色背景，再使用 `tools/prepare_wuhan_doupi_skin.ps1` 去绿，分别保存为 `doupi_ladle_v2.png` 和 `蛋液勺-透明-v2.png`。

两张素材保留原木柄、金属勺头、液体配色和朝向，加粗棕色外轮廓及勺口内缘。静置布局收进各自容器，动作复用新版素材。

## 缩小显示抗锯齿

两图保留 1254×1254 原始分辨率，导入时开启 `mipmaps/generate`，工作台使用 `TextureFilterEnum.LinearWithMipmaps`。实际显示宽度约 50～80 像素，需同时保留这两项设置，以避免勺口与柄边大幅缩小时出现锯齿。静置、拖动和倒入共用此过滤设置；无需重新生成图或改变容器内布局。

## 面糊勺最终提示词

Use case: precise-object-edit.
Asset type: small in-game ladle sprite for an existing cartoon Wuhan breakfast cooking game.
Input images: Image 1 is the edit target ladle. Image 2 is a supporting style reference only (the existing game workbench).
Primary request: Preserve the identity, pose, materials, colors, and silhouette proportions of the ladle in image 1, but make its DARK BROWN INK OUTLINES substantially thicker so they remain clearly visible when this entire object is rendered only 70 pixels wide. Match the bold warm brown outline style of the utensils and containers in the workbench reference.
Subject: exactly one silver round shallow ladle filled with pale cream bean-and-rice batter, orange-brown wooden handle pointing diagonally upper right, spoon bowl lower left.
Required change: consistent deep brown #4A2A16 chunky smooth outline around the entire outer silhouette, the rim ellipse and handle-to-metal connection. Outer outline thickness about 4 percent of the full object width (approximately 38 pixels at 1000-pixel object width); strong simple interior edges. Keep flat warm cartoon shading, restrained existing highlights. Make the rim readable without covering the liquid.
Background: solid perfectly uniform chroma key green #00FF00, fully opaque; green also in the handle hanging hole. No shadows on background, no checkerboard, no gradients or reflections of green. Keep all subject colors distinct from green.
Composition: square canvas, entire ladle visible with 10% clear green margins on all sides. Keep proportions from image 1. This is the standalone sprite only: do not include the reference workbench, any container, words, labels, letters, watermark, or extra objects.
Constraints: change only line weight to match existing game art; preserve spoon design and liquid identity. Do not make a large pot or enlarge the handle.

## 蛋液勺最终提示词

Use case: precise-object-edit.
Asset type: small in-game ladle sprite for an existing cartoon Wuhan breakfast cooking game.
Input images: Image 1 is the edit target ladle. Image 2 is a supporting style reference only (the existing game workbench).
Primary request: Preserve the identity, pose, materials, colors, and silhouette proportions of the ladle in image 1, but make its DARK BROWN INK OUTLINES substantially thicker so they remain clearly visible when this entire object is rendered only 70 pixels wide. Match the bold warm brown outline style of the utensils and containers in the workbench reference.
Subject: exactly one silver round shallow ladle filled with golden yellow beaten egg liquid, orange-brown wooden handle pointing diagonally upper right, spoon bowl lower left.
Required change: consistent deep brown #4A2A16 chunky smooth outline around the entire outer silhouette, the rim ellipse and handle-to-metal connection. Outer outline thickness about 4 percent of the full object width (approximately 38 pixels at 1000-pixel object width); strong simple interior edges. Keep flat warm cartoon shading, restrained existing highlights. Make the rim readable without covering the liquid.
Background: solid perfectly uniform chroma key green #00FF00, fully opaque; green also in the handle hanging hole. No shadows on background, no checkerboard, no gradients or reflections of green. Keep all subject colors distinct from green.
Composition: square canvas, entire ladle visible with 10% clear green margins on all sides. Keep proportions from image 1. This is the standalone sprite only: do not include the reference workbench, any container, words, labels, letters, watermark, or extra objects.
Constraints: change only line weight to match existing game art; preserve spoon design and liquid identity. Do not make a large pot or enlarge the handle.
