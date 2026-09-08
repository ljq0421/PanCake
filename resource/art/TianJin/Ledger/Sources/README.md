# 手账美术源文件

使用内置 imagegen 生成绿底原图。书签和印章通过内置工具 background-extraction 去除绿色背景；账本的两次工具提取未产生真实 alpha，经用户确认改用项目现有脚本抠图。Sources 中的 PNG 保留原始生成结果，并通过 `.gdignore` 排除运行时导入。

运行素材位于上级目录：`ledger_book.png`（1448×929，裁去透明留白）、`ledger_bookmark.png` 和 `ledger_record_stamp.png`（1254×1254，保留生成画布）。Godot 统一裁透明边并等比显示，不拉伸素材。

账本的确定性处理命令（Windows PowerShell 5.1）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/prepare_tianjin_stock_ui.ps1 -Source resource/art/TianJin/Ledger/Sources/ledger_book_green.png -Destination resource/art/TianJin/Ledger/ledger_book.png
```

书签和印章的透明提取提示词：

> Use case: background-extraction. Edit target: the provided green-screen game UI asset. Remove ONLY the entire solid green background, replacing it with actual alpha transparency, not black, white, or checkerboard pixels. Preserve the foreground object's geometry, colors, composition, edge details, original canvas dimensions and position exactly. Clean green fringe off antialiased edges. Do not redesign, redraw, add shadows, add text or add anything. Return a transparent PNG.

## ledger_book

二维休闲早餐经营游戏 UI 美术，扁平、圆润、大色块、低细节，深暖棕 #4A291C 粗描边，奶油米白 #FFF8E8、暖棕和浅橙配色。不带文字、数字、水印。背景必须均匀纯绿色 #00FF00（供后续抠图），主体内部不用绿色，不要真实纹理、写实光影、渐变、3D 或透视。 横向1536×1024画布，一本完全摊开的空白双页账本，正面俯视、没有透视倾斜。左右页面等宽且平坦，中间一道窄书脊。纸张奶油米白，封皮边缘暖棕色。每页中央至少80%完全空白供程序排版，装饰仅限页边和书脊。整本书完整居中，横向几乎充满画布，整体书本宽高比约1.8:1，四周保留少量安全距离。不要文字、数字、横线、格子、食物、按钮、书签、印章、金属装订。背景没有投影。

## ledger_bookmark

二维休闲早餐经营游戏 UI 美术，扁平、圆润、大色块、低细节，深暖棕 #4A291C 粗描边，奶油米白 #FFF8E8、暖棕和浅橙配色。不带文字、数字、水印。背景必须均匀纯绿色 #00FF00（供后续抠图），主体内部不用绿色，不要真实纹理、写实光影、渐变、3D 或透视。 方形512×512画布，单条竖向浅橙色短布条书签，正面平视，顶端平整、下端燕尾切口，中央留白。单个物体完整居中，约占画布宽度40%、高度80%，四周留安全距离。不要文字、数字、图案、账本、真实布纹或投影。

## ledger_record_stamp

二维休闲早餐经营游戏 UI 美术，扁平、圆润、大色块、低细节，深暖棕 #4A291C 粗描边，奶油米白 #FFF8E8、暖棕和浅橙配色。不带文字、数字、水印。背景必须均匀纯绿色 #00FF00（供后续抠图），主体内部不用绿色，不要真实纹理、写实光影、渐变、3D 或透视。 方形512×512画布，一枚正面圆形印章图案，砖橙色圆形边框，奶油白底，中央仅一个砖橙色粗壮清晰的勾号，用于表示当天已有营业记录。单个图案完整居中，四周留安全距离。不要任何文字、数字、星级、印章手柄、真实磨损或投影。
