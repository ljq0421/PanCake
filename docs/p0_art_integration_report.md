# P0 现有美术素材接入与验证报告

> 日期：2026-08-01  
> 引擎：Godot 4.7.1 stable  
> 渲染器：Forward Mobile / D3D12

## 实际接入

- `pancake_raw_texture_v1.png` → `PancakeVisual` 的 `raw_texture`。
- `pancake_cooked_texture_v1.png` → `PancakeVisual` 的 `cooked_texture`。
- `pancake_edge_texture_v1.png` → `PancakeVisual` 的 `edge_texture`。
- `pancake_charred_texture_v1.png` → `PancakeVisual` 的 `charred_texture`；磁盘文件、清单 SHA-256 和 Godot 导入记录均已确认。
- `griddle_base_v1.png` → `SafeArea/PanBase/GriddleArtwork`，在 `PancakeSurface` 后方。
- `workstation_backplate_v1.png` → `SafeArea/BackgroundArtwork`，在交互内容后方。
- `workstation_front_lip_v1.png` → `SafeArea/ForegroundLip`，在动态内容前方、底部引擎 UI 后方，鼠标过滤为 Ignore。
- `batter_spreader_v1.png` → `PancakeSurface/SpreaderArtwork`，作为实际摊饼动作的旋转 Sprite2D。
- `batter_ladle_v1.png` → `LeftRack/LadleButton/Artwork`，显示在右侧六格托盘左上格，作为自动倒面入口。
- `batter_spreader_v1.png` → `LeftRack/ScraperButton/Artwork`，显示在右侧六格托盘右上格，作为摊饼器选择入口。
- `folding_spatula_v1.png` → `LeftRack/FoldButton/Artwork`，显示在右侧六格托盘左中格，作为折叠工具入口。
- `sauce_brush_v1.png` → `RightRack/SauceBrushButton/Artwork`，显示在右侧六格托盘右中格，作为酱刷入口。

两张酱料候选纹理未接入，因为 P0.4 仍只有单一酱料浓度场，没有酱料种类字段或双纹理 Shader 规则。焦化候选的清单状态仍为 `review-detail-density`，运行时已接入，但小尺度焦斑密度必须由真人确认。

## 场景与缩放

- `SafeArea` 继续是固定 1920×1080、按视口居中的安全区；背景在该区域内拉伸铺满，额外宽高由根 `Backdrop` 承接。
- `PancakeSurface` 控件保持 600×600，`PanBase` 保持 650×650；其中的实际操作域改为与正式鏊子一致的椭圆。
- `PanBase` 从基准画布 y=184 下移到 y=455，650×650 外框和 600×600 鼠标区均未缩小；正式鏊子的外圈完整位于长收款托盘下方，并与托盘保留可见间隔。
- 鏊子源图透明有效边界为 1055×732，场景使用 `Vector2(0.616114, 0.616114)` 等比缩放；输入、模型、Shader 遮罩和折叠统一使用 `pan_height_ratio = 0.694`。
- 前景桌沿按源图宽度等比缩放到约 1920 px，并通过 1920×1081 的 TextureRect 下移到 y=515，使不透明桌沿从鏊子外圈下方开始；它忽略鼠标，底部文字与状态仍由 Godot 绘制在其上方。
- 原 `Worktop` 节点保留但隐藏灰盒视觉；`LeftRack`、`RightRack` 的稳定节点名、按钮和信号均保留，但两个透明容器都定位到右侧六格托盘。
- 面糊勺、T形摊饼器、折叠铲和酱刷均使用保持宽高比的 TextureRect 完整收在右侧托盘前两行。四个父 Button 的矩形严格对应四个盘格，因此点击盘子任意位置都能选择该工具；左侧托盘不再有交互工具。
- 酱瓶不重复叠加新图：`SauceRefillButton` 的透明热区直接覆盖底板右上现有瓶体，保留“按住蘸酱”路径。按钮、状态、评分和提示文字仍由 Godot 排版。
- `BottomStrip` 压缩并下移到 y=1020，`SurfaceReadoutLabel` 合入同一前景状态带；完整600×600控件仍位于画布内，HUD位于实际椭圆操作域下方，不改变业务刷新或重置路径。

## T形摊饼器

