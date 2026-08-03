# Ingredient restock containers v1

- Generated on: 2026-08-02 (Asia/Shanghai)
- Generator: Codex built-in `image_gen`
- Runtime purpose: clickable refill containers in the left-side workstation ingredient rack.
- Style reference: the current warm, hand-painted ProjectCake workstation plus the matching ingredient artwork.

## Prompt set

Generate one isolated, three-quarter top-view prop on a flat chroma-key background. Use a warm hand-painted mobile-game style, dark-brown readable outline, compact silhouette, consistent upper-left lighting, and no text, numeral, label, logo, watermark, hands, or workstation background.

- egg carton: open kraft-paper egg carton with several white eggs visible;
- baocui tin: vintage rectangular iron tin with its lid open and golden rectangular crisp sheets visible;
- ham freshness box: transparent-lidded food storage box with short ham sausage pieces visible;
- scallion enamel jar: white enamel jar with a dark rim, filled with chopped green scallion, lid set open.

## Sources and processing

- Egg carton source: `C:/Users/Administrator/.codex/generated_images/019fc0eb-edfa-73c3-b5be-3be8133fbaf0/exec-3f9799fc-da73-47b4-951f-dfc6e3dfc3de.png`
- Baocui tin source: `C:/Users/Administrator/.codex/generated_images/019fc0eb-edfa-73c3-b5be-3be8133fbaf0/exec-1dce5ef7-b83d-4183-aa2f-52fcc139f362.png`
- Ham box source: `C:/Users/Administrator/.codex/generated_images/019fc0eb-edfa-73c3-b5be-3be8133fbaf0/exec-6d2c2bed-ddef-4507-8914-c8c284388f8f.png`
- Scallion jar source: `C:/Users/Administrator/.codex/generated_images/019fc0eb-edfa-73c3-b5be-3be8133fbaf0/exec-d1e94773-b04d-400a-b699-2ead51be9da7.png`
- Project-bound raw copies: `tmp/imagegen/ingredient_stock/raw/`
- Alpha intermediates: `tmp/imagegen/ingredient_stock/alpha/`
- Build/check script: `tools/build_ingredient_stock_assets.py`

Chroma backgrounds were removed with the ImageGen helper, then each prop was centered and normalized to a 512 x 512 RGBA canvas. The build check verifies dimensions, transparency, and non-empty visible bounds.

## Final files

- `res://resources/art/workstation/restock/egg_carton_v1.png`
- `res://resources/art/workstation/restock/baocui_tin_v1.png`
- `res://resources/art/workstation/restock/ham_fresh_box_v1.png`
- `res://resources/art/workstation/restock/scallion_enamel_jar_v1.png`

Human art-direction approval remains separate from automated and local visual checks.
