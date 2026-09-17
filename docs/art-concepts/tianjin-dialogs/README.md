# 天津弹窗试装 · 2026-09-16

当前范围（2026-09-17）：按照用户“将附件 1 的旧弹窗全部替换为附件 2”的要求，首页重新开始旅程、重置账本、显示设置确认、西安暂停及离开确认、通用跳转失败提示统一复用天津这套面板和按钮。武汉保留已确认的绿色同款面板。下文 2026-09-16 的“仅天津”描述为素材制作历史。

本次直接引用用户指定的 `TianJin/DialogUI` 与 `Global/StartPage/首页地图按钮底板.png`，未生成、重绘或修改素材。设计尺寸为 1200×630，长标题在标题牌两侧装饰之间自动缩小字号。首页弹窗沿用原文案、按钮顺序和取消焦点；西安保留三个操作，教学说明收起时按钮居中，展开时按钮与说明分列。

视觉依据：用户附件的奶油纸面、金色边框、深棕轮廓、云纹和标题牌。后续用户确认去掉整个右上角关闭按钮，并让面板外框和标题牌长边轻微弯曲。文字由 Godot 独立排版，不烘焙到图片。

## 素材

- 主按钮直接引用 `resource/art/Global/StartPage/首页地图按钮底板.png`，通过 AtlasTexture 裁掉半透明导出留白，原文件不变。
- 面板：`resource/art/TianJin/DialogUI/dialog-panel-v1.png`，1682×844。
- 次级按钮：`resource/art/TianJin/DialogUI/button-secondary-v1.png`，1815×459。
- 内置 image_gen 生成／编辑，依照项目流程生成纯绿底，再抠出透明背景。绿底源图为本目录 `panel-green.png`、`secondary-green.png`。
- 最终源图提取：面板全透明像素 245885、半透明像素 13734；次级按钮全透明像素 787341、半透明像素 2252。去除绿色溢色后可见绿边像素均为 0；最终边缘已在实际游戏截图检查。

2026-09-16 后续微调：用户要求横向弧度减小、纵向也增加少量弧度。面板和标题牌横向长边的弧度减弱，主面板左右边线轻微向外鼓起；布局尺寸、文字和按钮沿用已验证版本，仍无右上角关闭按钮。

## 生成提示词

最新微调：左右外弧进一步减弱，面板和标题牌的上下边缘均改为外弧，上边中央向上、下边中央向下。标题牌下边缘单独修正，以避免内凹。仍只应用天津。

本轮四边外弧编辑（内置 image_gen）：

> Precise contour-only edit of this game dialog asset. Keep the same canvas, framing, overall dimensions, composition, cream paper, warm gold bevel, dark brown hand-painted outlines, dashed seam, clouds, centered title plaque and two pastry ornaments. Requested corrections: 1) HALVE the current outward bow of the left and right main-panel edges. They should be almost vertical, with only a gentle 8-10px outward bulge at their midpoints relative to their ends, not the pronounced swollen sides currently shown. 2) Change ALL horizontal long edges of the main panel AND the title plaque to OUTWARD CONVEX arcs relative to each shape: TOP edge midpoint is slightly HIGHER on the image than its ends, BOTTOM edge midpoint is slightly LOWER on the image than its ends. The bottom edge must sag gently DOWNWARD in the center, NEVER curve upward into the paper. Use very subtle 8-10px bow for the main panel and 5-7px for the title plaque. Think of a very slightly inflated rectangular biscuit: all four sides expand away from its center. NO concave edges, NO ribbon bend, NO wavy edges, NO exaggerated balloon shape. Preserve existing rounded corners and line weight. Inner gold borders and dashed seam follow the same convex contours. Keep the large body area flat and blank for independently rendered text. NO close button, NO X, NO text, NO action buttons, NO new decoration. Entire exterior stays pure flat chroma green #00FF00.

标题牌下沿定向修正（内置 image_gen）：

> Edit ONLY the bottom contour of the small centered golden title plaque in this image. It is currently WRONG: its bottom edge rises upward at the center (a concave underside). Reverse this curvature. The underside must bow DOWNWARD at its center: at x~430 and x~1300 the plaque bottom brown outline should sit at y~211; at x~864 (middle) the same outline must sit at y~221, so the center is about 10 pixels LOWER than the two ends. This forms a gently convex pillow/biscuit shape with the TOP arching UPWARD and the BOTTOM arching DOWNWARD, thicker in the middle than at the ends. Follow the corrected bottom arc with the inner golden bevel and offset shadow. Keep the upper contour of title plaque unchanged. Keep the ENTIRE large panel, its curves, all other decoration, colors, composition, canvas size, green background exactly unchanged. Do not create text, X, buttons or other decorations. Outside remains pure flat #00FF00.

次级按钮（输入：用户指定主按钮）：

