# Workstation expansion assets v1 — prompt record

Generated with Codex built-in `image_gen` on 2026-08-03 (Asia/Shanghai). Every output uses a flat chroma-key background and is converted locally to RGBA with the imagegen skill helper.

## Shared reference roles

- Image 1: `visual_style_anchor_v8.png`, style reference only. Match its warm hand-painted 2D mobile-breakfast-cart art, strong dark-brown outlines, restrained texture, upper-left morning light, teal enamel, warm ivory, brass and stainless steel.
- Image 2: `workstation_expansion_concept_v3_1920x1080.png`, layout and object-semantics reference only. Do not copy its labels, guide lines or UI text.
- Optional Image 3: an existing ProjectCake tool, restock container or ingredient image, silhouette/material reference only.

## Shared generation constraints

Use case: stylized-concept
Asset type: ProjectCake 2D game sprite
Scene/backdrop: perfectly flat solid chroma-key background, uniform edge to edge, with no floor plane, shadow, gradient, texture, reflection or lighting variation
Style/medium: polished hand-painted 2D game prop; semi-orthographic three-quarter top-front view; readable at 96–180 px
Lighting/mood: gentle warm light from upper left; controlled highlights; no cast shadow
Color palette: warm ivory enamel, aged teal, dark brown outline, brass accents, restrained stainless steel and food colors
Constraints: one isolated opaque prop; centered; generous padding; crisp silhouette; no text; no numerals; no labels; no logos; no watermark; no extra props; no scenery; no human hands; no steam or translucent effects

## Per-asset deltas

- `soy_milk_machine_tier_1_v1`: compact countertop soy-milk maker with bean hopper, water inlet, one processing body and maximum two-cup collection shelf; visibly manual add-beans/add-water/start/collect workflow; 16-second tier semantics. It may start below maximum capacity and finished cups do not spoil but remain in the shelf.
- `soy_milk_machine_tier_2_v1`: same identity and footprint as tier 1; added compact brass timing dial, reinforced teal motor collar and small speed gauge; maximum two cups, 12-second tier semantics, no extra outlet and no automation.
- `soy_milk_machine_tier_3_v1`: same identity; larger hopper and exactly four visible empty cups in a 2×2 arrangement under one central processing/dispensing assembly; 12-second tier semantics, inherited speed hardware and reinforced insulated casing. No automatic feeding, opening, or collection module.
- `youtiao_fryer_tier_1_v1`: compact horizontal maximum-two-stick fryer with oil well, manual start knob, wire draining rack and tongs rest; 12-second tier semantics; no loose food and no automation.
- `youtiao_fryer_tier_2_v1`: same footprint; reinforced heater housing, compact timing dial and stronger brass heat-control hardware; maximum two sticks, 9-second tier semantics; no extra basket and no automation.
- `youtiao_fryer_tier_3_v1`: same identity; widened maximum-four-stick oil well, double draining basket and insulated holding lid that communicates indefinite warm holding while finished food still occupies capacity; 9-second tier semantics; no automatic feeding or collection module.
- `egg_waffle_machine_tier_1_v1`: compact hinged egg-waffle iron with one maximum-one-portion round bubble-pattern plate, long handle, manual thermostat knob and visible lid hinge; 20-second tier semantics.
- `egg_waffle_machine_tier_2_v1`: same identity; reinforced hinge, clearer brass thermostat and small speed/timing gauge; maximum one portion, 15-second tier semantics; no automation.
- `egg_waffle_machine_tier_3_v1`: same identity; exactly two side-by-side bubble-pattern stations under one double-wide manually operated insulated lid and one shared handle, with inherited tier-2 controls; 15-second tier semantics and indefinite warm holding while finished portions continue occupying both stations; no automatic batter feed, lid operation, or collection module.
- `single_press_spreader_v1`: player-visible name is “压饼神器”; stable English file ID remains `single_press_spreader`. Permanent countertop single-press pancake device, broad round press head sized for one pancake, compact teal/brass hinge arm and one manual lever; used once per pancake, not a consumable and not a loose stamp.
- `automatic_sauce_brush_v1`: fixed automatic sauce-brushing tool with food-safe silicone brush head, small teal motor housing, brass pivot arm and docking bracket; visibly mechanized, unlike the existing manual brush.
- `ingredient_tray_4x3_v1`: empty one-piece 4 columns by 3 rows ingredient tray frame, twelve identical recessed bins, no ingredients, no labels, no locks, top-front view and a wide 2:1 silhouette.
- `ingredient_slot_locked_cover_v1`: one removable locked-slot cover for a single tray cell, dark desaturated teal enamel plate with a simple raised padlock silhouette, no text or symbols beyond the physical lock shape.
- `small_ingredient_box_tier_1_v1`: shallow single-cell ingredient box, low rim, maximum 6 portions, empty interior.
- `small_ingredient_box_tier_2_v1`: same footprint and angle; visibly taller wall, reinforced brass rim, maximum 10 portions, empty interior.
- `small_ingredient_box_tier_3_v1`: same footprint and angle; deepest wall, double reinforced rim, maximum 14 portions, empty interior; no wider footprint.

