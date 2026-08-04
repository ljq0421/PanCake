# Payment coin denominations v1

生成方式：Codex 内置 `image_gen`，每个面额一次独立生成；`payment_cash_small_v1.png` 仅作为现有手绘风格参考。

共享提示词：

> Create exactly one centered front-facing round denomination coin sprite for Project Cake. Match the reference's polished hand-painted casual cooking-game style, dark brown outline, beveled rim, and glossy highlight. Put one large, perfectly legible embossed Arabic numeral centered on the coin face. Use a perfectly flat solid `#00ff00` chroma-key background with no shadow, gradient, texture, reflection, floor plane, watermark, extra symbols, or additional coins. Keep the full coin visible with generous equal padding on a square canvas.

独立变体：

| 文件 | 面额文字 | 币面颜色 |
|---|---:|---|
| `coin_1_v1.png` | `1` | warm copper-bronze with amber highlights |
| `coin_2_v1.png` | `2` | cool silver-blue with pale cyan highlights |
| `coin_5_v1.png` | `5` | rich classic golden yellow |
| `coin_10_v1.png` | `10` | polished rose-gold / red-copper with coral highlights |
| `coin_20_v1.png` | `20` | premium violet-purple with indigo rim and lavender highlights |

后处理：五张色键源图分别执行 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，随后以 Lanczos 缩放为 256×256 RGBA PNG。
