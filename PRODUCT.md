# Product

<!-- impeccable:product-schema 1 -->

## Platform

desktop — Godot PC game

## Users

PC players who enjoy hands-on cooking and shop-management games. The primary play situation is a landscape desktop display with keyboard and mouse; the player alternates between precise food preparation and same-screen production scheduling.

## Product Purpose

Project Cake is a Chinese street-food shop campaign. Players begin with a breakfast jianbing stall, continue into a lunch knife-cut noodle shop, and then unlock a late-night skewer shop. Success means that every shop has a distinctive physical cooking interaction, readable food-quality outcomes, and a satisfying daily business-and-upgrade loop.

## Positioning

Cooking actions are not abstract progress bars: mouse movement, timing, ordering, and workstation coordination leave visible and scoreable differences in the finished food. Each chapter changes the manual skill rather than reskinning one common recipe loop.

## Operating Context

- One campaign contains multiple independently operated shops.
- Only one business day may be open at a time; players switch shops after daily settlement.
- Each shop keeps independent coins and progression while all shops share global reputation.
- Chapter two is the old-town knife-cut noodle shop. Chapter three is a late-night shop combining grilled skewers and fried skewers, unlocked after the chapter-two milestone.
- The third shop uses one customer queue and two concurrent production lines: charcoal grilling and deep frying.

## Capabilities and Constraints

- Engine: Godot 4.7.1, Forward Mobile renderer, Windows development environment.
- Input: keyboard and mouse; core cooking actions use click, drag, and release.
- Baseline logical canvas: 1920×1080. The vertical slice must also remain usable at 1280×720.
- Third-chapter deliverables: a complete design document plus a playable vertical slice integrated into chapter selection, campaign saving, independent shop economy, shared reputation, daily settlement, and next-day upgrades.
- Grilled skewers must emphasize concurrent skewers, turning, seasoning, and heat-zone control.
- Fried skewers must emphasize oil temperature, batch timing, lifting, and draining without duplicating the grill interaction.
- Automatic checks, GPU interaction checks, and human feel/visual acceptance remain separate gates.
- Any requested transparent generated asset is first generated against a pure green background and then keyed to real RGBA, per project policy.

## Brand Commitments

- Preserve the established Chinese cartoon hand-painted world: dark-brown readable outlines, warm orange/cream/gray-green fields, rounded forms, and restrained gouache/paper texture.
- The third chapter should feel unmistakably late-night through lighting and activity while remaining part of the same campaign rather than becoming a separate visual identity.
- Existing product terminology, chapter facts, save behavior, and the first two shops remain unchanged unless explicitly required for third-chapter integration.

## Evidence on Hand

- `docs/game_design.md`: PC interaction, campaign principles, 1920×1080 safe area, and visible cooking outcomes.
- `docs/noodle_shop_vertical_slice.md`: chapter switching, independent coins, shared reputation, daily settlement, and chapter-two vertical-slice precedent.
- `tmp/validation/single_jianbing_stall_gpu_1920x1080.png`: representative first-chapter runtime composition.
- `resources/art/noodle_shop/background/noodle_shop_interior_background-v1.png` and `resources/art/noodle_shop/ART_MANIFEST.md`: representative second-chapter art direction and asset-production precedent.
- `resources/art/night_market/ART_MANIFEST.md`: third-chapter empty background, separate equipment layers, food-doneness atlas, fryer-basket states, cooking effects, green-screen sources, prompt set, and alpha-validation provenance.
- `tmp/validation/night_market_twin_fire_gpu_1920x1080.png` and `tmp/validation/night_market_twin_fire_gpu_1280x720.png`: third-chapter formal layered runtime captures with active grill and fryer states.
- No long-session tuning playtest or human acceptance result exists yet; future work must not claim those separate gates are complete.

## Product Principles

1. Give every shop one memorable manual skill and one distinct scheduling problem.
2. Make mouse actions visible in the food result and legible in scoring feedback.
3. Keep concurrent stations readable on one landscape workbench without modal hopping.
4. Let ordinary mistakes continue into imperfect but deliverable food where the state allows.
5. Treat upgrades as next-day operational changes, not passive percentage inflation.
