# oil_absorbent_paper_upgrade_v1

## 生成提示词

```text
Use case: precise-object-edit.
Edit target: the provided ProjectCake oil_absorbent_paper_v1.png, an existing transparent single oil-absorbing paper sheet sprite.
Primary request: create its clearly upgraded P2 version while preserving the exact same one-sheet identity, near-top-down diagonal orientation, centered composition, complete uncropped rounded rectangle silhouette, and generous padding. Make it a thicker warm off-white premium absorbent sheet with a muted-teal reinforced border strip, a simple sparse embossed diamond-dot pattern made only of shapes, two shallow fold guide creases, and one small rounded pull tab at a corner. The upgrade should suggest better oil absorption and easier handling while remaining a single disposable manual sheet, not a paper sleeve, package, dispenser, stack, or electronic tool.
Style: match ProjectCake's approved simple hand-drawn 2D cartoon style, bold clean deep-brown outline, large flat color blocks, at most one shadow and one highlight, minimal paper texture, crisp readable silhouette.
Background: perfectly flat uniform solid #00ff00 chroma-key background in every corner and edge, no shadows, gradients, texture, reflections, floor plane, halo, or lighting variation. Do not use #00ff00 in the object.
Constraints: exactly one clean upgraded sheet only; no grease, sauce, food, hand, other paper, cast shadow, contact shadow, text, letters, numbers, logo, brand, watermark, photorealism, transparency within paper, thin outlines, painterly fibers, torn edges, or cropped corners.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。
