# 熟油条沥油架（右偏约 5°）

生成方式：内置 imagegen。先生成绿色背景，再按项目规则进行绿幕抠图并缩放为 512×512 RGBA PNG。

成品：resource/art/TianJin/熟油条沥油架-右偏5度-v1.png

参考：docs/天津托盘统一角度规则.md；resource/art/TianJin/早餐铺风格锚点图-v5.png。
空架依据：docs/美术提示词_3-天津.md 第 44 项，熟油条由游戏动态摆放。
透视骨架：perspective-guide.png。前后沿水平；纵深向后右偏约 5°；后沿宽为前沿约 97%。

## 最终使用的提示词

Use case: sketch-to-render.
Image 1 is a REQUIRED GEOMETRY TEMPLATE for a single EMPTY youtiao draining tray game sprite. Image 2 is ONLY the ART STYLE REFERENCE (cozy Tianjin breakfast shop).
Polish and finish the artwork of image 1 into the warm, hand-drawn 2D cartoon art style of image 2. LOCK image 1's shape, size, position, perspective, horizontal edge directions, and bar layout. Keep the distinctive geometry from the sketch absolutely unchanged: it is a near-parallelogram with BOTH side edges leaning RIGHT as they go UP/back, the back-right corner is further RIGHT than the front-right corner, and all five crossbars remain horizontal. Do not replace it with a symmetric trapezoid! Do not use the geometry of any appliance in image 2.

Finish the sketch into a production-quality game prop: subtly round the corners without shifting their locations; add a softly rounded enamel rim in warm creamy pale yellow, a warm honey-orange shallow drip pan, five simple warm grey rounded rack bars, very clean dark brown outline, gentle cel shading and a few small hand-painted highlights like the reference. Warm, friendly, flat 2D, low detail, slightly toy-like. The slim front wall stays shallow. The rack should feel integrated and low, as in the sketch. No feet, no handles, no extra pieces are needed.
Keep the sprite EMPTY and the whole canvas background perfectly solid #00FF00 chroma green for later keying. No dough sticks, food, oil, crumbs, tools, room, tabletop, external shadows, text, labels, logos or watermarks. No photorealism, no 3D, no complex metal mesh. Maintain the exact square composition and subject placement of image 1.

