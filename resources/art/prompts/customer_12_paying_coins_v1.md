# customer_12 paying_coins v1

- Role: customer_12, a 52-year-old Chinese middle-school teacher stopping by after class.
- State: calmly offers several unmarked brass-colored coins in an open palm.
- Reference: customer_12 neutral, preserving short salt-and-pepper hair, dark rectangular glasses, moss-green corduroy overshirt, warm-grey tee, tea-brown trousers, body and paper-watercolor style.
- Generation: built-in imagegen `identity-preserve`; generated on a flat #FF00FF chroma-key background, copied to `tmp/imagegen/customer_12_chinese_states/customer_12_paying_coins_v1_chroma.png`.
- Alpha processing: automatic soft matte made face pixels translucent, so safe hard-key removal was used instead: `remove_chroma_key.py --auto-key border --tolerance 120 --edge-contract 1 --despill`; verified transparent corners, opaque interior, no visible magenta edge fringe, and visible bounds `(501, 28, 1015, 1024)`.
- Status: generated and runtime-integrated; human review pending.
