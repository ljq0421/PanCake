# 2026-08-12 Youtiao fryer, soybean, and stock-state asset pass

## Generator and transparency workflow

- Generator: Codex built-in image generation via the `imagegen` skill.
- Chroma key: flat `#ff00ff`; no floor, shadow, reflection, text, logo, or watermark.
- Key removal: installed `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
- Registration: `tools/normalize_sprite_to_reference.py` fits the extracted subject into the alpha bounds of the prior runtime reference without changing the reference canvas.

## Intermediate youtiao fryer prompts

Shared art direction: polished cozy Chinese breakfast-stall game art, rounded chibi proportions, thick deep-brown outlines, warm cel shading, cream enamel, blue-green chassis, and gold trim. All three outputs are centered 1024 x 512 RGBA sprites.

- Body: redesign the compact two-serving intermediate fryer between the basic and advanced references; add reinforced lower chassis, one central orange rotary knob, exactly two indicator lights, and one small temperature gauge. Keep a single compact oil well. Prohibit four-slot capacity, a second heater well, automatic lift, dough feeder, basket, food, and text.
- Lowered basket: make a dedicated bronze-gold two-compartment basket in the basic lowered pose; reinforce the rim and supports and match the new body's green/blue-green handle accents. Prohibit four compartments and automation hardware.
- Raised basket: make the raised/draining version of the same intermediate two-compartment basket, preserving its identity and the established raised registration. Prohibit four compartments and automation hardware.

References:

- `res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_0_*_v1_chinese.png`
- `res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_body_v1_chinese.png`
- `res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_2_*_v1_chinese.png`

Final files:

- `res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_body_v2_chinese.png`
- `res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_lowered_v2_chinese.png`
- `res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_raised_v2_chinese.png`

## Yellow soybean prompt

Precise edit of `yellow_soybean_portion_v1_five_area_v2.png`: preserve the teal-green measuring scoop, handle, rim, perspective, outline, lighting, size, and registration. Change only the round yellow contents into a dense pile of plump oval golden-yellow soybeans with subtle pale hilum marks, using the black- and red-bean sprites as bean-shape references. No loose beans or vessel changes.

Final file: `res://resources/art/ingredients/soybean/yellow_soybean_portion_v2_five_area_v2.png`.

## Deterministic stock states

`tools/build_ingredient_stock_assets.py` uses one accepted unit/portion master per ingredient and composes exactly 1 through 14 separated portions on a 512 x 512 transparent canvas. It covers egg, baocui, ham sausage, scallion, meat floss, pork tenderloin, coriander, and preserved mustard. The generator checks file completeness, dimensions, transparent corners, non-empty alpha, distinct hashes, and exact connected portion counts for ham sausage and meat floss.

Final naming: `res://resources/art/ingredients/<ingredient>/stock/<ingredient>_stock_1_v2.png` through `<ingredient>_stock_14_v2.png`.

## Acceptance record

- Automated asset validation: `INGREDIENT_STOCK_ASSET_CHECK_PASS`.
- Godot resource import: 1024 x 512 for each fryer state, 256 x 256 for soybean, and 512 x 512 for stock states.
- Focused runtime checks: wide spreader no-tutorial/no-promotion contract, youtiao-to-baocui visible-width tolerance, dedicated intermediate fryer states and 2/2/4 capacities, and eight 14-texture stock slots.
- Human visual acceptance remains separate from automated and agent visual review.
