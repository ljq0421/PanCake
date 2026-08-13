# customer_16 neutral v2

## Character

- Intended runtime ID: `customer_16`
- State: `neutral` only
- Identity: 19-year-old Chinese male technical-college student studying electrical equipment maintenance, stopping for breakfast before class
- Personality: quietly curious, slightly shy, good-natured
- Visual markers: short softly tousled black hair, muted sage-green short jacket, warm clay-red crew-neck shirt, deep indigo straight-leg trousers, empty hands
- Direction: contemporary Chinese daily life without a school or occupational uniform, badge, tool, platform mark, historical costume, ethnic shorthand, or youth caricature

## Selected generation prompt

Use case: `identity-preserve`  
Asset type: Godot 2D game customer portrait, `customer_16` neutral candidate v2  
Input images: Image 1 is the rejected v1 edit target and identity/composition/clothing authority. Image 2 is the confirmed `customer_14` neutral style threshold only; customer_16 must be visibly a little more cartoon-like and graphic without copying customer_14's identity, hair, face, clothing, or colors.  
Primary request: Redraw the same 19-year-old Chinese male technical-college student with the same short black hair, muted sage-green short jacket, warm clay-red crew-neck shirt, deep indigo trousers, front-facing neutral pose, empty hands, and reserved small smile. Change only the rendering style to be more rounded, simplified, and game-illustrative.  
Style/medium: moderate 2D game illustration, distinctly more cartoon-like and graphic than customer_14, but never chibi and never anime. Slightly enlarged rounded head, broad graphic rounded face, simplified almond eyes, bold simple brows, tiny line-defined nose, simple curved mouth, circular cheek-color patches, ink-brown contours, warm beige rice-paper watercolor texture, restrained dry brush, and low-saturation mineral colors in two or three flat shade steps.  
Simplification: no realistic skin modelling; large graphic hair clumps; broad flat clothing shapes; reduced folds, seams, zipper and trouser modelling; minimal finger separation.  
Composition/framing: exactly one centered front-facing character on a 1536x1024 landscape canvas, complete from all hair to below waist/upper thighs, with both complete elbows and hands, generous side padding, and a stable bottom anchor.  
Backdrop: perfectly flat uniform bright magenta `#FF00FF`, without shadows, gradients, texture, reflections, floor plane, lighting variation, or magenta inside the subject.  
Avoid: portrait realism, anime, chibi, childlike proportions, realistic folds or fingers, historical costume, uniform, tools, backpack, phone, books, food, text, logos, watermark, other people, or clutter.

## Provenance and contract

- Generator: Codex built-in image generation through the imagegen skill.
- Rejected v1 generated source: `C:\Users\Administrator\.codex\generated_images\019ff3d7-4807-78a1-bc70-bb60e103a0c8\exec-f03f80d4-17f3-4fc2-b08c-fc58e4488bdc.png`; preserved as `tmp/imagegen/customer_16_chinese_neutral/customer_16_neutral_v1_rejected_too_realistic_chroma.png`; rejected because it was less cartoon-like than customer_14.
- Selected v2 generated source: `C:\Users\Administrator\.codex\generated_images\019ff3d7-4807-78a1-bc70-bb60e103a0c8\exec-35e9bcc3-2eb4-4cd0-9470-33787ffc4db5.png`.
- Preserved original chroma source: `tmp/imagegen/customer_16_chinese_neutral/customer_16_neutral_v2_chroma.png`.
- The generator's requested `#FF00FF` background sampled near `#F806E8`; the unmodified source and its safe auto-key output are retained. A separate audit source, `customer_16_neutral_v2_chroma_exact_ff00ff.png`, changes only pixels already classified as connected background to exact `#FF00FF` before final key removal.
- Final key removal: installed `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` from the exact-`#FF00FF` audit source.
- Final runtime PNG: `resources/art/customers/customer_16/customer_16_neutral_v2_keyclean.png`; SHA-256 `D18C076882B5F86892247EDB9AE914A078A7D4237D0F153D1B4BBACBA9EAACD8`.
- Alternate safe auto-key output: `resources/art/customers/customer_16/customer_16_neutral_v2.png`; retained for audit and not runtime-integrated.
- Final canvas: 1536x1024 RGBA; transparent corners: 4/4; alpha bounds: `(508, 18)` to `(1028, 1024)`; AtlasTexture region: `Rect2(508, 18, 520, 1006)`.
- Alpha validation: 1,200,519 transparent, 3,778 partial and 368,567 opaque pixels; zero visible magenta-like pixels at alpha >= 16; central clay-red shirt pixel remains `(215, 77, 39, 255)`.
- Runtime status: neutral-only integration; all four action-state Atlas resources intentionally fall back to this neutral pending explicit human approval.
- Godot import: passed with Godot 4.7.1; the 1,033-byte `.png.import` sidecar resolves to a non-empty 438,266-byte `CompressedTexture2D` cache.
- Automated verification: `FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS` and `P1 vertical-slice self-check PASS`; both customer pools rotate through all sixteen IDs, current snapshots preserve `customer_16`, and pre-expansion snapshots retain the original ten-customer modulo.
- GPU verification: Godot 4.7.1 non-headless Windows/D3D12 Forward Mobile on NVIDIA GeForce RTX 5070 passed with `CUSTOMER_16_NEUTRAL_GPU_PREVIEW_PASS`.
- Clear review screenshot: `tmp/validation/customer_16_neutral_v2_chinese_gpu_clear_1920x1080.png`; 1920x1080; SHA-256 `E94EB7B8235219F902EEB11D5999D51D1BEA202724DF9EB97A8344EEE129B124`. The earlier unobstructed-test attempt is retained separately because the formal middle service card covered the portrait.
- Human review: approved by the user on 2026-08-12; this neutral is the sole identity, outfit, palette, style and composition authority for all four action states.
