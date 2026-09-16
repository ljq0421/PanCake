# 游戏字体对比素材

资源圆体和站酷快乐体仅供 `Scenes/Tests/FontPreview.tscn` 的典型场景预览使用。
荆南麦圆体已被选为正式游戏默认字体，位于 `../KNMaiyuan/`；预览中的“当前字体”现在也显示麦圆体。

| 文件 | 来源 | 授权 |
| --- | --- | --- |
| ../KNMaiyuan/KNMaiyuan-Regular.ttf | https://github.com/maoken-fonts/KNMaiyuan | ../KNMaiyuan/OFL.txt |
| ResourceHanRoundedCN-VF.otf | https://github.com/CyanoHao/Resource-Han-Rounded/releases/tag/v1.910 | ResourceHanRounded-OFL.txt |
| ZCOOLKuaiLe-Regular.ttf | https://github.com/googlefonts/zcool-kuaile | ZCOOLKuaiLe-OFL.txt |

字体文件保持原样。资源圆体在 Godot 中以 `wght=400, ROND=100` 预览，避免其默认 200 字重过细。
三款字体遵循 SIL OFL 1.1，随软件分发时保留对应版权声明和许可证。

推荐在项目根目录运行 `./Preview-Fonts.ps1`，启动时会隔离用户设置及存档目录。
源码变动后先在编辑器构建，或传入 `-Build` 重新构建。
也可以在 Godot 打开 `Scenes/Tests/FontPreview.tscn`，按 F6 运行。下方选择天津城市页、营业现场、经营手账。
点击字体按钮或按 F7 切换；F8 隐藏/恢复对比栏。站酷快乐体仅在对比栏展示标题试样。
场景定格、金额为演示数据，使用独立临时存档；退出后不保留字体选择。

自动检查：运行 `./Preview-Fonts.ps1 -Verify`，会在 `artifacts/font-preview` 保存实际视口截图。
