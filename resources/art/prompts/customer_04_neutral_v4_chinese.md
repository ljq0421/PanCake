# customer_04_neutral_v4_chinese

## Scope

Only the `customer_04` neutral portrait is redrawn. The existing neutral/action PNGs remain preserved. This neutral is the sole identity and clothing-color authority for any later `customer_04` expression/action states after human approval.

## Generation

- Generator: Codex built-in `image_gen`
- Mode: identity-preserving edit
- Image 1: `customer_04_neutral_v1.png`, exact identity/composition authority
- Image 2: approved `customer_02_neutral_v4_chinese.png`, quality/style reference only
- Images 3-4: Chinese-style main-menu and workstation backgrounds, material/palette references only
- Chroma key: flat `#FF00FF`
- Generated source: `tmp/imagegen/customer_04_chinese_neutral_v4/customer_04_neutral_v4_chinese_key.png`
- Exact-key source: `tmp/imagegen/customer_04_chinese_neutral_v4/customer_04_neutral_v4_chinese_key_exact_ff00ff.png`
- Final alpha PNG: `res://resources/art/customers/customer_04/customer_04_neutral_v4_chinese.png`

## Prompt

```text
Use case: identity-preserve
Asset type: ProjectCake customer_04 neutral half-body gameplay Sprite2D, new versioned Chinese-style repaint on removable magenta chroma key.

Image 1 is the exact edit target and sole authority for customer_04 identity, age, skin tone, hairstyle, face, body proportions, clothing design, clothing colors, neutral expression, pose, canvas occupancy, crop, scale, and anchor. Preserve it exactly. Image 2 is the user-approved customer_02 v4 quality reference only for Chinese rice-paper watercolor surface, fine ink-brown line character, dry-brush texture, and restrained mineral color harmony. Images 3 and 4 are ProjectCake main-menu and workstation style references only for warm rice-paper ground feeling, ink-brown contours, watercolor paper grain, dry-brush handling, and coordinated mineral pigments. Do not add any background, architecture, props, workstation, or UI.

Repaint only Image 1 in the established ProjectCake Chinese visual language. Keep the exact same friendly middle-aged man with warm medium-brown skin, broad softly angular face, dark brown eyes, calm restrained closed-mouth smile, short dense tightly curled dark brown-black hair with every curl present, both ears exposed, no facial hair. Keep the exact same faded navy-blue short-sleeve polo, warm ochre collar and sleeve trim, two small blank buttons, and muted brick-brown lower garment. The clothing base palette must remain recognizably identical to Image 1.

Use warm xuan/rice-paper watercolor illustration, fine readable ink-brown outlines, subtle handmade paper fiber, controlled dry-brush texture, gentle pigment pooling, restrained value variation, and coordinated traditional mineral pigments. Preserve clear game-readable shapes at small scale. Preserve the old 1535 x 1024 canvas contract, centered frontal pose, slightly elevated viewpoint, head size, silhouette placement, top padding, lower waist edge, and complete half-body framing. Do not crop, widen, narrow, rescale, reframe, rotate, or move the person.

Keep the relaxed neutral expression. The backdrop must be perfectly flat uniform solid #FF00FF to every edge and corner, with no paper texture, shadow, gradient, halo, glow, floor, vignette, reflection, or lighting variation. Do not use #FF00FF in the character. Exactly one person; no redesign, props, bag, coins, UI, text, logo, watermark, extra limbs, hidden hands, or cropped body parts.
```

## Processing contract

The generated chroma-key source is copied into the repo before processing. Because ImageGen varied the requested background around `#FA04F1`, only the magenta-like region connected to the canvas border is deterministically normalized to exact `#FF00FF`; the original generated source remains preserved. `remove_chroma_key.py` is then run with auto-key border sampling, soft matte, conservative thresholds, and magenta despill and confirms `Key color: #ff00ff`. The alpha result is normalized to the legacy 1535 x 1024 canvas and legacy `Rect2(508, 81, 505, 895)` Atlas crop without changing the runtime anchor.
