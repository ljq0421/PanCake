# 天津生油条空盘

- 成品：`resource/art/TianJin/生油条盘-左侧-v1.png`，512×512 RGBA PNG。
- 用户确认：空盘，生油条面坯作为独立素材。
- 制作方式：内置 image_gen 生成、逐步修正；按项目要求保留绿色背景原图，再用 Pillow 抠绿并等比缩至 512×512。不改游戏引用。
- 依据：`docs/天津托盘统一角度规则.md`、`resource/art/TianJin/早餐铺风格锚点图-v5.png`。同系列形制参考 `鸡蛋香葱托盘-A型-v1.png`。
- 绿色原图：`raw-youtiao-tray-green.png`；透明原尺寸：`raw-youtiao-tray-cutout.png`；检查结果：`qa.json`；深浅底检查：`qa-light-dark.png`。

## 选定成品的生成及修正提示词

### 同系列空盘左侧版本

对这张现有的空托盘素材做精确图像编辑，生成天津左侧“生油条盘”的空盘版本。
只需做两项修改：
1. 将托盘本身水平镜像翻转（左右翻转，horizontal mirror flip），不要重新想象成对称梯形。参考图左右两条纵深边从前往后都向左偏；镜像后必须从前往后都向右偏约5度，也就是图像中两条短边从下往上都略向右斜。后沿相对于前沿略向右错开，前后长边仍水平0度，绝对不要整体旋转。保留参考托盘的宽高比例、低矮盘壁、空白内底、圆角、奶油色边缘、金黄色外壁和深棕描边，风格和结构完全一致。
2. 将原本透明的背景全部填充为完全不透明的纯绿色 #00FF00。本次必须保留绿色背景输出，不要透明，不要抠图，不要渐变、桌面、投影。
输出单个空托盘，正方形画布。不得加入面坯、食物、文字、标记或其他物体。

### 弱透视修正

Precise perspective correction of this empty yellow tray. Preserve its colors, line weights, shading, low walls, horizontal long edges, green background, and empty interior. Change ONLY the top-plane perspective.

The top plane must be a shallow PARALLELOGRAM (parallel left and right short sides), tilted only very slightly right at the top. Make the BACK long edge EXACTLY THE SAME LENGTH as the FRONT long edge. Move the back edge exactly 28 pixels RIGHT relative to the front edge for a top-plane depth of 320 pixels in this reference-sized image. Consequently BOTH the LEFT outer short side AND the RIGHT outer short side rise upward toward the RIGHT by 5 degrees from vertical. The rear-right corner MUST be to the RIGHT of the front-right corner. The rear-left corner must also be to the RIGHT of the front-left corner by the SAME small distance. So both side rims should be approximately parallel, leaning like / but almost vertical. All internal tray lines follow this small same-direction shear.

Current image error: the left side leans too much and the right side is nearly vertical. Reduce the left side slant and make the right side slant slightly right going UP by the same amount. Eliminate convergence completely. Do not produce a trapezoid. Do not rotate the whole tray. Use small radiused corners, not huge curve distortions. It is a clean technical weak-perspective 2D game prop. Square canvas, center the whole tray with comfortable margins. Keep the perfectly flat opaque green #00FF00 backdrop; do not remove it. No new objects, no food, no text.

### 最后局部修正

Make a very small precise geometry correction to this tray. Keep everything except the LEFT depth edge exactly the same: same opaque green background, empty interior, golden yellow tray, dark brown outlines, centered square composition, horizontal front/back edges, front wall and right edge.

The LEFT sloping edge is too diagonal. Make it almost vertical. Shift ONLY the rear-left corner about 50 pixels LEFT in this 1254x1254 image, keeping the front-left corner in place. This widens the back long edge on the left. The long back edge must still be perfectly horizontal. The left short edge must now slant toward the RIGHT going UP by only 5 degrees, a very tiny tilt matching the near-vertical right side. Adjust the left inner rim consistently with this changed edge. Do not change tray height or the front edge. Do not make the left side steep. After correction both short edges should be nearly parallel and almost vertical with a slight rightward lean going upward. No symmetrical trapezoid. Flat opaque vivid green #00FF00 background, do not remove background. No new details or text.

