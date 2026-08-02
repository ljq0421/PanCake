# workstation_backplate_v1 生成提示词

## 初始底板

```text
Use case: precise-object-edit
Asset type: ProjectCake layer-ready full rectangular workstation static backplate, P0/P1 key asset
Input images: Image 1 is the approved v8 visual and composition anchor
Primary request: convert the approved anchor into a clean static workstation background plate while preserving the exact 16:9 fixed near-top-down camera, warm street-stall environment, workstation footprint, color palette, line weight and established geometry.
Remove all dynamic or separately layered content: remove the customer completely; remove the patience frame and order card; remove the central griddle and its rim/shadow; remove every food ingredient from all twelve bins; remove the movable scraper, spatula and any loose tool; remove any pancake, payment, coin, banknote, hand, effect or text. Do not leave ghost silhouettes or object-shaped shadows.
Preserve fixed architecture: keep the tiled warm customer-area floor/background; keep the strong rear counter boundary that separates the customer zone from the workstation; keep the long empty payment tray in its approved v8 position and length; keep exactly six empty vegetarian-side bin wells on the left and six empty meat-side bin wells on the right, using identical clean empty stainless or dark inset interiors; keep the fixed counter surface, tool-holder recesses, heat-control base plate and bottom workstation structure. Keep the upper-left napkin box and chopstick holder, upper-right sauce-bottle holder and small plant as fixed noninteractive stall dressing, with their existing style and positions.
Central griddle mounting area: where the griddle was, show only a clean uninterrupted warm countertop or a subtle flat recessed mounting zone with no griddle, no rim, no dark oval, no shadow and no scorch mark. Leave generous clear space for a separately layered griddle sprite.
Foreground layering: simplify the front-most bottom counter edge into an unobtrusive base surface so a separately generated foreground lip/occluder can later be placed over it. Do not add hands, cloths or foreground props.
Style/medium: match v8 exactly—simple hand-drawn 2D cartoon game art, bold clean deep-brown outlines, large flat color shapes, at most base plus one shadow and one highlight, restrained warm cream/mustard/terracotta/faded-teal palette, crisp silhouettes, minimal texture.
Constraints: full rectangular opaque background; one workstation only; exact 12 empty bins; no customer, no UI, no griddle, no ingredients, no movable tools, no payment, no shadows belonging to removed objects, no readable text, letters, numbers, currency symbols, brands, logos, watermarks, magical content, photorealism, 3D gloss, painterly texture, thin lines, camera zoom, crop or perspective drift.
```

## 交互控件清理

```text
Use case: precise-object-edit
Asset type: ProjectCake static workstation backplate cleanup
Input images: Image 1 is the workstation backplate edit target
Primary request: remove only the two remaining interactive controls baked into the bottom strip: remove the black rotary heat knob from the small teal control plate, and remove the long orange-handled slider/tool from the dark recessed rectangular track. Reconstruct the exposed surfaces as clean empty fixed base plates matching the surrounding material, perspective, outlines and lighting.
The small teal plate should remain as an empty clean mounting area with no knob, pointer, tick marks, colored indicator marks, labels or object shadow. The long dark recessed track should remain as an empty clean holder/control recess with no handle, bar, slider, loose tool or object shadow.
Absolute invariants: preserve every other pixel-level layout element and the exact canvas—warm tiled customer background, rear counter boundary, long empty payment tray, upper-left napkins and chopsticks, upper-right sauce bottles and plant, exactly twelve empty ingredient wells, clean central griddle mounting area, empty lower-left tool mat, countertop, front edge, fixed near-top-down camera, palette, bold deep-brown outlines, large flat colors and minimal texture. Do not add or move anything else.
Constraints: no customer, UI, griddle, ingredients, movable tools, payments, text, letters, numbers, currency symbols, brands, logos, watermarks, magical content, photorealism, 3D gloss, painterly texture, thin lines, zoom, crop or perspective drift.
```
