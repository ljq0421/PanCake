# Panel 边框素材生成记录

2026-09-15：用户选定概念稿 01 通用纸卡 + 03 轻量分组，并确认先在一个普通弹窗试装。

工具：内置 imagegen。图中无文字，UI 文字和按钮独立绘制。保留绿底源图，以 `tools/prepare_panel_frames.ps1` 抠绿、去边缘溢色、裁去空白并缩至 384px 宽。源图不覆盖。首次生成出现错误透明区域，已弃用；以下是最终有效提示词。

## 主面板

```text
Create a completely OPAQUE RGB image. Do NOT remove background. Do NOT make transparency or alpha. This is a green-screen SOURCE image that we will process ourselves; every pixel must be opaque including background. One single 2D cartoon cream paper card centered on a perfectly solid bright green #00FF00 background. 1024x1024 square canvas. A large rounded square card from x80 y80 to x944 y934. Entire INSIDE of the card is filled fully with flat cream #FFF8E8, no hole, no transparency, no shadows inside. The card has a warm apricot #F2C67D rim 22 pixels wide and dark warm brown #4A3024 ink outline 6 pixels wide, with a thin tan inside border. Soft hand-drawn rounded corners radius 65px. Straight horizontal and vertical middle edge sections for a nine-slice game panel, identical border thickness throughout. One solid flat tan shadow 8 pixels below. Warm friendly simple illustrated game UI art, visually similar to the left-column 01 通用纸卡 in the reference image. One isolated blank panel only. No text, no objects, no gradients, no texture, no lighting, no holes, no bevel, no glossy white shine. CRITICAL both cream center and green exterior must be fully OPAQUE; retain pure bright green exterior in the exported image.
```

## 轻量分组

```text
Create a fully OPAQUE image for green-screen production, retain the background in the saved picture, no automatic transparency. Supporting reference is the attached concept sheet, copy ONLY 03 轻量分组 (rightmost column) as ONE standalone game UI card asset. 1024x1024 canvas. One large rounded square card approximately x80 y80 to x944 y944, entirely solid opaque pale cream #FFF8E8 interior, thin hand drawn muted warm brown #9D794E outer line approximately 5px thick. A restrained narrow flat beige inner lip about 7px wide confined near the outline. Rounded corners around 50px, slight hand-drawn corner asymmetry and quiet subtle variation, mostly straight middle edge sections to suit nine-slice stretching. Flat low-detail cozy 2D illustrated casual breakfast game art. ALL space outside the card is perfectly uniform opaque pure green #00FF00, keep the green. All space inside card is completely filled with flat opaque cream. NO transparency anywhere, NO holes, NO interior shadows, NO exterior shadows, no drop shadow, NO gradients, no glossy highlights, no grain or noise, no 3D or bevels, no text or objects, no presentation layout, no other panels. Entire border visible with green margin on each side.
```

