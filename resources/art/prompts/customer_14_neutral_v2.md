# customer_14 neutral v2

## Character

- Intended runtime ID: `customer_14`
- State: `neutral` only
- Identity: 38-year-old Chinese independent neighborhood-bookshop owner stopping for breakfast before opening.
- Personality: calm, curious, quietly sociable.
- Visual markers: short naturally wavy black hair with a soft side part; deep indigo linen overshirt; muted ochre crew-neck T-shirt; stone-gray straight trousers; empty hands.
- Direction: contemporary Chinese daily life without a uniform, badge, store sign, books, branded clothing, occupation prop, historical costume, ethnic shorthand, or regional stereotype.

## Selected generation prompt

Use case: `stylized-concept`  
Asset type: Godot game customer portrait neutral  
Primary request: a distinct contemporary Chinese everyday customer, rendered as a 38-year-old independent neighborhood-bookshop owner stopping for breakfast before opening.  
Style/medium: polished 2D game-character illustration, clearly not a portrait; slightly oversized rounded head, simplified round-rectangular face, large natural almond-shaped graphic eyes, simplified brows, small line-defined nose and mouth, broad flat warm cheek shapes, confident fine ink-brown outlines, readable silhouette, flat watercolor-gouache mineral colour blocks, warm rice-paper and watercolor-paper grain concentrated in clothing and colour blocks, and sparse dry-brush accents.  
Composition/framing: centered, front-facing 1536x1024 half-body from full hair to below waist; full elbows and hands visible; generous padding; stable bottom anchor near y=1000.  
Constraints: bright-magenta chroma-key background only; no shadows, floor, gradients, texture, reflections, text, watermark, logos, additional people, or magenta in the subject.  
Avoid: photorealism, portrait photography, realistic skin rendering, detailed facial shading, glossy 3D, cinematic lighting, anime glamour, historical costume, mud-gray palette, and high-saturation cartoon colours.

## Provenance and contract

- Generator: Codex built-in image generation (`stylized-concept`).
- Selected source: `C:\Users\Administrator\.codex\generated_images\019ff332-7492-7b02-a517-a5a95e6f3e56\exec-18b83462-f109-478f-a2a3-f3b0e9b9dd40.png`.
- Earlier v1 candidate was assessed as still too portrait-like, was not copied into the project, and was not runtime-integrated.
- Preserved chroma source: `tmp/imagegen/customer_14_chinese_neutral/customer_14_neutral_v2_chroma.png`.
- Key removal: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
- Final canvas: 1536x1024 RGBA; transparent corners: 4/4; alpha bounds: `(491, 34)` to `(1057, 1024)`; AtlasTexture region: `Rect2(491, 34, 566, 990)`.
- Runtime status: superseded by v3 before human approval; retained only as provenance and a non-runtime comparison candidate.
- GPU verification: this v2 candidate passed a Godot 4.7.1 non-headless Windows/D3D12 capture before it was superseded.
- Human review: not requested; review v3 instead.
