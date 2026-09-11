# 天津营业牌设备图标（2026-09-11）

使用内置 imagegen 编辑用户提供的营业牌截图，分别提取煎饼炉和油条锅。按项目要求先生成本目录的纯绿背景原图，再通过内置 imagegen 去背景；运行资源为上一级 `stove.png`、`fryer.png`。两张 PNG 已检查真实 alpha，并在营业牌奶油色背景上检查边缘。煎饼炉绿色指示灯保留。

## 提示词

### 煎饼炉绿底

Edit the reference to extract ONLY the round pancake griddle on the LEFT as one isolated game sprite, centered on a uniform pure chroma green #00FF00 background. Remove all other objects, UI, paper and orange tabletop background. Faithfully preserve the exact original griddle design, viewing angle, black round cooking surface, orange yellow body, red center knob and tiny indicator lights. Entire appliance visible with green margin. No new design, no text, no shadow outside the appliance. This is the green-screen intermediate for a transparent game icon.

### 油条锅绿底

Extract ONLY the square cream yellow oil fryer in the MIDDLE of this reference as one isolated game sprite. Place on uniform pure chroma green #00FF00 background. Remove the tabletop, paper, other objects and UI. Faithfully preserve original fryer silhouette, viewing angle, black rectangular opening filled with golden oil, orange dial, red indicator, side handles and feet. Entire appliance visible with green margin. No filter basket, no text, no shadows outside appliance. This is a green-screen intermediate for a transparent icon.

### 煎饼炉去背景

Remove ONLY the exterior green background and replace with real alpha transparency. Keep this pancake griddle exactly unchanged, all its solid details opaque, especially preserve the small GREEN indicator light inside the front control panel (it is part of the appliance, must NOT become transparent). Preserve smooth clean dark outlines with no green halo. Tight image crop with small transparent padding around entire appliance. Output transparent PNG game sprite, no checkerboard.

### 油条锅去背景

Remove ONLY the exterior green background and replace with real alpha transparency. Keep this oil fryer exactly unchanged including handles, feet, outline and oil inside. Preserve smooth clean edges with no green halo. Tight crop with small transparent padding around entire appliance. Output transparent PNG game sprite, no checkerboard, no ground shadow.
