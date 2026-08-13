# customer_11 paying_coins v1

- Generator: Codex built-in image generation, identity-preserve edit
- Edit target: `tmp/imagegen/customer_11_chinese_neutral/customer_11_neutral_v1_chroma.png`
- Supporting references: `resources/art/workstation/packaging/paper_bag_package_v1.png`, `resources/art/ui/economy/currency_coin_v1.png`
- Final source: `resources/art/customers/customer_11/customer_11_paying_coins_v1.png`
- Chroma source: `tmp/imagegen/customer_11_chinese_states/customer_11_paying_coins_v1_chroma.png`

## Prompt summary

Preserve customer_11's identity, face, hair, clothing, scale, and anchor. Put one received paper bag under her left forearm; extend her complete right hand toward the player with exactly three distinct gold coins. Keep a courteous closed-mouth smile. No cash notes, extra coins, text, UI, shadows, or extra people.

## Processing

Used `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`. Alpha bounds: `(469,48)` to `(1039,1023)`; final crop: `Rect2(469,48,571,976)`.
