# customer_16 action states v1

## Authority and shared contract

- Runtime ID: `customer_16`
- User-approved authority: `resources/art/customers/customer_16/customer_16_neutral_v2_keyclean.png`
- Preserve the approved 19-year-old Chinese technical-college student identity, short black hair, rounded graphic face, circular cheek patches, muted sage-green jacket, clay-red shirt, deep indigo trousers, warm rice-paper texture, ink-brown contours, low-saturation mineral palette, moderate cartoon level, 1536x1024 canvas and bottom anchor.
- Change only expression, arm/hand gesture and the explicitly required bag/coins.
- All selected sources use a flat bright-magenta background and keep complete hair, elbows, hands and below-waist framing.

## impatient v2

- Prompt: mild waiting impatience rather than worry or anger; almost-flat mouth with a tiny asymmetric downturn, one subtly raised eyebrow, eyes glancing slightly aside, both empty hands loosely clasped at lower waist.
- Hard exclusions: worried peaked inner eyebrows, pleading eyes, sorrow, scowl, clenched jaw/fists, crossed arms, watch, phone, bag or coins.
- Rejected first source: `tmp/imagegen/customer_16_chinese_states/customer_16_impatient_v1_rejected_worried_chroma.png`; retained because its brows and mouth read as worried/sad.
- Selected built-in source: `C:\Users\Administrator\.codex\generated_images\019ff3d7-4807-78a1-bc70-bb60e103a0c8\exec-5910a99d-ce57-4408-b8d0-1147aa6cecb1.png`.
- Preserved chroma source: `tmp/imagegen/customer_16_chinese_states/customer_16_impatient_v2_chroma.png`.
- Final: `resources/art/customers/customer_16/customer_16_impatient_v2.png`; region `Rect2(507,19,512,1005)`; SHA-256 `A4C106BB9A0CC96D89EDED93878889E783B61117D4B090126F03FEFECF717259`.

## satisfied v1

- Prompt: quietly pleased after breakfast; relaxed shoulders, softly smiling eyes, restrained closed-mouth smile, both empty hands loosely clasped at lower waist; no food or props.
- Selected built-in source: `C:\Users\Administrator\.codex\generated_images\019ff3d7-4807-78a1-bc70-bb60e103a0c8\exec-2f032b05-49f3-4884-a762-b1264c3254ed.png`.
- Preserved chroma source: `tmp/imagegen/customer_16_chinese_states/customer_16_satisfied_v1_chroma.png`.
- Final: `resources/art/customers/customer_16/customer_16_satisfied_v1.png`; region `Rect2(506,20,521,1004)`; SHA-256 `623A3E805A24AF95ADC65C7F96D3C9B23643BE5CDD034259ABEDF5121124ADF6`.

## accepting_bag v1

- Prompt: pleasantly attentive and modestly grateful, accepting exactly one small plain unbranded closed warm-kraft breakfast paper bag with both hands at mid-torso; zero coins and no visible food.
- Selected built-in source: `C:\Users\Administrator\.codex\generated_images\019ff3d7-4807-78a1-bc70-bb60e103a0c8\exec-c47059ff-66ff-4d7e-bc99-40dfd1a4a48b.png`.
- Preserved chroma source: `tmp/imagegen/customer_16_chinese_states/customer_16_accepting_bag_v1_chroma.png`.
- Final: `resources/art/customers/customer_16/customer_16_accepting_bag_v1.png`; region `Rect2(502,19,531,1005)`; SHA-256 `BFA3EAF6E89A3D8CB81F37076D92AC3D2E0D52553D089626A241966144A73770`.

## paying_coins v1

- Prompt: calmly focused and polite, exactly one plain closed kraft bag held under one forearm, with the other open palm displaying exactly three separate, non-overlapping, countable warm-gold coins; no banknotes or symbols.
- Selected built-in source: `C:\Users\Administrator\.codex\generated_images\019ff3d7-4807-78a1-bc70-bb60e103a0c8\exec-11ba7ddd-5441-4007-b069-48605a710ae9.png`.
- Preserved chroma source: `tmp/imagegen/customer_16_chinese_states/customer_16_paying_coins_v1_chroma.png`.
- Final: `resources/art/customers/customer_16/customer_16_paying_coins_v1.png`; region `Rect2(410,20,642,1004)`; SHA-256 `5B41207852FF190BC1BFE73BB4A72DD82B58B219BC0456F1520DD275720BC4FB`.

## Processing and validation

- Generator: Codex built-in image generation through the imagegen skill; one separate call per state plus the retained impatient retry.
- The generator backgrounds drifted slightly from requested `#FF00FF`. Each unmodified source and default safe auto-key output is retained. A separate audit source changes only already-classified connected background pixels to exact `#FF00FF`.
- Final key removal: installed `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` from each exact-`#FF00FF` audit source.
- Alpha validation: all four finals are 1536x1024 RGBA with four transparent corners, nonempty complete bounds and zero visible magenta-like pixels at alpha >= 16; central clay-red shirt pixels remain fully opaque.
- Godot import: passed with Godot 4.7.1; every `.png.import` sidecar resolves to a non-empty `CompressedTexture2D` cache (impatient 377,414 bytes; satisfied 376,204 bytes; accepting_bag 387,248 bytes; paying_coins 430,038 bytes).
- Runtime: the four `customer_16_*_cropped.tres` resources resolve the four selected PNGs and the exact regions listed above; `scripts/gameplay/workstation.gd` continues to route the established five state keys.
- Automated rotation/save checks: `FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS` and `P1 vertical-slice self-check PASS`; both current pools contain 16 identities, current snapshots preserve `customer_16`, and legacy snapshots retain the ten-customer modulo.
- Non-headless GPU check: Godot 4.7.1 on Windows, D3D12 12_0 Forward Mobile, NVIDIA GeForce RTX 5070; marker `CUSTOMER_16_STATES_GPU_PREVIEW_PASS`; all five runtime Atlas paths, source PNGs and regions were asserted in the real workstation scene.
- GPU screenshots: `res://tmp/validation/customer_16_states_v1_gpu/customer_16_neutral_v1_1920x1080.png`, `customer_16_impatient_v1_1920x1080.png`, `customer_16_satisfied_v1_1920x1080.png`, `customer_16_accepting_bag_v1_1920x1080.png`, and `customer_16_paying_coins_v1_1920x1080.png`.
- Agent visual review: passed for identity/outfit continuity, moderate cartoon treatment, state legibility, transparent edges, one bag in accepting, and one bag plus exactly three separated coins in paying.
- Human review: pending; automated, GPU and agent checks do not constitute final user acceptance.
