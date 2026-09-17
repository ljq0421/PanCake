# 武汉章节弹窗 · 2026-09-17

沿用已确认的天津面板轮廓：左右边缘轻微外弧，上下边缘向外弯曲，标题牌同样保留外弧；无右上角关闭按钮。文字使用 Godot 控件独立排版。

用户确认范围：青绿配色仅用于武汉章节内部的暂停、放弃／返回确认和跳转失败提示。主页面、地图及其跳转提示保留原有暖色，不按目标城市染绿。西安不推广本套素材。

## 素材与接入

- 面板：`resource/art/Wuhan/DialogUI/dialog-panel-v1.png`，1684×844。
- 主按钮：原有 `resource/art/Global/StartPage/首页地图按钮底板.png`，保持金色。
- 次级按钮：复用 `resource/art/TianJin/DialogUI/button-secondary-v1.png` 的米白版本。
- 面板青绿 `#387F70`，轮廓墨绿 `#24594F`，纸面米白 `#F7F3E8`；正文沿用武汉文字色 `#293E36`。
- 共享实现：`Scripts/UI/IllustratedCityDialogTheme.cs`；跳转提示由 `GameController.ShowNavigationError` 根据当前页面选择配色。

## 生成记录

内置 image_gen，以已确认的天津面板为参考，仅调整武汉配色。依项目要求先生成纯绿背景，再提取透明背景并检查实际游戏中的边缘。绿底原稿保存在本目录 `panel-green.png`；最终提取包含 245193 个全透明像素、3039 个半透明像素。

提示词：

> Precise COLOR-ONLY edit to this approved Chinese cooking game dialog panel, for the Wuhan chapter. Preserve the exact silhouette, gentle OUTWARD convex curves on all four sides, title plaque silhouette with top bulging up and bottom bulging down, rounded corners, line weights, dimensions, layout, ornaments, clouds, seam, shading style and blank areas. Change golden yellow frame/bevel to soft jade/teal green: base #387F70, highlighted edges #A8DCC7, softer midtones #76B9A4. Change dark brown outlines and shadows to dark forest/ink green #24594F (darkest #173E35). The large body stays warm ivory #F7F3E8, not green. Title plaque interior remains pale ivory, with very light mint edge tint. Small fan ornaments become pale mint/jade with deep green outlines. Dashed seam and cloud decorations use very pale desaturated sage with low contrast. Do not recolor the exterior chroma background: preserve pure flat vivid #00FF00 outside the panel, to be keyed out. NO text, NO X, NO close button, NO action buttons, NO new objects. This is the SAME panel with Wuhan's ivory/teal/deep-green palette, not a redesign. All horizontal and vertical curvatures must remain exactly as reference.

## 验证

`dotnet build --no-restore`：零警告、零错误。

专项入口：`Scenes/Tests/CityDialogVerification.tscn`。实际图形视口覆盖 1920×1080、1280×720 的天津、武汉与西安；检查暂停冻结、取消恢复、Esc、Tab、确认返回、提示关闭，以及武汉章节内青绿提示返回主页面后恢复暖色。截图位于 `.tmp/tianjin-dialog-art/verification/`，本轮日志为 `.tmp/wuhan-dialog-art/verification-scope.log`。
