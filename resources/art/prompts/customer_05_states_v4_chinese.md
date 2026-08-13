# customer_05 state portraits v4 (neutral-locked)

Generated on 2026-08-11 with the Codex built-in `image_gen` tool through the imagegen skill.

## Locked source and reference order

1. `res://resources/art/customers/customer_05/customer_05_neutral_v4_chinese.png` is the sole authority for identity, age, skin tone, hair, garment design, garment colors, ink line, rice-paper watercolor texture and overall rendering.
2. The matching legacy `customer_05_*_v1.png` is used only for the requested state/action and framing intent.
3. The approved matching `customer_02_*_v4_colorlocked.png` is used only as a quality/state-legibility reference and must not transfer identity or clothing.

Every generation requested the same young adult Chinese woman, warm light-medium skin, narrow oval face, straight dark chin-length blunt bob with short blunt bangs and exposed ears, muted dusty-plum shallow square-neck blouse, warm cream lower garment, Chinese warm rice-paper watercolor, fine ink-brown lines, restrained dry brush, complete frontal half-body, and a flat bright `#FF00FF` background. Only the following state delta was permitted:

- `impatient`: mildly impatient waiting expression; gently furrowed brows and a small downturned closed mouth; arms relaxed; explicitly not furious, hostile, crying or distressed.
- `satisfied`: warm satisfied closed-eye smile; arms relaxed.
- `accepting_bag`: calm pleased expression; both hands securely accepting one warm kraft-paper takeaway bag at center torso.
- `paying_coins`: calm friendly expression; one warm kraft-paper takeaway bag held on viewer-right; open palm extended on viewer-left with exactly three clearly separated gold coins.

## Generation and deterministic processing

- Selected ImageGen sources:
  - `C:/Users/Administrator/.codex/generated_images/019feea2-dbe6-7491-abe6-1c457461ae96/exec-8df63d2f-0201-4f0b-bd1e-c5ccb01f4512.png` (`impatient`)
  - `C:/Users/Administrator/.codex/generated_images/019feea2-dbe6-7491-abe6-1c457461ae96/exec-e1559e9d-3f81-415d-9cce-e48abe2f1615.png` (`satisfied`)
  - `C:/Users/Administrator/.codex/generated_images/019feea2-dbe6-7491-abe6-1c457461ae96/exec-4265490b-90de-406c-b6fb-b86fc55796b8.png` (`accepting_bag`)
  - `C:/Users/Administrator/.codex/generated_images/019feea2-dbe6-7491-abe6-1c457461ae96/exec-c6626ff9-bb56-4765-a20e-ab05f7476209.png` (`paying_coins`)
- Rejected impatient attempts `exec-e70a38d4-23de-4ea8-b41a-7fad08a11385.png` and `exec-8af62f41-c326-475b-940e-c89d6d90cc39.png` read as sad/worried and were not imported or referenced.
- Chroma removal: `remove_chroma_key.py --auto-key border --tolerance 60 --despill`. A hard border-connected tolerance was selected to protect the dusty-plum/red blouse and warm skin from soft-matte false positives.
- `res://tmp/imagegen/customer_05_states_v4/normalize_customer_05_states_v4.py` removes residual edge-only magenta spill, locks the blouse/lower-garment palette to the approved neutral, and normalizes each alpha bound to its legacy Atlas rectangle on the unchanged `1535x1024` RGBA canvas.

## Final files and hashes

- `customer_05_impatient_v4_chinese.png`: `4152118C63E7A25D28FC911D2C9C905563CB63CC1124ED24CE04A3C59D2F6E11`; `Rect2(536, 87, 451, 890)`.
- `customer_05_satisfied_v4_chinese.png`: `9A28CAEE4B240FA13D2E98F6C0A5A5567CCA0375132DC46932F2B915EFF3237E`; `Rect2(535, 85, 452, 892)`.
- `customer_05_accepting_bag_v4_chinese.png`: `D5BC094675A40CCE0AFAC48CA0FAAFDE4F43F86021992C5D635A7F1369C240AD`; `Rect2(534, 75, 461, 901)`.
- `customer_05_paying_coins_v4_chinese.png`: `8E4A7AE438F2FE995C8A0A0854578CF29A3C4F1A1BF9015F6EA5C0928FD8DC5F`; `Rect2(440, 63, 627, 914)`.

All four outputs have transparent corners and zero visible magenta-like pixels at alpha >= 16. Runtime GPU validation and human acceptance are tracked separately.
