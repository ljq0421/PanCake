# 天津工作台动态素材记录

2026-09-15。使用内置 **imagegen**，未使用 API/CLI 生图。

## 来源与处理

- 编辑参考：`resource/art/TianJin/天津-煎饼-炸锅-豆浆-v2.png`，1672×941。
- 最终绿底稿：[sprites-green.png](sprites-green.png)。首次分离稿被工具输出为透明图，因此追加明确的纯绿色、不透明背景指令，再执行去绿；没有把首次透明稿直接当最终素材。
- 干净底图生成稿：[clean-generated.png](clean-generated.png)。首次生成仍有工具残留，第二次只纠正两只工具托盘内面。
- 制作脚本：`tools/prepare_tianjin_living_art.ps1`。用 System.Drawing 去绿、消除绿色边缘、按不透明范围裁切。挂件 372×845，刮板 661×266，铲子 662×207；均有透明边缘与部分 alpha 像素。
- 正式文件位于 `resource/art/TianJin/LivingWorkbench/`：三张 `*-clean.png`、`pendant.png`、`scraper.png`、`spatula.png`。导入启用 mipmaps 和 alpha 边缘修复。
- 三阶段分别从各自原图复制，**只转移两个已授权局部**：源坐标挂件区域 `(1213,65,141,273)`，工具区域 `(1115,503,371,71)`；边缘 4 px 混合。区域外保留原图像素。原背景没有覆盖。
- 挂件、工具以独立节点叠回原位置。旧挂件轮廓继续提供固定点击检测，新 alpha 图层提供悬停轮廓，跟随挂件旋转。
- 已检查实际 1080p、720p：无绿色底、透明孔洞保留、取走工具后槽位为空。静态底图和新增层不参与业务判定。

## 实际提示词

### 1. 背景清理

Edit target: attached 1672x941 game background. Precise object removal for animation clean plate. Keep EXACT same canvas, viewpoint, illustration, color, every other pixel detail and object positions. Remove ONLY (1) the hanging orange wooden money pouch with red flower, red suspension cords, bottom tassel at x1215-1348 y48-330; retain the small fixed wall hook at top and repaint the wood pillar, tree/window behind the removed pouch seamlessly; (2) the T-shaped wooden pancake scraper at x1138-1275 y505-557; retain its rectangular wooden resting tray and repaint the tray surface under the scraper; (3) metal spatula at x1324-1464 y512-555; retain its rectangular wooden resting tray and repaint surface. Both trays remain separate unchanged, EMPTY. No other removals, no redesigned art. All food trays, fryer, tongs, stove, bowls, awning, trash unchanged. Produce one clean background image. Save output locally.

### 2. 分离素材参考稿

Create game sprite extraction sheet from reference. Solid pure chroma green #00FF00 background. Exactly THREE separate objects, large and well separated with generous green margins: LEFT original orange wood money pouch with red flower design, red suspension cords converging at top attachment, brass bead and bottom red tassel (do not include wall hook); TOP RIGHT original T-shaped wood pancake scraper; BOTTOM RIGHT original silver metal pancake spatula with brown handle. Copy exact original silhouettes, orientation, colors and hand-painted cartoon thick warm brown outlines from attached image. Money pouch upright, tools horizontal as in reference. No tray, no wall, no text, no shadows outside objects, no new design, no additional objects. Intended for transparent sprite extraction.

### 3. 纠正为绿底

Only change background: composite this exact three-object sprite sheet on a completely opaque solid bright green RGB(0,255,0) background. Green must fill the whole image including gaps between suspension cords. DO NOT output transparent alpha. No checkerboard, no black background. Keep all three objects exactly same size, position and artwork. This is explicitly a green-screen image, NOT a transparent extraction. Output opaque RGB green-screen PNG.

### 4. 工具槽底图纠正

Precise tiny correction only, keep full 1672x941 image unchanged outside two tool resting trays. Both small horizontal wooden trays above ingredients (x1118-1295,y510-572 and x1310-1482,y510-572) must have perfectly EMPTY flat warm wood interiors, matching their existing shadows and rims. Remove the narrow rounded horizontal wooden bar still present INSIDE EACH tray; these are leftover tools and should NOT be there. Keep tray OUTER RIM and perspective exactly. Fill interior with plain uninterrupted shaded wooden surface. Everything else same.

## HUD 材质

现有天津挂签图通过 `tianjin_sign_paper.gdshader` 仅对底板纹理暖化与减轻边饰对比；独立文字、图标与 alpha 不受影响。没有替换共享底板资源，武汉、西安不启用该材质。
