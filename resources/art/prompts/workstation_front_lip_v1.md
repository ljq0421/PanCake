# workstation_front_lip_v1 生成提示词与处理记录

## 生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake independent foreground counter-lip occluder sprite for CanvasLayer/Sprite2D
Input images: Image 1 is the approved static workstation backplate and geometry reference; Image 2 is the approved v8 style anchor
Primary request: create one isolated wide front countertop lip/apron that matches the very bottom front edge of the ProjectCake workstation. This is a foreground occlusion layer placed over tools, hands or food when they move beyond the playable countertop.
Subject geometry: one single continuous wide horizontal counter lip only, slightly trapezoidal in the same fixed near-top-down perspective, spanning about 88 to 92 percent of a landscape canvas width and about 9 to 13 percent of the canvas height. The top edge is nearly horizontal with subtle perspective taper toward both ends. Include a warm terracotta-orange top strip, a darker burnt-orange front face, and a thick clean deep-brown outline. Rounded or softly beveled outer corners. No gaps, cutouts, holes, controls or attached objects.
Composition/framing: centered horizontally on a landscape canvas with generous green padding on all sides; complete silhouette fully visible and separated from the canvas edges. Keep the object shallow and wide, not a full table and not a thick cabinet.
Style/medium: match the references exactly—simple hand-drawn 2D cartoon, bold deep-brown outlines, large flat color blocks, at most base color plus one shadow and one highlight, minimal texture and crisp silhouette.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local background removal. The background must be one uniform color with no shadows, gradients, texture, floor plane, reflections or lighting variation. Do not use #00ff00 anywhere in the subject.
Separation constraints: no cast shadow, no contact shadow, no reflection, no glow, no green-colored edge; generous padding and clean antialiased silhouette.
Content constraints: no workstation surface, griddle, bins, customer, UI, payment tray, tools, knobs, handles, ingredients, hands, food, text, letters, numbers, logos, brands or watermark. One opaque foreground counter-lip sprite only.
```

## 本地透明处理

```text
remove_chroma_key.py --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill
```

- 抠像键色：`#08f80d`
- 透明像素：1368203 / 1572411
- 半透明像素：4826 / 1572411
- 四角 alpha：0, 0, 0, 0
- 检测到的绿色边缘像素：0

