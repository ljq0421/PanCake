# visual_style_anchor_v5 生成提示词

## 1. 初始布局重构

```text
Use case: precise-object-edit
Asset type: ProjectCake gameplay composition anchor v5, major layout revision
Input images: Image 1 is the v4 edit target and exact visual-style reference
Primary request: redesign the composition while preserving v4's simple bold 2D cartoon style. Create more vertical room for a clearly separated half-body customer and customer UI, reduce the central griddle to approximately 80 percent of its v4 diameter, and make the physical workstation slightly smaller within the 16:9 canvas.
Composition: fixed straight near-top-down vendor-side gameplay camera, 1672x941-style 16:9 canvas. Reserve roughly the upper 35 to 40 percent for the customer zone and the lower 60 to 65 percent for the workstation. The customer zone and workstation must be separated by an unmistakable back counter edge/occluding rail. Show one customer's complete head, hair, shoulders, arms and torso down to approximately the waist behind the counter. The counter edge must visibly occlude the lower torso so the customer reads as standing behind the stall, never embedded inside the workstation.
Central interaction surface: one single round dark iron griddle only, centered in the lower workstation, approximately 80 percent of v4's diameter, still the largest interaction target, completely visible, with clear open space around it. Preserve the bottom heat-control/current-tool strip and keep it fully visible.
Ingredient organization: replace the old eight-slot right-side arrangement with twelve clearly separated fixed ingredient bins total. Put six vegetarian topping bins on the left side of the griddle in a clean 2-column by 3-row group. Put six meat topping bins on the right side of the griddle in a matching 2-column by 3-row group. The left/right groups must be visually balanced and reachable. Use simple recognizable food color blocks only; these are layout placeholders, not final ingredient designs. Keep cooking tools in a stable lower strip or compact lower-side holders so they do not occupy the ingredient bins.
Payment area: keep the payment receiving area at the upper counter directly in front of the customer, but make it much longer horizontally. It should form one long shallow empty rounded tray spanning approximately from the chopstick holder area on the upper-left counter to the sauce-bottle area on the upper-right counter. It must remain narrow enough not to overlap the griddle or ingredient bins. The tray is a fixed fixture and must be completely empty—no coins, banknotes, currency symbols, prices, hands exchanging money, labels or shadows from payments.
Customer UI placeholders: above the customer's head, add a clean empty horizontal patience-meter frame with no text, no numbers and no filled value that could be mistaken for final data. At the upper-right of the customer's head, add a larger empty order-requirements card/panel with several simple blank icon slots and blank rows, but no readable text, letters or numbers. Both UI elements must be separate-looking overlay frames with clear margins and must not cover the customer face, hair, payment tray or workstation.
Style/medium: match v4—simple hand-drawn 2D cartoon game art, bold clean deep-brown outlines, large flat color shapes, at most base color plus one shadow and one highlight, restrained warm cream/mustard/terracotta/faded-teal palette, crisp silhouettes, minimal texture, friendly grounded street-stall mood.
Invariants: one griddle only; one customer only; fixed near-top-down camera; no second workstation; no customer overlap with the counter interior; no cropped hair; full bottom strip visible; no magical or absurd ingredients; no detailed character production sheet.
Constraints: no readable text, Chinese characters, English letters, numbers, currency symbols, signage, brand, logo, watermark, photorealism, anime gloss, 3D rendering, painterly texture, thin outlines, heavy gradients, extra customers, crowds, extra cooking stations, or baked payment objects.
```

## 2. 鏊子与长托盘修正

```text
Use case: precise-object-edit
Asset type: ProjectCake gameplay composition anchor v5 correction
Input images: Image 1 is the v5 edit target with the approved new customer/UI/12-slot composition. Image 2 is the v4 size reference used only to calculate the requested griddle scale.
Primary request: correct exactly two scale errors in Image 1 while preserving its new composition.
Correction 1 — griddle: enlarge the single central round griddle so its diameter is approximately 80 percent of the griddle diameter in Image 2. This should be visibly larger than the current griddle in Image 1, approximately 650 pixels wide on a 1672-pixel canvas, but still smaller than v4. Keep it centered in the lower workstation and completely visible. Move the left six-bin vegetarian group slightly farther left and the right six-bin meat group slightly farther right only as needed to create clean gaps around the larger griddle. Preserve exactly six bins on each side and do not enlarge the overall workstation to fill the screen.
Correction 2 — payment tray: lengthen the existing narrow empty payment tray dramatically so it spans almost the full upper counter, starting near the chopstick holder on the left and ending near the sauce-bottle area on the right, approximately x=230 to x=1460 on the 1672-pixel canvas. Keep it shallow and narrow, at the same vertical position in front of the customer, with rounded corners and a deep-brown outline. The tray must remain empty and must not overlap the customer, UI, ingredients or griddle.
Absolute invariants: keep Image 1's complete half-body customer behind the clearly separating counter edge; keep the full hairstyle visible; keep the empty patience-meter frame above the head; keep the empty order-requirements panel at the upper-right of the head; keep the fixed near-top-down 16:9 camera; keep the bottom control/tool strip fully visible; keep the same bold deep-brown outlines, large flat color blocks, minimal texture, warm palette, lighting and street-stall mood. Preserve all twelve ingredient bins and their vegetarian-left/meat-right grouping.
Payment and UI constraints: no coins, banknotes, currency symbols, prices, hands exchanging money or payment shadows. UI frames must contain no readable text, Chinese characters, English letters or numbers; actual UI is added in Godot.
No extra customers, extra cooking stations, second griddle, extra bins, magical content, logos, brands, watermarks, photorealism, 3D gloss, painterly texture, thin lines, camera zoom or perspective drift.
```

## 3. 最终鏊子比例修正

```text
Use case: precise-object-edit
Asset type: ProjectCake gameplay composition anchor v5 final griddle-scale correction
Input images: Image 1 is the current v5 edit target
Primary request: change only the lower workstation geometry needed to enlarge the central griddle by approximately 20 percent relative to its current diameter. Keep the same center point and round shape. The target is a griddle approximately 640 to 660 pixels wide on the 1672-pixel canvas, corresponding to about 80 percent of the earlier v4 griddle diameter.
Supporting movement: move the complete six-bin vegetarian group approximately 35 to 45 pixels farther left and the complete six-bin meat group approximately 35 to 45 pixels farther right, without resizing the bins, so there is a clean visible gap around the enlarged griddle. Preserve exactly six bins on each side in their current 2-column by 3-row arrangement. Keep all groups fully inside the workstation.
Absolute invariants: preserve the exact canvas and camera; preserve the complete half-body customer behind the separating counter; preserve complete uncropped hair; preserve the empty patience-meter frame above the head; preserve the empty order-requirements panel at the upper-right; preserve the long empty payment tray exactly as it is, spanning from near the chopstick holder to near the sauce-bottle area; preserve the counter boundaries, chopstick holder, napkins, sauces, plant, bottom heat-control/tool strip, colors, lighting, line weight and flat simplified style. Do not zoom, crop, reframe, enlarge the overall workstation, or change the customer area.
The enlarged griddle must remain fully visible and must not overlap the ingredient bins or bottom controls.
No coins, banknotes, currency symbols, prices, hands exchanging money, payment shadows, readable text, Chinese characters, English letters, numbers, brands, logos, watermarks, extra customers, extra bins, second griddle, magical content, photorealism, 3D gloss, painterly texture or thin lines.
```