> Use case: precise-object-edit. Create the SECONDARY version of this exact Chinese cozy cooking game UI button. Keep the wide pill silhouette, thick dark chocolate brown outline, plump hand-painted bevel, simple cream highlight brushstrokes and warm bottom shadow. Change only golden yellow face to warm pale ivory cream (#FFF1D3), with soft biscuit beige bottom bevel. NO text, NO symbols. Single button centered, front view, wide landscape framing, roughly 4:1 button aspect, minimal padding. Production chroma key asset: background must be perfectly flat pure vivid green #00FF00, NO gradient, NO glow outside the outline, no green on the button. All pixels outside the button and small warm shadow are green. Match original art style closely.

面板初稿（输入：用户附件）：

> Use case: precise-object-edit. Extract and redraw ONLY the large illustrated game dialog panel from the reference as a clean reusable UI asset. Remove ALL text (title and message) and remove BOTH bottom buttons and their nearby yellow ray decorations. Remove the entire street/stall background. KEEP the large warm cream paper panel, rounded golden biscuit frame with thick dark chocolate hand painted outline and offset brown shadow, delicate dashed inner seam, pale cloud ornaments, attached raised centered golden title plaque with small yellow pastry/fan ornaments at its two ends. KEEP the circular cream-and-gold close button with dark brown X at upper right exactly like reference. Header plaque must be blank. The entire body must be clean empty cream space for separate game text and buttons. Match reference proportions: full panel about 1.9:1 width:height, title plaque centered about 60% of body width, overlapping top edge. Single front-facing panel fills canvas with small even padding. All outside pixels pure flat vivid green #00FF00 for chroma extraction, no scenery, no gradient in green, no exterior glow, no extra objects. High quality cozy Chinese breakfast game hand painted 2D UI. NO letters or words anywhere.

去除关闭按钮（输入：面板初稿）：

> Precise edit of this game dialog asset: REMOVE the entire circular close button including its brown X, golden rim, and shadow at the upper right. Reconstruct the uninterrupted rounded rectangular cream-and-gold panel corner and its dashed seam underneath, matching the left corner construction. Preserve everything else exactly: blank centered title plaque, its fan pastry ornaments, cream body, cloud ornaments, thick brown outlines, dimensions, composition and palette. Do not add any text or buttons. Keep the exterior solid pure #00FF00 green for chroma key extraction. Only change the upper right close-button area.

最终轻弧版本（输入：去掉关闭按钮后的面板）：

> Precise subtle contour edit to this existing illustrated game dialog. User requests a LITTLE curvature in the long edges of the main panel frame and the title plaque. Preserve overall layout, width/height, rounded corners, colors, hand-painted shading, fan ornaments, clouds, blank text areas, pure #00FF00 green exterior. Instead of ruler-straight long edges, make the main panel's upper and lower frame edges very gently bow in natural hand-drawn arcs, about 12-18 pixels deviation across full 1640px panel width. Make the title plaque's long edges gently curve similarly, about 8-12px bow across its width. The arcs should feel soft, plump, natural and subtle, NOT wavy, not a ribbon banner, not concave hourglass. Keep the body paper flat and spacious so text is not warped. Frame inner borders and dashed seam follow the gently curved outer contours. Only modest contour changes; no extra decorations. Absolutely NO close button, NO X, NO text, NO action buttons. Maintain the same size canvas and panel placement as reference.

最终横纵弧度微调（内置 image_gen，输入：上一版轻弧面板）：

> Precise contour refinement of the supplied game dialog asset. Preserve its exact overall size, aspect ratio, placement, palette, thick dark brown hand-painted border, gold bevel, pale cream interior, dashed seam, clouds and pastry ornaments. Make TWO small adjustments: (1) REDUCE the existing bow of the top and bottom horizontal edges of BOTH the main panel and title plaque to about HALF the current amount, roughly 5-8 pixels deviation at this source resolution, so these edges are almost straight but still organic. (2) Add a gentle continuous outward bow to BOTH vertical side edges of the MAIN PANEL: left edge curves 10-14 pixels farther LEFT at mid-height than at its upper/lower ends, right edge curves 10-14 pixels farther RIGHT at mid-height; symmetric softly plump sides, visibly curved across their whole height rather than just rounded corners. Also subtly soften the short vertical side edges of the title plaque with a 3-5px outward bow, preserving ornaments. Inner golden borders and dashed seam follow the same curves. Do not make an hourglass, wavy edge, balloon, strong arch or new decoration. Do NOT shrink the panel, alter its proportions, change its colors, or warp the flat body text area. NO close button, NO X, NO words, NO action buttons. Background must stay completely flat vivid chroma green #00FF00. Only these modest edge curvature adjustments.

## 验证

`dotnet build --no-restore`：零警告、零错误。

2026-09-17 最终验证：`Scenes/Tests/CityDialogVerification.tscn` 使用 Godot .NET 图形视口，1920×1080、1280×720，共 177 项检查通过。覆盖暂停冻结时间、取消恢复暂停菜单、Esc、Tab、确认返回、跳转错误提示、武汉绿色面板、西安教学展开／收起、尺寸稳定和换行幂等。真实截图位于 `.tmp/tianjin-dialog-art/verification/`。

`Scenes/Tests/StartScreenSelfTest.tscn -- --dialogs-only --capture`（以及 `--small`）两种尺寸各 26 项检查通过：重新开始、损坏存档长提示、重置进度、显示设置确认及超时恢复。截图位于 `.tmp/start-review/1920/`、`.tmp/start-review/1280/`；显示确认截图为切到全屏后的实际显示尺寸。全部使用隔离存档，损坏存档提示为测试主动构造。