Equipment-level invariants: maximum capacity never means a full-load requirement; a batch may start with any positive amount; one batch never mixes main recipes. Basic/mid youtiao and egg-waffle art must not imply indefinite holding (they have only a 5-second safe window in logic). Automation for feeding, lid operation, and collection is always a separately purchased visible module and must not appear in tier art.
- `yellow_soybean_portion_v1`: small readable portion of glossy pale-yellow soybeans in a shallow teal enamel scoop; no loose background beans.
- `plain_soy_milk_cup_v1`: one warm ivory paper cup of pale creamy soy milk, simple teal rim, no text, no logo, no steam.
- `plain_youtiao_dough_v1`: two neat pale uncooked youtiao dough strips, lightly floured, parallel and clearly raw.
- `plain_youtiao_v1`: two finished golden-brown youtiao sticks, airy ridged shape, no plate, no sauce.
- `plain_egg_waffle_batter_v1`: one compact pouring cup of pale golden batter, visible spout, no text and no spill.
- `plain_egg_waffle_v1`: one finished Hong Kong-style egg waffle portion, curved sheet of round bubbles, warm golden surface, no plate or topping.

## First unlock flavor variants

- `red_bean_portion_v1`: the same teal measuring scoop family, filled with small glossy deep-red adzuki beans.
- `black_bean_portion_v1`: the same scoop family, filled with charcoal-black beans with cool navy highlights and pale seams so they remain readable against teal.
- `red_bean_soy_milk_cup_v1`: the same paper cup family, pale rose-beige soy milk with exactly three tiny red-bean flecks on the liquid surface.
- `black_bean_soy_milk_cup_v1`: the same paper cup family, pale cool gray-lavender soy milk with exactly three tiny black-bean flecks on the liquid surface.
- `sesame_youtiao_dough_v1`: exactly two raw pale dough strips with embedded black and ivory sesame seeds; no loose seeds.
- `scallion_youtiao_dough_v1`: exactly two raw pale dough strips with embedded bright/dark green scallion pieces; no loose scallion.
- `sesame_youtiao_v1`: exactly two cooked golden youtiao sticks with embedded toasted black and ivory sesame seeds.
- `scallion_youtiao_v1`: exactly two cooked golden youtiao sticks with embedded cooked green scallion pieces.
- `strawberry_sauce_bottle_v1`: one translucent squeeze bottle of berry-red sauce with a cream nozzle, teal collar and physical strawberry relief; no printed label.
- `chocolate_sauce_bottle_v1`: the same bottle family, filled with rich chocolate-brown sauce and a physical cocoa-bean relief; no printed label.
- `strawberry_egg_waffle_v1`: the plain egg-waffle base with three broad strawberry-pink sauce ribbons contained within the waffle silhouette.
- `chocolate_egg_waffle_v1`: the plain egg-waffle base with three broad chocolate-brown sauce ribbons contained within the waffle silhouette.

All recipe icons were generated as independent assets, not a sprite sheet. Their final canvases are 512×512 RGBA; the raw keyed and alpha-intermediate sources are retained under `tmp/imagegen/workstation_expansion_v1/sources/`.

## Second expansion recipe batch — 2026-08-04

Each asset below is generated independently with the corresponding accepted ProjectCake icon as Image 1 edit target/style-and-silhouette authority. Change only the named food identity; preserve the canvas, camera angle, scale, vessel family, upper-left warm light, thick dark-brown outline, restrained three-level shading and generous padding. Replace the transparent backdrop during generation with one perfectly uniform flat `#ff00ff` chroma field reaching every edge and corner. No shadows, gradients, texture, floor plane, reflections or lighting variation in the background. Do not use magenta in the subject. No text, labels, numerals, logos, watermark, hands, scenery or extra props.

### Soy-milk main recipes

