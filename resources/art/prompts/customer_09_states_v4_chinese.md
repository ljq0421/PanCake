# customer_09_states_v4_chinese

## Scope and source authority

- Authorized after the user confirmed `customer_09_neutral_v4_chinese` on 2026-08-11.
- Generated exactly four states: impatient, satisfied, accepting_bag, and paying_coins. The confirmed neutral is the sole identity, outfit, base-palette, watercolor treatment, and line-work authority.
- The old customer_09 state PNGs were action/crop references only. customer_02 v4 state PNGs were quality/action-legibility references only; neither source was allowed to alter customer_09 identity or clothing.
- Base identity lock: adult woman, approximately 30-40; deep warm brown skin; softly heart-shaped adult face; broad nose; blue-black off-center hair with one full side braid; coral/cinnabar mandarin-collar diagonal-wrap blouse; deep mineral-indigo lower garment.

## Final prompt contract

```text
Use case: identity-preserve. Asset type: ProjectCake customer_09 state Sprite2D on removable #FF00FF chroma key. Preserve the confirmed neutral exactly: identity, adult age, face, deep warm-brown skin, hair and braid, body proportions, clothing design, coral/cinnabar blouse and mineral-indigo lower garment base colors, warm rice-paper watercolor treatment, restrained dry brush, and fine ink-brown contours. No color drift. The old state supplies only the action/crop; customer_02 v4 supplies only quality/readability. Keep one person, exactly two arms and hands, a clean opaque magenta background with no shadow, text, UI, scenery, or watermark.
```

- `impatient`: only facial cues change: brows almost neutral and nearly horizontal, eyes open/attentive, small straight closed mouth. This is polite mild impatience, explicitly not anger or a scowl. Two stronger angry generations were rejected.
- `satisfied`: only facial cues change: gently arched brows, happy closed crescent eyes, restrained closed-mouth pleased smile; arms remain at sides.
- `accepting_bag`: pleased open-eyed expression; exactly one upright filled warm-brown paper bag centered against the lower torso; both complete hands grip its left/right sides; no coins.
- `paying_coins`: calm appreciative open-eyed smile; exactly one paper bag held at the torso and exactly three separated round gold coins on the forward open palm; no fourth coin or second bag.

## Generation and deterministic processing

- Generator: Codex built-in `image_gen` through the imagegen skill.
- Accepted built-in sources: `exec-e997455a-2baf-4b54-b8d5-cdfccce270fe.png` (impatient), `exec-976d4c4c-3af1-48a3-8bd2-f4718018ec97.png` (satisfied), `exec-0c6e5553-2cac-48d3-9482-645e6f5f62d8.png` (accepting_bag), `exec-b2929663-a189-4c74-8040-204b66e7a6c4.png` (paying_coins), all under `C:\Users\Administrator\.codex\generated_images\019feeac-b190-74d3-8a31-e8657a1020d9`.
- Rejected impatient sources retained under `res://tmp/imagegen/customer_09_states_v4/`: `customer_09_impatient_v4_rejected_angry_1.png` and `customer_09_impatient_v4_rejected_angry_2.png`.
- Chroma removal: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
- Deterministic follow-up: `tools/normalize_customer_09_states.py` restores each legacy canvas/Atlas region and normalizes only opaque blouse/lower-garment HSV ranges to neutral v4's median palette. It leaves skin, hair, facial features, linework, props, and alpha-edge pixels unchanged.
- Final cleanup removed only six `#FF00FF` residual pixels with alpha `1`, introduced by resampling.

## Legacy canvas/anchor contracts

- impatient: `1536x1024`, `Rect2(541,76,438,883)`.
- satisfied: `1536x1024`, `Rect2(541,76,438,883)`.
- accepting_bag: `1536x1024`, `Rect2(528,60,457,947)`.
- paying_coins: `1530x1028`, `Rect2(450,67,640,910)`.
