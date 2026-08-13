# customer_15 neutral v1

## Character

- Intended runtime ID: `customer_15`
- State: `neutral` only
- Identity: 58-year-old Chinese woman who runs an independent neighborhood clothing-alteration shop, stopping for breakfast before opening
- Personality: brisk, good-humored, self-possessed
- Visual markers: short charcoal-and-silver bob, muted teal cropped jacket, dusty plum crew-neck top, charcoal straight-leg trousers, empty hands
- Direction: contemporary Chinese daily life without occupational props, uniform, brand marks, historical costume, ethnic shorthand, or age caricature

## Selected generation prompt

Use case: `stylized-concept`  
Asset type: Godot 2D game customer portrait, `customer_15` neutral candidate  
Primary request: Create one contemporary Chinese everyday customer character: a 58-year-old woman who runs an independent neighborhood clothing-alteration shop, stopping for breakfast before opening. She has a brisk, good-humored, self-possessed personality, shown through a small confident smile and relaxed posture, without caricature.  
Subject: short softly rounded charcoal-and-silver bob haircut with a few natural gray strands; individual contemporary East Asian facial features; warm medium skin; a cropped muted teal jacket over a dusty plum crew-neck top and charcoal straight-leg trousers; empty hands relaxed at both sides.  
Style/medium: distinctly slightly cartoon-like 2D game illustration, not portrait realism; moderately enlarged rounded head, simplified graphic face and features, clear friendly silhouette, fine ink-brown contour lines, warm rice-paper watercolor texture, restrained dry-brush accents, flat gouache-like mineral colors in two or three shade steps. Coordinate with a warm Chinese-inspired food-workstation visual language while remaining contemporary everyday clothing.  
Composition/framing: exactly one centered, front-facing character on a 1536x1024 landscape canvas; complete portrait from the very top of all hair to clearly below the waist/upper thighs; both complete elbows and both complete hands fully visible; stable flat lower-body anchor reaching the bottom edge; generous clear side padding. Neutral relaxed pose and expression.  
Scene/backdrop: perfectly flat uniform solid bright magenta `#FF00FF` chroma-key background for safe removal. No shadows, gradients, texture, reflections, floor plane, lighting variation, or magenta contamination in the subject.  
Constraints: preserve all hair, both complete hands, waistline and lower-body anchor without cropping; crisp separated silhouette; no cast/contact shadow; no prop; no text; no watermark; no logo; no other person.  
Avoid: photorealistic portraiture, realistic skin rendering, individual finger detail, glossy 3D, cinematic lighting, anime glamour, chibi proportions, exaggerated age caricature, ethnic or regional shorthand, historical costume, qipao, occupational uniform, platform or shop branding, name badge, scissors, measuring tape, needles, thread, fabric rolls, sewing machine, handbag, phone, keys, food, or clutter.

## Provenance and contract

- Generator: Codex built-in image generation (`stylized-concept`).
- Selected generated source: `C:\\Users\\Administrator\\.codex\\generated_images\\019ff3a7-3a5a-7f52-959e-0511a805474d\\exec-d8132c3c-159c-4fd7-988d-ef995d82ba17.png`.
- Preserved chroma source: `tmp/imagegen/customer_15_chinese_neutral/customer_15_neutral_v1_chroma.png`.
- Chroma source SHA-256: `51A9D0EF1729B0AF51804FEB5129056C085D6154A2DB1F02DEE810D5C799C9D0`.
- Alpha processing: installed `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
- Final asset: `resources/art/customers/customer_15/customer_15_neutral_v1.png`; SHA-256 `FC503C7604FFB74E5971F3A50F4373BD120408E7FB10D0631EE24469E37E5F14`.
- Final canvas: 1536x1024 RGBA; transparent corners: 4/4; alpha bounds: `(498, 35)` to `(1028, 1023)`; AtlasTexture region: `Rect2(498, 35, 531, 989)`.
- Alpha validation: no opaque or partially transparent magenta-like residue detected; complete hair, both hands, waistline, and bottom-edge lower-body anchor retained.
- Runtime status: `customer_15` is present in both customer ID pools. All five state keys exist as independent AtlasTexture resources; until neutral approval, the four action-state resources intentionally reference the neutral PNG.
- Automated validation: Godot 4.7.1 import, `CUSTOMER_15_PORTRAIT_CONTRACT_SELF_CHECK_PASS`, `FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS`, and `P1 vertical-slice self-check PASS`.
- Compatibility validation checkpoint: before an independent concurrent `customer_16` task extended the shared pool, rotation covered all fifteen identities; pre-expansion snapshots retained the original ten-customer modulo; current snapshots preserved an explicit `customer_15` identity. The later `customer_16` changes are outside this task and were neither created nor reverted here.
- GPU validation: Godot 4.7.1 non-headless Windows run passed with D3D12 12_0 Forward Mobile on NVIDIA GeForce RTX 5070. Preview-only code hid the order/service cards and tutorial overlay without changing gameplay UI logic.
- GPU evidence: `tmp/validation/customer_15_neutral_v1_chinese_gpu_1920x1080.png`; SHA-256 `DA9C25C1C258B81DB383A758AAEBE7366DEE54AD1F07BDFB1C02F2805CADA6DA`; log `tmp/validation/customer_15_neutral_gpu_d3d12.log`.
- Human review: pending. No action-state artwork should be generated until this neutral candidate is explicitly accepted.
