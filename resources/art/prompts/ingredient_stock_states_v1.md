# Ingredient stock states v1

- Generated on: 2026-08-02 (Asia/Shanghai)
- Generator: Codex built-in `image_gen`
- Runtime purpose: picture-only stock feedback for egg, baocui, ham sausage, and scallion; one final PNG for each stock level from 1 through 6.
- Style reference: the current warm, hand-painted ProjectCake workstation and the corresponding ingredient artwork already present in the repository.

## Prompt set

For each ingredient, generate a clean 2 x 3 atlas on a flat chroma-key background. Each cell must contain only that ingredient, use the same camera, scale, outline, light direction, and painted texture, and depict exactly 1, 2, 3, 4, 5, and 6 visibly separate portions in reading order. No container, text, numeral, badge, watermark, cast shadow outside the object, or workstation background.

Ingredient-specific subjects:

- egg: one through six intact white eggs, arranged naturally but individually countable;
- baocui: one through six whole rectangular golden fried crisp sheets, individually countable;
- ham sausage: one through six short pink-red ham sausage pieces, individually countable;
- scallion correction: the generated sixth atlas cell (a cluster of six chopped scallion rings) is defined as one usable handful/pile. Final states show one through six spatially separate copies of that whole pile; individual rings are not counted as portions.

## Sources and processing

- Egg atlas source: `C:/Users/Administrator/.codex/generated_images/019fc0eb-edfa-73c3-b5be-3be8133fbaf0/exec-f310da97-9131-4ff7-97c9-6fc943529a25.png`
- Ham atlas source: `C:/Users/Administrator/.codex/generated_images/019fc0eb-edfa-73c3-b5be-3be8133fbaf0/exec-c09f3bff-04b5-4576-8c82-b2ae6875d8a0.png`
- Scallion atlas source: `C:/Users/Administrator/.codex/generated_images/019fc0eb-edfa-73c3-b5be-3be8133fbaf0/exec-b1a9da83-31b2-478e-af10-eff5b16e1cd1.png`
- Accepted baocui style source: `C:/Users/Administrator/.codex/generated_images/019fc0eb-edfa-73c3-b5be-3be8133fbaf0/exec-05ff54a7-eb70-40f8-85a3-338428dd706f.png`
- Rejected baocui attempt: `C:/Users/Administrator/.codex/generated_images/019fc0eb-edfa-73c3-b5be-3be8133fbaf0/exec-47e50159-650d-4491-8e58-ce109ebc8797.png`; the depicted counts were ambiguous.
- Project-bound raw copies: `tmp/imagegen/ingredient_stock/raw/`
- Alpha intermediates: `tmp/imagegen/ingredient_stock/alpha/`
- Build/check script: `tools/build_ingredient_stock_assets.py`

Chroma backgrounds were removed with the ImageGen `remove_chroma_key.py` helper. Atlas cells were cropped and normalized by the project build script. The accepted baocui source supplied one whole sheet; the final 1–6 states were deterministically composed from that same generated sheet because the model-generated later cells did not preserve exact counts. The egg states are deterministically composed from the accepted single-egg cell because the generated sixth egg cell contained seven eggs. The scallion states are deterministically composed from the accepted whole-pile sixth cell because its six rings collectively represent one portion. The build check verifies 512 x 512 RGBA output, transparent corners, non-empty alpha, distinct quantity-state files, and exactly 1–6 independently visible egg/pile components.

## Final files

- `res://resources/art/ingredients/egg/stock/egg_stock_1_v1.png` through `egg_stock_6_v1.png`
- `res://resources/art/ingredients/baocui/stock/baocui_stock_1_v1.png` through `baocui_stock_6_v1.png`
- `res://resources/art/ingredients/ham_sausage/stock/ham_sausage_stock_1_v1.png` through `ham_sausage_stock_6_v1.png`
- `res://resources/art/ingredients/scallion/stock/scallion_stock_1_v1.png` through `scallion_stock_6_v1.png`

Human art-direction approval remains separate from automated and local visual checks.
