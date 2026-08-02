# currency_coin_v1 生成提示词

## 最终生成提示词

```text
Use case: game-asset
Asset type: ProjectCake P2 economy UI icon, currency coins
Primary request: create one compact icon made of exactly three overlapping round golden Chinese-style coins. Every coin must have exactly one clearly visible square center hole and no other dots, holes, eyes, face marks, letters, numbers, or currency symbols. The center/front coin should dominate, with two coins behind it forming a simple triangular cluster.
Style/medium: match ProjectCake's simple hand-drawn 2D cartoon UI—bold clean deep-brown outline, large flat warm color shapes, one simple shadow and one highlight at most, high contrast and unmistakable at 48 to 64 pixels, not painterly and not 3D.
Composition/framing: centered compact cluster, complete silhouette, generous empty margin, no crop, no cast shadow, no badge frame and no surrounding UI panel.
Color/material: warm mustard-gold faces, small pale-gold highlight, dark-brown outlines and square holes.
Background: solid uniform vivid magenta chroma-key background #FF00FF, flat and untextured.
Constraints: exactly 3 coins; exactly 1 square hole per coin; no circular dot decorations, face-like arrangement, smiling face, eyes, stars, text, letters, numbers, currency sign, logo, brand, watermark, purse, banknote, hand, photorealism, glossy 3D, gradients, thin outlines, or baked floor shadow.
```

## 淘汰版本与修正

首次结果在硬币表面用了三枚圆点，缩到 64px 后有“人脸”误读风险。旧版源图与透明图保留在 `tmp/imagegen/p2_ui_icons_v1/`，最终版改为每枚硬币一个方孔。

## 处理

- 生成方式：Codex 内置 `image_gen`
- 去背方式：技能自带 `remove_chroma_key.py`
- 小尺寸检查：以 64px 实际预览复核
