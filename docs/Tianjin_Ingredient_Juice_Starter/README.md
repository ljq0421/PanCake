# 天津配料动效：第一轮实现起点

## 范围与验证状态

这是两个独立的 Godot 4.x C# 表现组件，不是完整工程或业务系统。
没有包含美术、声音、订单、库存、拖拽控制器、配方判断、打蛋动画和流体模拟。
本环境没有 Godot 或 .NET 编译器，因此未进行引擎内编译、运行或性能验证。
动画参数都是首轮调参建议，不是已验证的最优值。

## 1. 单份食材落料

场景结构：

```text
PancakeRoot 或 TableWorld（Node2D，同一 Canvas）
└── Portion（Node2D，挂 IngredientMotion2D.cs）
    └── Visual（Node2D，专供回弹和拖拽倾斜）
        └── Sprite2D（放置贴图，并在此调整贴图显示尺寸）
```

`Portion`、`Visual` 建议保持单位缩放；1920×1080 设计画布下一个父级坐标单位对应一个设计像素。
独立碰撞区不挂在 Visual 下。托盘、碗、源库存内容和本次飞行的食材实例分开。
Visual 的最终静置姿态在 `_Ready()` 记录。不要在悬停缩放之后才记录基准。

拖拽中由现有控制器直接更新 Portion 的位置；不要每帧创建 Tween，也不要在拖拽时并行调用 PlayPlacement。
合法松手或点击加入被业务接受后调用：

```csharp
// portion 已实例化、加入场景并完成 _Ready。
// slot 和 portion 必须处于同一 Canvas 坐标系。
Node2D parent = (Node2D)portion.GetParent();
Vector2 target = parent.ToLocal(slot.GlobalPosition);

// 薄脆：硬质，不挤压，接触后轻跳 2 个设计像素。
portion.PlayPlacement(target, 0.10, 4.0f, 0.0f, 2.0f);

// 火腿：软贴合，不离开饼面，约 4.5% 形变。
portion.PlayPlacement(target, 0.11, 6.0f, 0.045f, 0.0f);
```

这是两个不同食材的替代调用示例，不应先后对同一个实例立即连调。
Tween 的落稳尾段约 0.18 秒；不是额外业务等待。
路径位置 `p(t)=lerp(start,end,t)+(0,-4*h*t*(1-t))`。`h=0` 为短吸附直线。

可通过 `portion.VisualContact += PlayContactSound;` 播接触声。
**禁止通过该事件扣库存、改变配方或开放下一步操作。**事件可能因快进/取消不再发生。

折叠之前，对当前饼已接受的份额调用 `FinishImmediately()`，再执行折叠表现。
丢弃/重开/回收时调用 `CancelMotion()` 并由外层控制器处置份额与库存。
`ReducedMotion=true` 时直接到终态，只保留接触事件。
同一动画属性不要同时交给别的 Tween/AnimationPlayer 修改。

## 2. 跟手刷酱显现

1. 将现有最终酱料覆盖图放在独立 Sprite2D 上。PNG 中不属于酱料的部分应透明，且酱料本身不能画出饼的边界。
2. 将 BrushReveal2D.cs 挂到该 Sprite2D。
3. 在 Inspector 的 RevealShader 指定 brush_reveal.gdshader。
4. 保持独立、单帧、不翻转的贴图；本示例不支持 AtlasTexture、Region 或 SpriteSheet。
5. 现有输入控制器在“刷酱允许、鼠标按住、笔尖接触有效饼面”时调用：

```csharp
sauceReveal.PaintAtGlobal(brushTip.GlobalPosition);
```

抬起鼠标、离开有效饼面、切换阶段、暂停时调用：

```csharp
sauceReveal.EndStroke();
```

开始新煎饼或从对象池取出时：

```csharp
sauceReveal.ResetReveal();
```

只有业务规则已确认刷酱完成、且设计允许将剩余小缝整理成完整覆盖图时：

