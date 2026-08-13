# customer_11 neutral v1

## Character

- Intended runtime ID: `customer_11`
- State: `neutral` only
- Identity: 24-year-old Chinese woman, entry-level urban office employee
- Personality: calm, observant, approachable
- Visual markers: neat low ponytail, dusty-cinnabar cardigan, ivory crew-neck shirt, muted indigo trousers
- Direction: contemporary Chinese everyday life without historical costume, ethnic shorthand, brand marks, or occupational uniform

## Generation prompt

Use case: stylized-concept  
Asset type: Godot game customer portrait neutral preview  
Primary request: Create one contemporary Chinese everyday customer character: a 24-year-old woman who works as an entry-level urban office employee, calm and observant, with a neat low ponytail, natural individual East Asian facial features, warm medium-light skin, wearing a practical dusty-cinnabar cardigan over an ivory crew-neck shirt and muted indigo trousers.  
Style/medium: warm Chinese watercolor illustration on textured rice paper, fine dark ink-brown outlines, subtle dry-brush texture, rounded friendly game portrait proportions, restrained mineral pigments.  
Composition/framing: one centered front-facing character on a 1536x1024 landscape canvas; complete half-body from full hair to below waist; both arms and hands visible; generous side padding; relaxed neutral pose and expression.  
Backdrop: perfectly flat solid bright magenta `#FF00FF` chroma-key background.  
Avoid: background shadows or texture, magenta in the subject, cast/contact shadow, props, text, watermark, extra people, historical or ethnic costume, glamour-anime rendering, Westernized facial identity, muddy gray palette, high-saturation cartoon color.

## References

- `resources/art/customers/customer_01/customer_01_neutral_v3_chinese_colorful.png`: portrait rendering language only
- `resources/art/ui/start_menu/start_menu_background_morning_mobile_cart_v3_chinese.png`: rice-paper warmth and ink-line reference
- `resources/art/workstation/background/workstation_18_single_row_1920x1080_v8_chinese.png`: workstation mineral palette and material reference

## Processing and contract

- Built-in image generation source: `C:\Users\Administrator\.codex\generated_images\019feece-75c3-7893-b5b5-85e359d9ca1c\exec-38d5481a-f958-45f1-b27d-270fc7c9ada3.png`
- Preserved chroma source: `tmp/imagegen/customer_11_chinese_neutral/customer_11_neutral_v1_chroma.png`
- Key removal: installed `remove_chroma_key.py`, auto-key border, soft matte, thresholds 12/220, despill
- Final canvas: 1536x1024 RGBA
- Non-zero alpha bounds: `(533, 45)` to `(999, 1023)`; AtlasTexture region `Rect2(533, 45, 467, 979)`
- Transparent corners: 4/4
- Runtime status: full five-state integration follows approved neutral identity
- Human review: full five-state set approved on 2026-08-11
