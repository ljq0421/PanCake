# customer_19 action states v1

## Shared identity and visual lock

- Authority: confirmed `customer_19_neutral_v1_keyclean.png` only. All four states retain the same 43-year-old Chinese man, black hair with gray temples, rounded-square face, warm medium skin, dusty-aubergine overshirt, oatmeal Henley shirt, olive-gray trousers, contemporary everyday identity, and moderate rounded 2D illustration style.
- Shared canvas: 1536x1024 landscape, complete hair, both elbows, both hands, below-waist/upper-thigh framing, generous side padding, and stable bottom anchor.
- Shared style: warm rice-paper watercolor texture, thin ink-brown contours, low-saturation mineral colors, two-to-three flat gouache shades, simplified features and hands; more graphic than customer_14, never chibi or anime.
- Shared background: perfectly flat bright magenta `#FF00FF`; no shadows, floor, text, watermark, logo, other person, historical costume, uniform, medical equipment, stereotype, or magenta within the subject.

## Selected prompts and provenance

### impatient

- Prompt: same confirmed character with only a restrained waiting side glance, one subtly lifted brow, and a slightly flattened mouth; calm posture, empty hands, no anger, sadness, worry, dramatic gesture, or prop.
- Generator source: `C:\Users\Administrator\.codex\generated_images\019ff456-253c-7182-9449-436683476a1f\exec-5fee5f20-fb4a-498f-b6f8-9af00d02a35c.png`.
- Preserved chroma source: `tmp/imagegen/customer_19_chinese_states/customer_19_impatient_v1_chroma.png`; SHA-256 `001B9F7A23EF97C53C5DE4316AEFB0546E15BE2322A1D4A0A758C686F387676E`.
- Final: `resources/art/customers/customer_19/customer_19_impatient_v1.png`; SHA-256 `E15E70DD2E92348C40E21F9CD85BFD101810C95FBC9CE9D71BEA7F6214790D5D`; region `Rect2(486,28,565,996)`.

### satisfied

- Prompt: same confirmed character with only a warm, small closed-mouth smile, calm eyes, softened brows, and relaxed posture; no exaggerated happiness, laugh, wink, or prop.
- Generator source: `C:\Users\Administrator\.codex\generated_images\019ff456-253c-7182-9449-436683476a1f\exec-7851011f-5cab-4377-8460-ce6c7194be49.png`.
- Preserved chroma source: `tmp/imagegen/customer_19_chinese_states/customer_19_satisfied_v1_chroma.png`; SHA-256 `11ED777D86C46D707F80C6B0E3E72B9DA4C61C4D6406CDA8707B2D7F98F36B35`.
- Final: `resources/art/customers/customer_19/customer_19_satisfied_v1.png`; SHA-256 `85A50AB5A4020306500A7480839330D13CAC983E0744160C0CEEE0A207BC67A1`; region `Rect2(487,28,563,996)`.

### accepting_bag

- Prompt: same character in a calm satisfied pose holding exactly one plain warm-kraft takeaway paper bag, with both complete hands at lower chest/upper waist; no visible food, coins, print, label, or logo.
- Generator source: `C:\Users\Administrator\.codex\generated_images\019ff456-253c-7182-9449-436683476a1f\exec-48feb096-616a-4be1-aa45-31a3efa88a81.png`.
- Preserved chroma source: `tmp/imagegen/customer_19_chinese_states/customer_19_accepting_bag_v1_chroma.png`; SHA-256 `D9ED47CEA5074E6156FBFA7C5D65018B18A29D820293AE0CCFCD4FA342B85C7A`.
- Final: `resources/art/customers/customer_19/customer_19_accepting_bag_v1.png`; SHA-256 `A16271E35CC931656F1F02F9F5395300826B7472F1BD4942C9FFA56E6D4DF429`; region `Rect2(487,28,567,996)`.

### paying_coins

- Prompt: same character in a calm paying pose holding exactly one plain warm-kraft bag in his left hand and exactly three clearly separated round coins on his open right palm; no extra coin, coin stack, label, or logo.
- Generator source: `C:\Users\Administrator\.codex\generated_images\019ff456-253c-7182-9449-436683476a1f\exec-eca28aa0-9e98-4621-91e5-a68254a55788.png`.
- Preserved chroma source: `tmp/imagegen/customer_19_chinese_states/customer_19_paying_coins_v1_chroma.png`; SHA-256 `0FBBDC11B620CEBF379D46A1E5A3E64A4C4B8AC2BBE75F8FAD4702BCD49C3921`.
- Final: `resources/art/customers/customer_19/customer_19_paying_coins_v1.png`; SHA-256 `5DC72A020E0FB717D24BFAD9644CA954F43549B5A8E506DC87C4EEAFBE171C93`; region `Rect2(428,28,622,996)`.

## Processing and status

- The four original chroma sources and all soft-key candidates are retained in `tmp/imagegen/customer_19_chinese_states/`.
- Each selected output uses installed `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`; sampled keys were near-magenta generator variants (`#F508ED`, `#F803F7`, `#F604F5`, and `#F704F5`).
- All four selected PNGs are 1536x1024 RGBA with four transparent corners and zero visible magenta-like pixels at alpha >= 16.
- Godot import: passed with Godot 4.7.1 for all four finals; their `.png.import` sidecars resolve to non-empty `CompressedTexture2D` caches.
- Runtime and GPU: `workstation.gd` maps all five states; `CUSTOMER_19_STATES_GPU_PREVIEW_PASS` and five single-state markers passed on non-headless Windows/D3D12 12_0 Forward Mobile / NVIDIA GeForce RTX 5070. Clear live-Atlas screenshots are retained in `tmp/validation/customer_19_states_v1_gpu_atlas/`. Earlier malformed root-frame captures are also retained but excluded from visual-review evidence.
- Human review: confirmed by the user on 2026-08-12 as `确认 customer_19 全套`; this is final visual approval for customer_19's five-state set only.
