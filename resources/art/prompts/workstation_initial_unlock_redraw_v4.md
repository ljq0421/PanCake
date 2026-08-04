# Workstation initial-unlock redraw v4

Generated with the built-in `image_gen` tool on 2026-08-03. These assets are isolated to the initial-unlock preview and do not replace the parallel expansion-art batch.

## Right-zone-clear worktop

- Output: `res://resources/art/workstation/background/workstation_initial_unlock_redraw_v4.png`
- Size: 1672×941 RGB
- SHA-256: `5A67F8917FD830A018DF6A63D576ADE097356BE63424D5FF619F2BD72434DE91`
- Input/edit target: `workstation_initial_unlock_redraw_v3.png`
- Dark-pixel fraction in the protected source strip `(1035,320,70,220)`: `0.0042`

```text
Use case: precise-object-edit
Asset type: 2D game workstation background, opening-day state
Input images: Image 1 is the edit target and authoritative composition.
Primary request: Move only the complete right-side equipment group approximately 60 source-image pixels to the right: (1) the exact 4 columns by 3 rows of twelve deep metal ingredient pans and their cream mounting border, and (2) the lower-right recessed fryer bay and its metal rim. Keep both groups the same size, perspective, depth, material, row/column alignment, and vertical positions. Reconstruct the newly exposed strip on their left as seamless flat cream-enamel countertop.
Target spatial result: the left edge of the 4x3 pan mounting border should begin around source x=1120, leaving an unmistakable clean cream-counter gap beside a centrally placed round griddle in the runtime composition. Keep the right edge of both equipment groups inside the counter boundary.
Preserve exactly: the continuous flat left and center worktop, outer counter silhouette and edge pipes, complete front cabinet and handles, sauce bottle caddy and plant, wall tiles, camera angle, lighting, shadows, aged cream-enamel material, and 1672x941 composition.
Constraints: change only the horizontal position of the two right equipment groups and the exposed cream counter fill. Exactly twelve pans in 4x3. No griddle, tools, containers, machines, labels, text, lock icons, UI frames, extra holes, new objects, or watermark.
```

## Tall clean tool holders

- Output: `res://resources/art/workstation/tools/countertop_tool_cups_initial_v4.png`
- Chroma source: `res://tmp/imagegen/initial_unlock_redraw_v4/countertop_tool_cups_initial_v4_chroma.png`
- Size: 1691×930 RGBA
- Alpha bounding box / runtime atlas crop: `(156, 144, 1381, 673)`
- Four corners: alpha 0
- SHA-256: `F501A962DEEAA841357A2D6329D69841BC88007816073F46F5582B3170817E5A`

```text
Use case: background-extraction
Asset type: transparent 2D game workstation prop overlay
Primary request: Create exactly four separate tall cylindrical countertop utensil holders in one horizontal row. Each holder is narrow and upright, approximately 1.45 times as tall as its body width, with a clearly visible round open top, a substantial rim, straight cylindrical wall, and stable base. Each is designed to hold one long cooking tool. They must read as real physical kitchen containers, not shallow bowls or UI slots.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal.
Style/medium: polished hand-painted 2D game prop art matching a clean morning street-food workstation.
Composition/framing: four evenly spaced holders, slight elevated front view, all fully visible with generous separation and padding; identical scale and baseline; no overlap between holders.
Materials/textures: fresh warm ivory enamel bodies, clean satin stainless-steel rims and bases, dark clean interiors, soft controlled highlights. Very light realistic use only; no heavy rust, peeling paint, dents, grime, or distressed antique finish.
Color palette: warm ivory, neutral silver, deep charcoal interior.
Constraints: exactly four tall narrow holders; no rack, rail, hooks, tools, handles, labels, icons, locks, text, UI frames, floor plane, cast shadow, reflection, watermark, or extra objects. Background must be one perfectly uniform #00ff00 with no shadows, gradients, texture, reflections, or lighting variation. Do not use #00ff00 in the holders. Crisp separated silhouette suitable for chroma-key removal.
```

The chroma source was converted with the installed `remove_chroma_key.py` helper using `--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
