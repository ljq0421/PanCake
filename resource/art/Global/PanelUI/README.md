# 手绘 Panel 边框与手账装饰

2026-09-15 用户选定：01 通用纸卡用于主面板，03 轻量分组用于内部说明区；先在一个普通弹窗试装，确认实际效果后再推广。

## 当前接入

- `StartScreen.OpenModal("confirm")` 的“重新翻开一本旅行手账？”弹窗使用通用主面板。主面板 930×535，内部说明区在 v2 调整为 820×160、向下移 15px，为标题纸签留出间隔（1920×1080 设计坐标）。文字、按钮、存档处理和焦点逻辑沿用原实现。
- 天津 Demo 的首份教学面板及教学聚焦说明卡使用 `resource/art/TianJin/TutorialUI/teaching-panel-v1.tres` 和同目录按钮贴图，保留蒸汽点缀、暖金描边与深棕文字。2026-09-15 用户确认武汉教学聚焦说明卡也接入同款装饰卡片与贴图按钮：`WuhanTeachingUi` 复用原始贴图及九宫格，通过 `resource/shaders/wuhan_teaching_palette.gdshader` 映射为米白纸面、青绿装饰与墨绿描边，文字独立使用武汉配色。材质保留原图 alpha；按钮透明外沿不绘制默认矩形底板。教学步骤、聚焦目标、关闭本次与键盘焦点行为沿用原实现。

## 当前版本：胶带描边收细

用户最终确认：蒸汽碗使用 `bowl-stamp-v2.png`，保留 60% 不透明度、72×72 显示范围和 8° 旋转。其余确认 OK：主/分组边框、细描边胶带及浅色标题沿用下述版本。最终确认截图为 `preview-confirmed-bowl-v2-1280.png`。

标题与左上角现在共用 `corner-tape-v4.png`（256×63）。内置 imagegen 编辑 v3 绿底源图，收细深棕描边；在最终 256px 素材中央列测量，上下各约 5px 的深色描边收至各约 3px。透明像素 1881，半透明抗锯齿像素 811，绿色溢色为 0。完整编辑提示词及源图见 [生成记录](../../../../docs/art-concepts/panel-frames/tape-v4-prompt.md)。

标题仍保留 55% 局部浅色混合，小碗保留 60% 不透明度。没有推广到其他弹窗或城市。最终截图为 `preview-thin-tape-1920.png`、`preview-thin-tape-1280.png`、`long-message-thin-tape-1280.png`。

本轮完整构建 0 警告、0 错误，前轮 RecipeId 编译阻塞已不再出现。1920×1080、1280×720 的真实游戏弹窗专项均 `PANEL_PREVIEW_OK 20`，实际截图已检查；本轮覆盖了前轮尚未完成的浅色标题与淡化小碗完整游戏验收。

## 上轮调整记录：浅色胶带标题与淡化小碗

用户要求恢复小碗淡化，标题停用 `title-paper-v3.png`，改用颜色更浅的 `corner-tape-v3.png`。

- 标题直接复用胶带 PNG，用 NinePatchRect 固定左右各 50px，按 94px 高度等比显示两端，中段延伸至 670px 宽。
- `resource/shaders/panel_tape_lighten.gdshader` 将亮纸色向奶油色混合 55%，保留深暖棕描边及 alpha；不修改原 PNG，也不把整张素材变透明。左上角胶带继续使用原色。
- 小碗不透明度恢复 60%。
- 当前使用范围仍只有 `StartScreen.OpenModal("confirm")`，尚未推广到各城市页面。建议未来共享造型、纸面与描边，仅对标题/页签/装饰使用城市强调色；全局设置和跨城市确认弹窗维持通用暖色。城市配色没有在本次修改。

验证限制：完整 C# 构建被工作区已有的 `Scripts/Gameplay/PancakeWorkbenchFocus.cs` 第 43/70/81 行 `PreparedPancake.RecipeId` 不存在错误阻断，本次未改动该玩法文件。独立 Godot OpenGL 预览已验证实际 PNG、九宫格、着色器和淡化效果，截图为 `material-preview-v4-1280.png`；不将独立材质预览视为完整游戏弹窗验收。

## v3 历史装饰：粗线卡通修正

用户指出 v2 装饰与游戏整体粗线卡通画风不一致，当前替换为 `title-paper-v3.png`（768×116）、`corner-tape-v3.png`（256×64）、`bowl-stamp-v3.png`（256×263）。采用更粗的深暖棕轮廓、圆钝缺口和大色块；碗图案不再使用 60% 透明度淡化。胶带显示范围改为 `(480,270,135,45)`，其余位置沿用 v2。仍然只试装当前确认弹窗。

