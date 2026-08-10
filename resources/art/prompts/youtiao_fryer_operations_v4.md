# Modular Youtiao Fryer Operations v4

## Generation contract

- Generator: Codex built-in `image_gen`; one independent call per accepted asset.
- References: approved straight-on v3 fryer family, then the accepted tier-1 v4 body/baskets for family consistency.
- Camera: player-facing front panel parallel to the image plane; no left/right yaw; only the shallow top-down view needed to read the well and basket.
- Style: ProjectCake rounded cartoon proportions, deep-brown outline, cream white / ink green / gold palette, polished cozy cel shading.
- Background: flat `#ff00ff` chroma key; no text, logos, shadows, food, steam or loose tools in equipment layers.
- Processing: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`, followed by `tools/normalize_transparent_sprite.py` on a fixed transparent canvas.
- Registration: all equipment parts are `1024×512` and use the canvas center as the shared pivot. Effects are `256×256`.
- Generator seed/model-version parameters were not exposed by the tool.

## Accepted prompts and sources

### Tier 1 body

> Edit the approved tier-1 fryer into a modular body-only sprite. Preserve its compact straight-on tabletop design, centered symmetric front panel, gentle top-down view, cream/green/gold palette and rounded deep-brown outlines. Remove the complete basket, handle, dividers and lift hardware. Show one empty long oil well with calm amber oil. Output only the fryer body on flat pure #ff00ff, with no food, effects, text, logo, shadow or automation.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-1fe7da05-b115-4392-b336-b5bf03056fae.png`
- Source copy: `tmp/imagegen/youtiao_fryer_operations_v4/sources/youtiao_fryer_tier_1_body_five_area_v4_key.png`
- Source SHA-256: `988ad617dd420167b8e00eeb631a4701ebf81506a3498fedbd1becde6f451216`

### Tier 1 lowered basket

> Create only one empty manual basket seated in the tier-1 oil-well registration, with exactly two serving lanes divided once, one centered ink-green handle, brass mesh and rounded deep-brown outlines. Face the player straight on and keep the body, oil, food, effects and automation absent on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-7d338647-814a-4d7f-a706-c83cd837bdee.png`
- Source SHA-256: `0edbd85f5331a687cd501caad88b3bdc0b03193fafce9f21d4082f7864fada7f`

### Tier 1 raised basket

> Create only the same empty two-lane tier-1 basket visibly lifted above the oil well for draining, with one centered handle and a longer visible lift stem. Preserve the strict straight-on camera and family rendering; exclude the fryer body, oil, food and effects on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-ae98d09c-cc6d-461e-937d-69986040e5b2.png`
- Source SHA-256: `0ed313284fd160be9806aaef8f4d71cf4738be0c9ff0b06c93e23e8708b430e5`

### Tier 2 body

> Evolve the accepted tier-1 body into the same straight-on family with a modestly reinforced housing and exactly one small round analog gauge. Keep one empty oil well and two-serving capacity. Remove all basket hardware and exclude screens, automation, food and effects on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-70682555-4789-4591-a411-efd495a3bec7.png`
- Source SHA-256: `8522901db9cada9ef9e7c9b5a75134604338d463f37144449fd8c1c7718b2fe8`

### Tier 2 lowered basket

> Create only a subtly reinforced version of the approved lowered two-lane basket, seated inside the tier-2 well, with one centered manual handle and no body, food, effects or automation on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-74eed42d-b88a-4758-9be9-15535ff0e3a1.png`
- Source SHA-256: `0c0f1c1fcbd10091dab60ed27cc80162d1f391e6ec4afee5a2c6a9036e69e43f`

### Tier 2 raised basket

> Create only that reinforced two-lane tier-2 basket lifted above the well for draining, with one centered ink-green handle and visible lift stem. Keep the strict straight-on view and omit the body, food, effects and automation on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-6b6aec7e-313c-4649-ba63-d6108282ac3e.png`
- Source SHA-256: `ead0c6362a139475ddf3ec33adac6ad66ceb070a29983e9cc69fc28e19bd326f`

### Tier 3 body

> Widen the accepted tier-2 body while preserving its exact player-facing camera, single knob, small gauge and one empty oil well. The well must accept one four-lane basket. Remove the basket and exclude extra wells, warming trays, automation, food and effects on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-f7384c05-2653-4b8c-838b-4faff79058f1.png`
- Source SHA-256: `b35801c9e5d1a85e02a406b3510ba3a8e0e1dbd0d28afce2a76ed473fe83026a`

