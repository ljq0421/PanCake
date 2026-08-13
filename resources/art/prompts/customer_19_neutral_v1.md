# customer_19 neutral v1

## Character

- Intended runtime ID: `customer_19`
- State: `neutral` only
- Identity: an original 43-year-old Chinese man who works as a hospital rehabilitation therapist and stops for breakfast before an early shift.
- Personality: steady, kind, and quietly playful.
- Visual markers: short neat black hair with a little natural gray at the temples; rounded-square face; dusty-aubergine casual overshirt; warm oatmeal collarless Henley shirt; muted olive-gray trousers; empty relaxed hands.
- Direction: contemporary Chinese daily life with no medical uniform, badge, equipment, platform mark, historical costume, ethnic shorthand, or occupational stereotype.

## Selected generation prompt

Use case: `stylized-concept`

Asset type: Godot 2D game customer portrait, `customer_19` neutral candidate

Input image: confirmed `customer_14` neutral was supplied only as a style-threshold reference. Its identity, age, face, hair, pose details, clothing, and colors were prohibited from being copied.

Primary request: Create the original character above in a centered, front-facing neutral pose with empty relaxed hands.

Style/medium: moderate 2D hand-painted game illustration, visibly a little more cartoon-like, rounded, and graphic than `customer_14`, but neither chibi nor anime. Slightly enlarged adult head; rounder graphic head and face; large simplified almond eyes; simple brows; tiny ink-line nose; simple curved mouth; clean round cheek-color patches. Warm beige rice-paper/watercolor-paper texture, fine ink-brown contours, low-saturation mineral colors, two to three flat gouache shade steps, restrained dry-brush accents, broad graphic hair/clothing shapes, reduced folds/seams/finger separation, and no realistic skin or shadow modelling.

Composition/framing: exactly one centered front-facing character on a 1536x1024 landscape canvas; complete from all hair to below the waist/upper thighs, with both complete elbows and both complete hands visible, generous side padding, and a stable bottom anchor reaching the bottom edge.

Backdrop: perfectly flat uniform bright-magenta `#FF00FF` chroma-key background, without shadows, gradients, texture, reflections, floor plane, lighting variation, or magenta within the subject.

Avoid: portrait realism, photorealism, cinematic lighting, glossy 3D, anime, chibi, childlike proportions, glamour, detailed fingers or cloth folds, scrubs, lab coat, badge, stethoscope, therapy equipment, phone, bag, food, text, logo, watermark, other people, historical costume, ethnic shorthand, regional stereotype, saturated colors, or clutter.

## Provenance and neutral-only contract

- Generator: Codex built-in image generation through the imagegen skill (`stylized-concept`).
- Selected generated source: `C:\Users\Administrator\.codex\generated_images\019ff456-253c-7182-9449-436683476a1f\exec-1857a0fc-fa51-4fe6-816a-0073d6522d3e.png`.
- Preserved original chroma candidate: `tmp/imagegen/customer_19_chinese_neutral/customer_19_neutral_v1_chroma.png`; SHA-256 `CB07EAFC5BDBBEC2D1B77CC48886D93E0BBB03DDD7A0355B59CC1E2E65CD9348`.
- Failed soft-matte output: `tmp/imagegen/customer_19_chinese_neutral/customer_19_neutral_v1_softkey.png`; SHA-256 `6B46E149F5AF8755BE9F954C40F95E2D1110CE134292E62BE5AE4DF401B90717`; retained because automatic soft-matte removal made the face and shirt partly transparent.
- Intermediate hard-key candidate: `tmp/imagegen/customer_19_chinese_neutral/customer_19_neutral_v1_hardkey60.png`; SHA-256 `AC5EA55E21FF1F0C2E6AEFD70A1978CAB1DE42C8DCCCDAE726B8A2855E4990F2`; retained because 17 visible magenta-like edge pixels remained.
- Selected key-clean output: installed `remove_chroma_key.py --auto-key border --tolerance 60 --edge-contract 1 --despill`; source key sampled as `#FB05F9` from the generator output.
- Final runtime PNG: `resources/art/customers/customer_19/customer_19_neutral_v1_keyclean.png`; SHA-256 `1793BC9CE8B4F3D8A5DB7DC6B233DB27C0229F8D413A915CD07129313BBC17AE`.
- Final canvas: 1536x1024 RGBA; transparent corners: 4/4; alpha bounds: `(486, 28)` to `(1051, 1024)`; AtlasTexture region: `Rect2(486, 28, 565, 996)`.
- Alpha validation: 1,185,289 transparent, 0 partial, and 387,575 opaque pixels; zero visible magenta-like pixels at alpha >= 16; complete hair, both hands, waistline, and bottom-edge lower-body anchor retained.
- Runtime status: neutral was initially integrated alone; explicit human approval authorized the four dedicated action states recorded in `customer_19_states_v1.md`.
- Pool compatibility: `customer_19` is appended after the already-present IDs; legacy snapshots retain the original ten-customer modulo.
- Godot import: passed with Godot 4.7.1; the 1,033-byte `.png.import` sidecar resolves to a non-empty 466,182-byte `CompressedTexture2D` cache.
- Automated verification: `CUSTOMER_19_NEUTRAL_CONTRACT_SELF_CHECK_PASS`, `FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS`, and `P1 vertical-slice self-check PASS`; both current pools rotate through all nineteen IDs, current snapshots preserve `customer_19`, and pre-expansion snapshots retain the original ten-customer modulo.
- GPU verification: Godot 4.7.1 non-headless Windows/D3D12 12_0 Forward Mobile on NVIDIA GeForce RTX 5070 passed with `CUSTOMER_19_NEUTRAL_GPU_PREVIEW_PASS`.
- GPU evidence: `tmp/validation/customer_19_neutral_v1_chinese_gpu_clear_1920x1080.png`; SHA-256 `C23F4B240FECAEDF13593A9CFADA7056B81E51AB1D2C393FC283F774EAFB338E`; complete hair, both hands, below-waist anchor, and clean transparent edges were visually retained in the real workstation.
- Human review: approved by the user on 2026-08-12; this confirmation is the identity, outfit and palette authority for the four action states.
