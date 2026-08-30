# Night Market Art Manifest

## Runtime layered set

The third shop now runs on formal separated art rather than the approved baked workstation concept. All text, controls, timers, temperatures, doneness logic, and feedback remain native Godot UI/state.

| Runtime file | Role | State contract |
| --- | --- | --- |
| `background/night_market_empty_stall-v1.png` | Empty late-night stall and countertop | 16:9 scene plate; contains no grill, fryer, plating station, food, labels, or UI |
| `layers/charcoal_grill-rgba-v1.png` | Left charcoal grill | Independent transparent equipment layer |
| `layers/plating_station-rgba-v1.png` | Shared center plating station | Independent transparent equipment layer |
| `layers/twin_fryer_base-rgba-v1.png` | Right twin-vat fryer without baskets | Independent transparent equipment layer |
| `sprites/skewer_doneness_atlas-rgba-v2.png` | Lamb, chicken-pepper, lotus, and potato states | 4 rows × 4 columns: raw, turning, ideal, charred |
| `sprites/fryer_basket_states-rgba-v1.png` | Fryer basket movement | 3 columns: raised, lowered/cooking, draining |
| `sprites/cooking_effects_atlas-rgba-v1.png` | Heat and seasoning feedback | 4 × 2: low/medium/high embers, smoke; gentle/active/vigorous bubbles, seasoning |

Godot slices the atlases at runtime in `scripts/gameplay/night_market_workstation.gd`. Equipment, food, basket, coal, smoke, oil-bubble, and seasoning layers are all updated from the actual production snapshot.

## Green-screen sources

Per project policy, every requested transparent generated asset was first produced on a flat chroma-green field and preserved under `source_green/`:

- `charcoal_grill-green-v1.png`
- `plating_station-green-v1.png`
- `twin_fryer-green-v1.png`
- `twin_fryer_base-green-v1.png`
- `skewer_doneness_atlas-green-v1.png`
- `fryer_basket_states-green-v1.png`
- `cooking_effects_atlas-green-v1.png`

The runtime green-keyed outputs have genuine alpha. `tests/unit/night_market_art_contract_self_check.gd` verifies transparent corners, mixed opaque/transparent pixels, green source corners, and the background aspect contract.

## Generation and extraction

- Generation/editing: built-in ImageGen.
- Final prompt set: `prompts/formal_layer_prompt_set.md`.
- Deterministic fallback keyer: `tools/chroma_key_green.gd`.
- ImageGen produced the empty background and all green-screen source art. It also successfully extracted the grill, plating station, and complete fryer RGBA variants.
- ImageGen returned baked checkerboard pixels for the food-atlas alpha extraction after two attempts. The preserved green source was therefore keyed locally with the deterministic Godot tool, as were the runtime basket, cooking-FX, and basket-free fryer layers.
- `sprites/skewer_doneness_atlas-rgba-v1.png` is a rejected, unreferenced extraction artifact retained only as provenance evidence. Runtime uses `-rgba-v2.png`.
- `layers/twin_fryer-rgba-v1.png` is a valid transparent complete-fryer alternative, but runtime uses the basket-free base plus the separate basket-state atlas.

## Approved concept retained as reference

- File: `background/night_market_twin_fire_workstation-concept-v1.png`
- Composition: “双翼火线” — charcoal grill left, shared plating axis center, double-basket fryer right.
- Seed key: `3e73e27e`.
- Approval: option 1 selected by the user on 2026-08-30.
- Source comp: `.impeccable/mocks/decision/night-market-twin-fire-wings.png`.
- Prompt source: `.impeccable/mocks/decision/night-market-twin-fire-wings.prompt.txt`.
- Approval sidecar: `.impeccable/mocks/decision/night-market-twin-fire-wings.png.json`.

The concept remains the approved composition reference, but it is no longer referenced by the runtime workstation scene.

## Validation evidence

- Art contract: `tests/unit/night_market_art_contract_self_check.gd`.
- Dynamic integration: `tests/integration/night_market_vertical_slice_self_check.gd`.
- GPU layer/state verification: `tests/integration/night_market_gpu_smoke.gd`.
- Captures: `tmp/validation/night_market_twin_fire_gpu_1920x1080.png` and `tmp/validation/night_market_twin_fire_gpu_1280x720.png`.
