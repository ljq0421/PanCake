# customer_18 neutral v1

## Character

- Intended runtime ID: `customer_18`
- State: `neutral` only
- Identity: 44-year-old Chinese man who teaches guitar at a neighborhood community arts center, stopping for breakfast before a morning class
- Personality: warm, observant, unhurried, mildly amused
- Visual markers: slightly stocky build, short side-parted salt-and-pepper hair, deep-brown rounded glasses, rust-brown cardigan, muted smoky-teal T-shirt, slate-gray trousers, empty hands
- Direction: contemporary Chinese daily life without an instrument, occupational prop, uniform, badge, brand mark, historical costume, ethnic shorthand, or age caricature

## Selected generation prompt

Use case: `stylized-concept`  
Asset type: Godot 2D game customer portrait, `customer_18` neutral candidate  
Input images: Image 1 is the human-approved `customer_14` neutral style and composition threshold only. Do not copy its identity, face, hair, clothing, colors, or age. The new character must be visibly a little more cartoon-like, round, and graphic than Image 1 while remaining a moderate 2D game illustration.  
Primary request: Create exactly one contemporary Chinese everyday customer: a 44-year-old Chinese man who teaches guitar at a neighborhood community arts center, stopping for breakfast before a morning class. He is warm, observant, unhurried, and mildly amused, without caricature.  
Subject: slightly stocky adult build; short side-parted salt-and-pepper black hair in two or three broad graphic clumps; deep-brown rounded glasses with clear lenses; individual contemporary East Asian features; warm medium skin; a rust-brown knitted cardigan worn open over a muted smoky-teal crew-neck T-shirt; slate-gray straight-leg trousers; empty hands relaxed at both sides. No instrument or occupational object.  
Style/medium: moderate 2D game illustration, more cartoon-like than Image 1 but not chibi and not anime. Slightly larger rounded head, wide rounded graphic face, simplified almond eyes clearly visible behind glasses, bold simple brows, tiny line-defined nose, simple curved mouth, clean circular cheek-color patches, fine ink-brown contour lines, warm beige rice-paper/watercolor-paper texture, restrained dry brush, and low-saturation mineral colors in only two or three flat shade steps.  
Simplification: large graphic hair clumps; broad flat clothing shapes; minimal knit texture; few large folds; no realistic skin modelling; no detailed fingers; no realistic fabric or shadow rendering.  
Composition/framing: exactly one centered front-facing character on a 1536x1024 landscape canvas. Complete half-body portrait from the very top of all hair to clearly below the waist/upper thighs. Both complete elbows and both complete hands fully visible. Stable flat lower-body anchor reaches the bottom edge. Generous clear side padding. Neutral relaxed pose and expression.  
Scene/backdrop: perfectly flat uniform solid bright magenta `#FF00FF` chroma-key background for safe removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the subject fully separated with crisp edges. Do not use magenta anywhere in the subject.  
Constraints: preserve all hair, both elbows, both hands, waistline, upper thighs and bottom anchor without cropping; no cast/contact shadow; no text; no watermark; no logo; no other person.  
Avoid: portrait realism, realistic skin shading, glossy 3D, cinematic lighting, anime glamour, chibi proportions, childlike proportions, realistic folds, detailed fingers, historical costume, ethnic shorthand, occupational uniform, platform marks, brand marks, music notes, guitar, instrument case, sheet music, badge, phone, keys, bag, food, extra props, or clutter.

## Provenance and contract

- Generator: Codex built-in image generation through the imagegen skill; `customer_14` supplied only as the style/composition threshold.
- Selected generated source: `C:\Users\Administrator\.codex\generated_images\019ff455-1077-71d1-a992-a8bac20971a7\exec-ecfdba69-daa2-4caf-b45b-f050957f44eb.png`.
- Preserved chroma source: `tmp/imagegen/customer_18_chinese_neutral/customer_18_neutral_v1_chroma.png`; SHA-256 `36D03EC4A16497BDBBD80A02ED09E6500C9D36AD60718032E1A80E4E94E1D696`.
- Rejected processing outputs retained: the default soft-matte result removed face, glasses, inner shirt and torso pixels; tolerance-120 hard key caused the same damage. The tolerance-60 and connected-background candidates are retained as non-selected audit alternatives.
- Safe key processing: only generated magenta-like pixels (`R>=160`, `B>=150`, `G<=130`, `R+B>=330`) were normalized to exact `#FF00FF` in a preserved audit source, then removed by the installed `remove_chroma_key.py --key-color '#FF00FF' --tolerance 0 --despill` path. No subject palette pixel met that predicate in visual inspection.
- Final runtime PNG: `resources/art/customers/customer_18/customer_18_neutral_v1_keyclean.png`; SHA-256 `FE72BC5F84D977A8DA3405B55DA73F5985C2370B96F607F82D5875831DEC57F4`.
- Final canvas: 1536x1024 RGBA; transparent corners: 4/4; alpha bounds: `(473,24)` to `(1056,1024)`; AtlasTexture region: `Rect2(473,24,583,1000)`; 1,168,905 transparent and 403,959 opaque pixels; zero visible magenta-like pixels under the processing predicate.
- Runtime status: neutral-only integration. All five state keys use independent AtlasTexture resources; the four action-state resources deliberately reference the neutral PNG pending explicit neutral approval.
- Godot import: passed with Godot 4.7.1; 1,033-byte `.png.import` sidecar resolves to a non-empty 510,710-byte `CompressedTexture2D` cache.
- Automated verification: `CUSTOMER_18_PORTRAIT_CONTRACT_SELF_CHECK_PASS`, `FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS`, and `P1 vertical-slice self-check PASS`; both customer pools contain 18 identities, current snapshots preserve customer_18, and pre-expansion snapshots retain the original ten-customer modulo.
- GPU verification: Godot 4.7.1 non-headless Windows/D3D12 12_0 Forward Mobile on NVIDIA GeForce RTX 5070 passed with `CUSTOMER_18_NEUTRAL_GPU_PREVIEW_PASS`.
- GPU evidence: `tmp/validation/customer_18_neutral_v1_chinese_gpu_clear_1920x1080.png`; 1920x1080; SHA-256 `233BD1AE57ABB12964FE08C8ECD3C7E8D79575E963A9DE76418D28A8FB7B5452`; log `tmp/validation/customer_18_neutral_gpu_d3d12.log`.
- Agent visual review: passed for complete hair/elbows/hands/below-waist framing, stable bottom anchor, intact face/glasses/clothing, clear non-chibi cartoon treatment, and absence of visible magenta holes or halo at actual workstation scale.
- Human review: confirmed by the user on 2026-08-12; this neutral is now the sole authority for the four action states.
