# Product

<!-- impeccable:product-schema 1 -->

## Platform

Desktop PC game built with Godot 4.7.1 .NET and C#.

## Users

Players who enjoy relaxed time-management, hands-on food preparation, and light shop progression. The primary interaction is mouse click, drag, and short gesture input.

## Product Purpose

《早餐铺子》让玩家在两分钟左右的早餐高峰中亲手制作地方早餐、安排并行工作、服务顾客并使用收入升级店铺。天津是第一章，目标是从学会制作煎饼逐步成长为能够掌控完整早餐工作台的店主。

## Positioning

The game combines tactile breakfast preparation with a deterministic customer rush and visible equipment upgrades. Management supports the making experience instead of replacing it with menus or passive number growth.

## Operating Context

The player moves through a shop-management home, a timed service shift, a receipt-style result, and back to the management home. Tianjin contains 15 playable days, pancakes, batched youtiao frying, ready-made soy milk, four customer types, equipment upgrades, chapter stars, and city progression.

## Capabilities and Constraints

- Preserve the existing day data, order generation, customer patience, cooking state machines, economy values, star goals, and version 2 save format.
- The first chapter is light management. Purchasing ingredients, rent, staffing, free-form decoration, and complex finance are out of scope.
- The shipping view targets 16:9 PC displays at a 1920×1080 design resolution and scales through Godot canvas stretching.
- Developer tools remain available only behind the `--dev-ui` command-line flag.

## Brand Commitments

- Product name: 《早餐铺子》.
- Tianjin art in `resource/art/TianJin` is the visual authority.
- UI is two-dimensional, flat, rounded, simple, strongly outlined, low-detail, and warm.
- Use cream, warm yellow, light orange, and warm brown, with limited light green and light red for status.
- Do not use glass, decorative blur, metallic material, realistic texture, complex gradients, bevels, or multi-layer shadows.

## Evidence on Hand

- Complete Tianjin chapter design and balancing documents in `docs`.
- Background, three stove levels, three fryer levels, food layers, ingredients, tools, 24 customer appearances with four expressions each, soy milk, finished products, and coin art in `resource/art/TianJin`.
- Existing deterministic self-tests and visual-capture scenes for all gameplay systems.
- Customer portraits are integrated. A bespoke order bubble and a bespoke patience frame are not yet available; their runtime-drawn replacements must remain swappable.

## Product Principles

- The workbench is the interface: food and equipment should communicate state before text does.
- Busy moments come from prioritization and parallel work, not hostile randomness.
- Equipment upgrades must be visually obvious and meaningfully reduce mechanical pressure.
- Mistakes reduce earnings and satisfaction without punishing the player with resource debt.
- Every non-service screen should lead clearly back to opening the shop.

## Accessibility & Inclusion

Status is never communicated by color alone. Interactive targets are at least 48×48 design pixels, Chinese body copy is at least 18 design pixels, and the largest five-customer order layout must remain readable at 1280×720.
