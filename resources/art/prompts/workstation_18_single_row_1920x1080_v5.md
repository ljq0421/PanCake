# Workstation 18-Slot Single-Row Background v5

## Asset contract

- Target: `res://resources/art/workstation/background/workstation_18_single_row_1920x1080_v5.png`
- Canvas: opaque `1920x1080` PNG.
- Integration: `res://scenes/gameplay/initial_unlock_workstation.tscn`, `SafeArea/BackgroundArtwork`.
- Source: v4 background, preserved non-destructively.

## Correction

Keep the original warm wooden divider style from v4's upper seam (`y=889..900`), but move that style to the material rail's upper edge at `y=947..955`. Smooth the former upper seam into neighboring normal wood grain. Replace the v4 dark divider at `y=947..955`; the final image must have exactly one visible tabletop-to-material-rail divider. Keep the 18 visual wells at `y=956..1045` and all other v4 composition unchanged.

## Processing

The source image was processed deterministically: each old seam pixel was blended from surrounding tabletop rows, while the original twelve-pixel wood-divider band was resampled into the nine-pixel target band. No node coordinate or gameplay behavior changed.
