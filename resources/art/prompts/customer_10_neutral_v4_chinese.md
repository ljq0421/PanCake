# customer_10_neutral_v4_chinese

- Generator: Codex built-in `image_gen` via the imagegen skill
- Generated: 2026-08-11 (Asia/Shanghai)
- Use case: `style-transfer`, followed by an `identity-preserve` scale/position correction
- Identity/framing target: `res://resources/art/customers/customer_10/customer_10_neutral_v1.png`
- Approved quality reference: `res://resources/art/customers/customer_02/customer_02_neutral_v4_chinese.png`
- Workstation material/palette reference: `res://resources/art/workstation/background/workstation_18_single_row_1920x1080_v8_chinese.png`
- Exact-key source: `tmp/imagegen/customer_10_chinese_v4/customer_10_neutral_v4_chinese_key_ff00ff.png`
- Final: `res://resources/art/customers/customer_10/customer_10_neutral_v4_chinese.png`
- SHA-256: `01D5CB8F9B528802EC0A1BF3F86752ED92B6784DB5FF398CDCA7E97621D7CD56`

## Accepted generation prompt

```text
Use case: style-transfer
Asset type: ProjectCake customer_10 neutral half-body runtime portrait sprite.

Image 1 is the exact edit target and sole identity, pose, framing, canvas, silhouette, age, skin-tone, facial-hair, clothing-design, and anchor authority. Image 2 is quality/style reference only: use its Chinese rice-paper watercolor texture, fine dark-brown ink contours, restrained dry-brush finish, readability, and polish; do not copy its identity, hair, face, clothing, pose, or body shape. Image 3 is palette/material context only: coordinate with its warm rice-paper base, ink-brown linework, muted mineral pigments, and Chinese street-stall atmosphere; do not include its workstation or scenery.

Restyle only the single customer from Image 1 into the approved Chinese visual language while preserving customer_10 exactly: sturdy broad man aged about 40–50, warm medium olive skin, broad rounded adult face, calm neutral waiting expression, complete bald crown, narrow dark side/back stubble, both visible ears, separated dark mustache and small rounded goatee. Preserve the deep muted burgundy short-sleeve camp-collar overshirt, warm cream undershirt triangle, and warm khaki lower garment as the same clothing design and base-color identity.

Traditional Chinese-inspired 2D game illustration: warm rice-paper visual material, fine readable ink-brown outlines, hand-painted watercolor grain inside the character, subtle dry-brush edges, large legible color shapes, restrained shading, and coordinated mineral pigments. Friendly everyday street-stall tone. No anime, glossy vector art, 3D, photorealism, thick black comic outline, or noisy high-frequency texture.

Output a 1536 x 1024 landscape canvas. Preserve Image 1's complete half-body and placement as closely as possible: x=507..1018, y=82..959, bottom-center anchor near (762,959). Keep the entire scalp, ears, shoulders, forearms, complete hands/fingers, and full lower edge visible. Straight front-facing relaxed stance; exactly one person, two arms, and two hands. Neutral relaxed brows, open attentive eyes, calm restrained closed-mouth friendliness.

Place the subject on a perfectly uniform flat solid bright magenta #FF00FF chroma-key background. Keep the character fully opaque with clean separation. Do not use #FF00FF, fluorescent pink, purple-magenta, or key-color rim light in the subject. Keep the burgundy shirt in a warm red-brown/mineral cinnabar family clearly separated from magenta. No scenery, counter, UI, order card, money, bag, food, tool, accessory, text, logo, watermark, cast/contact shadow, extra limb, hidden hand, malformed hand, cropped body part, or magenta fringe.
```

## Accepted scale/position correction

```text
Change only the uniform overall scale and placement of the complete character. Preserve the generated Chinese identity, face, expression, anatomy, clothing, colors, watercolor texture, dry-brush finish, linework, and #FF00FF background. Fit the full subject to the legacy 1536 x 1024 canvas contract with highest point near y=82, lower edge at y=959, and bottom-center anchor near (762,959). Do not redraw or add anything.
```

## Deterministic processing and validation

1. The generated background varied slightly around magenta. Only the border-connected high-magenta field (`R >= 180`, `B >= 180`, `G <= 90`, `abs(R-B) <= 55`) was normalized to exact `#FF00FF`; the burgundy clothing cannot match the blue threshold.
2. The imagegen skill helper removed the exact key with `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
3. The visible result was deterministically framed to the unchanged legacy Atlas region `Rect2(507, 82, 511, 878)` on the original 1536 x 1024 canvas. Five pure-key resampling pixels with alpha 1/255 were cleared; no visible subject pixel was changed.
4. Validation: exact `#FF00FF` source corners; final RGBA alpha bounds `(507,82)-(1018,960)`; transparent final corners; zero nontransparent magenta-like pixels; 220,508 identified burgundy source pixels and 0 made fully transparent by key removal.

Human review accepted on 2026-08-11. The user's explicit `确认` makes this neutral v4 the sole identity, clothing, age, skin-tone, base-palette, and Chinese-style authority for customer_10's later states.
