# Workstation 18-Slot Single-Row Background v3

## Asset contract

- Target: `res://resources/art/workstation/background/workstation_18_single_row_1920x1080_v3.png`
- Canvas: `1920x1080`, opaque PNG.
- Integration: `res://scenes/gameplay/initial_unlock_workstation.tscn`, `SafeArea/BackgroundArtwork`.
- Edit source: `workstation_18_single_row_1920x1080_v2.png`.
- Reference only: annotated user screenshot; its red line marks the rear tabletop edge near `y=630` and must never appear in the asset.

## Prompt

Edit only the worktable area of the current v2 background. From the tabletop rear edge at approximately `y=630` to the left and right image edges and the bottom edge, paint one continuous warm wooden work surface with a slim coherent front lip. Remove every large inset rectangle, framed panel, border, corner ornament, and painted functional-zone outline. Keep the work surface quiet: broad warm color, low-contrast wood grain, restrained dark-brown linework, and no photorealistic gloss.

At the bottom, keep exactly one row of 18 empty square material-slot wells. Preserve their horizontal ordering. Each well reads as `89x89` pixels and occupies `y=956..1045`; the `y=925..956` strip is unbroken tabletop. Do not add slots, frames, equipment silhouettes, food, ingredients, labels, text, logos, or watermarks.

Preserve the area above `y=630`: street opening, red timber, lantern, canopy, plaster wall, gray brick skirting, curtain, empty shelves, plant, and steamer niche. The five runtime functional areas remain unpainted, in this implicit left-to-right order only: soy milk, fried dough, pancake, packaged drink, steamer.

## Processing

ImageGen returned a `1672x941` source image. It was deterministically resampled with Windows System.Drawing HighQualityBicubic to the required `1920x1080` canvas before integration; no content was cropped or composited.
