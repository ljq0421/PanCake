# customer_13 impatient v1

- Role: customer_13, the approved 35-year-old Chinese ride-hailing driver identity.
- State prompt: restrained impatience with a small serious frown and subtly knit brows; one hand rests against the other wrist as if checking time, without a watch or prop.
- Identity lock: preserve the low black ponytail, softly angular face, dark jujube-red cropped jacket, smoke-grey high-neck knit, muted indigo trousers, proportions, scale, palette, and established ProjectCake paper-watercolor style from the approved neutral reference.
- Generation: built-in imagegen `identity-preserve`; the approved neutral and prior generated state were used as references. The generated flat-#FF00FF source was copied to `tmp/imagegen/customer_13_chinese_states/customer_13_impatient_v1_chroma.png`.
- Alpha processing: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`; verified RGBA, transparent corners, no visible magenta, and visible bounds `(473, 33, 1031, 1024)`.
- Final source: `resources/art/customers/customer_13/customer_13_impatient_v1.png`; crop: `Rect2(473, 33, 558, 991)`.
- Status: generated and runtime-integrated; automated checks and Godot 4.7.1 non-headless GPU verification passed; human review pending.
