# customer_18 action states v1

## Authority and shared contract

- Runtime ID: `customer_18`
- User-approved authority: `resources/art/customers/customer_18/customer_18_neutral_v1_keyclean.png`
- Preserve exactly: the 44-year-old Chinese community arts-center guitar teacher; slightly stocky build; salt-and-pepper side-parted hair; deep-brown rounded glasses; rust-brown cardigan; smoky-teal T-shirt; slate-gray trousers; rounded graphic face; ink-brown lines; rice-paper texture; restrained two-to-three-step mineral palette; 1536x1024 framing and bottom anchor.
- Change only expression, arms/hands and the requested bag/coins. All outputs have a flat bright-magenta key background, complete hair/elbows/hands and below-waist framing.

## impatient v1

- Prompt: mild waiting impatience only — sideways glance, one subtly raised eyebrow, nearly flat mouth with a tiny asymmetric downturn, both empty hands loosely clasped at the lower waist; still warm and composed, never sad, worried or angry.
- Source: `C:\Users\Administrator\.codex\generated_images\019ff455-1077-71d1-a992-a8bac20971a7\exec-d6c593e0-1dd1-48b8-998a-70c277052cd1.png`.
- Preserved chroma source: `tmp/imagegen/customer_18_chinese_states/customer_18_impatient_v1_chroma.png`; SHA-256 `11D37B8B6C66E0EFCDDE5C7392C0BA1F96179E17E022EFA2571E81F1BD44D499`.
- Final: `resources/art/customers/customer_18/customer_18_impatient_v1.png`; `Rect2(492,25,546,999)`; SHA-256 `4B889189570821E1B73985474F384AE4B4C40C0BFEF3365B39C072035DBC572B`.

## satisfied v1

- Prompt: quiet satisfaction after breakfast — relaxed shoulders, softly smiling eyes behind the same glasses, restrained warm closed-mouth smile and both empty hands loosely clasped at lower waist; no food or props.
- Source: `C:\Users\Administrator\.codex\generated_images\019ff455-1077-71d1-a992-a8bac20971a7\exec-e229659d-0392-4e02-aba7-937eba2d1f45.png`.
- Preserved chroma source: `tmp/imagegen/customer_18_chinese_states/customer_18_satisfied_v1_chroma.png`; SHA-256 `5D26B17A4E88649785E62F2EB0001F1F8EC28A6FD93E9DE8958697025B238D8D`.
- Final: `resources/art/customers/customer_18/customer_18_satisfied_v1.png`; `Rect2(493,25,542,999)`; SHA-256 `2C23C22429466DD8DE6F50EFB0163815744E5D985DB4E83DFE368BE9673B92EC`.

## accepting_bag v1

- Prompt: pleasantly attentive and modestly grateful, receiving exactly one small unbranded closed warm-kraft breakfast paper bag with both hands at mid-torso; no coins, no visible food, no second bag or extra props.
- Source: `C:\Users\Administrator\.codex\generated_images\019ff455-1077-71d1-a992-a8bac20971a7\exec-7cc1968d-21ad-4bf6-bc1c-97ec34ac8f99.png`.
- Preserved chroma source: `tmp/imagegen/customer_18_chinese_states/customer_18_accepting_bag_v1_chroma.png`; SHA-256 `30B0F139B8035DC33D483B0305244993289CD0CD4B672691A7A3485CCA21F8F0`.
- Final: `resources/art/customers/customer_18/customer_18_accepting_bag_v1.png`; `Rect2(487,28,563,996)`; SHA-256 `CCDB8FFB8F535FA4F9259C10B77CE1042642607E826D4D822B37454CEFE65144`.

## paying_coins v1

- Prompt: calmly focused and polite, exactly one unbranded closed kraft bag tucked under the subject's left forearm (viewer-right), one open right palm (viewer-left) displaying exactly three separated, non-overlapping, countable warm-gold coins; no fourth coin, banknote, card or food.
- Source: `C:\Users\Administrator\.codex\generated_images\019ff455-1077-71d1-a992-a8bac20971a7\exec-60b4c368-b2b4-4bfc-b278-10d495a7528f.png`.
- Preserved chroma source: `tmp/imagegen/customer_18_chinese_states/customer_18_paying_coins_v1_chroma.png`; SHA-256 `250D835468B4BF39F029EC134014643E6B250A4DDB1995A9D5CA51ABB190B08F`.
- Final: `resources/art/customers/customer_18/customer_18_paying_coins_v1.png`; `Rect2(416,26,677,998)`; SHA-256 `5795DD4CEC230B870DED28583EF1067BDCA8A67CECD175D78EF5374205F69884`.

## Processing and validation

- Generator: one Codex built-in imagegen identity-preserving generation per state, always using the user-approved neutral as the only input image.
- Processing: each original source is retained. A separate `*_chroma_exact_ff00ff.png` audit source normalizes only magenta-like generated background pixels (`R>=160`, `B>=150`, `G<=130`, `R+B>=330`) to exact `#FF00FF`; installed `remove_chroma_key.py --key-color '#FF00FF' --tolerance 0 --despill` then creates the selected `*_keyclean.png` audit candidate.
- Alpha result: all four selected finals are 1536x1024 RGBA, four corners transparent, non-empty complete alpha bounds, and have zero visible magenta-like pixels under the processing predicate.
- Godot import: passed with Godot 4.7.1; each `.png.import` resolves to a non-empty `CompressedTexture2D` cache: impatient 469,606 bytes; satisfied 486,276 bytes; accepting_bag 484,716 bytes; paying_coins 493,676 bytes.
- Runtime and automated checks: the four `customer_18_*_cropped.tres` resources resolve their selected action PNGs and exact regions. `CUSTOMER_18_PORTRAIT_CONTRACT_SELF_CHECK_PASS`, `FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS`, and `P1 vertical-slice self-check PASS` passed. The current shared pool contains 20 identities, explicitly preserves customer_18, while pre-expansion snapshots retain the original ten-customer modulo.
- Non-headless GPU check: Godot 4.7.1 / Windows / D3D12 12_0 / Forward Mobile / NVIDIA GeForce RTX 5070 passed with `CUSTOMER_18_STATES_GPU_PREVIEW_PASS`; all five runtime Atlas paths, PNGs and crop regions were asserted in the real workstation and captured at 1920x1080.
- GPU screenshots: `tmp/validation/customer_18_states_v1_gpu/`; a five-state contact sheet is `customer_18_states_v1_gpu_contact_sheet.png`.
- Agent visual review: passed for identity/outfit continuity, readable state separation, actual-workstation-scale silhouette, clean edges, exactly one bag in accepting_bag, and one bag plus exactly three separated coins in paying_coins.
- Human review: confirmed by the user on 2026-08-12 as `确认 customer_18 全套`. This is final visual acceptance for the customer_18 five-state set only; it does not imply approval, status, or work for any other customer.
