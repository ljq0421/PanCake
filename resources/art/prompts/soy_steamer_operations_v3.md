# Soy Milk Machine and Steamer Operation Parts v3

## Generation record

- Generator: Codex built-in `image_gen`
- Use case: `stylized-concept` for new modular game props, with precise object-isolation constraints
- Style reference: the current ProjectCake warm hand-painted breakfast-stall art and the user's simple cartoon soy-milk-machine reference
- Generation background: solid `#ff00ff` chroma key, no gradients, shadows, text, logo, border, watermark, food, cup, or unrelated prop unless the asset definition explicitly asks for it
- Post-process: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`, followed by deterministic alpha-bounds normalization and residual-key cleanup
- Runtime canvas: equipment parts `1024x512` RGBA; cups and effects `256x256` RGBA
- Registration rule: every final file keeps its full transparent canvas and is not tightly cropped; runtime uses the documented visible alpha bounds to place the subject
- Contact sheet: `res://tmp/imagegen/soy_steamer_operations_v3/contact_sheet.png`

## Shared art direction

> Create one isolated modular game asset for a cozy Chinese breakfast-stall simulation. Use warm cream, honey wood, muted orange-red and restrained cel-shaded highlights, rounded readable silhouettes, clean dark-brown outlines, and a slightly top-down three-quarter perspective consistent with the current ProjectCake workstation art. The object must remain recognizable at a small gameplay size. Show only the requested part, centered on a flat solid #ff00ff background. No text, numbers, brand, logo, watermark, scenery, floor, cast shadow, glow, border, frame, food, cup, steam, or extra equipment unless explicitly requested. Preserve generous empty space around the object.

## Steamer prompt variants

- Tier 1 material language: simple pale bamboo and warm wood, beginner construction, minimal decoration.
- Tier 2 material language: sturdier lacquered bamboo with cream enamel and small orange-red accents.
- Tier 3 material language: professional cream-and-brass steamer construction with restrained red accent details; still compatible with the same bamboo breakfast-stall family.
- `base_body`: generate only the stationary bottom stove/base with the top receiver visible; no basket and no lid.
- `basket_layer`: generate exactly one empty stackable basket layer, with matching top and bottom rim; no base, lid, food, steam, or other layer.
- `lid_closed`: generate only the closed lid in its normal horizontal orientation; no basket or base.
- `lid_open`: generate only the same lid lifted and tilted back, clearly exposing its underside; no basket or base.

Final outputs (12):

- `steamer_tier_1_base_body_five_area_v3.png` — source `exec-f6b95e25-1c81-4225-877d-a85c070eec09.png`
- `steamer_tier_1_basket_layer_five_area_v3.png` — source `exec-db9fa737-face-4f6b-a6bc-1a50f2bb4657.png`
- `steamer_tier_1_lid_closed_five_area_v3.png` — source `exec-b1a13849-d751-43bb-8857-99193448b0b6.png`
- `steamer_tier_1_lid_open_five_area_v3.png` — source `exec-03a44632-e75c-4c4b-aeac-97fe32d7c1df.png`
- `steamer_tier_2_base_body_five_area_v3.png` — source `exec-37bf539f-58ec-49db-a32e-6457eedb1cdf.png`
- `steamer_tier_2_basket_layer_five_area_v3.png` — source `exec-7e8697e8-2378-4173-a521-c12f718f8ad2.png`
- `steamer_tier_2_lid_closed_five_area_v3.png` — source `exec-05184f8d-ad6c-48c2-9a09-cf6aedbc1c1e.png`
- `steamer_tier_2_lid_open_five_area_v3.png` — source `exec-60889201-f2a0-4b8e-b00c-86b64362e41a.png`
- `steamer_tier_3_base_body_five_area_v3.png` — source `exec-f2224721-fc09-44d4-bcf2-5e081b9b2191.png`
- `steamer_tier_3_basket_layer_five_area_v3.png` — source `exec-e353c430-6630-4b30-8eeb-a8e865d0662e.png`
- `steamer_tier_3_lid_closed_five_area_v3.png` — source `exec-d56964ab-db70-4807-afac-8f526bbf9dcc.png`
- `steamer_tier_3_lid_open_five_area_v3.png` — source `exec-d2e9d483-8059-4fa0-a78d-06793cadeb7b.png`

## Soy-milk-machine prompt variants

