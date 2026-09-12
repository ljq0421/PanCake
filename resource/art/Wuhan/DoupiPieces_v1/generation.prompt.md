# 武汉三鲜豆皮切块素材生成提示词

生成方式：内置 imagegen。参考 `../成熟豆皮三鲜馅.png` 和 `.tmp/doupi-tray-review/pan-and-tray.png`；先生成绿色背景，再通过外部连通背景去背保留食物内部的绿色配料。

```text
Use case: stylized-concept. Asset type: a single production sprite sheet containing four matching Wuhan sanxian doupi cut-piece variants for a cozy Chinese breakfast management game.

Reference image 1 is the existing WHOLE COOKED DOUPI texture: this is the primary and strict reference for the food's golden yellow colors, pale sticky rice grain shapes, green scallion pieces, orange diced ingredients, brown filling chunks, and warm dark brown painterly outlines. Reference image 2 is the actual game counter: use only the pan/tray camera perspective, lighting and hand-painted cartoon visual language. The current rectangular food tiles on that tray are a BAD example of stiff cut-and-paste edges; do not copy those.

Create four separate cut pieces which clearly look cut from reference 1, but with freshly illustrated natural cut edges and modest visible food thickness. Each piece is roughly square in food space, gently trapezoidal in this game's fairly high, straight-on oblique top-down view; broad almost horizontal front edge, matching the reference pan orientation, NOT a 45-degree diamond/isometric view. Keep top surfaces dominant. Make each sprite's projected total silhouette about 1.25 to 1.45 times wider than high. Golden sticky rice and colorful filling are VISIBLE ON THE TOP like reference 1. Absolutely no second pastry skin covering the top, no sandwich, no filling hidden between two pancake lids. Show a small believable front cut face with pale-golden sticky rice grains and a few filling fragments, a thin golden skin edge at its base. Thickness should feel appetizing and modest, not a tall cake.

The cut outlines are generally neat but organically uneven, softly irregular corners, subtle tiny rice protrusions, short broken highlights and warm hand-painted outline with varied weight. Preserve the graphic simplicity of reference 1; each piece has approximately 4–6 large, readable diced topping shapes and simple rice marks, no photoreal microdetail. The food must feel tender and warm, not like hard paper rectangles, UI buttons, ceramic tiles, plastic blocks, sushi or toast. Same light from upper left, soft shading on the food itself, warm golden palette; retain dark and lime greens in the toppings as in reference 1. Four variants must have identical scale, viewing angle, general footprint, moderate thickness, lighting and style, varying only organic cut contours and topping placement.

Output ONE square image as a clean 2-by-2 sprite sheet: exactly ONE independent piece centered within each quadrant, four pieces total. Equal comfortable exterior margins and wide completely empty gutters between quadrants. Every food silhouette fully contained, no overlap, no clipping. No visible grid or labels.

BACKGROUND MUST BE PERFECTLY FLAT SOLID CHROMA GREEN #00FF00 EVERYWHERE OUTSIDE THE FOUR FOOD SILHOUETTES. This is an intermediate green-screen asset that will be keyed to transparency later. No gradients, no glow, no cast/contact shadows on the green background, no green reflections on food. Retain self-shading on the food. No tray, pan, plate, utensil, table, hands, text, numbers, dividers, logos or watermarks. Do not return a transparent/checkerboard background.
```
