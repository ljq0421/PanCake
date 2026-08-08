# Workstation 18-Slot Single-Row Background v4

## Asset contract

- Target: `res://resources/art/workstation/background/workstation_18_single_row_1920x1080_v4.png`
- Canvas: opaque `1920x1080` PNG.
- Integration: `res://scenes/gameplay/initial_unlock_workstation.tscn`, `SafeArea/BackgroundArtwork`.
- Edit target: v3 background. The prior annotated screenshot defines the horizontal tabletop rear edge at `y=630`.

## Prompt

Preserve the reference background above `y=630`. From exactly `y=630` to the image bottom, paint one continuous full-width rectangular warm wooden worktable. Do not retain a trapezoid, street floor, side cabinet, niche, wall, brick, shelf, or scenery below that line. Keep the tabletop quiet: no five-zone frames, large panels, device silhouettes, food, labels, or decorations.

Draw exactly 18 compact square recessed wells in one row at `y=956..1045`; each is `89x89` and stays in the existing horizontal order. Keep `y=630..946` as open tabletop. Draw a deliberately clear warm dark-and-highlighted horizontal wooden divider at `y=947..955` between the operating table and material rail, then retain a slim front lip below the wells.

## Processing

Codex built-in ImageGen produced a `1672x941` precise-object-edit source. It was high-quality-resized to `1920x1080`, then deterministically geometry-corrected to move the full-width table rear edge to `y=630`, redraw square wells at `y=956..1045`, and add the explicit `y=947..955` material-rail divider.
