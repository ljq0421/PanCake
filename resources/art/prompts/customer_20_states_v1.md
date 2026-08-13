# customer_20 action states v1

## Scope and identity lock

- Intended runtime ID: `customer_20`; states: `impatient`, `satisfied`, `accepting_bag`, and `paying_coins` only.
- The user confirmed `customer_20` neutral on 2026-08-12. Its selected final was the sole identity, outfit, palette, age and proportion reference for every action generation.
- Keep: 67-year-old Chinese woman; short softly curled salt-and-pepper hair; muted teal cardigan, dusty clay-rose top and dark olive-charcoal trousers; calm, observant and gently self-possessed contemporary daily-life character.
- The character is not a uniformed worker, stereotype, historical costume, branded person or portrait-realistic subject.

## Shared generation and style contract

Codex built-in image generation through the imagegen skill. Each 1536x1024 landscape generation required the neutral identity lock, complete half body (all hair, both elbows, both hands and below waist), stable bottom anchor, and a perfectly flat solid bright `#FF00FF` background. The visual direction is slightly more cartoon-like than customer_14 but still moderate 2D game illustration: warm rice/watercolor paper texture, fine ink-brown contours, low-saturation mineral colors, rounded graphic face, simplified almond eyes, cheek patches, two-to-three-step flat color blocks, and simplified fabric/hands. Excluded: chibi, anime, text, logos, props except the explicitly requested bag/coins, photographic portraiture, detailed fingers, cinematic shading, floor or magenta within the subject.

## State prompts and selected outputs

### impatient

- Prompt delta: restrained ordinary waiting impatience, small sideways glance and one relaxed hand lightly holding the opposite wrist; closed mouth, no anger, no worry, no props.
- Imagegen source: `C:\Users\Administrator\.codex\generated_images\019ff456-df6c-7f21-a4a1-9950a7eac04b\exec-e8cf8a28-1e9e-4fad-9f1b-725a02acd3a4.png`.
- Preserved source/key candidates: `res://tmp/imagegen/customer_20_chinese_states_v1/customer_20_impatient_v1_chroma.png` and `customer_20_impatient_v1_keyed.png`.
- Final: `res://resources/art/customers/customer_20/customer_20_impatient_v1_keyclean.png`; alpha bounds `(536,43)-(993,1024)`; Atlas `Rect2(536,43,457,981)`; SHA-256 `6FE014560F12C20089689D0C075F60DAC42E4CAF03D9D773171214D7B248D003`.

### satisfied

- Prompt delta: quiet small closed-mouth satisfied smile after a good breakfast; relaxed arms at the sides, empty hands and no exaggerated expression or props.
- Imagegen source: `C:\Users\Administrator\.codex\generated_images\019ff456-df6c-7f21-a4a1-9950a7eac04b\exec-7065f53b-a246-43a5-aa4e-000683d88648.png`.
- Preserved source/key candidates: `res://tmp/imagegen/customer_20_chinese_states_v1/customer_20_satisfied_v1_chroma.png` and `customer_20_satisfied_v1_keyed.png`.
- Final: `res://resources/art/customers/customer_20/customer_20_satisfied_v1_keyclean.png`; alpha bounds `(506,40)-(1026,1024)`; Atlas `Rect2(506,40,520,984)`; SHA-256 `CB36207C1118EE732D07985120B3A2D7CCA39BB744F7D64A9EF6EC7E93AAEF1E`.

### accepting_bag

