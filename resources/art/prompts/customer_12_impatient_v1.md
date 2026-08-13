# customer_12 impatient v1

- Role: customer_12, a 52-year-old Chinese middle-school teacher stopping by after class.
- State: mildly impatient waiting; he glances at his wrist, with a restrained tense expression.
- Reference: customer_12 neutral, preserving short salt-and-pepper hair, dark rectangular glasses, moss-green corduroy overshirt, warm-grey tee, tea-brown trousers, body and paper-watercolor style.
- Generation: built-in imagegen `identity-preserve`; generated on a flat #FF00FF chroma-key background, copied to `tmp/imagegen/customer_12_chinese_states/customer_12_impatient_v1_chroma.png`.
- Alpha processing: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`; verified transparent corners and visible bounds `(473, 23, 1071, 1024)`.
- Status: generated and runtime-integrated; human review pending.
