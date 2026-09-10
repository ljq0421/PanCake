# 天津工作台前景 V1

两张新增前景通过 Image Gen 生成纯绿色背景原稿，再用 `tools/key_tianjin_workbench.py` 提取透明背景。绿底源图、旧版美术均保留，没有改写背景或桌体正面。

| 原稿 | 运行素材 | 尺寸 |
| --- | --- | --- |
| tray-green.png | resource/art/TianJin/Workbench/tray_right_v1.png | 1809 × 573，RGBA |
| rack-green.png | resource/art/TianJin/Workbench/rack_left_v1.png | 1898 × 612，RGBA |

生成要求摘要：沿用天津卡通经营游戏的奶油黄、金黄色金属、深棕描边和简洁阴影；采用低角度浅盘透视、薄前沿、宽盘底，不加入文字或食物。右侧托盘后沿向左偏移，左侧生料盘镜像使用。沥油架沿用金色容器和银色横向沥油条，后沿向右偏移，与左侧器具组呼应。

引用图为原天津托盘、原沥油架及新托盘风格参考。各运行纹理由 `TianjinArtCatalog` 加载；金币盘使用同母版的深色表面和金币嵌饰，食材盘母版场景为 `Scenes/UI/IngredientTray_Right.tscn`。

复现抠图：安装 Pillow、NumPy 的 Python 执行 `python tools/key_tianjin_workbench.py docs/art-concepts/tianjin-workbench/tray-green.png resource/art/TianJin/Workbench/tray_right_v1.png`，沥油架替换对应文件名。脚本只写输出文件。