- Tier 1 language: compact beginner machine, rounded cream body, simple orange control, one serving bay.
- Tier 2 language: sturdier mid-level machine, larger control panel and refined cream/orange construction.
- Tier 3 language: professional multi-output machine with exactly four visible cup placement rings; the automatic rack remains a separate purchase.
- `body`: generate only the stationary machine body with its bean hopper visibly open and no lid, cup, beans, water, liquid, steam, or rack.
- `lid_closed`: generate only the detachable lid in its normal closed orientation.
- `lid_open`: generate only the matching lid raised and tilted back so opening is immediately readable.

Final outputs (9):

- `soy_milk_machine_tier_1_body_v3.png` — source `exec-be56f306-2bbc-4bd1-8bee-1ad153cb765a.png`
- `soy_milk_machine_tier_1_lid_closed_v3.png` — source `exec-d8ddc3b2-ef95-463f-9689-410914a93487.png`
- `soy_milk_machine_tier_1_lid_open_v3.png` — source `exec-1bd87b71-ad70-4c01-a370-a87ab65f8b1b.png`
- `soy_milk_machine_tier_2_body_v3.png` — source `exec-c5d307e4-74f0-41e0-8512-5cbe068a25ae.png`
- `soy_milk_machine_tier_2_lid_closed_v3.png` — source `exec-a655d5a7-faf5-4571-b2d7-c89089469607.png`
- `soy_milk_machine_tier_2_lid_open_v3.png` — source `exec-1903a1c5-5e4f-47c2-9f42-68e488feeb66.png`
- `soy_milk_machine_tier_3_body_v3.png` — source `exec-0dc9a106-0a8b-4c55-bf87-b097219c163f.png`
- `soy_milk_machine_tier_3_lid_closed_v3.png` — source `exec-27f0027b-727c-405a-a6b7-5dde4fd43bec.png`
- `soy_milk_machine_tier_3_lid_open_v3.png` — source `exec-07d1e6a3-6ded-4688-9a4e-d0b3d7c9290c.png`

## Cups, automation and effects

- Cup: one reusable transparent-glass/cream-ceramic serving cup at the same perspective and silhouette in every variant. Empty, yellow soybean, black bean, red bean, and multigrain fillings must differ primarily through the liquid color and subtle surface detail; no paper order cup or text.
- Automatic rack: one independent four-position cup rack with exactly four empty rings, no machine body and no cups.
- Water effect: a clean pouring arc and splash only.
- Soy stream effect: one thick pale warm soy-milk stream only.
- Spoiled vapor effect: several muted yellow-green sour vapor curls only; readable but not toxic-neon.

Final outputs (9):

- `soy_milk_cup_empty_v3.png` — source `exec-c482c8ff-b0a6-4f59-b8ea-3ac9d6b66962.png`
- `soy_milk_cup_yellow_bean_v3.png` — source `exec-192a81f9-a10b-42bf-abc6-58df1ad9bed4.png`
- `soy_milk_cup_black_bean_v3.png` — source `exec-e8e2a33a-4c2e-4e66-a289-5a3df93c2431.png`
- `soy_milk_cup_red_bean_v3.png` — source `exec-24bf0968-1f47-441b-bcb2-2ed4a145d31c.png`
- `soy_milk_cup_multigrain_v3.png` — source `exec-9fb250c1-1be9-4454-bde4-404ade83a372.png`
- `soy_milk_auto_cup_rack_empty_v3.png` — source `exec-523d1456-7fe2-4079-9e57-c6544e897a89.png`
- `soy_milk_water_pour_v3.png` — source `exec-92bcec00-a513-416a-a20a-0d3cd7309f74.png`
- `soy_milk_liquid_stream_v3.png` — source `exec-e2eae174-fdbb-457a-b230-70028b162f78.png`
- `soy_milk_spoiled_vapor_v3.png` — source `exec-220f3af9-a817-4175-8be8-e5f40e8347a4.png`

## Runtime constraints

- Full v2 tier images remain the source for the main-workbench thumbnail and upgrade presentation.
- v3 parts are composed only in the central operation panels.
- Lid motion, ingredient flight, cup flight, shake, glow, progress and steam are runtime feedback, not persisted production state.
- The auto-cup rack is controlled only by `automation.fresh_soy_milk.auto_cup_rack`; it is not part of tier 3.
- New snapshots cancel any in-progress visual tween and converge immediately to the latest business state.

