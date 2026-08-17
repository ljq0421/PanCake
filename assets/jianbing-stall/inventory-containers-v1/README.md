# 工作台库存容器素材

所有可运行素材均为 **512 × 512、RGBA 透明 PNG**。容器底图每类只有一张；库存变化时只替换同一类的 `*-content-*.png` 文件，容器图永远不替换。

| 品类 | 固定容器 | 内容状态 |
| --- | --- | --- |
| 香葱 | `scallion-basket-base.png` | `scallion-content-{empty,quarter,half,three-quarters,full}.png` |
| 鸡蛋 | `egg-basket-base.png` | `egg-content-{empty,quarter,half,three-quarters,full}.png` |
| 薄脆 | `crisp-tray-base.png` | `crisp-content-{empty,quarter,half,three-quarters,full}.png` |

渲染顺序：先绘制固定容器底图，再以相同坐标绘制对应内容层。每组内容层已采用相同的画布和锚点；`empty` 是完全透明。

推荐在 1920 × 1080 工作台中将三个素材显示为约 128–170 px 宽，放在鏊子上方的后沿。`inventory-container-preview.png` 仅用于快速预览三类物品的 5 个状态；`source/` 保存生成后的高分辨率源图和状态图集，`tools/build_inventory_container_layers.ps1` 可从源图重建运行时 PNG。
