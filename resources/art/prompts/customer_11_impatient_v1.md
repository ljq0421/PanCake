# customer_11 impatient v1

- Generator: Codex built-in image generation, identity-preserve edit
- Edit target: `tmp/imagegen/customer_11_chinese_neutral/customer_11_neutral_v1_chroma.png`
- Final source: `resources/art/customers/customer_11/customer_11_impatient_v1.png`
- Chroma source: `tmp/imagegen/customer_11_chinese_states/customer_11_impatient_v1_chroma.png`
- Rejected source: `tmp/imagegen/customer_11_chinese_states/customer_11_impatient_v1_rejected_too_sad_chroma.png`

## Prompt summary

Preserve customer_11's exact identity, low ponytail, cardigan, canvas, silhouette, scale, bottom anchor, and flat `#FF00FF` backdrop. Change only the face one small step from neutral: nearly horizontal brows, upper eyelids lowered about 10–15%, and a closed straight mouth. The read is composed waiting impatience, not sadness, anger, or fatigue. No props, text, UI, shadows, or extra people.

## Processing

Used `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`. Alpha bounds: `(534,49)` to `(998,1023)`; final crop: `Rect2(534,49,465,975)`.
