# ham_sausage_whole_v1

## 初次生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake movable ingredient sprite, whole peeled cooked ham sausage, chroma-key source for transparent PNG
Input images: Image 1 is the approved ProjectCake broken baocui sprite and style reference only, not an edit target
Primary request: create one whole peeled cooked Chinese ham sausage viewed from the fixed near-top-down gameplay angle. A short plump cylindrical pink-red sausage with gently rounded sealed ends, angled diagonally, practical ingredient proportions, complete object centered with generous padding and a clear silhouette when scaled down.
Style/medium: simple hand-drawn 2D cartoon matching Image 1 and V8—bold clean deep-brown outline, large flat muted coral-pink color block, at most one darker side tone and one restrained warm highlight, minimal texture.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal. Background must be one uniform color with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Object constraints: exactly one bare sausage only; no wrapper, label, knot, skewer, plate, bowl, sauce, cut slices or garnish; fully separated from background; no cast shadow, contact shadow or reflection; do not use #00ff00 in the sausage.
Constraints: no text, letters, numbers, logo, brand or watermark; no photorealism, glossy 3D, thin outlines, meat marbling, grill marks, face, decoration or cropped ends.
```

## 材质修正提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake whole ham sausage sprite material correction
Input images: Image 1 is the whole sausage edit target
Primary request: make only the object read clearly as a peeled cooked ham sausage rather than candy or a glossy capsule. Flatten both ends slightly into subtle blunt rounded end faces, reduce the bright glossy highlights by about 70 percent, shift the body from saturated red toward muted coral-pink cooked meat, and add one very faint broad darker side band. Keep the same diagonal orientation, size and single-object silhouette.
Style invariants: preserve bold clean deep-brown outline, simple flat 2D cartoon rendering, large color blocks, minimal texture and generous padding.
Chroma invariant: preserve the perfectly flat solid #00ff00 background for local removal, with no shadows, gradients, texture, reflections or floor plane; do not use #00ff00 in the sausage.
Constraints: one bare whole sausage only; no wrapper, text, logo, brand, knot, skewer, plate, sauce, cut slices, grill marks, marbling, face or cropped ends.
```

## 透明处理

使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`。