以实际游戏主/次级按钮作为风格依据，内置 imagegen 重绘；最终绿底源图和 [完整提示词](../../../../docs/art-concepts/panel-frames/decorations-v3-prompts.md) 保留于设计记录目录。三张素材抠图后绿色溢色均为 0，抗锯齿半透明像素分别为 2001、815、1331。最终截图保存为 `preview-v3-1920.png`、`preview-v3-1280.png`、`long-message-v3-1280.png`。

v3 验证：`dotnet build --no-restore` 0 警告、0 错误；1920×1080 与 1280×720 实际视口各 `PANEL_PREVIEW_OK 20`，正常/长提示、取消、Tab/Esc 均通过。最终截图已人工检查，确认标题、装饰与按钮无重叠。

## v2 历史装饰（已由 v3 替换）

在 v1 两款边框上叠加三张独立透明素材：

- `title-paper-v2.png`：768×108，标题纸签，显示范围 `(625,332,670,94)`。
- `corner-tape-v2.png`：256×55，左上角斜贴胶带，显示范围 `(475,270,145,52)`，旋转 −24°。
- `bowl-stamp-v2.png`：256×278，右下角蒸汽碗印记，显示范围 `(1320,702,72,72)`，旋转 8°、不透明度 60%。

三张素材保留宽高比，独立于九宫格边框，均忽略鼠标输入。标题保持可翻译文字，纸签中不烘焙文字。装饰的最终完整提示词及绿底源图见 [v2 生成记录](../../../../docs/art-concepts/panel-frames/decorations-v2-prompts.md)。内置 imagegen 生成后，使用同一抠图脚本分别指定 `-Width 768/256/256`；碗印记允许内部透明。

三张素材绿色溢色检测均为 0，半透明抗锯齿像素分别为 2068、777、2982。最终截图使用 `preview-v2-1920.png`、`preview-v2-1280.png` 与 `long-message-v2-1280.png`，保留 v1 对照图。v2 继续使用同一专项检查，实际视口覆盖 1080p/720p、正常与长提示、Tab/Esc 和取消操作。

## 素材与九宫格

| 用途 | PNG | 配套 StyleBoxTexture | 尺寸 | 四边切片 |
| --- | --- | --- | --- | --- |
| 主面板 | panel-main-v1.png | panel-main-v1.tres | 384×385 | 48px |
| 内部分组 | panel-group-v1.png | panel-group-v1.tres | 384×377 | 40px |

加载 `.tres` 并作为 Panel 或 PanelContainer 的 `panel` 样式。四角保持原尺寸，边段与中心使用 Stretch；不要把整张图用 TextureRect 直接拉伸。保留 PNG 原色，外部透明、纸面不透明，文字独立绘制。

主面板内容边距左/上/右 32px、下 36px；分组内容边距 20px。主面板使用时宽高应大于 96px，分组应大于 80px，并按文字量增加留白。此轮实际渲染覆盖宽面板 840×190、竖面板 360×520、小面板 310×170 及确认弹窗尺寸。

## 来源与复现

内置 imagegen 生成，依据已选定对照稿。最终提示词、概念稿、绿底源图和实际视口截图保存在 [设计记录](../../../../docs/art-concepts/panel-frames/prompts.md)。使用 `tools/prepare_panel_frames.ps1` 执行项目要求的绿底抠图、去溢色、裁切和等比缩小；不覆盖源图。

主款透明像素 2292、半透明抗锯齿像素 1521；分组透明像素 3500、半透明像素 1955。两者中心 alpha 为 255，检测到的绿色溢色均为 0。检查了深浅底上的轮廓与实际九宫格接缝。

## 验证

- `dotnet build --no-restore`：0 警告、0 错误。
- 真实 Godot .NET/OpenGL 视口，1920×1080、1280×720 各 `PANEL_PREVIEW_OK 20`（含截图检查）。
- 正常提示、损坏存档的长提示、取消按钮、Tab 焦点循环、Esc 返回与存档不变检查通过。测试使用工作区隔离存档。
- 命令：运行 `Scenes/Tests/StartScreenSelfTest.tscn` 并传入 `-- --panel-preview --capture`；720p 追加 `--small`。日志必须通过 `--log-file` 指向可写路径。
- 运行环境有默认 Godot 用户目录/着色器缓存访问受限与根证书读取提示；测试切换隔离存档后正常完成，损坏存档报错为测试构造。素材导入成功，图形截图和专项断言通过。

截图见 `docs/art-concepts/panel-frames/preview-1920.png`、`preview-1280.png`、`long-message-1280.png`、`nine-slice-1920.png`。此轮没有推广到其他弹窗或城市页面。
