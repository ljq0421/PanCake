# Panel 手账装饰 v2

用户确认补充标题纸签、左上角胶带、右下角浅棕蒸汽碗印记。工具：内置 imagegen；以下提示词每项独立调用。绿底源图保留于本目录，透明图由 `tools/prepare_panel_frames.ps1` 提取。纹理分别按 768、256、256px 宽保存。所有装饰在 Godot 中独立等比显示。

## title

```text
Produce a FULLY OPAQUE green-screen SOURCE image: keep every background pixel bright pure green #00FF00. Do not auto-remove background or generate alpha. We extract alpha ourselves afterwards. ONE isolated BLANK horizontal paper title strip for a cozy Chinese breakfast shop game. Warm apricot paper #F2C67D with thin muted warm brown outline #9D794E. Aspect ratio of paper itself 6.2:1, wide enough for a long Chinese dialog heading later. Subtly hand-torn short ends, soft irregular corners, one small flat tan downward offset shadow, no folds or curls over the writing area. Large completely empty flat pale apricot central writing area. Hand-drawn 2D low-detail cartoon big color shapes. The paper takes up 85% of canvas width and only 15% of canvas height, centered in a landscape canvas. NO writing, text, symbols, drawings, speckles, realistic grain, gradients, 3D, metallic ornaments or highlights. Keep all artwork visible without cropping. Match a warm cream/apricot/brown hand-drawn 2D casual game UI family.
```

## tape

```text
Produce a FULLY OPAQUE green-screen SOURCE image: keep every background pixel bright pure green #00FF00. Do not auto-remove background or generate alpha. We extract alpha ourselves afterwards. ONE isolated short piece of pale caramel masking tape for a hand-crafted cozy Chinese breakfast shop game UI. Horizontal strip, aspect ratio 2.8:1, softly irregular torn short ends, very subtle 2D lighter stripe along its top edge. Solid opaque warm honey beige #E8C187, slightly darker warm tan fine contour. Flat cartoon illustration, low detail, gentle organic shape. No paper behind it, no panel, NO text, symbols, patterns, grain, speckles, shadows, photorealism or 3D. Center the tape in canvas with substantial surrounding green margin. Keep it horizontal; game engine will rotate it. Keep all artwork visible without cropping. Match a warm cream/apricot/brown hand-drawn 2D casual game UI family.
```

## stamp

```text
Produce a FULLY OPAQUE green-screen SOURCE image: keep every background pixel bright pure green #00FF00. Do not auto-remove background or generate alpha. We extract alpha ourselves afterwards. ONE isolated small steaming breakfast bowl imprint icon for a cozy Chinese breakfast shop game UI. Three friendly curling steam strokes over a wide shallow bowl, short flat foot beneath the bowl. Bowl and steam are stylized hand-drawn warm tan #BA8C57 thick linework, with warm tan flat solid details, NO circular badge border, NO enclosing shape, NO background paper. Open areas inside the bowl and between steam strokes MUST be bright green. Simple memorable 2D ink-stamp illustration, clean smooth edges with a tiny organic variation, no distressed speckles. Only one ink color. Center the icon with green margins, icon approximately square. NO text, chopsticks, food, utensils, gradients, shadows, red ink, green ink or 3D. Keep all artwork visible without cropping. Match a warm cream/apricot/brown hand-drawn 2D casual game UI family.
```

