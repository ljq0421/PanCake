# customer_09_neutral_v4_chinese

## Scope and audited contract

- Neutral state only. No impatient, satisfied, accepting_bag, or paying_coins state was generated in this phase.
- Image 1 was the sole identity and geometry authority: `customer_09_neutral_v3_chinese_colorful.png`.
- The legacy canvas and Atlas contract are unchanged: `1536x1024`, alpha bounds `(540,75)-(979,959)`, and `Rect2(540,75,439,884)`.
- Identity lock: adult woman, approximately 30-40 years old; deep warm brown skin; softly heart-shaped adult face; broad nose; dark eyes; blue-black off-center-parted hair with one long side braid; coral-orange mandarin-collar diagonal-wrap blouse; deep indigo lower garment.
- Style references: the human-approved `customer_02_neutral_v4_chinese.png`, `start_menu_background_morning_mobile_cart_v3_chinese.png`, and `workstation_18_single_row_1920x1080_v8_chinese.png`.

## Generation

- Generator: Codex built-in `image_gen` through the imagegen skill.
- Chroma key: flat bright magenta `#FF00FF`; the generated border sampled as `#FA04F4`.
- Generated source: `C:\Users\Administrator\.codex\generated_images\019feeac-b190-74d3-8a31-e8657a1020d9\exec-6c45b815-1b3b-40c1-98e5-3177df498699.png`.
- Workspace chroma source: `res://tmp/imagegen/customer_09_neutral_v4/customer_09_neutral_v4_chinese_chromakey.png`.

## Complete prompt

```text
Use case: style-transfer
Asset type: ProjectCake customer_09 neutral half-body gameplay Sprite2D, Chinese-style redraw on removable chroma-key background.

Input images:
- Image 1 is the exact edit target and the sole authority for customer_09 identity, face, age, skin tone, hairstyle, braid, clothing design, pose, silhouette, body proportions, 1536x1024 landscape canvas placement, crop, and anchor. Preserve the character completely; change only rendering style and palette refinement.
- Image 2 is the already human-approved customer_02 v4 quality reference only: use its warm rice-paper watercolor feel, restrained dry-brush variation, fine dark-brown ink lines, and readable mineral pigments. Do not copy its identity, face, hair, clothing, body shape, or colors.
- Images 3 and 4 are the approved Chinese-style start-page and workstation references only: match their warm xuan/rice-paper base feel, delicate ink-brown contours, watercolor paper grain, dry-brush edges, and coordinated mineral color harmony. Do not add any scenery, counter, architecture, UI, shadows, or objects.

Primary request:
Redraw only customer_09 neutral as the same friendly adult woman, approximately 30-40 years old, with deep warm brown skin, softly heart-shaped adult face, defined jaw, high cheekbones, broad nose, dark brown attentive eyes, gently arched black brows, restrained closed-mouth neutral smile, blue-black off-center-parted hair tucked behind both visible ears, and one long thick three-section side braid over one shoulder. Preserve exactly the coral-orange short-sleeve mandarin-collar diagonal-wrap blouse and deep indigo lower garment.

Style/medium:
Chinese-inspired hand-painted 2D game illustration matching Images 2-4: warm rice-paper/xuan-paper undertone within the painted subject, fine confident ink-brown outlines (not black, not chunky), translucent watercolor washes, restrained dry-brush texture, subtle irregular pigment pooling, and coordinated mineral pigments. Keep the silhouette clean and readable at gameplay size. Use warm coral/cinnabar orange for the blouse, deep mineral indigo for the lower garment, blue-black hair, and the exact deep warm brown skin identity. Texture should be organic and varied, not an evenly tiled digital paper overlay. Keep facial features crisp and adult.

Composition and geometry invariants:
Preserve Image 1's exact 1536x1024 landscape canvas, centered half-body framing, silhouette size, pose, body proportions, and anchor. All hair, crown, full braid tip, both ears, shoulders, upper arms, complete forearms, both relaxed open hands and fingertips, and the complete finished lower garment edge must remain fully visible and detached from every edge. Preserve the visible bounds as closely as possible: left x=540, top y=75, right x=979, bottom y=959. Do not crop, extend to full body, add legs, resize the head, or change the bottom hem.

Neutral-state invariants:
Relaxed brows, open attentive forward gaze, calm restrained closed-mouth smile, symmetrical relaxed stance. No impatience, anger, laughter, wink, surprise, blush, dramatic gesture, or comic expression.

Chroma-key backdrop:
Perfectly flat solid #FF00FF bright magenta background edge to edge, including all corners. One uniform key color only: no shadows, gradient, paper texture, vignette, floor plane, halo, glow, reflection, lighting variation, cast shadow, or contact shadow on the background. Do not use #FF00FF, hot pink, fuchsia, purple-magenta, or neon pink anywhere inside the character. The coral-orange/red blouse must remain clearly warm orange-red/cinnabar and must not shift toward magenta, so safe chroma removal cannot damage it.

Absolute constraints:
One customer only. Exactly two arms and two hands. No extra fingers or limbs. No identity drift, age drift, skin-tone drift, hairstyle drift, clothing redesign, accessory, jewelry, glasses, hat, apron, pattern, logo, text, letters, numbers, prop, food, money, bag, UI, order card, patience bar, counter, workstation, background scenery, watermark, shadow, reflection, or transparent holes inside the painted character.

Output intent:
One opaque #FF00FF chroma-key source for safe local background removal, then transparent customer_09 neutral Sprite2D integration while preserving the legacy Atlas crop and bottom-center anchor exactly.
```

## Processing and validation

```text
remove_chroma_key.py
  --auto-key border
  --soft-matte
  --transparent-threshold 12
  --opaque-threshold 220
  --despill
```

- Raw alpha result retained at `res://tmp/imagegen/customer_09_neutral_v4/customer_09_neutral_v4_chinese_raw_alpha.png`.
- Deterministic geometry normalization resized only the extracted complete subject into the exact legacy alpha bounds `(540,75)-(979,959)` on the unchanged `1536x1024` canvas.
- One residual key-color pixel at `(563,465)` with alpha `1` was made fully transparent; no subject-colored pixel was removed.
- Final alpha checks: four transparent corners; zero nontransparent canvas-edge pixels; zero magenta-like residual pixels; 12,172 partially transparent antialias pixels.
- Final SHA-256: `EBA5BC7744E7873CF20557E0AC3BC0FFD2CC04098F7C0D921E929399BD39F448`.
- Godot import, runtime integration, GPU preview, and human review are recorded separately in `ASSET_MANIFEST.md`.
