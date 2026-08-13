# customer_06_neutral_v4_chinese

## Scope

- Customer: `customer_06` only
- State: `neutral` only
- Generator: Codex built-in `image_gen`
- Identity authority: `customer_06_neutral_v1.png`
- Quality reference: approved `customer_02_neutral_v4_chinese.png`
- Workstation style reference: `workstation_18_single_row_1920x1080_v8_chinese.png`

## Final generation prompt

```text
Use case: identity-preserve
Asset type: ProjectCake customer_06 neutral half-body gameplay Sprite2D redraw, production candidate.

Image 1 is the sole identity, pose, clothing, age, skin-tone, body-proportion, canvas-framing, crop, and anchor authority for customer_06. Preserve this exact elderly Chinese man: lean build, long softly rectangular face, warm light-medium skin, prominent rounded nose, dark attentive eyes, thick silver-gray eyebrows, subtle age lines, no facial hair or glasses, high receding hairline with short silver-gray hair combed back and fuller at the sides. Preserve the exact frontal relaxed pose, both complete arms and hands, and the same clothing structure and base palette: faded powder-blue short-sleeve collared shirt, warm mustard-ochre sleeveless V-neck vest, muted dark brick-red/brown lower garment. Do not reinterpret his identity, age, skin tone, outfit design, or base garment colors.

Image 2 is a quality benchmark only for the approved Chinese-style repaint: warm rice-paper watercolor feel, fine ink-brown outlines, dry-brush/paper texture, restrained mineral colors, clean readable face and silhouette. Do not copy this woman's identity, body, hair, clothing, pose, or palette.

Image 3 is the actual workstation visual-style reference: warm Chinese street-stall atmosphere, rice-paper ground, ink-brown linework, watercolor paper texture, dry-brush edges, coordinated mineral pigments. Do not include any workstation/background elements in the sprite.

Redraw only customer_06's neutral state in the established Chinese visual language while preserving Image 1's character contract. He must remain clearly the same elderly man in exactly the same neutral standing presentation and outfit. Apply subtle rice-paper watercolor texture and controlled dry-brush variation across the character, with fine but readable ink-brown contour lines and coordinated mineral pigments. Texture must be gentle and intentional, not noisy or photorealistic. Keep the neutral expression calm and attentive with a restrained closed-mouth friendly smile.

Create one centered complete half-body character on a broad landscape canvas. Match Image 1's placement and visible bounds as closely as possible: preserve the full hair silhouette, both ears, both shoulders, both forearms, both complete hands/fingers, and the entire waist/lower edge. Target subject boundary exactly x=529..998 and y=56..973 on a 1535x1024 final canvas, corresponding to the existing Atlas crop Rect2(529,56,470,918) and the existing bottom-center/counter anchor. Do not crop, narrow, widen, lengthen, shorten, or independently resize any body part.

Render on a perfectly uniform flat solid bright magenta #FF00FF chroma-key background reaching every edge and corner. No gradient, texture, halo, lighting variation, vignette, floor, cast shadow, contact shadow, or reflection. Do not use #FF00FF or any near-magenta pink/purple in the person, clothing, highlights, outlines, or paper texture. Keep all red/brick garment colors visually far from magenta: muted earthy brick red/brown only.

Exactly one elderly man, two arms, two hands. Preserve Image 1's identity, facial structure, age, warm light-medium skin tone, hairstyle, clothing design, garment base colors, pose, anatomy, canvas contract, crop, and anchor. Change only the rendering language to the approved Chinese rice-paper watercolor/ink style. No bag, coins, food, counter, workstation, griddle, order card, patience bar, UI, speech bubble, props, accessories, text, numbers, logo, watermark, symbols, extra limbs, hidden hands, malformed fingers, or shadows. Neutral state only; no impatience, exaggerated joy, action pose, payment, or receiving gesture.
```

## Processing record

- Chroma source: `tmp/imagegen/customer_06_chinese_redraw/customer_06_neutral_v4_chinese_chromakey.png`
- Raw alpha: `tmp/imagegen/customer_06_chinese_redraw/customer_06_neutral_v4_chinese_alpha_raw.png`
- Key removal: `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`
- Sampled key: `#FA05F4` from the generated bright-magenta border
- Deterministic geometry normalization: uniformly scaled the complete alpha subject by `0.9357798165` with premultiplied-alpha resampling, without recoloring or redrawing, then bottom-aligned it inside the unchanged atlas region `Rect2(529,56,470,918)` on the unchanged `1535x1024` canvas. Cleared only resampling pixels with alpha `<= 1/255`; this removed invisible key-color interpolation without any color-based deletion, preserving the brick-red/brown garment.
- Final alpha bounds: `(536,56)-(991,974)`, fully contained by the legacy Atlas region.
- Final file: `res://resources/art/customers/customer_06/customer_06_neutral_v4_chinese.png`
