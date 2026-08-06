# Angled elliptical griddle v3

Use case: game-art correction for the initial workstation.

Reference: `codex-clipboard-13d8ae19-3a59-430c-a74b-2566b7d64b7a.png`. The required functional cooking face is the dark horizontal oval highlighted by the user's red frame; the red frame and kitchen background are annotation/reference only.

Finalization decision: the generated candidates flattened the entire griddle too far or returned to a top-down circle, so neither is used. The approved `griddle_base_compact_v2.png` source art is vertically resampled to 68% around its center, preserving the hand-painted rim while changing the cook face into the requested horizontal ellipse. This deterministic raster transform makes the artwork match the existing `pan_height_ratio = 0.694` ellipse used by rendering and input validation.

Constraints: no UI, no food, no red annotation, no background, transparent corners; the actual pancake, ingredients, and pointer acceptance must remain inside the same oval.
