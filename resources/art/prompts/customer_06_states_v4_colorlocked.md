# customer_06_states_v4_colorlocked

## Scope and authorities

- States: `impatient`, `satisfied`, `accepting_bag`, `paying_coins`
- Generator: Codex built-in `image_gen`, one independent call per state
- Sole identity, clothing, base-palette, and rendering authority: human-approved `customer_06_neutral_v4_chinese.png`
- Per-state legacy `customer_06_*_v1.png`: action, expression, framing, and anchor reference only
- Approved `customer_02_*_v4_colorlocked.png`: Chinese watercolor quality/action-readability reference only

## Common generation prompt

```text
Use case: identity-preserve
Asset type: ProjectCake customer_06 Chinese-style gameplay Sprite2D state.

Image 1 is the human-approved customer_06 neutral v4 and is the sole authority for identity, face geometry, age, skin tone, hair, body proportions, clothing structure, clothing base colors, watercolor paper texture, dry-brush treatment, mineral palette, and ink-brown linework. Preserve it exactly except for the state-specific expression/arms/held objects explicitly requested. The shirt must remain the same faded powder blue, the sleeveless V-neck vest the same warm mustard ochre, and the lower garment the same muted earthy brick-brown. No palette drift toward brighter yellow, orange, green, purple, or red.

Image 2 is the legacy customer_06 state and is an action/expression/framing reference only. Do not copy its flat rendering, colors, facial proportions, skin color, or clothing rendering.

Image 3 is the approved customer_02 matching state and is a Chinese watercolor quality/action-readability reference only. Do not copy the woman, face, hair, body, clothes, palette, or proportions.

Keep the exact approved neutral v4 Chinese visual language: warm rice-paper watercolor feel, fine readable ink-brown contours, subtle dry-brush/paper texture, restrained coordinated mineral colors. Keep customer_06 clearly the same lean elderly Chinese man with long softly rectangular face, warm light-medium skin, prominent rounded nose, dark eyes, thick silver-gray eyebrows, subtle age lines, high receding combed-back silver-gray hair, no facial hair, no glasses.

Use a perfectly uniform flat solid bright magenta #FF00FF background to every edge and corner. No gradient, texture, halo, floor, shadow, reflection, or vignette. Never use #FF00FF or near-magenta pink/purple in the person, clothing, props, highlights, or paper texture. Exactly one person, two arms and two hands. No text, UI, order card, patience bar, logo, watermark, speech bubble, floating symbols, extra limbs, hidden hands, or unrelated props.
```

## State-specific prompts

### impatient

Change only eyebrows, eyelids, gaze, and mouth. Keep the approved neutral head, hair, ears, nose, age lines, body, arms, hands, pose, clothing seams, colors, texture, and framing unchanged. Use mildly tired waiting: slightly lowered eyelids, gently drawn brows, and a restrained near-horizontal/downturned closed mouth. Not angry, hostile, shouting, scowling, or exaggerated. Arms remain relaxed at the sides. Preserve the `1535x1024` canvas and legacy `Rect2(529,57,468,917)` Atlas/anchor contract.

### satisfied

Change only eyebrows, eyelids, cheeks, and mouth. Keep the approved neutral head, hair, ears, nose, age lines, body, arms, hands, pose, clothing seams, colors, texture, and framing unchanged. Use calm warm satisfaction: relaxed brows, gently closed smiling eyes, subtle lifted cheeks, and a restrained closed-mouth smile. No open mouth, teeth, laughter, wink, heart, sparkle, or exaggerated joy. Arms remain relaxed at the sides. Preserve the `1535x1024` canvas and legacy `Rect2(529,58,469,916)` Atlas/anchor contract.

### accepting_bag

Preserve the approved neutral identity and clothing palette. Change only expression and arms: a pleased restrained receiving expression; both forearms extend forward/down and two complete hands firmly grip the sides of exactly one upright filled kraft paper takeaway bag centered against the lower torso. Exactly one bag and no coins. Preserve the `1448x1086` canvas and legacy `Rect2(479,45,509,1023)` Atlas/anchor contract.

### paying_coins

Preserve the approved neutral identity and clothing palette. Change only expression, arms, and held objects: a pleased polite payment expression; exactly one upright filled kraft bag under the subject's left arm on viewer-right, while the right forearm reaches toward the player on viewer-left with one complete open palm holding exactly three clearly separated round gold coins. Preserve the `1536x1024` canvas and legacy `Rect2(404,40,682,930)` Atlas/anchor contract.

## Processing record

- Chroma sources and raw alpha files: `tmp/imagegen/customer_06_chinese_redraw/customer_06_<state>_v4_colorlocked_{chromakey,alpha_raw}.png`
- Key removal: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`
- Geometry: premultiplied-alpha uniform scaling, bottom-centered inside each unchanged legacy Atlas bound; only alpha `1/255` resampling pixels were cleared.
- Color locking: deterministic local HSV normalization with `customer_06_neutral_v4_chinese.png` as the only palette source. Only unambiguous blue-shirt, mustard-vest, and brick-brown lower-garment pixels inside state-specific clothing regions were adjusted. Skin, hair, ink lines, bag, food, and coins were excluded.
- Neutral target median HSV: shirt `(0.531746, 0.130841, 0.827451)`; vest `(0.106322, 0.754386, 0.901961)`; lower garment `(0.073383, 0.728814, 0.694118)`.
