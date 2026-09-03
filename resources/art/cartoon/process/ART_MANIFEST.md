# 卡通煎饼过程素材

> 生成日期：2026-09-03  
> 生成方式：Codex 内置 ImageGen  
> 用途：`PancakeModel` 实时字段的卡通着色，不作为阶段贴图替换算法结果。

## 运行时素材

| 文件 | 用途 | SHA-256 |
| --- | --- | --- |
| `pancake_raw_cartoon_v1.png` | 生面糊材质 | `A0A60D5A6FD409097B9E4959A3A4FC680CEDC1F818FD388BEB3BAD55FB2F4D16` |
| `pancake_cooked_cartoon_v1.png` | 金黄熟制材质 | `ECAFCFFA908CA62720689670EE72E1F0E982FCFC3E00DC6ECC483B36F12FA4D8` |
| `pancake_charred_cartoon_v1.png` | 焦糊材质 | `8379137F38875C30D8AF6F7DDEF250CBB71435E467FB8331CEE390BD71F86EA3` |
| `egg_spread_cartoon_v1.png` | 摊开蛋液材质 | `4ED57011CB8C4393110157B7935C017DECB797140395C12E09204BAF07C54354` |
| `sweet_flour_sauce_cartoon_v1.png` | 甜面酱材质 | `DD5C6042EB568794C295CF9EB2FD7281B053FCAC6E06FB34A5FB83C429290EB5` |
| `chili_sauce_cartoon_v1.png` | 辣椒酱材质 | `1E94F6736C490552880B6DD58168E319D7CC135E05A184175B8366DD6443684D` |
| `batter_spreader_cartoon_v1.png` | T 形摊饼器透明游标 | `3C5BE944741D1E0FBF4DE7BAF6D9CB2A6C2F25A1FD81A94B7BB30E64899E6B99` |

## 透明素材流程

`batter_spreader_cartoon_v1.png` 由保留的纯绿源图 `../sources/batter_spreader_cartoon_v1_green.png` 扣图得到。源图四角为不透明 `#00FF00`，成品四角 alpha 为 0。

## 最终提示词集

- 面饼材质：无透视、正交、满画布无物体轮廓的无缝平铺卡通食物纹理；分别表现湿润生面糊、金黄熟面和焦斑过火表面。
- 蛋液与酱料：无缝平铺、细小均匀细节，不出现整蛋、容器、刷子、文字或边框。
- T 形摊饼器：单个完整木制 T 形工具，深棕轮廓和蜜橙色木质，匹配新工作台的暖色手绘卡通风格，纯绿背景用于后续扣图。

所有提示词均要求：无商标、无水印、无文字、无无关物体，风格对齐 `resources/art/cartoon/xiaoliao-1.png`。
