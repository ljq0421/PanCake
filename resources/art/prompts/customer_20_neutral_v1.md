# customer_20 neutral v1

## Character

- Intended runtime ID: `customer_20`
- State: `neutral` only
- Identity: a 67-year-old Chinese woman, retired from teaching middle-school physics, stopping for breakfast during an ordinary morning errand.
- Personality: calm, observant, gently self-possessed.
- Visual markers: short softly curled salt-and-pepper black hair, muted teal cardigan, dusty clay-rose crew-neck top, dark olive-charcoal straight trousers, empty hands, front-facing pose.
- Direction: contemporary Chinese daily life without a uniform, badge, platform mark, occupational prop, historical costume, ethnic shorthand, retirement stereotype, or teacher stereotype.

## Selected generation prompt

Use case: `stylized-concept`  
Asset type: Godot 2D customer portrait, `customer_20_neutral` only  
Input image: customer_14 neutral was supplied only as a cartoon-style threshold reference; the new identity must not copy its face, hair, outfit, colors, age, or proportions.  
Primary request: create the new customer identity above with a neutral closed-mouth expression, front-facing relaxed pose, and empty hands.  
Style/medium: slightly more cartoon-like than customer_14 while remaining moderate 2D game illustration; explicitly not chibi and not anime; warm rice-paper and watercolor-paper feel, fine ink-brown contours, low-saturation mineral colors, two-to-three-step flat painted color blocks, sparse dry-brush texture, rounded graphic head and face, slightly larger head, simplified almond eyes, tiny line-defined nose, clean cheek patches, simplified hands, fingers, and fabric folds, minimal realistic shadow modeling.  
Composition/framing: exact landscape 1536x1024 canvas; centered complete half-body from all hair to below the waist; entire hairstyle, both elbows, both hands, and lower waist/trouser area visible; generous side padding and stable bottom anchor.  
Scene/backdrop: perfectly flat solid bright `#FF00FF` chroma-key background, uniform with no shadows, gradients, texture, reflections, floor, horizon, or lighting variation.  
Constraints: exactly one person; empty hands; no props, text, watermark, logo, magenta inside the subject, cropped anatomy, realistic portraiture, detailed skin/finger/fabric modeling, glossy 3D, cinematic lighting, saturated colors, chibi proportions, anime glamour, historical costume, or stereotypes.

## Provenance and contract

- Generator: Codex built-in image generation through the imagegen skill.
- Generated source: `C:\Users\Administrator\.codex\generated_images\019ff456-df6c-7f21-a4a1-9950a7eac04b\exec-48cd6d70-a685-4442-aef5-3379f33dabef.png`.
- Preserved chroma source: `res://tmp/imagegen/customer_20_chinese_neutral/customer_20_neutral_v1_chroma.png`.
- Preserved rejected key candidates: default soft-matte, hard-60, hard-120, hard-60/contract-2, hard-60/contract-4, hard-100/contract-2, soft-80, and key-clean iterations are retained beside the source. The default soft-matte, soft-80, hard-100, and hard-120 candidates visibly removed face or clothing pixels and are not runtime-integrated.
- Selected key source: `customer_20_neutral_v1_keyed_hard60_contract2.png`, produced with installed `remove_chroma_key.py --key-color '#FF00FF' --tolerance 60 --edge-contract 2 --despill`.
- Selected cleanup: transparent RGB was zeroed; remaining saturated magenta pixels near the transparent silhouette edge were cleared through the retained deterministic cleanup scripts. The selected tmp candidate is `customer_20_neutral_v1_keyclean_v4.png`.
- Final file: `res://resources/art/customers/customer_20/customer_20_neutral_v1_keyclean.png`.
- Final canvas: 1536x1024 RGBA; alpha bounds `(503,38)-(1029,1024)`; Atlas region `Rect2(503,38,526,986)`; transparent top/left/right edges and four corners; bottom edge is the intended 340-pixel anchor span.
- SHA-256: `21D2245D68C596F7CB7AAAB9EA28A670FB54FDE1FBAD4F2389CB34C7F45C5DA5`.
- Godot import: passed with Godot 4.7.1; the 1,032-byte `.png.import` sidecar resolves to a non-empty 478,882-byte `CompressedTexture2D` cache.
- Runtime and rotation: `workstation.gd` exposes only `neutral`, so ungenerated reaction states fall back to this AtlasTexture; both live customer pools include customer_20; focused formal-order and P1 rotation/save checks passed while the legacy ten-customer modulo remained unchanged.
- GPU verification: Godot 4.7.1 non-headless Windows/D3D12 12_0 Forward Mobile on NVIDIA GeForce RTX 5070 passed with marker `CUSTOMER_20_NEUTRAL_GPU_PREVIEW_PASS`. The first runtime-valid but visually obstructed capture is retained; selected clear screenshot: `res://tmp/validation/customer_20_neutral_v1_gpu_clear_1920x1080.png`, SHA-256 `58EA6E488DC35376EF57E1FCEA4DA5A93629B0B71042866DAFA0782CEB3D9D90`.
- Human review: the user confirmed neutral on 2026-08-12. That approval authorized only the customer_20 `impatient`, `satisfied`, `accepting_bag`, and `paying_coins` states; their separate provenance is recorded in `customer_20_states_v1.md`.
