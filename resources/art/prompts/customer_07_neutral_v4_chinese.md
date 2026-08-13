# customer_07_neutral_v4_chinese

Human review: accepted by the user on 2026-08-11. This image is the locked identity, clothing-design, clothing-palette, and rendering authority for all four v4 action/expression states.

## Scope and authority

- Only `customer_07` neutral is redrawn.
- `customer_07_neutral_v1.png` is the sole identity, age, skin tone, clothing-design, pose, canvas, crop, and anchor authority.
- `customer_07_neutral_v3_chinese_colorful.png` is style-direction reference only; its narrower silhouette and magenta fringe are rejected.
- `customer_02_neutral_v4_chinese.png` is the approved paper/watercolor quality reference only and is not modified.

Locked identity: comfortably full, sturdy woman approximately 45–55 years old; softly rounded-square face; warm fair-to-light skin; sparse freckles across the nose and upper cheeks; dark hazel eyes; copper-brown brows; short layered copper-red pixie hair; warm sunflower-gold boat-neck short-sleeve blouse; deep desaturated teal lower garment.

## Built-in imagegen prompt

```text
Use case: identity-preserve
Asset type: ProjectCake customer_07 neutral half-body gameplay sprite, Chinese-style redraw on removable chroma-key background.

Image 1 is the sole exact identity, anatomy, clothing-design, pose, canvas, crop, scale, and anchor authority. Image 2 is non-authoritative style direction only. Image 3 is the approved paper/watercolor quality benchmark only and must not contribute identity or clothing design.

Redraw the exact customer_07 identity in a cohesive Chinese folk watercolor treatment: warm xuan/rice-paper undertone within the painted character, delicate ink-brown contour lines, visible but controlled watercolor paper grain, restrained dry-brush texture, softly layered watercolor washes, and coordinated traditional mineral pigments. Preserve the exact age, face, warm fair skin, freckles, copper-red pixie hair, full sturdy body, neutral expression, pose, sunflower-gold boat-neck blouse, and deep mineral-teal lower garment. Do not alter identity, anatomy, clothing design, or base palette.

Preserve the old 1535 x 1024 gameplay canvas and the old Atlas/anchor contract Rect2(489,110,541,867), with the lower edge at y=976. Keep the complete hair, ears, shoulders, forearms, hands, fingers, and lower waist edge visible. Exactly one person, two arms, and two complete hands.

Use a perfectly uniform flat #FF00FF chroma-key background to every edge and corner. Do not use magenta or purple in the character or subject edge. Keep copper/red hair distinct from the key. No counter, UI, order card, patience bar, props, bag, coins, food, tools, shadow, reflection, text, logo, brand, watermark, accessory, extra limb, hidden hand, or cropped body part.
```

The first redraw preserved identity and style but placed the lower edge at the canvas bottom. A second built-in `precise-object-edit` pass changed only uniform scale and position, using v1 as the sole geometry reference. It still exceeded the Atlas bounds slightly after key removal, so deterministic local geometry normalization uniformly scaled the complete keyed character by `0.9719730941704036` and positioned it at `(509,110)` on the unchanged `1535 x 1024` transparent canvas. Final alpha bounds are `(509,110)-(1010,977)`, fully contained by the unchanged old Atlas region and sharing its `y=976` lower anchor.

## Chroma-key processing

Source: `tmp/imagegen/customer_07/customer_07_neutral_v4_chinese_key.png`

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

The sampled bright-magenta border key was `#F210EA` (the built-in generator's rendered approximation of requested `#FF00FF`). Uniform LANCZOS geometry normalization produced 13 exact `#FF00FF` pixels at alpha 1; those key-colored edge pixels alone were deterministically cleared to transparent. The result has transparent corners, no visible magenta pixels, and preserves the copper/red hair pixels. Final: `res://resources/art/customers/customer_07/customer_07_neutral_v4_chinese.png`.