- `peanut_portion_v1`: preserve the yellow-soybean teal measuring scoop exactly; replace only the contents with about nine clearly separated shelled pale-tan peanuts, each with a warm reddish seam, no shells and no loose nuts.
- `mung_bean_portion_v1`: preserve the scoop exactly; replace only the contents with small glossy green mung beans, using yellow-green highlights and tiny pale seams for recognition.
- `five_grain_mix_portion_v1`: preserve the scoop exactly; replace only the contents with a controlled readable five-grain mix of exactly five visually distinct grain families—pale oat kernels, golden millet, reddish sorghum, brown rice and small black rice—without turning into noisy confetti.
- `peanut_soy_milk_cup_v1`: preserve the plain soy-milk cup exactly; change only the liquid to warm pale peanut beige and add exactly three tiny peanut crumbs on the surface.
- `mung_bean_soy_milk_cup_v1`: preserve the cup exactly; change only the liquid to pale muted celadon-green and add exactly three tiny green-bean flecks on the surface.
- `five_grain_soy_milk_cup_v1`: preserve the cup exactly; change only the liquid to warm light oatmeal-tan and add exactly five sparse tiny grain flecks in restrained brown, gold and red tones.

### Youtiao main recipes

- `glutinous_rice_youtiao_dough_v1`: preserve the two-strip raw youtiao composition exactly; make both strips slightly plumper, pearl-ivory and subtly glossy/elastic, with a restrained dusting of rice flour; no grains, plate or filling.
- `multigrain_youtiao_dough_v1`: preserve exactly two raw dough strips; use a pale wheat-beige dough with sparse embedded brown, gold and dark grain flecks large enough to read at icon scale; no loose grains.
- `filled_youtiao_dough_v1`: preserve exactly two raw dough strips; make each strip slightly thicker with one clear continuous sealed center ridge that communicates an enclosed filling, but do not expose or identify the flavor at the raw stage.
- `glutinous_rice_youtiao_v1`: preserve exactly two finished youtiao sticks; make them slightly plumper with a crisp golden exterior and restrained pearl-ivory chewy breaks at the ends, without plate or loose rice.
- `multigrain_youtiao_v1`: preserve exactly two finished golden youtiao sticks; add sparse embedded toasted brown, gold and dark grain flecks, clearly distinct from sesame dots and scallion pieces.
- `filled_youtiao_v1`: exactly two finished golden youtiao sticks; one remains whole with a visible sealed center ridge, and the other has one clean broken end revealing a compact neutral warm-brown filling core. The filling is intentionally flavor-neutral: no beans, meat, cream, cheese or written label.

### Egg-waffle main recipe and add-ons

- `matcha_egg_waffle_batter_v1`: preserve the plain batter pouring cup exactly; change only the batter to an opaque muted matcha-green mixture with one broad cream highlight, no powder mound and no garnish.
- `sesame_topping_portion_v1`: use the yellow-soybean scoop as vessel authority but reduce it to a shallow single serving; fill with a clearly separated mix of toasted ivory and black sesame grains, no sauce, no loose seeds.
- `dried_fruit_topping_portion_v1`: use the same shallow teal serving scoop; fill with chunky, readable dried-fruit bits in restrained cranberry red, apricot orange and raisin purple-brown, no fresh fruit, syrup or loose pieces.
- `matcha_egg_waffle_v1`: preserve the plain egg-waffle curved bubble sheet exactly; change the baked surface to warm muted matcha green with golden-brown toasted rims, no sauce or topping.
- `sesame_egg_waffle_v1`: preserve the plain golden egg-waffle sheet; add sparse clearly embedded toasted black and ivory sesame grains across the bubbles, contained within the silhouette.
- `dried_fruit_egg_waffle_v1`: preserve the plain golden egg-waffle sheet; add a sparse scatter of chunky dried-fruit bits in cranberry red, apricot orange and raisin purple-brown, all contained within the silhouette and readable as dried pieces rather than sauce.

Raw keyed sources, alpha intermediates and final RGBA outputs for this batch remain under the same provenance and validation rules as the first batch.

### Accepted chroma correction

The first `glutinous_rice_youtiao_v1` source used `#ff00ff`, but the prescribed soft matte/despill path visibly desaturated the golden-orange subject. That source was rejected and retained as `glutinous_rice_youtiao_v1_magenta_rejected.png`. The accepted iteration kept the same two-stick food specification but used a perfectly flat `#00ff00` background with no green in the subject, then ran `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` before 512×512 normalization.
