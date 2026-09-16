# 早餐铺子 · 两城 Demo RC1

Windows x64 · 2026-09-16 · 内容版本 3 / 存档结构 2

解压整个文件夹，运行 **BreakfastDemo.exe**。保留旁边的 .pck 文件和 data_ProjectCake_windows_x86_64 文件夹；无需安装 Godot 或 .NET。

包含天津 7 局、武汉 6 局：煎饼果子、油条、豆浆、热干面、三鲜豆皮；独立制作教学、可选设备升级、五张早餐收藏卡和两城纪念结尾。西安只有预告，本版未接入商店或反馈入口。

## 开始与继续

1. 首页“设置”切换简体中文 / English、窗口、音乐和音效音量。
2. “新的旅程”从天津开始；教学可跳过，准备页可重看。确认新建会覆盖现有 Demo 进度。
3. 至少完成 1 单，正常收摊并保存成功后开放下一局。零完成可免费重试，升级不是推进条件。
4. T7 完成并保存后开放武汉；经营手账可选择已开放营业日重玩。
5. 重玩只补超过历史最佳的收入差额。收藏可以在未刷新收入时获得。
6. “继续旅程”回到上次选择或新开放的准备页，未结算营业重新开始。

## 制作与交付

- 天津：拖面糊入炉；按住左键划动摊饼，点击鸡蛋。点酱碗拿刷子后划动刷酱。F 翻面、收刷、折叠或装袋。
- 油条：长按装入，G 下锅／提篮；金黄时提篮后沥油。订单里的夹入油条和单卖油条不同。
- 豆浆是供应商品。组合订单可分次交付；每件正确商品恢复耐心总量的 15%，最多回满。
- 武汉：生面入篮、提篮沥水、倒入面碗、调味并划动拌匀。豆皮倒浆加蛋、翻面放馅、成熟切块后入盘；按工作台提示操作。
- 两城均自动入账。点击收银挂件查看本次营业明细并暂停。
- 右键长按 0.45 秒，将已投入制作的食物拖入垃圾桶丢弃。左键不丢弃。
- Esc 暂停；切出窗口暂停营业与配乐。恢复不补播经营提示音。

## 收藏与声音

五张卡从合格且匹配的交付记录获得，收摊保存成功后入册。豆浆卡是供应记录。放弃与保存失败不会提前入册，失败后可在结算页重试保存。

曲目经试听确认：Wholesome / Carefree / Local Forecast - Elevator。署名与许可见 MUSIC-CREDITS.md，游戏内“帮助 → 配乐与署名”也有说明。

## 存档

Demo 与正式版分开，默认位置：
%APPDATA%/Godot/app_userdata/早餐铺子/demo/project_cake_demo_pilot_v1.json

文件名保留兼容，内部结构已升级为版本 2。迁移前保留 .before-v2-r3.bak 原档。天津前三局旧档保留金币、设备、教学、最佳成绩；已完成 T3 可继续 T4，不重复发奖。请勿手工合并正式版存档。

这是 Release 候选包。此前首批真人试玩已按用户确认完成；**新增两城全路线的时长、疲劳与手感仍需真人试玩**。自动验证和源码状态机检查不能替代这些结论。详细实现、自动验证、人工待验与校验值见 RELEASE-NOTES.md 和 SHA256SUMS.txt。

---

# Breakfast Shops · Two-city Demo RC1

Extract everything and run **BreakfastDemo.exe**. Keep the .pck and data folder together. No Godot or .NET installation is required.

- 7 Tianjin shifts and 6 Wuhan shifts, five food records, optional upgrades and a two-city ending.
- Complete at least one order, close normally and save to unlock the next shift. Upgrades are optional; zero-order retries are free.
- Complete Tianjin to open Wuhan. Replay from the journal; only income above the previous best is credited.
- Follow the workstation lessons. F handles pancake actions; G lowers/lifts the fryer. Drag food to matching customers.
- Combo items can be served separately. Each correct item restores 15% of maximum patience.
- Hold right mouse for 0.45 seconds, then drag prepared or cooking food to the bin.
- Payments are automatic. The cash pendant opens shift details. Esc and focus loss pause play.
- Food records commit with a successful shift save, even without new best earnings. Abandoning a shift discards its pending records.
- Settings offer English, display and separate music/effects volume. See MUSIC-CREDITS.md for music attribution.
- Old three-shift Demo progress migrates with a backup; full-game saves are separate.
- The complete route still needs human duration, fatigue and feel evaluation. See RELEASE-NOTES.md for verified scope.
