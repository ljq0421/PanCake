# 新中国风付款 UI v2

生成日期：2026-08-11；使用 built-in imagegen，透明件先生成纯洋红色键底，再经 `remove_chroma_key.py` 去键。

## 硬币共用提示词

```text
Use case: stylized-concept
Asset type: Godot management-game payment UI bitmap.
Style/medium: refined modern Chinese watercolor UI, warm rice-paper ground, thin ink-brown outlines, dry-brush mineral-pigment grain, matte finish, soft gray-brown edge shadow; readable at small size. Avoid glossy plastic, chrome, metallic glare, fluorescent saturation, thick black cartoon outlines, text except the required Arabic numeral, logos, watermark.
Transparency workflow: place the whole subject on a perfectly flat solid #ff00ff chroma-key background. Background must be uniform with no shadows, gradients, texture, floor plane, reflection, or lighting variation. Do not use #ff00ff in the subject.
```

- `coin_1_v2_chinese_ui.png`: exact single Arabic numeral `1`; warm ochre and walnut with restrained stone-blue outer rim.
- `coin_2_v2_chinese_ui.png`: exact single Arabic numeral `2`; muted stone-blue, ivory and walnut with restrained ochre edge.
- `coin_5_v2_chinese_ui.png`: exact single Arabic numeral `5`; gamboge, ivory and walnut with restrained stone-blue edge.
- `coin_10_v2_chinese_ui.png`: exact Arabic numeral `10`; restrained rouge, ivory and walnut with stone-blue edge.
- `coin_20_v2_chinese_ui.png`: exact Arabic numeral `20`; malachite, ivory and walnut with restrained gamboge edge.

所有硬币均要求：居中、正面圆形、留足透明边距，在 48 和 82 逻辑像素下轮廓与数字均清晰；无货币符号。

## 结果面板现金条提示词

```text
Use case: stylized-concept
Asset type: Godot management-game result-panel payment strip.
Primary request: one wide horizontal payment-receipt strip, no text and no numerals. On the left, a pale celadon rice-paper receipt plaque with subtle symmetrical clipped corners, a thin ink-brown border, and barely visible bamboo-and-mountain wash. On the right, exactly three small equal solid round payment coins in a row, coloured warm gamboge with walnut outlines.
Style/medium: refined modern Chinese watercolor UI, warm rice-paper ground, thin ink-brown outlines, dry-brush mineral-pigment grain, matte finish, restrained soft gray-brown edge shadow. Avoid glossy plastic, chrome, metallic glare, fluorescent saturation, thick black cartoon outlines, logos, watermark.
Composition/framing: all visible artwork forms one centered 3.9:1 wide horizontal strip, front-facing, with generous transparent padding around it. It must remain recognizable after being placed inside a 1020 x 259 AtlasTexture region.
Critical invariant: each of the three coins is a completely solid filled disk. No holes, square cut-outs, frames, glyphs, slots, transparent centers, or magenta inside any coin.
Transparency workflow: place the whole subject on a perfectly flat solid #ff00ff chroma-key background. The background must be uniform with no shadows, gradients, texture, floor plane, reflection, or lighting variation. Do not use #ff00ff anywhere in the subject.
```

## 交付契约

- 五枚硬币最终文件为 256×256 RGBA；保持原有 `82×82 -> 48×48` 显示与点击收款逻辑。
- 现金条最终文件为 1536×1024 RGBA；仅在 `Rect2(281,390,1020,259)` 写入图案，其余画布透明，保持两场景现有 `AtlasTexture` 参数不变。
- 原始 `coin_*_v1.png` 与 `payment_cash_small_v1.png` 全部保留。
