# Initial Unlock Workstation Redraw v2

Generated: 2026-08-03 (Asia/Shanghai)  
Generator: built-in `image_gen`  
Runtime target: Godot 4.7.1, 1920×1080

## Sources and roles

- `workstation_backplate_morning_mobile_cart_v1.png`: established tiled-wall, counter-material and hand-painted style reference.
- `codex-clipboard-daede357-b72e-4192-b245-196a065d7315.png`: recessed metal ingredient-pan depth reference.
- The generated full workstation is consumed through an `AtlasTexture` crop. The tool rack was generated separately so `.tscn` controls its exact 620×135 position.

## Successful full-workstation prompt

> Edit Image 1 into a production-ready 16:9 background for the opening-day workstation of a hand-painted Chinese jianbing game. Image 1 is the edit target and its established style; Image 2 is only the spatial-depth reference for metal ingredient pans.
>
> Preserve the cool tiled wall, warm morning light, back shelf, sauce-bottle caddy and plant of Image 1. Completely repaint the workstation from about 42% canvas height downward as ONE continuous cream-enamel physical counter with believable thickness, perspective, metal edge trim, seams, front cabinet depth and ambient shadows.
>
> Required fixed structure: center clean mounting well for a separate griddle; a real empty bracketed tool rack; two stacked left equipment cavities; exactly 12 empty metal ingredient pans in 4×3; one lower-right fryer cavity. No UI, text, locks, food, tools, appliances, griddle, steamer or watermark. Do not retain the old 2×3 tray banks. All bays, pans and rack parts must be constructed physical objects with depth and support.

## Successful isolated-tool-rack prompt

> Recreate only the physical empty wall-mounted tool rack from the full-workstation reference. Use a dark stained wood/bronze backplate, two wall brackets, one aged steel rail and exactly seven evenly spaced hooks. Match the polished hand-painted game style. Render on a perfectly flat `#00ff00` chroma-key background with no shadow, texture, text, tool, icon or watermark.

The keyed source is retained at `tmp/imagegen/initial_unlock_redraw_v2/wall_tool_rack_initial_v2_key.png`. Transparency was produced with the installed `remove_chroma_key.py` helper using auto-key, soft matte and despill.

## Output evidence

| File | Size | SHA-256 |
| --- | ---: | --- |
| `resources/art/workstation/background/workstation_initial_unlock_redraw_v2.png` | 2,224,086 bytes | `5F820E67AC87F3B89B48CBF1A25460D48A8494DDBF28DAF96B84E40227621AB5` |
| `resources/art/workstation/tools/wall_tool_rack_initial_v2.png` | 695,817 bytes | `2389CFC094639826FEBE6A1A1A681E0ABB6D03BB469274ACDF8723B5C23542EB` |

Tool-rack alpha validation: 1836×857 RGBA, corner alpha `0,0,0,0`, used alpha bounds `(116,195)-(1720,616)`.

## Acceptance boundary

- Generated and project-integrated: yes.
- Godot imported/runtime loaded: verified by the workstation scene checks.
- Automated GPU screenshot review: recorded separately.
- Human visual and mouse acceptance: pending.
