# customer_04 action states v4 colorlocked

## Authority and scope

The human-approved `customer_04_neutral_v4_chinese.png` is the sole authority for identity, age, warm medium-brown skin, short dense dark curls, face proportions, navy polo, ochre trim, brick-brown lower garment, rice-paper watercolor texture, ink-brown line weight, canvas registration and color palette. Only `impatient`, `satisfied`, `accepting_bag` and `paying_coins` are covered. The older v1 files remain preserved.

## Built-in ImageGen prompt set

- `impatient`: change only the expression from neutral. Slightly lower and turn eyebrows inward, keep attentive open eyes, and use a short mildly tense closed mouth. It must read as waiting impatience, never anger, rage, glare, red face, hostile scowl or stress symbols. The first generated draft was rejected because its scowl was too strong; the accepted correction relaxes only eyebrow, eyelid and mouth tension.
- `satisfied`: change only the expression to softly closed happy eyes, relaxed brows and a modest closed-mouth smile with subtle cheek warmth. No laugh, teeth, wink, raised arms or celebration prop.
- `accepting_bag`: preserve the neutral head/torso/outfit exactly; use a gentle pleased expression; both forearms reach forward/down with exactly two complete hands gripping the sides of one upright filled kraft paper bag centered against the lower torso. No coins or other props.
- `paying_coins`: preserve the neutral head/torso/outfit exactly; use a polite pleased expression; one upright filled kraft paper bag is tucked under the subject's left arm (viewer-right), while the subject's right hand (viewer-left) presents exactly three separated gold coins on an open palm. No other payment object.

Each state used the legacy customer_04 state image only as action-semantic reference and the confirmed customer_02 v4 corresponding state only as quality reference; neither is an identity or color authority. All four requested a perfectly flat `#FF00FF` background, no text/UI/shadows/extra limbs, complete half-body framing and the original slightly elevated frontal gameplay viewpoint.

## Processing

- Generator: Codex built-in `image_gen`, one identity-preserving edit call per state.
- Generated key sources and the rejected impatient draft are preserved at `tmp/imagegen/customer_04_states_v4/`.
- ImageGen's border-connected near-magenta background is deterministically normalized to exact `#FF00FF` before `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
- `tools/normalize_customer_04_state.py` then rescales the alpha bounds to each legacy Atlas region and matches only blue shirt and bottom-center brick trouser pixels to the approved neutral's HSV medians. It never modifies skin, bag, coins or background.

## Legacy Atlas regions

| state | target `Rect2` |
| --- | --- |
| impatient | `Rect2(508, 81, 504, 895)` |
| satisfied | `Rect2(508, 81, 504, 895)` |
| accepting_bag | `Rect2(506, 79, 511, 898)` |
| paying_coins | `Rect2(422, 61, 675, 927)` |
