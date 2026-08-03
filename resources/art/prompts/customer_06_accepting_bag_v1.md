# customer_06_accepting_bag_v1

- Generator: Codex built-in `image_gen`
- Generated: 2026-08-02 (Asia/Shanghai)
- Use case: `identity-preserve`
- References: `customer_06_neutral_v1.png`, customer 01 action pose reference, `paper_bag_package_v1.png`, `visual_style_anchor_v8.png`
- Source: `tmp/imagegen/customer_service_v1/customer_06_accepting_bag_v1_chromakey.png`
- Final: `res://resources/art/customers/customer_06/customer_06_accepting_bag_v1.png`
- Rejected/processing record: none; accepted first visual candidate after hard chroma extraction
- Chroma removal: skill `remove_chroma_key.py`, border auto-key, hard alpha, tolerance 60
- SHA-256: `887fbd2e1b10f96a075fb8c35a745a834d3ea0b5847e0015de58ff733e0c8662`

## Complete accepted prompt

```text
Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_06_accepting_bag_v1. Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references. Preserve customer_06 exactly: slim elderly man, long rectangular face, swept-back silver hair, light-blue shirt, mustard V-neck vest, brick-red lower garment; keep the same face, age, body proportions, palette and bold deep-brown outline. Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins. Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background.
```
