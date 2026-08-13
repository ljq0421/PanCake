# customer_17 neutral v1

## Character

- Intended runtime ID: `customer_17`
- State: `neutral` only
- Identity: an original 52-year-old Chinese woman who works as a neighborhood accountant and stops for breakfast before work.
- Personality: practical, warm, alert, and quietly humorous.
- Visual markers: short softly waved charcoal-black side-parted bob; muted teal-green cropped cardigan; dusty-rose crew-neck knit top; soft charcoal wide-leg trousers; empty relaxed hands.
- Direction: contemporary Chinese daily life with no uniform, badge, platform mark, occupational prop, historical costume, ethnic shorthand, or stereotype.

## Selected generation prompt

Use case: `stylized-concept`

Asset type: Godot 2D game customer portrait, `customer_17` neutral candidate

Input images: customer_14 and customer_16 neutral were supplied only as style-threshold references. Their identity, age, gender, hair, face, clothing, colour palette, and pose details were prohibited from being copied.

Primary request: Create the original character above in a front-facing neutral pose with empty relaxed hands.

Style/medium: moderate 2D hand-painted game illustration, visibly more cartoon-like and graphic than customer_14 while neither chibi nor anime. Slightly enlarged rounded adult head; rounded graphic mature face; large simplified almond eyes; simple brows; tiny ink-line nose; simple curved mouth; clean cheek-colour patches. Warm rice-paper watercolor texture, thin ink-brown contours, low-saturation mineral colours, two to three flat gouache shade steps, and restrained dry-brush texture. Use broad graphic hair clumps and clothing shapes, minimal fabric seams/folds and finger separation, and no realistic skin rendering.

Composition/framing: exactly one centered front-facing character on a 1536x1024 landscape canvas, with complete hair, both elbows, both hands, and below-waist/upper-thigh framing; generous padding and stable bottom anchor.

Backdrop: perfectly flat bright-magenta `#FF00FF` chroma-key background, without shadows, gradients, texture, reflections, floor plane, lighting variation, or magenta within the subject.

Avoid: portrait realism, photorealism, anime, chibi, baby-like proportions, glamour, individual finger detail, realistic fabric folds, uniform, badge, logo, text, watermark, books, calculator, phone, food, tool, other people, clutter, or occupational stereotype.

## Neutral provenance and contract

- Generator: Codex built-in image generation through the imagegen skill (`stylized-concept`), with customer_14 and customer_16 as style-only references.
- Selected generated source: `C:\\Users\\Administrator\\.codex\\generated_images\\019ff44d-12f2-7c62-913f-21625016b163\\exec-cdcaee4d-e49b-4645-9767-0aaa0fa5aff3.png`.
- Preserved original chroma candidate: `tmp/imagegen/customer_17_chinese_neutral/customer_17_neutral_v1_chroma.png`.
- First safe auto-key output: `resources/art/customers/customer_17/customer_17_neutral_v1_keyclean.png`, produced with `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`; sampled border key `#FB04FA` from the generator output. The source was prompted for `#FF00FF`; the model emitted a visually equivalent near-magenta key, so the original chroma source is retained rather than altered.
- Final canvas: 1536x1024 RGBA; transparent corners: 4/4; alpha bounds: `(516, 39)` to `(1021, 1024)`; AtlasTexture region: `Rect2(516, 39, 505, 985)`.
- Alpha validation: 1,201,107 transparent, 5,293 partial, and 366,464 opaque pixels; no visible magenta-like pixels at alpha >= 16.
- Runtime status at neutral review: neutral-only integration. Action states were intentionally deferred until explicit human neutral approval.
- Godot 4.7.1 import: passed; the 1,032-byte `.png.import` sidecar resolves to a non-empty 435,010-byte `CompressedTexture2D` cache.
- Automated checks: `CUSTOMER_17_NEUTRAL_CONTRACT_SELF_CHECK_PASS`, `FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS`, and `P1 vertical-slice self-check PASS`. The rotation check covers all 17 current identities, while pre-expansion snapshots retain the original ten-customer modulo.
- Non-headless GPU check: Godot 4.7.1 on Windows, D3D12 12_0 Forward+ using NVIDIA GeForce RTX 5070; marker `CUSTOMER_17_NEUTRAL_GPU_PREVIEW_PASS`.
- GPU screenshot: `res://tmp/validation/customer_17_neutral_v1_chinese_gpu_clear_1920x1080.png`; 1920x1080; SHA-256 `57612897FAD3D61FDD10339E8DE5E6C5D14BD59FD1A7559353597AC6DB128CB1`; log `tmp/validation/customer_17_neutral_gpu_d3d12_retry.log`.
- Human review: pending.

## Approved-neutral action-state authority

- The user explicitly approved customer_17 neutral before these states were generated.
- Every action state uses the approved `customer_17_neutral_v1_keyclean.png` as its sole identity, outfit, palette, style, composition and bottom-anchor authority. Only expression, arm/hand gesture, and the required paper bag/coins change.
- Shared constraints: one centered front-facing 1536x1024 adult half-body, complete hair/elbows/hands/below-waist framing, warm rice-paper watercolor, thin ink-brown outlines, low-saturation mineral colours, two to three flat shade steps, flat bright-magenta chroma background, no realism/anime/chibi/logos/text/watermarks/other people.

### impatient v1

