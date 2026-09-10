# Product

<!-- impeccable:product-schema 1 -->

## Platform

Desktop PC game built with Godot 4.7.1 .NET and C#.

## Users

Players who enjoy relaxed time-management, hands-on food preparation, and light shop progression. The primary interaction is mouse click, drag, and short gesture input.

## Product Purpose

《早餐铺子》以“去各地开早餐铺”为主题，让玩家在两分钟左右的早餐高峰中亲手制作地方早餐、安排并行工作、服务顾客并使用收入升级店铺。天津是第一章，目标是从学会制作煎饼逐步成长为能够掌控完整早餐工作台的店主；全局品牌不绑定某一城市或固定城市数量。

## Positioning

The game combines tactile breakfast preparation with a deterministic customer rush and visible equipment upgrades. Management supports the making experience instead of replacing it with menus or passive number growth.

## Operating Context

The app opens on a global title page with fixed New Game, Continue, and Quit actions. A new game enters Tianjin; an existing or unreadable save requires explicit reset confirmation with Cancel focused by default. Continue opens the last saved city's management home, not an interrupted service shift; it remains visible but disabled when no readable save exists. Quit exits without saving. A failed save keeps the player on the title page with recovery guidance and preserves prior progress.

The player then moves through a shop-management home, a timed service shift, a receipt-style result, and back to the management home. Tianjin contains 15 playable days, pancakes, batched youtiao frying, ready-made soy milk, four customer types, equipment upgrades, chapter stars, and city progression.

## Capabilities and Constraints

- Preserve the existing day data, order generation, customer patience, cooking state machines, economy values, and star goals. The current save format is v3, with optional `LastVisitedCityId` defaulting to Tianjin. Earlier v3 saves without this field remain readable; v1/v2 retain their migration path. Unknown or locked resume destinations fall back to Tianjin. Saved-game availability follows successful persistence rather than coin or day totals.
- The first chapter is light management. Purchasing ingredients, rent, staffing, free-form decoration, and complex finance are out of scope.
- The shipping view targets 16:9 PC displays at a 1920×1080 design resolution and scales through Godot canvas stretching. The title page centers and scales its own canvas with letterboxing on wider displays, restoring the city's original window aspect mode when hidden.
- Developer tools remain available only behind the `--dev-ui` command-line flag.

## Brand Commitments

- Product name: 《早餐铺子》.
- The global cover's visual authority is `resource/art/Global/start-journey.png` and `Scripts/UI/StartScreenTheme.cs`: a generic dawn shop, suitcase, closed notebook, and receding street accompany the game title and fixed menu. This identity is independent of the city roster. Tianjin art in `resource/art/TianJin` is authoritative for the Tianjin chapter; other cities keep their own skins.
- UI is two-dimensional, flat, rounded, simple, strongly outlined, low-detail, and warm.
- The global cover uses cream, teal, apricot, and brick. Tianjin uses cream, warm yellow, light orange, and warm brown; city skins preserve the shared rounded 2D style and common feedback semantics.
- Do not use glass, decorative blur, metallic material, realistic texture, complex gradients, bevels, or multi-layer shadows.

## Evidence on Hand

- The implemented global title page, save compatibility, and 1920×1080, 1280×720, and 1600×720 captures are documented in [游戏开始页](docs/游戏开始页.md). Its motion is limited to a 250ms entrance fade and 120ms button feedback; the background is static.
- Complete Tianjin chapter design and balancing documents in `docs`.
- Background, three stove levels, three fryer levels, food layers, ingredients, tools, 24 customer appearances with four expressions each, soy milk, finished products, and coin art in `resource/art/TianJin`.
- Existing deterministic self-tests and visual-capture scenes for all gameplay systems.
- Customer portraits and the shared Tianjin/Wuhan `OrderBubbleView` are integrated. Each pancake or noodle portion has its own icon row and extras; side products share a bottom row with delivered/required fractions. Completed regions turn green independently. Product names, ordinals, customer types, status copy, and overall progress are absent; patience remains a dynamic bar. See [天津与武汉图标订单气泡](docs/天津与武汉图标订单气泡.md). Tianjin stock art shows exact units up to six, up to ten separated density slots above six, and separate liquid levels.

## Product Principles

- The workbench is the interface: food and equipment should communicate state before text does.
- Busy moments come from prioritization and parallel work, not hostile randomness.
- Equipment upgrades must be visually obvious and meaningfully reduce mechanical pressure.
- Mistakes reduce earnings and satisfaction without punishing the player with resource debt.
- Every non-service screen should lead clearly back to opening the shop.

## Accessibility & Inclusion

Status normally has a non-color cue. The user-approved icon-only order bubble is a local exception: main-portion completion changes its region to green without adding status text or marks; side products also show delivered/required fractions, and patience uses bar length. Interactive targets are at least 48×48 design pixels, Chinese body copy is at least 18 design pixels, and the largest five-customer order layout must remain readable at 1280×720.