- 倒面已简化为按钮动作：一次点击在鏊心生成固定面糊团并自动拿起摊饼器，旧的按住鏊面连续倒面路径已移除。
- 旧的任意方向直线刮动已替换为围绕鏊心、由内向外的螺旋摊饼。
- 输入按椭圆坐标归一化后判断曲线意图；最低圆周运动占比为 0.20，向内回摆容差为 16 格，并允许 4 个短暂偏向采样。纯放射状直推仍不写入模型。
- T形横杆长 54 格、接触厚度 10 格；推料沿 7 个近、中、远抹开点连续分配，手柄不接触面糊。
- 正式工具图以 `Vector2(0.27, 0.27)` 等比缩放，枢轴设在横杆与手柄的接触中心；鼠标、模拟采样点和横杆中心三者重合。该节点位于 `PancakeVisual` 之上、`PancakeFoldOverlay` 之下，切换或收回工具时同步显隐。
- 有效采样沿当前椭圆半径向外推料。速度继续进入模型：慢转摊开更充分、平均厚度更薄，快转作用减弱、饼皮更厚。
- 真人反馈确认原瞬时速度和逐帧径向转向过于敏感。现在按角速度而非随半径增长的线速度计算，使用 0.22 秒平滑、慢/适中/快三档和 0.4 rad/s 滞回；第二轮反馈后，横杆改为约 8° 转向死区、0.20 秒方向响应与 4.2 rad/s 最大转速，模型受力方向同步使用稳定角度。
- 后续反馈继续放宽手势判定到最低圆周运动占比 0.20、向内回摆 16 格和 4 个短暂偏向采样；从头到尾的纯直线外推依然不会摊开面糊。
- 自动螺旋基准覆盖 91.4% 可用鏊面；自动定量倒面的真实 Mobile 冒烟覆盖从中心面糊团的 14.2% 提升到 86.6%，总质量约 2,569。

## 自动验证

- `tools/run_checks.ps1`：全部通过。
- `tools/run_mobile_smoke.ps1`：通过；128×128 动态纹理，240 次上传平均 6.234 ms/次，静态内存增量 144.9 KiB，纹理 RID 复用；180 帧平均 16.39 ms，P95 16.84 ms。
- `tools/run_p0_5_smoke.ps1`：通过；180 个拖动帧脚本 CPU 平均 0.147 ms/帧，稳定渲染 P95 16.84 ms。
- 运行过程中仍出现 Windows 根证书存储读取警告，但三个命令退出码均为 0，未阻止纹理加载、Mobile 渲染或截图保存。

## 最新截图

- 正常制作：`tmp/validation/p0_art_production_latest.png`
- 刷酱：`tmp/validation/p0_4_latest.png`
- 折叠：`tmp/validation/p0_5_folded.png`

## 仍需真人确认

- 鏊子下移后，600×600控件的透明下部延伸到画布底部，但实际椭圆操作域位于HUD上方；需要真人确认长时间画外圈时手腕和鼠标可达性是否舒适。
- 正式生面、熟面和破边纹理在真实连续鼠标制作中的颗粒尺度、接缝和状态可读性。
- 无侧栏底色后，桌面物件的标签、酱料状态文字和悬停轮廓在不同显示器上的对比度是否足够。
- 右侧四个整格托盘点击区是否符合视觉预期，尤其是盘格间距附近和背景酱瓶的透明热区。
- 前景桌沿的高度是否既能形成遮挡层次，又不会让底部状态区显得拥挤。
- 正式焦化候选的小尺度焦斑数量高于目标简化风格，熟化到焦化区间的过渡和细节密度是否可接受。
- 真人实际画 2–3 圈时，T形横杆方向是否自然、直推无效提示是否足够及时、慢转与快转的厚薄差异是否容易控制。
- 正式 T 形工具当前按“横杆接触点跟随鼠标”校准，而非素材清单中的建议握柄末端枢轴；真人需确认这种控制映射是否比“鼠标握住柄端”更直观。
- 连续螺旋操作 10 分钟的手腕疲劳仍必须按 `tests/manual/p0_2_mouse_playtest.md` 验收。
- P0 总门槛的连续制作 20 张煎饼综合试玩仍未完成。
