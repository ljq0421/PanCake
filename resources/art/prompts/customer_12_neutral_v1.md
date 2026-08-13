# customer_12 neutral v1

## Character

- Intended runtime ID: `customer_12`
- State: `neutral` only
- Identity: 52-year-old Chinese middle-school teacher, stopping by after class
- Personality: gentle, thoughtful, approachable
- Visual markers: short salt-and-pepper hair, thin dark rectangular glasses, muted moss-green corduroy overshirt, warm gray T-shirt, tea-brown trousers
- Direction: contemporary Chinese daily life without a uniform, badge, historical costume, regional shorthand, or brand

## Generation and processing

- Generator: Codex built-in image generation
- Source: `C:\Users\Administrator\.codex\generated_images\019feece-75c3-7893-b5b5-85e359d9ca1c\exec-9455b79d-2eac-4e11-bc7b-0c5134388364.png`
- Preserved chroma source: `tmp/imagegen/customer_12_chinese_neutral/customer_12_neutral_v1_chroma.png`
- References: customer_11 rendering language only; Chinese start-menu and workstation material/palette references
- Key removal: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`
- Final canvas: 1536x1024 RGBA; transparent corners 4/4
- Alpha bounds: `(474,26)` to `(1050,1023)`; AtlasTexture region: `Rect2(474,26,577,998)`
- Runtime status: neutral-only integration; remaining four visual states deliberately fall back to neutral pending human approval
- Human review: pending