- Prompt: mild waiting impatience only—almost-flat mouth with a tiny asymmetric downturn, one subtly raised eyebrow, eyes glancing slightly aside, both empty hands loosely clasped at the lower waist. Exclude worry, sadness, scowl, clenched fists, crossed arms, watch, phone, bag and coins.
- Selected built-in source: `C:\\Users\\Administrator\\.codex\\generated_images\\019ff44d-12f2-7c62-913f-21625016b163\\exec-d629d865-4bd3-4be7-a529-3a3119055376.png`.
- Preserved chroma candidate: `tmp/imagegen/customer_17_chinese_states/customer_17_impatient_v1_chroma.png`.
- Final PNG: `resources/art/customers/customer_17/customer_17_impatient_v1_keyclean.png`; auto-key border sample `#F804F6`; region `Rect2(531, 42, 468, 982)`; SHA-256 `1B12BF7C500351565FFE0CDC370437D06F4BF998F8670FEF78B47FE2041868AF`.

### satisfied v1

- Prompt: quietly pleased after breakfast—relaxed shoulders, softly smiling eyes, restrained closed-mouth smile, both empty hands loosely clasped at the lower waist; no food or props.
- Selected built-in source: `C:\\Users\\Administrator\\.codex\\generated_images\\019ff44d-12f2-7c62-913f-21625016b163\\exec-78e6d669-1300-4059-83cd-7e76ad3f84cc.png`.
- Preserved chroma candidate: `tmp/imagegen/customer_17_chinese_states/customer_17_satisfied_v1_chroma.png`.
- Final PNG: `resources/art/customers/customer_17/customer_17_satisfied_v1_keyclean.png`; auto-key border sample `#F804F2`; region `Rect2(533, 40, 469, 984)`; SHA-256 `72FD7FB87923F9A8DF5785F24DF5180220816EBE374D7AFA38C75AB2308F8D4A`.

### accepting_bag v1

- Prompt: pleasantly attentive and modestly grateful while accepting exactly one small plain unbranded closed warm-kraft breakfast paper bag with both hands at mid-torso; zero coins and no visible food.
- Selected built-in source: `C:\\Users\\Administrator\\.codex\\generated_images\\019ff44d-12f2-7c62-913f-21625016b163\\exec-e2ce35ab-2ee2-4414-88f7-46c5fc8d29a9.png`.
- Preserved chroma candidate: `tmp/imagegen/customer_17_chinese_states/customer_17_accepting_bag_v1_chroma.png`.
- Final PNG: `resources/art/customers/customer_17/customer_17_accepting_bag_v1_keyclean.png`; auto-key border sample `#F804F7`; region `Rect2(516, 41, 510, 983)`; SHA-256 `2475AA9488823617D277708C7875E4595C64B1B65448D3233AFE03BE2B67F10D`.

### paying_coins v1

- Prompt: calmly focused and polite, holding exactly one small plain closed warm-kraft breakfast bag under the left forearm while the right open palm displays exactly three separate, non-overlapping, countable warm-gold coins; no banknotes, symbols, logos, text or other objects.
- Selected built-in source: `C:\\Users\\Administrator\\.codex\\generated_images\\019ff44d-12f2-7c62-913f-21625016b163\\exec-2123d528-c729-4636-9102-8ebf74dcf9b4.png`.
- Preserved chroma candidate: `tmp/imagegen/customer_17_chinese_states/customer_17_paying_coins_v1_chroma.png`.
- Final PNG: `resources/art/customers/customer_17/customer_17_paying_coins_v1_keyclean.png`; auto-key border sample `#F904F8`; region `Rect2(480, 43, 577, 981)`; SHA-256 `BED843130EAE590096973B1E65C17F29E22BB2934080C6DC35DE3A475B271DB7`.

## Full-state processing and validation

- Generator: Codex built-in image generation through the imagegen skill, using one separate identity-preserving generation call per state.
- Key removal: every original chroma candidate is retained. Each selected final uses `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
- Alpha validation: all four action PNGs are 1536x1024 RGBA with four transparent corners, nonempty bounds reaching the stable bottom anchor, and zero visible magenta-like pixels at alpha >= 16. No action-state candidate or key output was rejected.
- Import: Godot 4.7.1 imported all five selected PNGs to non-empty `CompressedTexture2D` caches: neutral 435,010 bytes; impatient 376,916; satisfied 386,238; accepting_bag 386,264; paying_coins 412,718.
- Runtime: `scripts/gameplay/workstation.gd` maps all five state keys to independent `customer_17_*_cropped.tres` AtlasTexture resources.
- Automated check: `CUSTOMER_17_STATES_CONTRACT_SELF_CHECK_PASS` verifies five keys, five final PNG paths, all regions, canvas size, alpha channel and transparent corners. During neutral integration, the then-current 17-customer rotation/old-save modulo and P1 checks passed. Subsequent parallel work expanded the shared customer pool beyond customer_17; this task deliberately did not alter those other identities or their rotation tests.
- Non-headless GPU check: Godot 4.7.1 on Windows, D3D12 12_0 Forward+ using NVIDIA GeForce RTX 5070; marker `CUSTOMER_17_STATES_GPU_PREVIEW_PASS`. All five runtime Atlas paths, source PNGs and regions were asserted while capturing real 1920x1080 workstation frames.
- GPU screenshots: `res://tmp/validation/customer_17_states_v1_gpu/customer_17_neutral_v1_1920x1080.png`, `customer_17_impatient_v1_1920x1080.png`, `customer_17_satisfied_v1_1920x1080.png`, `customer_17_accepting_bag_v1_1920x1080.png`, and `customer_17_paying_coins_v1_1920x1080.png`; log `tmp/validation/customer_17_states_gpu_d3d12.log`.
- Human review: the user confirmed the complete customer_17 five-state set on 2026-08-12. Automated, GPU and agent checks remain supporting evidence rather than a substitute for that acceptance.