- Prompt delta: receiving exactly one plain unmarked kraft breakfast bag with both hands in front of the torso; mild pleased expression; no coins or extra props.
- Imagegen source: `C:\Users\Administrator\.codex\generated_images\019ff456-df6c-7f21-a4a1-9950a7eac04b\exec-2fa70618-819a-4d44-aa54-d8fe3a61734a.png`.
- Preserved source/key candidates: `res://tmp/imagegen/customer_20_chinese_states_v1/customer_20_accepting_bag_v1_chroma.png` and `customer_20_accepting_bag_v1_keyed.png`.
- Final: `res://resources/art/customers/customer_20/customer_20_accepting_bag_v1_keyclean.png`; alpha bounds `(491,38)-(1044,1024)`; Atlas `Rect2(491,38,553,986)`; SHA-256 `03BD3B77CB91BAA27FF824FB65BDBB3B78AFC131ED5BF5AFBE8A86C161E4805B`.

### paying_coins

- Prompt delta: exactly one plain unmarked kraft bag in one relaxed hand and exactly three clearly separated visible copper coins on the open other palm; polite small smile, no extra coin, cash or prop.
- Rejected source retained: `C:\Users\Administrator\.codex\generated_images\019ff456-df6c-7f21-a4a1-9950a7eac04b\exec-c1cab0a9-a9a9-45c1-8c4a-c2085996a4e8.png`; it showed only two coins and is retained in tmp as `customer_20_paying_coins_v1_rejected_two_coins_chroma.png` with its keyed and cleaned products. It is not runtime-integrated.
- Selected retry source: `C:\Users\Administrator\.codex\generated_images\019ff456-df6c-7f21-a4a1-9950a7eac04b\exec-95f6d84e-8802-470f-a953-bd5bc7fd0be6.png`.
- Preserved selected source/key candidates: `res://tmp/imagegen/customer_20_chinese_states_v1/customer_20_paying_coins_v2_chroma.png` and `customer_20_paying_coins_v2_keyed.png`.
- Final: `res://resources/art/customers/customer_20/customer_20_paying_coins_v2_keyclean.png`; alpha bounds `(439,41)-(1038,1024)`; Atlas `Rect2(439,41,599,983)`; SHA-256 `E4F571A8C0BAF690839F438FB8B8834458365178DF113F1F82CD785E94FBD15E`.

## Keying, import and verification

- All raw chroma sources and safe-key candidates are retained under `res://tmp/imagegen/customer_20_chinese_states_v1/`. The selected keyed sources used `remove_chroma_key.py --key-color '#FF00FF' --tolerance 60 --edge-contract 2 --despill`; the retained `cleanup_customer_20_state_keys.py` then clears only saturated magenta at alpha-zero silhouette edges and zeroes transparent RGB. No candidate was overwritten.
- Every selected final is 1536x1024 RGBA, has four transparent corners and preserved complete half-body framing. Godot 4.7.1 import succeeded: the action `.png.import` sidecars resolve to non-empty `CompressedTexture2D` caches.
- Dedicated `AtlasTexture` resources are `customer_20_impatient_cropped.tres`, `customer_20_satisfied_cropped.tres`, `customer_20_accepting_bag_cropped.tres`, and `customer_20_paying_coins_cropped.tres`. `scripts/gameplay/workstation.gd` maps all five established state keys for `customer_20`.
- Automated checks: `FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS` and `P1 vertical-slice self-check PASS`, including 20-identity rotation, customer_20 current-save restore, and preserved pre-expansion ten-customer modulo.
- GPU check: Godot 4.7.1 non-headless Windows/D3D12 12_0 Forward Mobile on NVIDIA GeForce RTX 5070 passed with `CUSTOMER_20_STATES_GPU_PREVIEW_PASS`. The real workstation test asserts every Atlas resource, final PNG and region, then captures five 1920x1080 frames under `res://tmp/validation/customer_20_states_v1_gpu/`.
- Agent visual review: passed for identity/outfit continuity, readable runtime scale, clean edges, restrained impatience, exactly one bag in accepting_bag, and exactly one bag plus three separated coins in paying_coins.
- Human review: confirmed by the user on 2026-08-12 as `确认 customer_20 全套`. This is final visual acceptance for the customer_20 five-state set only; it does not imply approval, status, or work for any other customer.
