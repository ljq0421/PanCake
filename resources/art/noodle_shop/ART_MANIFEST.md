# 老城刀削面馆美术清单（Batch 1）

生成日期：2026-08-30

统一画风锚点：第一章现有的中式卡通手绘风；深棕清晰轮廓、暖橙/奶油/灰绿主色、轻微水粉和纸张纹理、圆润简洁造型、适合轻松经营游戏。独立透明素材均先生成纯绿幕源图，再使用色键脚本输出真实 RGBA PNG。

## 正式素材

| 类型 | 正式素材 | 绿幕源图 | 尺寸 |
| --- | --- | --- | --- |
| 背景 | `background/noodle_shop_interior_background-v1.png` | 不适用 | 1672×941 RGB |
| 工作台 | `tools/dough_station-v1.png` | `tools/_source/dough_station_chroma-v1.png` | 1672×941 RGBA |
| 工作台 | `tools/boiling_pot_stove-v4.png` | `tools/_source/boiling_pot_stove_chroma-v1.png` | 1448×1086 RGBA |
| 工作台 | `tools/noodle_basket-v3.png` | `tools/_source/noodle_basket_chroma-v1.png` | 1448×1086 RGBA |
| 成品 | `products/clear_broth_noodles-v3.png` | `products/_source/clear_broth_noodles_chroma-v2.png` | 1254×1254 RGBA |
| 成品 | `products/tomato_egg_noodles-v1.png` | `products/_source/tomato_egg_noodles_chroma-v1.png` | 1254×1254 RGBA |
| 成品 | `products/zhajiang_noodles-v1.png` | `products/_source/zhajiang_noodles_chroma-v1.png` | 1254×1254 RGBA |
| 反馈 | `feedback/shaving_knife-v1.png` | `feedback/_source/shaving_knife_chroma-v1.png` | 1536×1024 RGBA |
| 反馈 | `feedback/noodle_batch_standard-v1.png` | `feedback/_source/noodle_batch_standard_chroma-v1.png` | 1536×1024 RGBA |
| 反馈 | `feedback/drain_droplets-v1.png` | `feedback/_source/drain_droplets_chroma-v1.png` | 1024×1536 RGBA |

## 最终提示词

### 场景背景

> 2D 烹饪游戏“老城刀削面馆”的空操作间背景。奶油色微旧灰泥墙、青灰低砖墙裙、深暖木梁与传统门窗；下方留连续宽阔操作台，中左预留面团台、中右预留煮面锅。严格匹配第一章的深棕轮廓、暖橙/奶油/灰绿配色和轻微水粉纸张肌理。16:9，轻微俯视，无人物、文字、UI、食材或设备。

### 削面台

> 独立传统削面面团台：低矮榫卯实木底座、略倾斜面托和占主体约 55% 的圆润米白大面团，形成清楚起刀区。轻微俯视三分之四视角，深棕粗轮廓，暖木和奶油色手绘质感；无刀、手和其他器皿；纯绿 #00FF00 背景。

### 煮面锅与灶座

> 独立单口煮面锅与传统灶座：宽大深灰铁锅、清楚锅口、蓝灰沸水和少量气泡，嵌入青灰砖灶与暖木包边，正面小炉口有克制暖火光。轻微俯视三分之四视角；无面篮、面条、锅盖；纯绿 #00FF00 背景。

### 长柄面篮

> 独立长柄圆形煮面篮：简化细金属网篮、暖铜包边、右上斜伸深木手柄和防滑绕绳，透视与煮面锅一致，篮体能覆盖锅面约一半。篮内为空，无锅和面条；纯绿 #00FF00 背景。

### 清汤刀削面

> 白瓷青蓝双线大碗中的清汤刀削面：淡金清汤、宽窄适中的米白刀削面片和少量翠绿葱花，轻微俯视，成品图标级清晰度。无番茄、鸡蛋、炸酱、餐具和文字；碗外为均匀纯绿 #00FF00。

### 番茄鸡蛋刀削面

> 与清汤碗型和视角完全一致的番茄鸡蛋刀削面：较薄较窄的刀削面、淡橙番茄汤、鲜红番茄块、暖金炒蛋和少量葱花；红黄浇头醒目但仍能看见面条粗细。无肉酱、红油和餐具；碗外为均匀纯绿 #00FF00。

### 炸酱刀削面

> 与前两碗一致的无汤炸酱刀削面：较厚较宽、充分沥水的暖米白刀削面，中央铺浓稠深红棕肉末豆酱，配少量翠绿黄瓜丝、葱花和浅黄豆粒。必须清楚表达无汤和厚面；碗外为均匀纯绿 #00FF00。

### 削面刀

> 独立刀削面专用削面刀：宽扁弧形深银灰钢片、浅弧刃线、短暖木手柄与两圈麻绳，刀身左下、手柄斜向右上。安全圆润的卡通工具感，不像武器；无手和动作线；纯绿 #00FF00 背景。

### 单刀面条批次

> 5–7 条刚削下、在空中舒展的生刀削面片：长而扁、米白奶油色、中间略厚、两端收窄、边缘轻微波浪，多条平行成束并沿左上到右下形成弧线。无刀、锅和动作线；纯绿 #00FF00 背景。

### 沥水水滴簇

> 7–10 颗从面篮底部向下滴落的清水水滴，大小有节奏变化，竖向轻微弯曲排列；淡青蓝和蓝灰半透明感、奶油白高光、深青细轮廓。无篮子、锅、水柱或飞溅环；纯绿 #00FF00 背景。

