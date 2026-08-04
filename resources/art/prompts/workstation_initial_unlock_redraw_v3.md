# Workstation initial-unlock redraw v3

Generated with the built-in `image_gen` tool on 2026-08-03. These are isolated, versioned assets for `initial_unlock_workstation.tscn`; they do not replace or modify the parallel expansion-art batch.

## Continuous worktop

- Output: `res://resources/art/workstation/background/workstation_initial_unlock_redraw_v3.png`
- Size: 1672×941 RGB
- SHA-256: `C9071006B0C8D5D7AE84F7C90DA253F906E18E2E6FD31542E17C8519A07826AB`
- Input/edit target: `workstation_initial_unlock_redraw_v2.png`

```text
Use case: precise-object-edit
Asset type: 2D game workstation background, opening-day state
Input images: Image 1 is the edit target and authoritative composition.
Primary request: Change only the worktop geometry. Fill the two large rectangular recessed bays on the left and the large rectangular mounting recess in the center completely flush with the surrounding cream enamel countertop. The result must be one continuous, solid, flat cream-enamel worktop across the entire left and center areas, suitable for future countertop machines and a round griddle placed directly on top.
Also remove the hanging wall rail and all hooks from the upper-left wall, reconstructing the same blue tile wall behind it.
Preserve exactly: the outer counter silhouette and edge pipes, the cream enamel material and worn patina, the complete front cabinet and handles, the right-side exact 4 columns by 3 rows of twelve deep physical metal ingredient pans, the lower-right recessed fryer bay, the sauce bottle caddy and plant, the wall tiles, camera angle, perspective, lighting, shadows, and 1672x941 composition.
Materials/textures: aged cream enamel, brushed dark metal pans, subtle rust wear, coherent contact shadows and bevels.
Constraints: no holes, grooves, outlines, lock icons, placement markings, labels, text, tools, griddle, machines, or UI frames anywhere on the newly flattened left and center worktop. No new objects. No watermark.
```

## Cylindrical tool containers

- Output: `res://resources/art/workstation/tools/countertop_tool_cups_initial_v3.png`
- Chroma source: `res://tmp/imagegen/initial_unlock_redraw_v3/countertop_tool_cups_initial_v3_chroma.png`
- Size: 1823×863 RGBA
- Alpha bounding box: `(55, 229, 1756, 701)`; all four corners have alpha 0
- SHA-256: `E4AFD13E91AECA9527156EBC8554818C6B642AF2532D6A38C266F82DFC70A1BE`

```text
Use case: background-extraction
Asset type: transparent 2D game workstation prop overlay
Primary request: Create exactly four separate cylindrical countertop utensil containers in one horizontal row. Each container is an open-top, thick-rimmed, short cylindrical cup designed to hold one long cooking tool upright. The four cups are identical in scale but have subtle individual wear. They must read as real physical containers, not UI slots.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal.
Style/medium: polished hand-painted 2D game prop art matching an aged cream-enamel street-food workstation with brushed steel trim, dark open interiors, warm brown patina, and crisp outlined material edges.
Composition/framing: straight horizontal row, evenly spaced, slight elevated front view so each circular opening and cylindrical wall are clearly visible; generous transparent-boundary padding after key removal; cups occupy the lower two-thirds of the canvas.
Materials/textures: cream enamel cylinders, brushed steel rims, subtle chips and rust wear, dark empty interiors.
Constraints: exactly four cups; no rack, rail, hooks, tools, handles, labels, icons, locks, text, UI frames, floor plane, cast shadow, reflection, watermark, or extra objects. The background must be one perfectly uniform #00ff00 with no shadows, gradients, texture, reflections, or lighting variation. Do not use #00ff00 anywhere in the cups. Crisp separated silhouette suitable for chroma-key removal.
```

The chroma source was converted with the installed `remove_chroma_key.py` helper using `--auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
