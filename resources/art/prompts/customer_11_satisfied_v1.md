# customer_11 satisfied v1

- Generator: Codex built-in image generation, identity-preserve edit
- Edit target: `tmp/imagegen/customer_11_chinese_neutral/customer_11_neutral_v1_chroma.png`
- Final source: `resources/art/customers/customer_11/customer_11_satisfied_v1.png`
- Chroma source: `tmp/imagegen/customer_11_chinese_states/customer_11_satisfied_v1_chroma.png`

## Prompt summary

Preserve customer_11's exact identity, clothing, canvas, silhouette, scale, bottom anchor, and flat `#FF00FF` backdrop. Change only to calm satisfaction: relaxed brows, softly closed happy eyes, and a modest closed-mouth smile. No props, text, UI, shadows, or extra people.

## Processing

Used `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`. Alpha bounds: `(533,47)` to `(998,1023)`; final crop: `Rect2(533,47,466,977)`.
