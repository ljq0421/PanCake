# 初始解锁独立小料槽 v3

- 用途：供后续手动逐格拼接的 12 个独立透明 PNG；当前不接入 `initial_unlock_workstation.tscn`。
- 生成方式：沿用已确认的生成美术，按等宽槽位无缩放切分，保证所有格子的画风、尺寸和边缘一致。
- 最终目录：`res://resources/art/workstation/material_slots/individual/`。

## 文件与顺序

1. `slot_01_egg_v1.png`
2. `slot_02_baocui_v1.png`
3. `slot_03_scallion_v1.png`
4. `slot_04_sweet_flour_sauce_v1.png`
5. `slot_05_locked_v1.png` 至 `slot_12_locked_v1.png`

## 拼接约束

- 每个文件均为 176 × 98 的透明 PNG；每个文件只含一个槽位。
- 无条带、无第二行、无文字、无序号；八个锁位保留为八个可独立放置的文件。
- 底图不得烘焙这些格子；需要时由人工或后续场景层逐格叠加。
