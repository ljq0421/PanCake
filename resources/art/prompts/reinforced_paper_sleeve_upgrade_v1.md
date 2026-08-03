# reinforced_paper_sleeve_upgrade_v1

## 生成提示词

```text
Use case: stylized-concept.
Asset type: ProjectCake P2 upgraded reinforced paper sleeve repair item sprite, chroma-key source for transparent PNG.
Style reference: the provided ProjectCake oil_absorbent_paper_v1.png establishes the near-top-down diagonal angle, warm paper material, bold deep-brown outline, flat-shape rendering, and object scale.
Primary request: create exactly one empty reinforced food-safe paper sleeve for a folded jianbing, viewed from the same near-top-down diagonal angle. It must clearly be an open-ended shallow pocket/sleeve rather than a flat sheet, envelope, closed bag, napkin, or tray: warm off-white kraft paper folded into a wide tapered U-shaped pocket, visible open top, visible inner layer, double-thickness rim, rounded lower corners, two simple muted-teal reinforcing bands around the outside, and one small brass-colored round fastener at each upper side. Center the complete empty sleeve with generous padding.
Function contract: it manually supports a lightly cracked folded pancake; it is not sealed and not an automatic wrapping device.
Style: simple hand-drawn 2D cartoon matching ProjectCake, bold clean deep-brown outline, large flat color blocks, at most base plus one shadow and one highlight, minimal paper fiber marks, crisp readable silhouette.
Background: perfectly flat uniform solid #00ff00 chroma-key background, including every corner and edge, no shadows, gradients, texture, reflections, floor plane, halo, or lighting variation. Do not use #00ff00 in the object.
Constraints: exactly one empty sleeve only; no food, pancake, hands, other packaging, cast shadow, contact shadow, text, letters, numbers, logos, brands, watermark, printed pattern, photorealism, glossy 3D, thin outlines, torn edges, or cropped corners.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。
