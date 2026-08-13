# UI Core Chinese v1 ImageGen record

Generated with the built-in ImageGen tool on 2026-08-11. Existing runtime images were used as geometry/semantic references. Transparent assets were generated on a flat chroma key and processed with the installed `remove_chroma_key.py` helper using `--auto-key --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.

## Shared visual direction

Warm rice-paper base; walnut wood and warm gray brick neutrals; thin ink-brown linework; dry-brush watercolor grain; restrained soft gray-brown shadow; readable management-game UI; restrained mineral accents (azurite, malachite, gamboge, rouge, burnt sienna). Avoid muddy gray, neon saturation, glossy plastic, chrome, bright metallic gold and thick black cartoon outlines.

## Order card

- Reference: `res://resources/art/ui/order/order_card_multi_dish_v3.png`
- Output: `res://resources/art/ui/order/order_card_multi_dish_v4_chinese_ui.png`
- Key: flat `#ff00ff`
- Prompt-specific constraints: portrait card; blank payment tab; exactly three top dish wells centered near 22%, 50%, 78%; two rows of four requirement wells; empty heart outline; blank patience trough; no text, food, currency or filled heart.

## Locked ingredient-slot cover

- Reference: `res://resources/art/workstation/expansion/trays/ingredient_slot_locked_cover_v1.png`
- Output: `res://resources/art/workstation/expansion/trays/ingredient_slot_locked_cover_v2_chinese_ui.png`
- Key: flat `#ff00ff`
- Prompt-specific constraints: low wide rounded plaque; rice paper and walnut wood; stone-blue/malachite inset accents; one centered closed aged-brass lock; readable at 89×89; no text.

## Order currency icon

- Reference: `res://resources/art/ui/economy/currency_coin_v1.png`
- Output: `res://resources/art/ui/economy/currency_coin_v2_chinese_ui.png`
- Key: flat `#00ff00`
- Prompt-specific constraints: one front-facing traditional round cash coin with a square hole; readable at 22×22; gamboge/ochre/burnt-sienna palette; no extra coins or text.

## Heated-order requirement icon

- Reference: `res://resources/art/ui/quality/quality_heat_uniformity_v1_five_area_v2.png`
- Output: `res://resources/art/ui/quality/quality_heat_requirement_v2_chinese_ui.png`
- Key: flat `#00ff00`
- Prompt-specific constraints: round rice-paper seal with exactly three rouge/burnt-sienna rising steam strokes; readable at 28×28; no flames or text.
