# 胶带描边收细 v4

用户反馈 corner-tape-v3.png 描边过粗。本次用内置 imagegen 编辑其绿底源图，目标将描边减薄约三分之一，保留胶带整体轮廓与色彩；经过同一抠图脚本输出 256px 宽的 corner-tape-v4.png。标题和左上角同时改用新版本，保留标题局部浅色 Shader 和小碗 60% 不透明度。

## 完整编辑提示词

```text
Edit ONLY the outline thickness of the supplied green-screen tape source image. Preserve the exact canvas size, object position, tape outer silhouette, overall width/height ratio, warm apricot fill color, two caramel crease marks, curved top/bottom, rounded notched ends and all other details. The continuous dark brown OUTER CONTOUR is currently too heavy: reduce its thickness by approximately ONE THIRD (keep 65% of current width) by extending the apricot fill outward into the INNER part of the contour. Do not shrink the overall outer silhouette. Do not lighten the dark brown contour, do not add outlines, and do not change the tape into a different object. Preserve cartoon clarity with a medium-weight smooth rounded dark brown outline, not a fine hairline. All outside pixels must remain fully opaque pure green RGB(0,255,0), identical green-screen background. No automatic transparency, no alpha, no added text, new marks, decorations, shading or texture.
```

