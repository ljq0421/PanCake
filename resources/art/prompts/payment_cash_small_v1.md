# payment_cash_small_v1

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake payment-tray collectible sprite, one blank banknote and three coins, magenta chroma-key source for transparent PNG
Input images: Image 1 is the approved ProjectCake customer sprite and style reference only, not an edit target
Primary request: create one compact small payment group viewed from the fixed near-top-down gameplay angle: exactly one flat muted warm-teal rectangular banknote with rounded corners and exactly three separate round brass-gold coins beside it. Keep the group horizontally arranged and compact so it fits the long payment tray; objects must not overlap heavily and each coin remains readable when scaled down.
Style/medium: simple hand-drawn 2D cartoon matching Image 1 and V8—bold clean deep-brown outlines, large flat color blocks, at most one shadow and one highlight per object, minimal detail, crisp silhouettes.
Banknote constraints: completely blank abstract banknote with only a simple inset border and two non-symbol geometric corner blocks; no portrait, currency symbol, denomination, letters, numbers, seals, flags or national identifiers.
Coin constraints: exactly three blank coins with simple raised rims and one small central highlight each; no currency symbols, numbers, text, portraits or emblems.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background for local removal. Background must be uniform with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Object constraints: one grouped payment sprite only; no wallet, hand, tray, counter, receipt or props; no cast shadow, contact shadow or reflection; do not use #ff00ff in the money.
Constraints: no text, letters, numbers, logo, brand or watermark; no photorealism, glossy 3D, thin outlines, complex engraving, sparkle effects or cropped objects.
```

## 透明处理

纸币为青绿色，因此使用品红背景。使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。