### Tier 3 lowered basket

> Create only one wide empty basket seated in the tier-3 well with exactly four equal side-by-side lanes created by exactly three dividers and exactly one centered manual handle. Preserve the straight-on camera; no body, food, effects or automation on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-cfe614e3-abc3-43ee-82a3-b1fb517f10c3.png`
- Source SHA-256: `34c04622e05f92aa098d8a0de7cabcee5d1440da76c78a829d4e38bcbd89019e`

### Tier 3 raised basket

> Create only the same one wide four-lane basket lifted for draining, still with exactly three dividers and one centered handle. Preserve strict straight-on symmetry and omit the body, food, effects and automation on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-425949fa-b60f-44f1-a9f0-c02b3ddd8ae1.png`
- Source SHA-256: `1fc503ab939553ec595b25d4f0ff631dc012aea411b370be913f21f99d3b4708`

### Auto-lift arm

> Create only one optional compact lift attachment: an ink-green rear post, one rounded gold pivot and a short curved arm reaching toward the centered basket handle. Match the fryer registration and straight-on camera; exclude the fryer, basket, feeder, food and effects on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-d025ddec-baf5-4b6f-a4e5-4d74e0c14aae.png`
- Source SHA-256: `f3cd58ce5367d74e8c6e43dd1c8a8086c9366d91e3c678c5f1d06320151cc643`

### Auto-load feeder

> Correct the optional cream-and-green dough feeder to face the player strictly straight on: symmetric hopper and front panel parallel to the image plane, with a centered short gold-guided chute pointing forward/down. Output only the feeder; no fryer, basket, dough, food, effects or lift arm on flat pure #ff00ff.

- Accepted built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-1c7965a2-e460-4dd5-8a3a-72917e6d0dba.png`
- Rejected angle draft: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-83467b81-4d68-440e-ac97-65fcc0d60b0d.png` (three-quarter yaw)
- Source SHA-256: `31d9b256d0c9eec72506057f739dd29639b3534365491e1b032a8491f9543de3`

### Sizzle bubbles

> Create only a compact horizontal cluster of chunky cream/gold oil bubbles and curved fizz marks readable at small UI size, suitable for staggered looping. No fryer, basket, food, steam, smoke or shadow on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-8372e9f9-4379-48ef-bdba-d1bd3e021e01.png`
- Source SHA-256: `8a02349f8594b523b6d1863ce4960f467155f830b3ea6c9c692a2a55ab3536dc`

### Oil drips

> Create only seven separated amber droplets and two short tapered falling streaks for the raised-basket draining state. Use chunky cel-shaded shapes without puddles, equipment, food, bubbles, steam or shadow on flat pure #ff00ff.

- Built-in output: `C:/Users/Administrator/.codex/generated_images/019fe49f-002c-77e1-8166-6ddc348953e4/exec-fec9ca13-d638-4264-9845-098dbad1688a.png`
- Source SHA-256: `2f50cb4dd5ca5a93b0529a48fa84444f3fb010e9dc7da2cc67155b3dee82566a`

## Alignment boxes

- Bodies: `900×430`, center `(512,256)`.
- Tier 1/2 lowered baskets: `330×225`, center `(512,178)`; tier 3 lowered: `430×225`, same center.
- Tier 1/2 raised baskets: `350×260`, center `(512,140)`; tier 3 raised: `450×260`, same center.
- Auto lift: `360×300`, center `(650,180)`; auto loader: `250×300`, center `(350,185)`.
- Bubbles: `220×150`, center `(128,128)`; drips: `180×180`, center `(128,128)`.
- Final hashes and measured alpha bounds: `res://docs/youtiao_fryer_operations_v4_audit.json`.
