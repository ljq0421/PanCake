# Steamer whole-machine v6 Chinese set

## Reason for replacement

The v5 sprites used inconsistent subject bounds, so fixed-size runtime boxes made tiers 2 and 3 appear narrower than tier 1. Their bright orange bamboo and heavier icon-like outlines also did not match the current ProjectCake start page and workstation machines.

## Style authority

- Start-page authority: `start_menu_background_morning_mobile_cart_v3_chinese.png`.
- Workstation machine authorities: `soy_milk_machine_tier_1_v1_chinese.png`, `youtiao_fryer_tier_1_body_v2_chinese.png`, and `packaged_drink_heater_tier_2_v3_chinese.png`.
- Shared visual language: warm cream enamel, desaturated celadon trim, aged brass/copper controls, muted natural materials, thin ink-brown contours and subtle rice-paper/watercolor grain.

## Generation workflow

- Generator: Codex built-in imagegen in image-edit mode on 2026-08-12.
- Tier 2 closed was created first and refined into the sole geometry/style mother asset.
- Tier 2 open changed only the lid.
- Tier 1 removed exactly one basket from the tier-2 mother while retaining the same broad base and basket diameter; its open state changed only the lid.
- Tier 3 added exactly two baskets to the tier-2 mother for four total, retaining the same broad base and basket diameter; its open state changed only the lid.
- All prompts prohibited food, steam, text, UI, cast shadows and scenery and requested a flat `#FF00FF` background.

Selected generated sources:

- tier 1 closed: `exec-a1835277-6fc7-47c6-aecc-126a6be48ac9.png`
- tier 1 open: `exec-06c185dc-ce1c-4ab9-bfa0-512afa53a2b4.png`
- tier 2 closed mother: `exec-caca9eb5-3562-4000-bb1a-a64b736f1feb.png`
- tier 2 open: `exec-cbda9de1-7d33-48c6-959a-30aaacebfd26.png`
- tier 3 closed: `exec-7bab322c-246e-4bf1-bd65-ae812ee7ff10.png`
- tier 3 open: `exec-7ec9b586-344a-49c3-8247-78b9a10d6219.png`

## Processing and runtime geometry

- Sources are retained under `res://tmp/imagegen/steamer_v6/sources/`.
- A hard edge-connected key removal was selected because generated open-state magenta included slight texture; the generic soft matte created unacceptable translucent background fog.
- `res://tools/build_steamer_v6_assets.py` creates 1024x1536 RGBA assets, zeroes residual key pixels, bottom-aligns every state and normalizes every state to the same 690-pixel subject width.
- Runtime files use `steamer_tier_{1,2,3}_{closed,open}_five_area_v6_chinese.png`.
- Runtime display uses the same physical width of 300 pixels for every tier and a fixed bottom registration. Higher tiers extend upward instead of shrinking into a fixed-height icon box.
- Audit: `res://tmp/validation/steamer_v6_asset_audit.json`.
- Contact sheet: `res://tmp/validation/steamer_v6_contact_sheet.png`.
- Formal-workstation GPU captures: `res://tmp/validation/direct_steamer_v6/`.
- Human art acceptance remains separate from automated and agent visual review.
