# quality_fold_stability_v1

## 用途

P1 评价界面的“折叠结构稳定性”图标。以完整度徽章作为系列外框参考，只替换中心象形符号。

## 最终成功提示词

```text
Use case: precise game UI icon variant edit with strict chroma-key background.
Input image: the approved ProjectCake circular quality badge reference.
Asset type: P1 quality metric icon, folded structure stability.
Preserve exactly the same outer circular badge, canvas size, placement, scale, cream face, orange-gold inner rim, bold dark-brown outlines, flat matte style, and background treatment. Replace only the central pictogram.
New center pictogram: remove the round pancake disc and grain dots. Draw one simple cooked golden-brown folded jianbing parcel directly from above, fully inside the inner badge circle. Use a wide rounded-rectangle food silhouette divided into exactly three vertical overlapping panels: left folded panel, wider center panel, right folded panel. Use one clean dark-brown vertical seam down the middle of the center panel and exactly two short curved vertical fold lines, one on each side. No diagonal lines and no V shape. The parcel must look firmly closed, symmetrical and intact. Add two small soft brown toasted spots, one on the left panel and one on the right panel. Readable at 48 to 64 pixels.
Critical background requirement: the entire area outside the circular badge must remain one perfectly uniform solid chroma-key magenta RGB 255,0,255. No gradient, glow, halo, texture, vignette, lighting variation, or color shift anywhere in the background.
Style: ProjectCake V8 simple 2D cartoon UI, large flat blocks, thick clean dark-brown lines, at most three value layers.
Must not include: envelope flap, diagonal V seams, filling, wrapper, tray, lock, shield, check mark, ribbon, text, letters, numbers, shadow, extra icon, logo, brand, watermark, cropped badge.
Output: one clean chroma-key bitmap for remove_chroma_key.py.
```

## 迭代记录

- 初稿：顶部 V 形折线过于接近信封，未采用；保留于 `quality_fold_stability_v1_attempt1_envelope_like.png`。
- 第二稿：移除了信封语义，但纯品红背景被生成器改成渐变；抠像产生大面积半透明和色污染，未采用；保留于 `quality_fold_stability_v1_attempt2_gradient_key.png`。
- 第三稿：从干净徽章基准重新生成，背景均匀，三段包合结构清楚，通过。

最终使用 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill --force`。
