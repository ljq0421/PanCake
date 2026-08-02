# egg_cracked_raw_v2

## 最终生成提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake top-down gameplay sprite for the instant immediately after one raw egg is cracked onto a pancake
Input images: Image 1 is the egg_cracked_raw_v1 edit target; Image 2 is the approved egg_whole_v1 color and rendering style reference
Primary request: correct Image 1 so it unmistakably reads as one freshly cracked raw egg, not a fried egg. Keep one intact golden-orange yolk slightly off center, flatten the yolk dome, make the egg-white puddle broader, looser and organically irregular with 3 to 5 shallow lobes, and make the white pale creamy and glossy but still opaque enough for clean chroma-key extraction and readability over a golden pancake. Remove the dark brown cooked outline around the egg white completely. A thin warm illustrated contour may remain around the yolk only.
Style/medium: polished stylized 2D mobile/PC cooking-game ingredient sprite, matching the supplied ProjectCake assets, fixed near-top-down view, soft internal shading, clean readable silhouette
Composition/framing: one egg centered with generous transparent-safe padding, complete object not cropped
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal
Constraints: change only the rawness, puddle shape and outline treatment; preserve the project palette and rendering style; exactly one yolk; no shell; no pan, plate, griddle, pancake or utensils; background must be one uniform #00ff00 with no shadows, gradients, texture, reflections, floor plane or lighting variation; do not use #00ff00 in the egg; no cast shadow, contact shadow, text, logo, brand or watermark
Avoid: fried egg appearance, cooked brown rim, crispy edge, bubbles, solid white rubbery egg white, extra yolks, cropped edges
```

## 处理说明

使用 Codex 内置 `image_gen`，以 v1 为编辑目标、完整鸡蛋为风格参考。生成纯绿色抠像源后，使用技能自带 `remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill` 输出透明 PNG。该图只表现落蛋瞬间；玩家开始摊蛋后由运行时逻辑网格与 Shader 接管连续形状。
