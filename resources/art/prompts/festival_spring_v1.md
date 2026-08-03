# festival_spring_v1

## 用途

P3 春节独立装饰层。中央招牌与顾客区必须完全留空。

## 初始生成提示词

```text
Use case: stylized-concept
Asset type: ProjectCake P3 spring-festival independent full-frame decoration overlay, magenta chroma-key source
Primary request: create only a restrained Chinese Spring Festival decoration layer for the same fixed street stall. Add a short garland of six small red-and-gold lanterns across the upper edge, two compact red tassel ornaments near the far upper corners, and four small blank red diamond paper decorations spaced along the rear-wall band. Every diamond is plain with no symbol or writing.
```

## 最终布局修正提示词

```text
Use case: precise-object-edit
Asset type: ProjectCake P3 Spring Festival overlay final clear-zone correction
Input images: Image 1 is the current compact magenta chroma-key festival overlay and exact edit target.
Primary request: change only the lantern count and horizontal positions. Keep exactly four small lanterns total: two grouped in the far-left upper band and two grouped in the far-right upper band. Remove the two central lanterns completely. Preserve the top red cable and both far-corner knot-and-tassel ornaments.
Absolute clear zone: from x=540 through x=1130, no lantern, knot, tassel, ornament or hanging cord may appear below the top cable. This entire central region must be uniform magenta below the cable so the centered signboard and customer remain fully visible. All remaining lanterns and tassels must end above y=205 on the unchanged canvas.
Preserve: exact same small lantern designs, red-and-gold palette, deep-brown outlines, flat ProjectCake V8 rendering, and perfectly flat solid #ff00ff background.
Constraints: exactly four lanterns; no diamonds, text, Chinese characters, letters, numbers, zodiac animal, brand, logo, watermark, food, customer, UI, fireworks, smoke, stall, wall, counter, photorealism or painterly background.
```

## 处理

- 两张遮挡中央业务区的尝试稿保留在 `tmp/imagegen/p3_overlays_v1/`，未进入正式素材。
- 最终稿使用技能自带 `remove_chroma_key.py` 抠图，并统一到 1671×941 运行画布。
