# Night Market Formal Layer Prompt Set

## Shared art direction

Chinese hand-painted cooking-game art, warm late-night street-stall lighting, dark-brown readable outlines, rounded friendly forms, restrained gouache and paper texture, warm wood, cream ceramics, gray-green metal, amber fire highlights. Match the approved “双翼火线” composition and its slightly elevated three-quarter countertop perspective. No text, logos, labels, people, hands, UI, borders, drop shadows, or checkerboard transparency previews.

## Empty stall background

Edit the approved twin-fire workstation concept into a clean 16:9 background plate. Preserve the exact night alley, wooden stall frame, lantern glow, floor, countertop perspective, palette, and camera. Remove the charcoal grill, center plating equipment and seasonings, fryer, baskets, utensils, food, steam, smoke, and every interactive prop. Reconstruct one continuous believable empty wooden counter with matching grain, reflections, and perspective. No text or UI.

## Charcoal grill green source

Create one isolated long rectangular charcoal skewer grill in the shared art direction and matching three-quarter perspective. Dark iron body, six readable skewer rails across three heat zones, glowing coals visible beneath, sturdy legs and rim, no skewers or food. Center the complete object with generous clearance on a perfectly flat pure chroma-green background. No cast shadow and no green material on the object.

## Plating station green source

Create one isolated central plating station in the shared art direction and perspective: a low warm-wood work surface, one empty cream ceramic serving plate, four small seasoning bowls, brushes and compact utensil holders arranged behind it. No food and no text. Center the complete object with generous clearance on a perfectly flat pure chroma-green background. No cast shadow and no green material on the object.

## Fryer sources

Create one isolated twin-vat countertop fryer in the shared art direction and perspective: gray-green/dark iron body, two oil wells, right-side draining rack, readable handles and rim details. For the complete variant include two wire baskets; for the runtime base variant remove every basket so the basket animation can be layered separately. Center the complete object on a perfectly flat pure chroma-green background. No steam, bubbles, food, text, shadow, or green material on the object.

## Food doneness atlas

Create a clean orthographic 4×4 sprite atlas on perfectly flat pure chroma green. Every cell contains exactly one full skewer in the same left-to-right orientation, centered with equal padding and consistent scale. Rows: lamb cubes; chicken cubes with green pepper; lotus-root slices; potato slices. Columns: raw, lightly cooked/turning color, ideal golden cooked, heavily charred. Keep wooden sticks, silhouettes, and camera angle consistent so states can swap without jumping. No separators, labels, shadows, cropped food, extra objects, text, or green spill.

## Fryer basket atlas

Create a clean horizontal 3-cell sprite atlas on perfectly flat pure chroma green. Each cell contains the same empty wire fryer basket and handle in consistent scale and perspective. States: basket raised above oil, basket lowered into the fryer, basket tilted/resting to drain. Isolate the basket only—no fryer body, oil, food, bubbles, steam, labels, borders, or shadows.

## Cooking effects atlas

Create a clean 4×2 VFX sprite atlas on perfectly flat pure chroma green, with centered effects and generous cell padding. Top row: low ember glow, medium ember glow, strong ember glow, thin dark cooking smoke. Bottom row: gentle oil bubbles, active oil bubbles, vigorous oil bubbles, warm seasoning powder sprinkle. Effects only; no equipment, food, hands, labels, borders, or shadows. Avoid green within the effects.

## Alpha extraction instruction

Using the corresponding green-screen source, remove only the pure chroma-green field and edge spill. Preserve the illustrated object, dark outlines, holes and thin wires. Output real RGBA transparency, not a painted checkerboard, white matte, or cropped preview. Keep the original canvas, scale, position, and pixel dimensions unchanged.
