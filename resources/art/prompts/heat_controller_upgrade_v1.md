# heat_controller_upgrade_v1

## 生成提示词

```text
Use case: stylized-concept.
Asset type: ProjectCake P2 upgraded manual griddle thermostat / heat controller sprite, chroma-key source for transparent PNG.
Style reference: the provided ProjectCake upgraded workstation backplate establishes the warm cream, muted teal, orange-brown, brass, charcoal, and deep-brown-outline palette.
Primary request: create exactly one compact tabletop griddle heat controller seen from the same fixed near-top-down angle. It has a sturdy rounded rectangular warm-cream enamel body with muted teal side trim, a single large charcoal rotary dial with a red-orange pointer, a simple semicircular heat arc made only from colored tick shapes without letters or numbers, one small brass indicator lamp, and a short dark cable stub exiting the rear. The silhouette must read immediately as a manual temperature controller rather than an alarm clock, radio, kitchen scale, or timer. Center the complete object with generous padding.
Function contract: it improves heat feedback and adjustment precision only; it does not automate cooking. No digital display, no timer, no thermostat text, no numeric scale.
Style: simple hand-drawn 2D cartoon matching ProjectCake, bold clean deep-brown outline, large flat color blocks, at most base plus one shadow and one highlight, crisp icon-like readability.
Background: perfectly flat uniform solid #00ff00 chroma-key background, including every corner and edge, no shadows, gradients, texture, reflections, floor plane, halo, or lighting variation. Do not use #00ff00 in the object.
Constraints: exactly one controller only; no griddle, flame, hand, counter, other tools, food, cast shadow, text, letters, numbers, logo, brand, watermark, photorealism, glossy 3D, sci-fi styling, thin outlines, excessive detail, or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。
