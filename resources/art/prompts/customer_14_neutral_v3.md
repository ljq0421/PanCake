# customer_14 neutral v3

## Character

- Intended runtime ID: `customer_14`
- State: `neutral` only
- Identity: the same 38-year-old Chinese independent neighborhood-bookshop owner as v2, stopping for breakfast before opening.
- Personality: calm, curious, quietly sociable.
- Visual markers retained: wavy black side-parted hair, deep indigo overshirt, muted ochre T-shirt, stone-gray trousers, empty hands, front-facing pose.
- Direction: contemporary Chinese daily life without a uniform, badge, platform mark, store sign, occupational prop, historical costume, ethnic shorthand, or regional stereotype.

## Selected generation prompt

Use case: `identity-preserve`  
Asset type: Godot 2D customer portrait, `customer_14_neutral` v3  
Primary request: use v2 only as an identity reference and make the illustration substantially more cartoon-like: a slightly larger rounded head, a graphic rounded face, larger simplified almond eyes, bold brows, a tiny line-defined nose, a simple smile, clean cheek patches, fewer individual finger and fabric details, and no realistic facial modelling.  
Style/medium: warm rice-paper watercolor texture, ink-brown contour line, flat gouache mineral colours in two to three shade steps, sparse dry-brush accents, readable hand-painted game-sprite silhouette.  
Composition/framing: preserve the centered 1536x1024 full-hair-to-below-waist framing, full elbows and hands, generous side padding, and stable bottom anchor.  
Constraints: retain the same person, clothes, colour family, empty hands, and flat `#FF00FF` background; no shadows, floor, text, watermark, logos, other people, or magenta within the subject.  
Avoid: realistic portraiture, skin-rendering detail, individual finger detail, glossy 3D, cinematic lighting, chibi proportions, anime glamour, historical costume, saturated cartoon colours, and occupational stereotypes.

## Provenance and contract

- Generator: Codex built-in image generation (`identity-preserve`), using v2 as the supplied image reference.
- Selected generated source: `C:\Users\Administrator\.codex\generated_images\019ff332-7492-7b02-a517-a5a95e6f3e56\exec-d770959c-23bb-4b2f-81b2-c665a13f80f7.png`.
- Preserved chroma source: `tmp/imagegen/customer_14_chinese_neutral/customer_14_neutral_v3_chroma.png`.
- The default soft-matte candidate `customer_14_neutral_v3.png` failed alpha validation by making parts of the face and clothes transparent; it is retained for audit and is not runtime-integrated.
- The intermediate `customer_14_neutral_v3_hardkey.png` was retained for audit but had a stronger magenta fringe and is not runtime-integrated.
- Selected key-clean candidate: `customer_14_neutral_v3_keyclean120.png`, produced with `remove_chroma_key.py --key-color '#FF00FF' --tolerance 120 --edge-contract 1 --despill`.
- Final canvas: 1536x1024 RGBA; transparent corners: 4/4; alpha bounds: `(488, 25)` to `(1045, 1024)`; AtlasTexture region: `Rect2(488, 25, 557, 999)`.
- Runtime status: neutral-only integration; the four action states deliberately fall back to neutral pending explicit human approval.
- Automated import and identity-rotation verification: passed.
- GPU verification: Godot 4.7.1 non-headless Windows/D3D12 run on NVIDIA GeForce RTX 5070 passed and captured a real 1920x1080 workstation frame.
- Human review: approved before the four action states were generated.
