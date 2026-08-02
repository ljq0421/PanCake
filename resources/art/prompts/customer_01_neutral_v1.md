# customer_01_neutral_v1

## 生成提示词

```text
Use case: identity-preserve
Asset type: ProjectCake P1 customer half-body gameplay sprite, magenta chroma-key source for transparent PNG
Input images: Image 1 is the approved V8 composition; use only its centered customer as the identity, proportions, clothing, camera-angle and style reference, not the workstation or UI
Primary request: redraw the same young male customer as one isolated clear half-body character from complete hair to just below the waist. Preserve his short tousled dark-brown hair, friendly rounded face, warm skin, dark eyes, small neutral-friendly smile, muted olive-green T-shirt and dark blue pants waistband. Both shoulders, upper arms, forearms and relaxed hands must be fully visible; arms hang naturally near his sides. Keep the straight frontal pose and slightly elevated fixed gameplay viewpoint from Image 1.
Framing: centered character, complete hairstyle and every hair tip inside the canvas, at least 90 pixels of clear background above the highest hair point, generous side padding around both elbows and hands, no crop through head, hair, hands or shoulders; clean waist-level lower termination suitable for standing behind the service counter.
Style/medium: exact V8 simple 2D cartoon language—bold clean deep-brown outlines, large flat color blocks, base plus at most one shadow and one highlight, minimal fabric and hair texture, crisp readable silhouette.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background for local removal. Background must be one uniform color with no shadows, gradients, texture, reflections, floor plane or lighting variation.
Constraints: one customer only; no counter, workstation, order card, patience bar, payment tray, money, props, food, cast shadow, contact shadow or reflection; do not use #ff00ff in the character; no text, letters, numbers, logo, brand or watermark; no photorealism, anime rendering, glossy 3D, thin outlines, painterly detail, extra limbs or cropped hair.
```

## 透明处理

人物绿色上衣与绿幕冲突，因此使用品红背景。使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill`，未使用 CLI 真透明生成。

