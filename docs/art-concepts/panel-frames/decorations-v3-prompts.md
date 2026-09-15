# Panel 装饰 v3：粗线卡通修正

根据用户反馈，重绘标题纸签、胶带和小碗装饰，使深暖棕粗描边、圆润轮廓及大色块更接近游戏现有素材。先查看了项目 `通用主操作按钮底板.png` 与 `通用次级按钮底板.png` 作为风格依据；首批参考图生成结果含异常半透明底，未采用。以下是最终绿底素材的完整提示词（内置 imagegen，独立生成），经 `tools/prepare_panel_frames.ps1` 抠图后保存。源图分别为 title-green-v3.png、tape-green-v3.png、stamp-green-v3.png。

## title

```text
An OPAQUE RGB green-screen SOURCE illustration. The entire canvas background is fully solid bright green RGB(0,255,0). KEEP THAT GREEN BACKGROUND. Every pixel including background and object is opaque. No alpha/transparency. This is a bold simple 2D CARTOON CASUAL GAME UI asset, using thick chocolate brown ink contours, rounded forms and 2-4 pure solid fill colors, same visual language as cartoon Chinese breakfast-shop game objects. It must look like painted animation CEL art. NO GRADIENTS anywhere, no noise or paper texture, no grain, no lighting, no highlights, no glossy effects, no bevel or 3D, no realism, no text. Single blank horizontal rounded cartoon title label, width to height ratio exactly 7:1. Only one shallow smoothly rounded notch in each short end. Body solid buttery yellow RGB(255,214,133). Continuous extremely bold dark chocolate outline RGB(85,48,29), thickness 7% of label height. One narrow flat caramel under-edge below label. Flat opaque center for game heading added later. Label approximately 1400px wide and 200px high on a landscape canvas.
```

## tape

```text
An OPAQUE RGB green-screen SOURCE illustration. The entire canvas background is fully solid bright green RGB(0,255,0). KEEP THAT GREEN BACKGROUND. Every pixel including background and object is opaque. No alpha/transparency. This is a bold simple 2D CARTOON CASUAL GAME UI asset, using thick chocolate brown ink contours, rounded forms and 2-4 pure solid fill colors, same visual language as cartoon Chinese breakfast-shop game objects. It must look like painted animation CEL art. NO GRADIENTS anywhere, no noise or paper texture, no grain, no lighting, no highlights, no glossy effects, no bevel or 3D, no realism, no text. Single SHORT FAT cartoon tape strip, width to height ratio exactly 3:1. Outline is very thick dark chocolate RGB(85,48,29), 10% of tape height, rounded joints. Flat honey apricot fill RGB(242,198,125). Each end has just one shallow soft notch and one short chunky caramel crease line. Horizontal orientation. Friendly puffy cartoon silhouette but no volume or 3D. The strip is roughly 800px wide and 267px tall, centered on square canvas.
```

## stamp

```text
An OPAQUE RGB green-screen SOURCE illustration. The entire canvas background is fully solid bright green RGB(0,255,0). KEEP THAT GREEN BACKGROUND. Every pixel including background and object is opaque. No alpha/transparency. This is a bold simple 2D CARTOON CASUAL GAME UI asset, using thick chocolate brown ink contours, rounded forms and 2-4 pure solid fill colors, same visual language as cartoon Chinese breakfast-shop game objects. It must look like painted animation CEL art. NO GRADIENTS anywhere, no noise or paper texture, no grain, no lighting, no highlights, no glossy effects, no bevel or 3D, no realism, no text. Single compact square cartoon breakfast bowl symbol: a shallow rounded cream bowl with apricot rim and a small wide rounded foot, TWO short wavy dark chocolate steam strokes above. Bowl contour and steam are very bold uniform thick dark chocolate RGB(85,48,29), line width 7% of entire emblem width, all round caps and joins. Fill cream RGB(255,243,216), rim apricot RGB(242,198,125). All gaps around steam are bright green. Only two short steam curls, no face, no food, no badge, no circle. Icon approximately 700px wide by 700px high.
```

