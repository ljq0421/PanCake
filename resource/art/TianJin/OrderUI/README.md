# 酱量订单图标

内置 image_gen 生成。原始绿底图保存在 Sources/sauce_amounts_green.png；按左右两半分离，复用项目绿幕抠图算法去绿、收紧透明边界，等比输出 96px 宽 PNG。正常酱不显示图标。

复现命令：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/prepare_order_sauce_icons.ps1`。

首次生成提示词：

Create a game UI asset sprite sheet, landscape 1536x1024, EXACTLY TWO isolated sauce amount icons centered in equal left and right halves of a perfectly uniform pure chroma green background #00FF00. Each icon is the SAME simple rounded upright teardrop/sauce droplet shape, pointed at top, plump round base, thick smooth dark warm brown outline #4A291C, flat warm golden ochre fill #F5B83D. LEFT droplet contains only a large legible dark brown Chinese character 少. RIGHT droplet contains only a large legible dark brown Chinese character 多. Characters should look like clean friendly bold Chinese game lettering, accurate Chinese strokes, occupying about half the droplet. Exact icon shape, scale, outline, fill and character size MATCH across both icons. No other text. No sauce jars, no realistic liquid, no 3D, no shine, no texture, no gradients, no shadow, no decorations, no border around sheet. Icons about 370 pixels wide by 500 pixels tall, ample green margin on all sides and between icons. No green inside icons. Designed for high readability when scaled to 32x40 game pixels, simple low-detail 2D warm hand-drawn casual breakfast cooking game.

最终绿底修正提示词（以首次输出为参考）：

Edit this two-icon sprite sheet. Replace ALL the black background and brown glow outside the two outlined sauce drops with a completely solid opaque bright chroma green #00FF00 background. Remove ALL shadows and outer glow. Keep both droplet outlines and the accurate Chinese characters 少 (left) and 多 (right). Make interiors flat golden yellow #F5B83D and outlines flat dark brown #4A291C, with no texture or gradients. Two matching flat 2D game icons on PURE BRIGHT GREEN SCREEN. This must be a GREEN background RGB 0,255,0, not transparent and not black. No other changes.
