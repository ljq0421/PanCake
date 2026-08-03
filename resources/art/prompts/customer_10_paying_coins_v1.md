# customer_10_paying_coins_v1

- Generator: Codex built-in `image_gen`
- Generated: 2026-08-02 (Asia/Shanghai)
- Use case: `identity-preserve`
- References: `customer_10_neutral_v1.png`, customer 01 action pose reference, `paper_bag_package_v1.png`, `currency_coin_v1.png`, `visual_style_anchor_v8.png`
- Source: `tmp/imagegen/customer_service_v1/customer_10_paying_coins_v1_chromakey.png`
- Final: `res://resources/art/customers/customer_10/customer_10_paying_coins_v1.png`
- Rejected/processing record: customer_10_paying_coins_v1_rejected_bottom_crop.png (lower trouser edge touched the canvas)
- Chroma removal: skill `remove_chroma_key.py`, border auto-key, hard alpha, tolerance 60
- SHA-256: `97f8d1b726e82ecdc74dcc3e31a4762fc4d6585a1865a23c823ca5c77b53475d`

## Complete accepted prompt

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_10_paying_coins_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_10 exactly: sturdy broad middle-aged man, warm olive skin, bald head with dark side stubble, dark mustache and short goatee, dark burgundy open-collar shirt over cream undershirt, warm khaki trousers; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins. This is the accepted targeted composition correction: scale the complete figure/action to about 82% canvas height and leave at least 70 pixels of clean key color below the complete lower trouser/waist edge. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```
