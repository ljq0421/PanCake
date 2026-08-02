# egg_whole_v1

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake movable ingredient sprite, whole raw egg, chroma-key source for transparent PNG
Input images: Image 1 is the approved V8 gameplay composition and style reference only, not an edit target
Primary request: create one single intact light-brown chicken egg viewed from the same fixed near-top-down angle as Image 1. Simple oval form, slightly narrower at one end, practical ingredient scale, complete object centered with generous padding and a clear silhouette when scaled down.
Style/medium: exact V8 visual language—simple hand-drawn 2D cartoon, bold clean deep-brown outline, large flat color blocks, base warm tan plus one soft shadow and one small restrained highlight, almost no shell texture.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal. Background must be one uniform color with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Object constraints: exactly one unbroken egg only; no carton, nest, bowl, cracked shell, yolk or egg white; fully separated from background; no cast shadow, contact shadow or reflection; do not use #00ff00 in the egg.
Constraints: no text, letters, numbers, logo, brand or watermark; no photorealism, glossy 3D, thin outlines, speckled microtexture, face, decoration or cropped edges.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。

