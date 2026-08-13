# customer_15 action states v1

## Identity continuity

- Intended runtime ID: `customer_15`.
- Reused approved neutral identity: a 58-year-old Chinese woman who runs an independent neighborhood clothing-alteration shop, with a short charcoal-and-silver bob, muted teal cropped jacket, dusty plum crew-neck top, and charcoal trousers.
- The visual direction remains a slightly cartoon-like 2D game illustration: warm rice-paper watercolor texture, fine ink-brown contours, restrained dry brush, and flat mineral colors. It is contemporary daily life, with no uniform, platform mark, shop branding, occupational prop pile, historical costume, or ethnic shorthand.

## Selected generation prompts

All four generation calls used the approved neutral PNG as the identity reference, requested a 1536x1024 landscape canvas, exactly one complete front-facing character from full hair through the lower-body anchor, complete hands, a crisp separated silhouette, and a perfectly flat `#FF00FF` background without shadow, text, logo, or watermark.

- `impatient`: Mildly impatient but restrained: one hand on hip and the other relaxed, eyebrows lightly raised, mouth neutral-to-tight; do not depict anger or a different character.
- `satisfied`: Warmly satisfied: small pleased smile and both hands gently clasped at the lower abdomen; no prop.
- `accepting_bag`: Calmly accepting exactly one plain unbranded kraft paper bag held with both hands at the lower chest; no logo, text, food visibility, or other objects.
- `paying_coins`: Paying with exactly three small warm-gold blank coins resting in one open palm; no currency markings, brand, wallet, phone, cash register, or other prop.

## Provenance and alpha contract

- Generator: Codex built-in image generation (`stylized-concept`) with the approved neutral PNG as identity reference.
- Preserved chroma sources:
  - `tmp/imagegen/customer_15_chinese_states/customer_15_impatient_v1_chroma.png`; SHA-256 `4E570CD212020E7B71F130B7BD91BAD378D20C1F5659BAEE2E576CE736874F4F`.
  - `tmp/imagegen/customer_15_chinese_states/customer_15_satisfied_v2_chroma.png`; SHA-256 `092CD1E8D70364D9CA8E01C0D93466354122DF158F65CDAFF84B1DD46EF6FE31`.
  - `tmp/imagegen/customer_15_chinese_states/customer_15_accepting_bag_v1_chroma.png`; SHA-256 `30858D7A44E1931375A5D6BBBA6C644E2F59E5C2ED99D446168351AF8B1D4100`.
  - `tmp/imagegen/customer_15_chinese_states/customer_15_paying_coins_v1_chroma.png`; SHA-256 `86EFD698E7D8A8E34CD7A2DF0C935E589828F5A37D62848E314601B208B4E2FA`.
- Final RGBA processing: `remove_chroma_key.py --key-color <sampled magenta> --tolerance 100 --edge-contract 1`. The one-pixel matte contraction was selected after visual comparison because soft matte retained a magenta fringe; it was not used on the neutral asset.
- Final assets and AtlasTexture regions:
  - `customer_15_impatient_v6.png`; SHA-256 `F9E8819879C2A60A13A3581A6769017B134FBFC1BE14B990220B05E52F122728`; `Rect2(443, 38, 586, 986)`.
  - `customer_15_satisfied_v7.png`; SHA-256 `1E93FFF4FDFACEE92C7AA92F5648CC89BD3B6EAB42FCCB1AED793B2C1F400FA7`; `Rect2(516, 37, 492, 987)`.
  - `customer_15_accepting_bag_v6.png`; SHA-256 `6E319365A4EEFEC49B91EC2C3D984AC0C22B3B45F6B32D5C795234E154DE2EF8`; `Rect2(513, 38, 495, 986)`.
  - `customer_15_paying_coins_v6.png`; SHA-256 `DA0E28A1714D4C638FD36EDEFFC9B6471B2FBB11B9F0C6DC985163503846FA99`; `Rect2(518, 29, 506, 995)`.
- All final canvases are 1536x1024 RGBA. Their four corners are transparent; alpha bounds retain complete hair, both hands, and the lower-body anchor. The final output has no alpha-semi-transparent magenta border; a small number of opaque warm-plum garment pixels remain by design and are not chroma residue.

## Runtime and review status

- The four dedicated AtlasTexture resources now replace the temporary neutral fallback for `impatient`, `satisfied`, `accepting_bag`, and `paying_coins`.
- Godot 4.7.1 import passed. `CUSTOMER_15_PORTRAIT_CONTRACT_SELF_CHECK_PASS` confirmed all five runtime keys, final PNG paths, AtlasTexture crop regions, 1536x1024 RGBA format, and four transparent corners.
- Godot 4.7.1 non-headless D3D12 preview passed on NVIDIA GeForce RTX 5070: `CUSTOMER_15_STATES_GPU_PREVIEW_PASS`. It captured one real 1920x1080 workstation frame for each state under `tmp/validation/customer_15_states_v1_gpu/`; log: `tmp/validation/customer_15_states_gpu_d3d12.log`.
- Human visual review of these four action-state candidates remains pending.
