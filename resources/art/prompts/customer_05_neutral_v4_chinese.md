# customer_05_neutral_v4_chinese

## Scope and locked contract

- Neutral state only. No other customer or customer_05 state was regenerated.
- Identity authority: `customer_05_neutral_v1.png` — young adult Chinese woman, warm light-medium skin, narrow oval face, straight dark chin-length blunt bob, short blunt bangs, both ears exposed, muted dusty-plum shallow square-neck blouse, warm cream lower garment.
- Quality/style references: user-approved `customer_02_neutral_v4_chinese.png` and the real Chinese workstation background.
- Canvas: `1535x1024` RGBA.
- Locked Atlas region / alpha bounds: `Rect2(536, 86, 451, 891)`, i.e. `(536,86)-(987,977)`.
- Runtime resource: `customer_05_neutral_cropped.tres`; its region and anchor contract are unchanged.

## Generation

- Generator: Codex built-in `image_gen` (imagegen skill).
- Generated: 2026-08-11 (Asia/Shanghai).
- Raw source: `res://tmp/imagegen/customer_05_chinese_v4/customer_05_neutral_v4_chinese_key_raw.png`.
- Final: `res://resources/art/customers/customer_05/customer_05_neutral_v4_chinese.png`.

```text
Use case: identity-preserve and style-transfer.
Asset type: ProjectCake customer_05 NEUTRAL half-body gameplay Sprite2D, chroma-key source for transparent PNG.

Input images:
- Image 1 is the exact edit target and sole identity, outfit, pose, silhouette, canvas, crop, scale, and anchor authority: customer_05 old neutral.
- Image 2 is the user-approved customer_02 v4 quality reference only for the Chinese watercolor/rice-paper character rendering. Do not copy Image 2's identity, hair, face, clothing cut, colors, or proportions.
- Image 3 is the actual Chinese workstation mood/style reference only: warm rice-paper feeling, ink-brown linework, dry-brush watercolor, restrained mineral colors. Do not add its background, architecture, counter, shelves, or props.

Primary request: redraw only the person from Image 1 in a refined Chinese hand-painted game-illustration style while preserving her exact established identity. She remains one young adult Chinese woman with warm light-medium skin, narrow oval face, dark attentive eyes, softly straight eyebrows, calm restrained closed-mouth smile, very dark brown-black chin-length blunt bob, short straight blunt bangs, both complete ears exposed, muted dusty-plum shallow square-neck short-sleeve blouse, and warm cream waistband/lower garment. Neutral expression only.

Style/medium: Chinese warm rice-paper visual language, fine controlled ink-brown outlines (not thick black), subtle watercolor-on-paper granulation confined inside the painted character, sparse dry-brush modulation, broad readable shapes, and coordinated restrained mineral pigments. Preserve clear gameplay readability and do not over-texture the face. The dusty-plum blouse must stay muted dusty plum and the lower garment warm cream; no hue shift toward hot pink, red, orange, or green.

Exact geometry invariants: preserve Image 1's 1535 x 1024 broad landscape canvas; keep the complete half-body centered; preserve the same front-facing pose, straight arms and relaxed complete hands, body proportions, silhouette occupancy, scale, waist lower edge, and pivot. The full opaque/antialiased subject must fit inside the exact old Atlas crop Rect2(536,86,451,891), spanning no farther left than x=536, no farther right than x=986, no higher than y=86, and no lower than y=976. Keep the head top, every hair tip, both ears, shoulders, forearms, complete hands, and complete lower waist edge visible. Do not crop, move, widen, shrink, enlarge, or change the pose.

Scene/backdrop: perfectly uniform flat solid bright magenta #FF00FF edge to edge and into every corner for deterministic local key removal. No background texture, paper texture, shadow, gradient, lighting variation, halo, vignette, floor plane, reflection, or cast/contact shadow. Do not use #FF00FF anywhere in the person. Keep all reds, dusty plum, skin warmth, and mineral pigments clearly separated from the key color.

Constraints: change only the rendering style of the existing customer_05 person; preserve identity, age, skin tone, hairstyle, facial features, neutral expression, outfit design, base clothing colors, pose, hands, fingers, composition, canvas, crop, and anchor. Exactly one person; no props, bag, coins, food, counter, workstation, UI, text, logo, watermark, symbols, extra limbs, hidden hands, fused fingers, anime, chibi, photorealism, glossy 3D, heavy gradients, thick black outlines, or noisy background.
Output intent: one opaque chroma-key source for safe #FF00FF removal, then transparent ProjectCake Atlas use.
```

## Processing and checks

- The requested default soft matte (`12/220`) was rejected because it removed warm skin and dusty-plum interior pixels.
- Accepted key removal used the skill helper with border auto-key, hard per-channel tolerance `60`, and despill. A deterministic edge-only magenta cleanup then removed key-like boundary pixels without touching the opaque blouse interior.
- The generated subject was uniformly normalized into the old exact Atlas bounds; no local face, clothing, pose, or color edits were applied.
- Final SHA-256: `10be97b4a0c250d6694d02deb06e953aad95393730ef71acdd599c7e1b994d07`.
- Alpha: four corners transparent; alpha bbox `(536,86)-(987,977)`; 1,272,048 transparent, 10,610 partial, 289,182 opaque pixels.
- Red/plum safety check: 176,336 opaque red-family pixels retained; zero visible key-like magenta pixels detected at alpha >= 16.
- Human review: pending.
