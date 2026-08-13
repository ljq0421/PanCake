# customer_11 accepting_bag v1

- Generator: Codex built-in image generation, identity-preserve edit
- Edit target: `tmp/imagegen/customer_11_chinese_neutral/customer_11_neutral_v1_chroma.png`
- Supporting reference: `resources/art/workstation/packaging/paper_bag_package_v1.png`
- Final source: `resources/art/customers/customer_11/customer_11_accepting_bag_v1.png`
- Chroma source: `tmp/imagegen/customer_11_chinese_states/customer_11_accepting_bag_v1_chroma.png`

## Prompt summary

Preserve customer_11's identity, face, hair, clothing, scale, and anchor. Bend both forearms inward so both complete hands receive one modest warm-brown paper bag at lower torso height; retain a gentle appreciative closed-mouth smile. No coins, extra food, text, UI, shadows, or extra people.

## Processing

Used `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`. Alpha bounds: `(522,48)` to `(1006,1023)`; final crop: `Rect2(522,48,485,976)`.
