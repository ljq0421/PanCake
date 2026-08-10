# packaged_drink_cabinet_empty_tier_1_five_area_v3

## Edit target

`res://resources/art/workstation/expansion/machines/packaged_drink_cabinet_tier_1_five_area_v2.png`

## Prompt summary

Preserve the approved compact cream-enamel packaged-drink cabinet, warm wood trim,
glass-blue interior, brass details, perspective, silhouette and hand-painted game
asset style. Remove every packaged drink and all baked-in stock from the cabinet.
Leave four clearly empty shelf lanes with visible shelf depth so runtime sprites can
represent real inventory. Do not add labels, text, prices, UI, people, shadows,
watermarks or a dark production panel. Isolate the cabinet against a flat `#00ff00`
chroma-key background.

This is a faithful summary retained for provenance; the image tool did not expose a
seed or model-version parameter. The first generated attempt used a painted
checkerboard-like background and was rejected. The accepted retry used the flat
green key described above.

## Post-processing

```text
remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
```

The accepted RGBA result was resized with Lanczos to a fixed `1024x512` canvas.
