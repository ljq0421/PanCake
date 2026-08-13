# customer_07_states_v4_colorlocked

## Scope and locked source

The user accepted `customer_07_neutral_v4_chinese.png` on 2026-08-11. It is the sole authority for identity, age, skin tone, freckles, hair, body proportions, clothing design, clothing base colors, rice-paper watercolor texture, dry-brush finish, and ink-brown linework.

Each state was independently edited from the approved neutral with built-in `image_gen`; no state used another generated state as input. Old customer_07 v1 images supplied action/expression and Atlas-crop semantics only. Customer_01/02 and concurrent customer_03–06 assets were not modified.

## State prompts

- `impatient`: change only brows, eyelids, and closed mouth to restrained mild impatience; arms/hands remain neutral; no symbols or props.
- `satisfied`: change only brows, eyelids, and mouth to relaxed closed smiling eyes and a small closed-mouth smile; preserve freckles; no blush/palette drift or symbols.
- `accepting_bag`: pleased restrained expression; both forearms bend forward; both complete hands grip exactly one upright kraft-paper takeaway bag containing one folded pancake; no coins.
- `paying_coins`: pleased polite expression; the subject's left arm (viewer-right) holds exactly one filled kraft-paper bag; the subject's right hand (viewer-left) extends with exactly three separated gold coins.

All prompts require the approved neutral identity and exact sunflower-gold/deep-teal clothing colors, a broad `1535 x 1024` canvas, uniform bright-magenta `#FF00FF` background, no magenta within the subject, complete anatomy and props, and no UI/text/shadows/extraneous objects. The first impatient tool call stalled without creating an image and was discarded; the successful retry used the same approved neutral authority and a shorter equivalent prompt.

## Chroma key and deterministic normalization

Raw key sources are stored under `tmp/imagegen/customer_07_states_v4/`. Each source was processed with:

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

Garment color normalization changed only the largest connected opaque components matching the approved warm-gold shirt and deep-teal lower-garment HSV ranges. The locked neutral target medians were:

- shirt: `(H 0.1130186, S 0.9083665, V 0.9882353)`
- lower garment: `(H 0.5547264, S 0.5384615, V 0.4588235)`

Skin, freckles, copper hair, paper bag, pancake, coins, outlines, and translucent edges were excluded. Each complete subject was then uniformly scaled only when necessary and bottom-aligned inside its unchanged old Atlas region. Any exact bright-magenta pixels introduced at alpha edges by resampling were cleared to transparent.

| State | Final file | Unchanged Atlas region | Final alpha bounds |
| --- | --- | --- | --- |
| impatient | `customer_07_impatient_v4_colorlocked.png` | `Rect2(489,110,540,867)` | `(518,110)-(1000,977)` |
| satisfied | `customer_07_satisfied_v4_colorlocked.png` | `Rect2(489,110,540,867)` | `(521,110)-(997,977)` |
| accepting_bag | `customer_07_accepting_bag_v4_colorlocked.png` | `Rect2(467,85,593,906)` | `(489,85)-(1037,991)` |
| paying_coins | `customer_07_paying_coins_v4_colorlocked.png` | `Rect2(398,79,702,884)` | `(412,82)-(1086,963)` |
