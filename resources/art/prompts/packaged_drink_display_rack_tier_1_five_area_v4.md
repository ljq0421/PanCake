# packaged_drink_display_rack_tier_1_five_area_v4

## Purpose

Runtime backdrop for the four packaged-drink inventory lanes in
`direct_packaged_drink_station.tscn`. This is a passive display rack, not the
separate packaged-drink heater below it.

## Built-in ImageGen prompt

```text
Use case: stylized-concept
Asset type: transparent 2D game workstation sprite for ProjectCake, displayed in a 302x194 horizontal UI region.
Primary request: Create a minimal finished packaged-drink display rack, not a heating machine. It must be a very shallow cream-enamel countertop tray frame containing exactly four large, completely empty square-ish recessed slots arranged in a balanced 2 by 2 grid. The four slots must have clear warm-brown outlines, subtly cool pale-blue inner surfaces, a thin honey-gold rim, and enough blank inner area for runtime drink sprites, inventory counts, and controls to overlay. Keep each slot visually distinct and evenly spaced.
Style/medium: polished hand-painted 2D mobile-game equipment sprite; compact rounded proportions, crisp deep warm-brown linework, warm bakery palette, soft restrained painterly gradients.
Composition/framing: front-facing with only a very slight top view; wide horizontal silhouette; centered with generous padding; the outer frame must stay low-profile and simple.
Constraints: no drink bottles, cartons, food, product silhouettes, labels, text, icons, logos, glass doors, glass panels, knobs, switches, screens, lights, vents, shelves, wheels, steam, shadows, people, room, counter, or separate props. This is a passive storage/display area only, not a warmer or refrigerator. Keep all four slots empty.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background, one uniform color with no gradient, texture, reflection, floor plane, shadow, or lighting variation. Do not use #00ff00 in the object. No watermark.
```

## Post-processing

- Built-in ImageGen output was copied to the project, then passed through
  `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill --edge-contract 1`.
- The de-keyed result was centered without distortion on a `1024x656` RGBA
  canvas to match the authored `302x194` display rectangle.
- The four slots are intentionally empty. Product sprites, duplicate-depth
  visuals, counts, and hold-to-restock controls remain runtime-owned.
