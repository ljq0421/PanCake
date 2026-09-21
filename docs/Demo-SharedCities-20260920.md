# Demo 与正式版共用完整两城 · 2026-09-20

## 当前行为

- Demo 使用正式版天津 15 天、武汉 12 天配置和订单生成器；耐心、顾客计划、商品、设备、升级费用、教学与章节目标共用。
- 城市访问由 ExperienceProfile 限制。完成天津 Day 7 营业后开放武汉；武汉满足正式末日星级条件并保存后显示两城纪念页，西安仍为预告，广州和扬州不可进入。
- 准备页、日历、升级和账本直接读取共享城市进度。两版继续使用同一套五卡收藏；完成天数来自实际结算记录。
- 当前正式武汉日配置未开放蛋酒，Demo 不额外开放。共享存档可保存该设备字段，但不因此改变关卡内容。
- 两城结算共用保存及重试处理。重复提交同一场次不重复入账；失败回滚，成功保存后才产生章节完成提示。

## 存档

Demo 路径仍为 `user://demo/project_cake_demo_pilot_v1.json`，文件内容改用正式版 SaveData v3 / CityProgressData。正式存档路径、格式与迁移规则不变，不提供跨版本导入。

已识别的旧三局/13 局存档先原样备份为 `.before-shared-cities*.bak`，再原子写入新路线初始存档。已有备份不覆盖；旧金币、设备、成绩、教学与收藏不迁入。未知格式、缺失必要字段或损坏文件不自动重置。

备份或写入失败保留原档，首页提供“重试读取存档”；成功后提示旧档已备份、新路线从天津首日开始。旧 Demo 清单及 DTO 仅用于验证旧档，已删除旧关卡生成、结算和进度重建实现。

## 验证结果

构建：`dotnet build --no-restore -v:q`，0 警告、0 错误。`git diff --check` 通过。

| 检查 | 结果 |
| --- | --- |
| DemoProfileSelfTest | 26 项通过；完整城市字段往返、旧两种格式备份重开、失败保护、首页重试、未知格式与正式档隔离 |
| DemoRouteSelfTest | 299 项通过；逐日正式配置及固定种子计划对照、星级推进、升级、重玩及后三城限制 |
| DemoJourneySelfTest | 中文 1080p / 英文 720p 各 181 项通过；27 天真实订单交付、结算、保存重载、收藏、两城结尾、场景限制及界面检查 |
| DemoTutorialSelfTest / FullJourneyFeaturesSelfTest | 两版各 81 项通过；共用首份教学、真实交付、练习不计收益、教学保存失败重试、收藏及配乐 |
| AllDaysClosingSelfTest（Demo） | 27 天分别覆盖全完成及超时流失，确认最后离场即结算，独立教学不结算 |
| WuhanWorkbenchSelfTest（Demo） | 851 项通过，覆盖完整 12 天订单、实际制作状态及 Lv2/Lv3 升级 |
| CollectionSelfTest | 15 项通过，记录、统计、保存回滚及界面 |
| DemoUiSelfTest | 英文 720p 实际视口 35 项通过，等待翻页结束后执行鼠标与键盘操作，验证购买升级、重玩和共享继续进度 |
| YoutiaoBatchDeliverySelfTest / DaySixSoyMilkLessonSelfTest | 通过；油条批量交付及 Demo 跟随正式豆浆开放日，无旧第六天独立教学 |

实际 OpenGL 截图等待翻页动画结束后采集，已检查准备页、15/12 天日历、升级页、西安预告和纪念结尾。补齐共用关卡标题及设备英文文案，英文捕获文本未发现中文遗漏。

自动路线测试使用真实 DayController 与交付/结算接口，但部分制作结果由脚本供应，不代替真人连续游玩的手感评估。故障注入测试会故意产生保存/读取错误日志；headless 沿用已有 FoodInk 着色器后端告警，武汉专项退出仍有对象清理告警，未将这些告警隐藏或计作新增通过项。

## 本地导出

Demo Pilot Windows 与 Demo QA Windows 均完成本地 Debug 导出；两者 include_filter 包含正式天津、武汉每日 JSON。普通包以 OpenGL 启动并正常退出（退出码 0）。QA 包使用项目原有 `demo_qa` 内置入口，完整路线 181 项通过（退出码 0）。导出模板不支持命令行替换主场景，因此 QA 通过内置入口运行，不依赖场景覆盖。

仅用于本地验证，未发布或上传安装包，既有发行包不会自动更新。发布辅助脚本已改为随包携带本文，而不是旧 RC1 的历史说明。

证据目录：`artifacts/demo-shared-20260920/`。主要日志：`profile-verified.log`、`DemoRouteSelfTest.log`、`journey-zh-final.log`、`journey-en-final.log`、`wuhan-final.log`、`pilot-smoke-final.log`、`qa-journey.log`。中英文截图位于对应 `userdata-journey-*-final/Godot/app_userdata/早餐铺子/demo-qa-artifacts/` 子目录。
