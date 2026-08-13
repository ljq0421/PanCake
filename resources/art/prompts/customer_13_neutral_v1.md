# customer_13 neutral v1

- Role: customer_13, a 35-year-old Chinese ride-hailing driver buying breakfast between trips.
- Visual identity: low black ponytail; composed, practical expression; dark jujube-red cropped jacket, smoke-grey high-neck knit top, muted indigo straight-leg trousers. No uniform, platform branding, name badge, vehicle, phone, keys, map, headset, prop, or stereotype.
- Generation: built-in imagegen `stylized-concept`; generated on a flat #FF00FF chroma-key background and copied to `tmp/imagegen/customer_13_chinese_neutral/customer_13_neutral_v1_chroma.png`.
- Art direction: warm rice-paper language; fine ink-brown outline; watercolor-paper texture and dry-brush detail; restrained mineral colour coordinated with the Chinese-themed workstation.
- Alpha processing: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`; output verified RGBA, transparent corners, visible bounds `(495, 33, 1036, 1024)`, and full hair, hands and below-waist anchor.
- Status: neutral generated, runtime-integrated, GPU-verified, and human-confirmed; the other four state portraits now have dedicated generated assets and runtime mappings.
