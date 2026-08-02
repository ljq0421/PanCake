# egg_cracked_raw_v1

## 初次生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake placed ingredient sprite, freshly cracked raw egg on pancake, chroma-key source for transparent PNG
Input images: Image 1 is the approved ProjectCake whole egg sprite and color/style reference only, not an edit target
Primary request: create one freshly cracked raw egg viewed straight from the fixed near-top-down gameplay angle. A broad irregular but compact pale egg-white puddle with one intact round golden-orange yolk slightly off center. Keep the egg white visibly thick and readable over a dark griddle or golden pancake, with a simple organic outline and generous padding.
Style/medium: simple hand-drawn 2D cartoon matching Image 1 and V8—bold clean deep-brown outer outline, large flat color shapes, at most base plus one soft shadow and one small highlight, minimal surface detail.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal. Background must be one uniform color with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Object constraints: exactly one cracked egg puddle; one yolk only; no shell pieces, pan, plate, griddle, pancake, cooked brown edge, bubbles or utensils; fully separated from background; no cast shadow or reflection; do not use #00ff00 in the egg.
Constraints: no text, letters, numbers, logo, brand or watermark; no photorealism, glossy 3D, thin outlines, transparent watery disappearance, face, decoration or cropped edges.
```

## 生蛋感修正提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake freshly cracked raw egg sprite correction
Input images: Image 1 is the cracked egg edit target
Primary request: make only the egg look freshly raw rather than fried. Flatten the yolk dome slightly, remove the strong glossy shine from the egg white, make the white puddle looser and more irregular with two or three shallow spreading lobes, and shift the white toward pale translucent cream while keeping it opaque enough to read on a dark griddle. Keep one intact golden yolk slightly off center.
Style invariant: preserve the simple flat 2D cartoon style, bold clean deep-brown outer silhouette, large color blocks, minimal detail and same generous padding.
Chroma invariant: preserve the perfectly flat solid #00ff00 background, fully separate the egg from it, and do not add shadows, gradients, floor plane or reflections to the background.
Absolute constraints: one raw cracked egg only; no shell, plate, pan, griddle, pancake, utensils, bubbles, cooked brown rim, crispy edge, text, letters, numbers, logo, brand or watermark; do not crop the egg.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。蛋白保持不透明浅奶油色以确保黑色鏊面和金色饼面上的可读性；真实半透明可由运行时材质控制。