```csharp
sauceReveal.FinishVisual(0.08);
```

马上折叠时，可用 `FinishVisual(0.0)` 到终态；这不是判定配方完成的方法。
`BrushRadiusUv` 相对整个贴图画布，而非可见煎饼的直径。含较大透明边距的 PNG 需据此调小/调大。
256×256 是遮罩分辨率，不是要求降低食物 PNG 的分辨率。
遮罩由黑逐渐变白，路径补采样，修改后每帧最多上传一次，且每个实例独立材质和纹理。
脚本会设置该 Sprite2D 的 Material；额外高亮应放在独立视觉层，或自行合并 Shader。

该组件**不计算制作完成比例**。保留现有制作规则。若改为覆盖率判定，应另行按有效饼面做业务统计；不能把透明留白也算进面积。
离开饼面再回来不应跨空白连线，控制器必须及时调用 EndStroke。

## 3. 六种配料如何组合

- 面糊：勺子跟随原有拖拽；合法松手后短倾倒；液流只是视觉；中心面糊小摊显现。摊饼仍跟随玩家实际输入，不自动播放到完成。不要降低面糊碗液面或增加补货。
- 鸡蛋：点击按原规则接受；移动至饼上方；切换为两片蛋壳和独立蛋液层；蛋壳向上方两侧离开，蛋液落下摊开。不要把整蛋当硬球砸到饼上。蛋液素材版本省略蛋壳。
- 酱料：刷头跟手，遮罩沿实际笔尖路径出现；不增加额外蘸酱操作，不做酱料碗液面消耗。
- 香葱：一撮转移后，拆为约 8–12 个可读的小叶/葱段 Sprite 落入预设锚点；这些节点落地后直接作为最终配料，不立即换成位置不同的总图。当前轮不增加香葱库存玩法。
- 薄脆：复用落料组件，squash=0，reboundHeight≈2。保持刚性形状，不在投放时碎裂。
- 火腿：复用落料组件，squash≈0.045，reboundHeight=0。落稳后不要持续扭动。

所有角度都是食物/工具的附加姿态，不是托盘透视角度；不旋转托盘来做反馈。
有库存的食材拖拽时预留，取消归还，接受时原子提交；显示库存由源内容物数量表达，不添加库存数字。
点击接受后应立即记录配料，连点不能因视觉尚未落地而重复加入。
“能放入”不等于“符合顾客订单”；本轮不添加自动阻止错配料的功能。

## 4. 防止迟到的动画写入新煎饼

所有表现实例归属于当前 PancakeRoot，或由控制器登记 pancakeId/generation。
接受事件应携带本次煎饼标识、配料类型和份额标识。
折叠：当前已接受份额全部快进，随后切换为折叠成品；不等待装饰动画完成。
丢弃/新建：取消旧饼的所有表现与回调，不把迟到的配料加到新饼。
开关设置和暂停不能改变库存、配方、金币或营业计时规则。

## 5. 首轮检查

- 快速连点鸡蛋/香葱，加入数量符合原规则。
- 薄脆拖出后取消，不丢库存，不多复制食材。
- 快速依次加葱、放火腿、折叠，最终配料完整且无幽灵飞行物。
- 抬笔/越出饼面/暂停后继续刷酱，不突然出现跨区域连线。
- 旧饼丢弃后，新饼没有残留酱料遮罩或旧飞行物。
- 30/60/高刷新率、不同窗口尺寸下，拖拽位置与刷头落点一致。
- 素材缩放在 Sprite2D；Visual 的挤压幅度不会把托盘/命中区一起改变。

## 官方 API 参考

https://docs.godotengine.org/en/4.7/classes/class_tween.html
https://docs.godotengine.org/en/stable/classes/class_node2d.html
https://docs.godotengine.org/en/stable/classes/class_sprite2d.html
https://docs.godotengine.org/en/stable/classes/class_imagetexture.html
https://docs.godotengine.org/en/stable/classes/class_shadermaterial.html
https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html
