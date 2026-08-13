# Steamer whole-machine v5 Chinese set

## Scope and generator

- Generated on 2026-08-12 with Codex built-in `imagegen` in image-edit mode.
- Runtime target: `res://scenes/gameplay/direct_steamer_station.tscn` only.
- Visual reference: the existing v2 Chinese steamer artwork. Existing v4 files were retained and were not overwritten.
- Generation order: tier 2 closed first; tier 2 open was edited from that result; tiers 1 and 3 were then derived while preserving the same base, center line, perspective, palette, outline and rendering style. The first tier 3 open result had only three baskets and was rejected; the selected correction has exactly four.

## Prompt contract

All generations used the following shared constraints:

> Create a complete Chinese bamboo steamer workstation as one coherent game sprite. Moderate hand-painted Chinese breakfast-cart style, warm bamboo and muted red metal base, dark brown outlines, consistent three-quarter perspective. Flat solid #FF00FF chroma-key background. No food, steam, text, labels, UI, cast shadow, floor, wall, scenery, or separate loose parts. Keep the entire machine inside frame with generous clearance.

Closed variants added:

> The fitted domed bamboo lid is centered and fully closed. Show exactly the requested number of visible stacked bamboo steaming baskets: tier 1 has one, tier 2 has two, tier 3 has four. Basket seams must close cleanly with consistent diameter, perspective, and spacing.

Open variants used the selected closed image for the same tier as the edit reference and added:

> Preserve the base, every basket, center point, silhouette, scale, colors, outlines and camera perspective exactly. Change only the lid: lift it clearly above and slightly behind the stack so the open state is unmistakable and the basket opening is visible. Do not add, remove, resize, or restack baskets.

## Selected source outputs

- tier 1 closed: `exec-c6041d1d-842c-4621-bcb5-feb6340a4b97.png`
- tier 1 open: `exec-6cf6b4ed-231a-420c-8e8a-b452d5ac7a24.png`
- tier 2 closed: `exec-6b0c2093-9503-4494-b554-863539d831d1.png`
- tier 2 open: `exec-a7b6f8f5-da3a-4675-bd67-9f8973114534.png`
- tier 3 closed: `exec-9f319cf7-a866-4133-8d54-3965d65a6f6f.png`
- tier 3 open selected correction: `exec-9ac2684f-79f4-4c2d-8698-1fbf48ff969e.png`
- rejected tier 3 open draft: `exec-183f3cb9-93f1-42b1-950c-3732d99a9907.png` (three baskets; not used)

The selected sources are staged under `res://tmp/imagegen/steamer_v5/sources/`.

## Processing and final files

- Magenta-key removal used the installed ImageGen helper with soft matte/despill. The selected tier 3 open needed a conservative high-red/high-blue/low-green mask because the generic helper also selected yellow bamboo pixels.
- `res://tools/build_steamer_v5_assets.py` normalizes each open/closed pair to one shared 1024x512 registration without changing aspect ratio, then removes resize-induced magenta residue.
- Final runtime files are `steamer_tier_{1,2,3}_{closed,open}_five_area_v5_chinese.png` under `res://resources/art/workstation/expansion/machines/`.
- Pair bounds: tier 1 `Rect2(332,12,359,500)`; tier 2 `Rect2(334,12,356,500)`; tier 3 `Rect2(338,12,347,500)`.
- Audit: `res://tmp/validation/steamer_v5_asset_audit.json`.
- Contact sheet: `res://tmp/validation/steamer_v5_contact_sheet.png`.
- Automated asset acceptance: all six are 1024x512 RGBA, decodable by Godot, have transparent corners, contain no residual key color, and retain identical open/closed registration within each tier.
- Human art acceptance: pending. Automated and GPU checks do not substitute for the requested human review of the tier 2 seam, lid readability, perspective and upgrade progression.
