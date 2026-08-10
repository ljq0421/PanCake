# Simplified Youtiao Fryer Tiers v3

## Generation record

- Generator: Codex built-in `image_gen`
- Use case: `precise-object-edit` plus tier-family consistency
- Style references: `customer_01_neutral_v1.png`, `soy_milk_machine_tier_1_v1_five_area_v2.png`, and `steamer_tier_1_five_area_v2.png`
- Functional references: the earlier v3 fryer candidates were used only for the single-well, manual-basket, gauge, and four-lane requirements
- Angle correction: after the first GPU preview showed a three-quarter yaw, all three tiers were regenerated to face the player straight on; the front panel is parallel to the image plane and the only remaining camera tilt is a gentle top-down view into the basket
- Generation background: perfectly flat `#ff00ff` chroma key
- Post-process: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`, then alpha-bounds normalization to a `1024x512` RGBA canvas with a `900x430` maximum subject box centered at `(512, 256)`
- Runtime integration: tier 1 replaces the main-workstation youtiao artwork; tiers 2-3 are delivered but not dynamically bound
- Human visual review: pending

## Tier 1 prompt

> Edit the tier-1 youtiao fryer while retaining the compact single-well tabletop appliance, cream-white body, dark ink-green base and handle, gold control knob, rounded cartoon proportions, dark-brown outlines, and polished ProjectCake rendering. Correct the camera orientation so the appliance faces the player straight on, centered and horizontally symmetric, with the front control panel parallel to the image plane. Show no three-quarter yaw or diagonal side recession. Keep only a gentle top-down tilt so the one long oil well and one manual lift basket remain visible. Center the basket handle toward the player. Use a flat `#ff00ff` background. No text, food, steam, shadow, logo, loose tools, side trays, extra baskets, extra wells, gauges, screens, automation, or warming features.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-a883009f-fbdf-4110-877d-759173d5a689.png`
- Source copy: `tmp/imagegen/youtiao_fryer_v3/sources/youtiao_fryer_tier_1_five_area_v3_front_key.png`
- Source SHA-256: `c856e018ec1f574644a9aad657b45a1cc78142ea9b2ef6cbf0c958ef8b19e4d7`
- Final: `resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_five_area_v3.png`
- Final SHA-256: `4dd6b159bda81f7d31ad0b78bc63e5a9cddbc72ac1c849ffc5459bc79ed6b432`

## Tier 2 prompt

> Evolve the approved straight-on tier-1 image while preserving its exact player-facing camera, centered symmetric front panel, single oil well, single manual basket, centered handle, silhouette, palette, outline weight, and cel-shading. Make the housing slightly sturdier and add exactly one small round analog temperature gauge beside the existing knob to suggest faster heating. Capacity remains two portions. Do not add another oil well, basket, handle, screen, automation, warming tray, or complex controls. Use a flat `#ff00ff` background with no text, food, steam, shadow, logo, loose tools, or side trays.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-143888d4-147d-4d5b-aff8-f43996eb3965.png`
- Source copy: `tmp/imagegen/youtiao_fryer_v3/sources/youtiao_fryer_tier_2_five_area_v3_front_key.png`
- Source SHA-256: `0fc5144136a5af37b5eeb8c79e95d01e4110fa23b86c05350d8e0b38d864448a`
- Final: `resources/art/workstation/expansion/machines/youtiao_fryer_tier_2_five_area_v3.png`
- Final SHA-256: `164dec7b37afd7b1bf00909b6c428858bf2a4b68d9b5ac79220e95c69d5b9ec9`

## Tier 3 prompt

> Evolve the approved straight-on tier-2 image while preserving its exact player-facing camera, centered symmetric front panel, palette, outline, analog knob, small gauge, and manual lift. Widen the same body and keep exactly one wide oil well containing exactly one wide basket with one centered handle. Divide the basket into exactly four equal side-by-side serving lanes using three dividers. Do not add a second well, second basket, multiple handles, automatic lift, warming tray, extra screens, or industrial controls. Use a flat `#ff00ff` background with no text, food, steam, shadow, logo, loose tools, or side trays.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-6a12211c-e47d-4493-913f-70351f35ad67.png`
- Source copy: `tmp/imagegen/youtiao_fryer_v3/sources/youtiao_fryer_tier_3_five_area_v3_front_key.png`
- Source SHA-256: `0f3e53d91ce843b6e8e05a1fb66e8aede10811e72d75e76ef33adc2f1e3e8e9f`
- Final: `resources/art/workstation/expansion/machines/youtiao_fryer_tier_3_five_area_v3.png`
- Final SHA-256: `b06208cfa8d4ac659e9ca6448681a52a4ccc724c59225a299314fbbc1d9db1ca`

## Visual contract

- Every tier faces the player straight on. The front panel is horizontal and parallel to the screen; only the basket-opening view uses a gentle top-down tilt.
- Tier 1 and tier 2 remain two-portion manual fryers; tier 2 communicates speed only through the sturdier body and temperature gauge.
- Tier 3 communicates four-portion capacity through four divisions inside one basket.
- Automatic lift and automatic loading remain separate progression purchases and are not built into any tier image.
- All three assets remain readable at the existing main-workstation youtiao slot without changing its interaction rectangle.
- Comparison sheet: `tmp/validation/youtiao_fryer_v3_contact_sheet.png`
- Runtime GPU frame: `tmp/validation/youtiao_fryer_unlocked_gpu_1920x1080.png`
