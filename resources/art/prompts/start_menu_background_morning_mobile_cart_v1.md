# 清晨移动摊车开始页背景 v1

- 生成日期：2026-08-03（Asia/Shanghai）
- 生成器：Codex 内置 `image_gen`
- 用途：与初始营业场景统一的清晨移动煎饼车开始页背景
- 编辑目标：`res://resources/art/ui/start_menu/start_menu_background_v1.png`
- 色板参考：`res://resources/art/workstation/background/workstation_backplate_morning_mobile_cart_v1.png`
- 初次内置生成源：`C:/Users/Administrator/.codex/generated_images/019fc542-4d9c-7fa1-b4f3-a688a98cb786/exec-48baf908-b8d5-4060-ab13-77b111f8abda.png`
- 初次工程内生成源：`tmp/imagegen/start_menu_morning_mobile_cart_v1/start_menu_background_morning_mobile_cart_v1_builtin_source.png`
- 去除日式元素后的内置生成源：`C:/Users/Administrator/.codex/generated_images/019fc542-4d9c-7fa1-b4f3-a688a98cb786/exec-77153409-8627-46b2-afbf-cd62c21b1505.png`
- 去除日式元素后的工程内生成源：`tmp/imagegen/start_menu_morning_mobile_cart_v1/start_menu_background_morning_mobile_cart_v1_corrected_builtin_source.png`
- 正式文件：`res://resources/art/ui/start_menu/start_menu_background_morning_mobile_cart_v1.png`

## 初次编辑提示词

```text
Use case: lighting-weather plus precise-object-edit.
Asset type: ProjectCake 16:9 PC start-menu background for the initial small mobile Chinese jianbing breakfast cart.
Input images: Image 1 is the exact start-menu edit target and strict composition/layout authority. Image 2 is the approved early-morning mobile-cart palette, lighting, enamel materials, and world-state reference.
Primary request: bring Image 1 into the same clear 7:00 AM mobile-breakfast-cart visual direction as Image 2, removing the global amber/evening cast while preserving the title-screen composition and left-side UI safety.
Scene/backdrop: an outdoor early-morning street corner with pale blue-gray daylight and a quiet, clean street/sidewalk backdrop. Keep the LEFT 38% as calm, low-detail negative space for the existing Godot menu panel. The workstation remains concentrated center-right.
Cart semantics: the workstation should read as the same modest movable cart as Image 2, with warm-ivory enamel, faded desaturated teal panels, restrained brick-red trim, lightweight canopy/frame supports, and practical portable fixtures. Reduce permanent-shop cues: no heavy indoor tiled-wall ambience, no glowing fixed brass wall lamps, no mature decorated storefront. A small lucky cat and one small plant may remain as portable personal touches, but simplify the shelves and decor.
Lighting/mood: clean cool ambient morning daylight from upper left; soft low-contrast blue-gray shadows; lamps switched off or barely reflective. Welcoming breakfast energy, not cold or sterile. Warmth is limited to a few small food-service accents and muted trim. No golden hour, sunset, yellow fog, orange wash, or nighttime glow.
Color palette: pale blue-gray and cool ivory dominant, faded teal, charcoal metal, muted brick-red accents, deep-brown outlines. Match Image 2 closely.
Style/medium: preserve Image 1's exact polished hand-drawn flat 2D cartoon style, bold deep-brown outlines, large color shapes, limited soft shading, subtle paper texture.
Absolute invariants: exact canvas dimensions and 16:9 crop; same fixed camera and perspective; preserve the large empty left menu-safe zone; keep the round griddle, closed ingredient trays, cart counter, canopy silhouette, and center-right visual balance at the same coordinates and scale. Background art only. No UI panels, buttons, readable text, letters, numbers, people, customers, food on griddle, money, logos, brands, watermark, dramatic shadows, rain, photorealism, 3D gloss, painterly rendering, zoom, crop, perspective drift, or important detail in the left menu zone.
```

## 中式语义定点修正提示词

```text
Use case: precise-object-edit.
Asset type: ProjectCake Chinese jianbing breakfast-cart start-menu background correction.
Input images: Image 1 is the exact edit target and pixel-composition authority.
Primary request: remove the maneki-neko / beckoning lucky cat completely because it is a Japanese cultural element and does not belong in this Chinese breakfast-cart setting. Remove the small display shelf directly under the cat as well. Reconstruct that area as a simple clean pale cool-gray cart back panel matching the surrounding surface, with no object-shaped shadow or ghost silhouette.
Cultural direction: this is a grounded Chinese street breakfast cart. Preserve the bamboo steamers, chopsticks, wok spatula, pan, sauce bottles, enamel surfaces, portable cart structure, and all other practical Chinese breakfast-stall cues. Do not introduce torii, noren, Japanese lanterns, Japanese characters, sushi, ramen imagery, maneki-neko, daruma, or other Japanese motifs. Do not add replacement mascots, religious symbols, decorative statues, text, logos, or flags.
Absolute invariants: change only the cat and its small shelf area. Preserve exact 1672x941 canvas, crop, camera, perspective, pale blue-gray 7:00 AM light, outdoor sidewalk, warm-ivory and faded-teal mobile cart, striped canopy, round griddle, all closed trays, small plants, utensils, bamboo steamers, sauce bottles, left 38% low-detail menu-safe zone, line weight, shading, and texture. No people, customers, food on griddle, UI, buttons, text, letters, numbers, watermark, color-temperature drift, zoom, crop, or perspective drift.
```

## 验收记录

- 尺寸：1672 × 941，RGB PNG。
- SHA-256：`EADA97E7F0BDDDD3CF60222F069DA4AA222C7ED460ACFC0BFD4B5AE4C60EDD63`
- 构图检查：左侧菜单安全区保持低细节；中央背板保持干净留白，作为后续游戏名称的预留区；工作台、圆鏊子、封闭料槽、雨棚轮廓与中心偏右重心保留。
- 方向检查：环境为冷灰蓝清晨街面，车体为米白珐琅与旧青绿；招财猫及其展示架已移除，原区域不放置海报、吉祥物、文字、价格或伪书法。
- 真人视觉验收：待完成。
