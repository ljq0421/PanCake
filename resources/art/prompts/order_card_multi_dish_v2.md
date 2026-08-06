# order_card_multi_dish_v2

## Purpose

Transparent frame for the customer-overhead order HUD. Godot dynamically renders
the coin and total, up to two dish icons, ingredient icons, and patience state.

## Layout contract

- One narrow empty payment nameplate centered over the top outer border, for a
  coin icon plus total; it overlaps the rim rather than occupying card interior.
- The two dish wells begin immediately below that nameplate; do not leave a
  large unassigned parchment area above them.
- Two equal empty circular dish wells; no dish-name region.
- Eight empty ingredient wells in a strict 2 by 4 grid.
  - Columns 1–2: warm parchment/amber backing for dish one.
  - Columns 3–4: muted jade backing for dish two.
- One compact empty heart-shaped patience indicator recess and one thin empty
  capsule progress recess, about one-third the former progress-bar height.
- Keep the heart and thin progress recess high enough above the lower rim to
  avoid a tall unused parchment band; the overall card is vertically compact.
- The gap directly above the heart/progress controls, below the second
  ingredient row, is deliberately compressed to about one third of its prior height.

## Constraints

- Match the latest GPU workstation screenshot, not the obsolete V8 flat-cartoon
  reference: hand-painted parchment, aged amber-gold double rim, deep cocoa-brown
  outlines, and restrained inset shading.
- The card is a compact portrait HUD asset displayed above/right of the customer.
- Do not bake food, ingredients, coin, numerals, text, names, customer, clip, or
  progress fill into the frame.
- Generated on a magenta chroma-key background and processed using
  `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
