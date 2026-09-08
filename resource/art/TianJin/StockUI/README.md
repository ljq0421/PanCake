# 天津库存与订单 UI 素材

2026-09-08 使用内置 image_gen 生成。所有最终素材由绿底原图抠透明后输出；绿色原图保存在 `Sources/`，该目录使用 `.gdignore` 避免运行时重复导入。

| 文件 | 运行尺寸 | 用途 |
| --- | --- | --- |
| order_body.png | 288×165 | 订单底框，四边 28px 九宫格边距 |
| order_tail.png | 42×21 | 独立尾巴，游戏中等比显示为 36×18 |
| patience_frame.png | 160×28 | 耐心条底框，左右 16px、上下 4px 九宫格边距 |
| batter_empty.png | 1154×885 | 面糊空碗，保持原容器轮廓 |
| sauce_empty.png | 887×729 | 酱料空碗，保持原容器轮廓 |

`TianjinArtCatalog` 缓存运行图；不得把 `Sources/` 的绿底图接入游戏。空碗是新文件，原有满碗图片保留。`LiquidStockView` 从原满碗素材采样液面，以独立 shader 层显示满、半、少三档；零库存隐藏液面。勺子、刷子仍使用原素材。

复现抠图（Windows PowerShell 5.1，无外部 Python 依赖）：

```powershell
powershell.exe -NoProfile -File tools/prepare_tianjin_stock_ui.ps1 -Source resource/art/TianJin/StockUI/Sources/order_body_green.png -Destination resource/art/TianJin/StockUI/order_body.png -Width 288
```

其他图片使用相同命令，替换文件名；尾巴 Width=42，耐心条 Width=160，空碗不指定 Width。工具移除绿色、去除边缘绿溢色、按 alpha 裁切并等比缩放，不改变原始来源图。

## 生成提示词

### order_body_green.png（新生成）

Use case: stylized-concept. Production game UI sprite for a warm Chinese breakfast-shop 2D cartoon game. Generate ONE empty rounded rectangular speech-bubble BODY, no tail (tail will be separate). Front facing, perfectly horizontal and symmetric, aspect ratio body 1.8:1. Cream white fill #FFF8E8, thick warm dark brown #4A291C slightly hand-drawn outline, softly rounded corners, restrained warm cream inner rim, single flat brown shadow offset slightly down. Broad completely blank flat interior for dynamic food icons and Chinese text. The straight middle portions of all four edges must be uniform for nine-slice scaling. Cute confident linework, flat colors, low detail, same visual family as hand-painted cozy cartoon cooking game. No text, icons, food, characters, watermark, texture, glitter or decorative marks. Isolate the complete object centered with generous padding on perfectly solid chroma key green #00FF00 background. Absolutely no green within the object. Output square image.

### order_tail_green.png（新生成后补绿底）

Production 2D cozy cartoon breakfast-shop game UI sprite: ONE standalone downward-pointing speech bubble tail. A short wide softly rounded triangular tongue, cream white #FFF8E8 fill and thick dark warm brown #4A291C outline ONLY along the two sloping sides and rounded tip. Top of triangle completely open (no horizontal brown outline), flat cream white upper edge so it can overlap seamlessly onto a cream speech bubble body. Tip curves a little to the left. Symmetric overall width about twice height. Tiny flat brown shadow underneath only. Flat colors, low detail, clean cartoon linework. No entire bubble, no words, no icons, no other objects. Centered on perfectly flat solid chroma green #00FF00, generous green padding. No green inside shape.

首次输出实际带透明背景，随后使用内置 image_gen 保持形状并补绿底，再统一抠图。补绿底提示词：

Keep the existing cream triangular speech bubble tail exactly unchanged. Change ONLY background: replace all transparent/black surrounding background with fully opaque bright green RGB(0,255,0). This deliverable must be an OPAQUE green-screen image, no alpha transparency. No extra objects. Preserve centered shape, colors and size.

### patience_frame_green.png（新生成）

Generate ONE horizontal empty patience meter frame sprite for a cozy 2D Chinese breakfast cartoon game. Long low pill shaped frame, width to height 12:1, completely level front view. Warm dark brown #4A291C bold hand-drawn outline with softly rounded ends, cream #F4DDB5 thin rim and flat tan EMPTY inner track, no colored fill. Flat warm cartoon colors, clean low detail, no text, no ticks, no icons, no gradients, no realistic effects. Isolated, centered with ample margins on absolutely solid bright chroma key GREEN #00FF00 background, no transparency, no black background, no green inside the frame. This is game art to be sliced into left cap, repeatable horizontal middle and right cap.

### batter_empty_green.png（编辑面糊容器.png）

Edit target: attached batter bowl sprite. Remove ALL yellow batter liquid from inside the bowl, revealing an EMPTY bowl with plain cream ceramic inner bottom. Preserve exact outer bowl silhouette, handles, blue horizontal stripe, perspective, framing, size, camera, rim and outer colors. No utensils, no liquid, no food inside. Keep thick dark warm brown outlines, cozy flat 2D cartoon art. Replace the background with perfectly solid chroma key green #00FF00, absolutely opaque green background with no shadow on the green. The bowl must stay in exactly the original position and scale on square canvas.

### sauce_empty_green.png（编辑酱料容器.png）

Edit target: attached orange sauce bowl sprite. Remove ALL red brown sauce liquid from inside the bowl, reveal an EMPTY bowl with plain warm cream ceramic interior and inner bottom. Preserve EXACT original outer silhouette, camera, rim, orange exterior, lighting, size and placement on square canvas. No brush, utensils, food or liquid. Thick dark warm brown outline and low detail cozy 2D cooking game art. Replace transparent background with perfectly SOLID bright chroma green #00FF00 background. No green within bowl, no cast shadow on background. Retain exact original composition and dimensions.
