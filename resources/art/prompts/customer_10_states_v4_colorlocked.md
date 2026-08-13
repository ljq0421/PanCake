# customer_10_states_v4_colorlocked

- Generator: Codex built-in `image_gen` through the imagegen skill
- Generated: 2026-08-11 (Asia/Shanghai)
- Use case: four independent `identity-preserve` state generations
- Sole identity, clothing, age, skin-tone, base-palette, and Chinese-style authority: `res://resources/art/customers/customer_10/customer_10_neutral_v4_chinese.png`
- Pose/action references only: the matching `customer_10_*_v1.png` files
- Quality/readability references only: the matching accepted `customer_02_*_v4_colorlocked.png` files
- Processing script: `tmp/imagegen/customer_10_states_v4/process_customer_10_states_v4.py`
- Headless import log: `tmp/validation/customer_10_states_v4_colorlocked_gpu/godot-headless-import-20260811-113037211.log`
- Real GPU log: `tmp/validation/customer_10_states_v4_colorlocked_gpu/godot-gpu-states-20260811-113105165.log`

## Shared generation contract

```text
Use the confirmed customer_10 neutral v4 as the sole authority for identity, age, warm olive skin, bald crown and side stubble, separated mustache and rounded goatee, broad proportions, deep muted burgundy camp-collar overshirt, cream undershirt, warm khaki lower garment, fine ink-brown contours, warm rice-paper watercolor texture, dry-brush finish, and coordinated mineral palette. Preserve those traits exactly. The old customer_10 state image supplies only the requested expression/action and legacy framing. The accepted customer_02 v4 state supplies only polish and action readability; never copy its person, face, clothes, colors, or proportions.

Output exactly one complete half-body person on a uniform bright-magenta #FF00FF background reaching every edge and corner. Keep the entire scalp, ears, shoulders, arms, complete hands/fingers, props, and lower edge inside the 1536 x 1024 canvas. No scenery, counter, UI, text, logo, watermark, cast shadow, extra person, extra limb, malformed hand, unrelated prop, or fluorescent magenta on the subject.
```

## State-specific contracts

- `impatient`: change only to restrained waiting impatience through slightly lowered eyelids/brows and a controlled mouth; do not make him angry. Keep the neutral relaxed arm position; no bag or coins.
- `satisfied`: change only to a gentle pleased closed-eye smile; keep the neutral relaxed arm position; no bag or coins.
- `accepting_bag`: pleased receiving expression; both complete hands hold exactly one upright filled paper bag centered against the torso; exactly one bag and no coins.
- `paying_coins`: pleased polite expression; exactly one filled paper bag tucked under his left arm (viewer-right), while his right open palm (viewer-left) presents exactly three clearly separated gold coins; exactly one bag and three coins.

The first `accepting_bag` generation was rejected because the lower garment was cropped. A targeted imagegen scale/position correction preserved its identity, palette, action, and style while fitting the full lower edge inside the canvas.

## Sources and finals

| State | Exact-key source | Final RGBA | SHA-256 | Legacy Atlas region |
|---|---|---|---|---|
| `impatient` | `tmp/imagegen/customer_10_states_v4/customer_10_impatient_v4_colorlocked_key_ff00ff.png` | `res://resources/art/customers/customer_10/customer_10_impatient_v4_colorlocked.png` | `BE3B2371C4C53961379FBC012A87B72BAC71198B872B4305B6E312E7D19D0F66` | `Rect2(507,83,511,876)` |
| `satisfied` | `tmp/imagegen/customer_10_states_v4/customer_10_satisfied_v4_colorlocked_key_ff00ff.png` | `res://resources/art/customers/customer_10/customer_10_satisfied_v4_colorlocked.png` | `CED010BFE125B06E5DA0D1D95A17B29EF0FE3685C07709B18FC1C49E0DA8D9B4` | `Rect2(507,83,511,876)` |
| `accepting_bag` | `tmp/imagegen/customer_10_states_v4/customer_10_accepting_bag_v4_colorlocked_key_ff00ff.png` | `res://resources/art/customers/customer_10/customer_10_accepting_bag_v4_colorlocked.png` | `071C3AB4A3F75C9FF10F1B3704FB106C776CCD0A3812D8C7A900DCD4C86616A1` | `Rect2(529,88,469,799)` |
| `paying_coins` | `tmp/imagegen/customer_10_states_v4/customer_10_paying_coins_v4_colorlocked_key_ff00ff.png` | `res://resources/art/customers/customer_10/customer_10_paying_coins_v4_colorlocked.png` | `95F17ABA22EB0A70A77A7D28DD6CD43B1DEF8F43117A39CFA4FE7C2B0F6B0FFA` | `Rect2(447,87,590,845)` |

## Deterministic processing and validation

1. Only the border-connected high-magenta field (`R >= 180`, `B >= 180`, `G <= 90`, `abs(R-B) <= 55`) was normalized to exact `#FF00FF`; this blue-channel gate excludes the burgundy clothing.
2. The imagegen skill helper removed the key with `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`.
3. Each complete alpha subject was deterministically fitted to its unchanged legacy Atlas region on the original 1536 x 1024 canvas.
4. Only pixels deterministically classified as burgundy shirt or lower khaki garment were normalized in HSV to the confirmed neutral v4 median palette. All four final shirt and lower-garment median deltas are below 0.0012, inside the 0.006 validation limit.
5. Every final has the exact expected alpha bounds, transparent corners, zero nontransparent magenta-like pixels, and zero identified burgundy pixels made transparent by key removal.
6. Godot 4.7.1 imported all four PNGs and created alpha-preserving `CompressedTexture2D` caches. The real `main.tscn` workstation path loaded every state through its actual AtlasTexture and captured a 1920 x 1080 frame on Windows, D3D12 Forward Mobile, NVIDIA GeForce RTX 5070.

Human review of the four new action/expression states remains pending. GPU/runtime validation does not constitute human visual acceptance.
