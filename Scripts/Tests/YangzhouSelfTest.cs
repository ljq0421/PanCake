using Godot;
using ProjectCake.Core;
using ProjectCake.UI;
using ProjectCake.Xian;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class YangzhouSelfTest : Node
{
    private int _passed, _failed;
    private YangzhouCatalog _catalog = null!;
    private string _root = $"res://.tmp/yangzhou-tests/{Guid.NewGuid():N}";
    public override void _Ready()
    {
        try { _catalog = YangzhouCatalog.Load(); DataTests(); ProductionTests(); OrderTests(); ChapterTests(); SaveTests(); }
        catch (Exception exception) { _failed++; GD.PushError(exception.ToString()); }
        GD.Print($"YANGZHOU_TEST_RESULT passed={_passed} failed={_failed}"); GetTree().Quit(_failed == 0 ? 0 : 1);
    }
    private void Check(bool condition, string name) { if (condition) { _passed++; GD.Print("PASS " + name); } else { _failed++; GD.PushError("FAIL " + name); } }
    private void DataTests()
    {
        Check(_catalog.Days.Count == 12 && _catalog.Day(12).Customers == 20 && _catalog.Day(12).Duration == 180, "12天完整配置与最终日20组180秒");
        Check(_catalog.Price(_catalog.Template("L")) == 46 && _catalog.Boards.Sum(b => b.Price) + _catalog.Steamers.Sum(b => b.Price) == 980, "大单46元、升级总价980元");
        bool valid = true, deterministic = true, pressureTeaching = true;
        foreach (var day in _catalog.Days)
        {
            var a = YangzhouOrderGenerator.Generate(_catalog, day); var b = YangzhouOrderGenerator.Generate(_catalog, day);
            deterministic &= a.SequenceEqual(b);
            for (int seed = 0; seed < 100; seed++)
            {
                var plan = YangzhouOrderGenerator.Generate(_catalog, day, seed);
                valid &= plan.Count == day.Customers && plan.All(o => o.Arrival > 0 && o.Arrival < day.Duration)
                    && plan.All(o => _catalog.Template(o.TemplateId).Items.All(p => _catalog.Product(p.Key).UnlockDay <= day.Day))
                    && plan.All(o => o.TemplateId != "L" || o.CustomerId == "group" && day.Day >= 8)
                    && plan.Count(o => o.TemplateId == "L") <= day.MaxLarge;
                foreach (var order in plan.Where(o => o.CustomerId != "ordinary")) valid &= _catalog.Customer(order.CustomerId).Preferences.ContainsKey(order.TemplateId);
                if (day.Day == 3) pressureTeaching &= plan.First(o => _catalog.Template(o.TemplateId).Items.ContainsKey("B01")).TemplateId == "C" && plan.Count(o => _catalog.Template(o.TemplateId).Complex) <= 2;
                if (day.Day == 5)
                    for (int i = 1; i < plan.Count; i++) pressureTeaching &= !_catalog.Template(plan[i].TemplateId).MixedSteam || !_catalog.Template(plan[i - 1].TemplateId).MixedSteam;
            }
        }
        Check(valid && deterministic, "1200个种子：人数、时间、商品解锁、专属偏好、大单限制及重放确定性");
        Check(pressureTeaching, "三丁首单与Day5混蒸订单教学保护");
    }
    private void ProductionTests()
    {
        var stock = new RefillableStock(3, .8); stock.TryConsume(1); stock.TryRefill(); stock.Tick(.79);
        Check(stock.Count == 2 && !stock.TryConsume(1), "补料未完成前不增库存且禁止取用"); stock.Tick(.02); Check(stock.Count == 3, "0.8秒免费补满");
        for (int level = 1; level <= 3; level++)
        {
            var s = new YangzhouSession(_catalog, 12, level, level);
            Check(s.Cut() && !s.Cut() && s.Kitchen.Tofu.Count == 2, $"Lv{level}开切只扣一块");
            s.Tick(10); Check(s.Kitchen.Board.Portions == 0, "静止等待不完成切丝");
            for (int i = 0; i < 30; i++) s.Stroke(i % 2 == 0 ? 70 : -70, .1);
            Check(s.Kitchen.Board.Portions == s.Kitchen.Board.Data.Yield, $"Lv{level}往复切丝产量正确");
            s.LoadGansi(); s.Dip(); s.Tick(.2); Check(!s.Lift() && s.Kitchen.Scald.Dips == 0, "不足0.3秒不计烫次");
            for (int i = 0; i < 3; i++) { s.Dip(); s.Tick(.31); s.Lift(); }
            Check(s.Kitchen.Scald.Dips == 3 && !s.Dip(), "三烫后锁定禁止第四次");
            s.Season(); Check(!s.Kitchen.Scald.Ready, "调味需要0.3秒"); s.Tick(.31);
            Check(s.Kitchen.Scald.TryTake(out var food) && food.Quality == YangzhouQuality.Perfect && !s.Kitchen.Scald.TryTake(out _), "三烫成品品质保留且只能取一次");
        }
        foreach (string product in new[] { "B01", "B02" })
        {
            var steamer = new YangzhouSteamer(_catalog.Steamers[0]); var raw = new RefillableStock(12, .8); var output = new Queue<YangzhouFood>();
            Check(steamer.Load(product, 6, raw) && !steamer.Load(product == "B01" ? "B02" : "B01", 1, raw), "单笼不混蒸且不超量");
            steamer.Start(); steamer.Tick(steamer.CookSeconds - .1); Check(!steamer.Open(), "未熟禁止揭盖交付"); steamer.Tick(.1);
            Check(steamer.State == YangzhouSteamState.Ready && steamer.Quality == YangzhouQuality.Perfect, "精确熟制时间进入最佳");
            steamer.Tick(3.01); Check(steamer.Quality == YangzhouQuality.Good, "越过黄金窗口Good"); steamer.Tick(3);
            steamer.Open(); Check(steamer.Quality == YangzhouQuality.Poor && steamer.Collect(output) && output.Count == 6, "严重过蒸仍可整批入库");
        }
        var safe = new YangzhouSession(_catalog, 12, 3, 3);
        Check(safe.LoadSteamer(0, "B01", 8) && !safe.LoadSteamer(1, "B02", 8), "5秒准备阶段最多一笼");
        safe.SteamAction(0); safe.Tick(5.1); Check(safe.Phase == YangzhouPhase.Running && safe.LoadSteamer(1, "B02", 8), "准备结束自动营业开放第二层");
        safe.SteamAction(1); safe.Tick(4.71);
        Check(safe.Kitchen.Steamers.All(s => s.State == YangzhouSteamState.Ready), "双层独立计时并行生产");
        safe.Tick(100); Check(safe.Kitchen.Steamers.All(s => s.Quality == YangzhouQuality.Perfect && s.Holding), "高等级自动保温不自动出笼");
        safe.SteamAction(0); safe.SteamAction(0); safe.SteamAction(1); safe.SteamAction(1);
        Check(safe.Kitchen.Buns.Count == 8 && safe.Kitchen.Siumai.Count == 8, "两种成品独立8容量");
        safe.LoadSteamer(0, "B01", 2); safe.SteamAction(0); safe.Tick(7); safe.SteamAction(0);
        Check(!safe.SteamAction(0) && safe.Kitchen.Steamers[0].Quantity == 2, "成品满盘时保留笼内点心");
        safe.Pause(true); var before = safe.Elapsed; safe.Tick(10);
        Check(safe.Elapsed == before && !safe.TakeTea() && !safe.Cut() && !safe.Refill("tofu"), "暂停冻结时间与所有操作");
    }
    private void OrderTests()
    {
        var kitchen = new YangzhouKitchen(_catalog, 12, 3, 3);
        var a = new YangzhouOrder(new(1, 0, "ordinary", "F"), _catalog, false);
        a.Tick(a.Patience * .1, false);
        double waitBeforeStaging = a.Wait;
        var b = new YangzhouOrder(new(2, 0, "ordinary", "B"), _catalog, false);
        kitchen.Buns.Enqueue(new("B01")); kitchen.Buns.Enqueue(new("B01")); a.Stage("B01", kitchen);
        Check(a.Wait == waitBeforeStaging && !a.Served, "扬州放入部分餐品不算交付、不恢复耐心");
        kitchen.TakeTea(); kitchen.Tick(.31); b.Stage("T01", kitchen); b.Serve();
        Check(a.StagedItems.Count == 1 && !a.Serve() && b.Served, "切换托盘保留，缺件禁止正式出餐");
        a.Stage("B01", kitchen); kitchen.TakeTea(); kitchen.Tick(.31); a.Stage("T01", kitchen);
        Check(a.Perfect && a.Serve() && !a.Serve() && a.Satisfaction == 100 && a.Tip == 1, "完整套餐一次出餐、正确收入及小费");
        Check(a.Wait == waitBeforeStaging, "扬州整盘上桌保留实际等待时间");
        var wrong = new YangzhouOrder(new(3, 0, "ordinary", "B"), _catalog, false); kitchen.Buns.Enqueue(new("B01"));
        Check(!wrong.Stage("B01", kitchen) && kitchen.Buns.Count == 1 && wrong.Mistakes == 1, "错商品扣分但不吃掉库存");
        kitchen.TakeTea(); kitchen.Tick(.31); wrong.Stage("T01", kitchen);
        Check(wrong.Satisfaction == 80 && !wrong.Perfect, "错误后不能Perfect");
        foreach (var pair in new[] { (.3, 100), (.6, 95), (.84, 85), (.99, 70) })
        {
            var order = new YangzhouOrder(new(4, 0, "ordinary", "B"), _catalog, false); order.Tick(order.Patience * pair.Item1, false);
            Check(order.Satisfaction == pair.Item2, "等待百分比扣分边界 " + pair.Item1);
        }
        var lost = new YangzhouOrder(new(5, 0, "ordinary", "C"), _catalog, false); lost.Stage("B01", kitchen); lost.Lose();
        Check(lost.StagedItems.Count == 0 && !lost.Serve(), "离店销毁专属托盘");
        var tutorial = new YangzhouSession(_catalog, 1, 1, 1); tutorial.Tick(1000);
        Check(tutorial.Phase == YangzhouPhase.Closing && tutorial.Waiting.Count == 4 && tutorial.Result().Lost == 0, "Day1长等待不会离店教学失败");
        var pressure = new YangzhouSession(_catalog, 12, 3, 3); bool cap = true;
        for (int i = 0; i < 3600; i++) { pressure.Tick(.05); cap &= pressure.Waiting.Count <= 4 && pressure.CurrentDelay <= 4; }
        Check(cap && pressure.PressureDelays > 0, "高压保护最多延迟4秒、同屏最多4组");
        Check(new YangzhouResult(12,20,18,2,1,0,90,0,10).Stars == 3 && new YangzhouResult(12,20,18,2,1,0,90,20,9).Stars == 2, "三星数交付Perfect干丝份数，不替换为Perfect订单数");
        for (int dips = 1; dips <= 2; dips++)
        {
            var s = new YangzhouSession(_catalog, 1, 1, 1); s.Cut();
            for (int i = 0; i < 30; i++) s.Stroke(i % 2 == 0 ? 70 : -70, .1);
            s.LoadGansi(); for (int i = 0; i < dips; i++) { s.Dip(); s.Tick(.31); s.Lift(); }
            s.Season(); s.Tick(.31);
            var order = new YangzhouOrder(new(99, 0, "regular", "A"), _catalog, false); order.Stage("G01", s.Kitchen);
            Check(order.Serve() && !order.Perfect && order.Satisfaction == (dips == 1 ? 90 : 95), $"{dips}烫可以出售并正确扣分");
        }
    }
    private void ChapterTests()
    {
        for (int day = 1; day <= 12; day++)
        {
            var session = Play(_catalog, day, 3, 3);
            var r = session.Result();
            Check(session.Phase == YangzhouPhase.Results && r.Completed + r.Lost == r.Planned && r.Completed >= (day == 12 ? 18 : r.Planned - 2), $"Day{day}实际生产整日完成{r.Completed}/{r.Planned}，满意{r.Satisfaction:0.0}%");
            if (day == 12) Check(r.Stars == 3, $"最终日三星可达：Perfect干丝{r.PerfectGansi}份");
        }
        var save = new SaveService(); save.UsePathForTests(_root + "/progression.json"); AddChild(save);
        bool affordable = true;
        for (int day = 1; day <= 12; day++)
        {
            if (day == 4) affordable &= save.PurchaseYangzhou(YangzhouCatalog.BoardId, _catalog, out _);
            if (day == 6) affordable &= save.PurchaseYangzhou(YangzhouCatalog.SteamerId, _catalog, out _);
            if (day == 9) affordable &= save.PurchaseYangzhou(YangzhouCatalog.BoardId, _catalog, out _);
            if (day == 10) affordable &= save.PurchaseYangzhou(YangzhouCatalog.SteamerId, _catalog, out _);
            save.PrepareYangzhou(day, out _);
            var session = Play(_catalog, day, save.Data.Yangzhou.EquipmentLevels[YangzhouCatalog.BoardId], Math.Max(1, save.Data.Yangzhou.EquipmentLevels[YangzhouCatalog.SteamerId]));
            save.CommitYangzhou(session);
            var result = session.Result();
            Check(result.Completed >= result.Planned - 2, $"从零资金正常成长Day{day}：{result.Completed}/{result.Planned}组 · ¥{result.Revenue}");
        }
        Check(affordable && save.Data.Yangzhou.BestStars == 3, "无需继承金币，按正常成长节奏可买齐设备并三星"); save.Free();
    }
    public static YangzhouSession Play(YangzhouCatalog catalog, int day, int board, int steamer)
    {
        var session = new YangzhouSession(catalog, day, board, steamer); int guard = 0;
        session.Tick(5);
        while (session.Phase != YangzhouPhase.Results && guard++ < 2000)
        {
            if (session.Selected is null) { session.Tick(.25); continue; }
            int id = session.Selected.Plan.Id;
            foreach (var line in session.Selected.Template.Items.ToArray())
            {
                while (session.Selected?.Plan.Id == id && session.Selected.Needs(line.Key))
                {
                    var k = session.Kitchen;
                    if (line.Key == "G01")
                    {
                        if (k.Board.Portions == 0)
                        {
                            if (k.Tofu.Count == 0) { session.Refill("tofu"); session.Tick(.81); }
                            session.Cut(); for (int j = 0; j < 30 && k.Board.Cutting; j++) { session.Stroke(j % 2 == 0 ? 70 : -70, .1); session.Tick(.1); }
                        }
                        session.LoadGansi();
                        for (int j = 0; j < 3; j++) { session.Dip(); session.Tick(.31); session.Lift(); session.Tick(.05); }
                        if (k.Seasoning.Count == 0) { session.Refill("season"); session.Tick(.61); }
                        session.Season(); session.Tick(.31);
                    }
                    else if (line.Key == "T01")
                    {
                        if (k.Tea.Count == 0) { session.Refill("T01"); session.Tick(.61); }
                        session.TakeTea(); session.Tick(.31);
                    }
                    else if (!k.HasFood(line.Key))
                    {
                        int layer = line.Key == "B02" && k.Steamers.Length > 1 ? 1 : 0;
                        var raw = line.Key == "B01" ? k.RawBuns : k.RawSiumai;
                        if (raw.Count < k.Steamers[layer].Data.Capacity) { session.Refill(line.Key); session.Tick(.81); }
                        session.LoadSteamer(layer, line.Key, k.Steamers[layer].Data.Capacity); session.SteamAction(layer);
                        session.Tick(k.Steamers[layer].CookSeconds + .05); session.SteamAction(layer); session.SteamAction(layer);
                    }
                    if (session.Selected?.Plan.Id != id) break;
                    if (!session.Stage(line.Key)) throw new InvalidOperationException("模拟生产不能放入 " + line.Key);
                    session.Tick(.1);
                }
            }
            if (session.Selected?.Plan.Id == id) session.Serve();
        }
        if (guard >= 2000) throw new InvalidOperationException("整日模拟未结束"); return session;
    }
    private void SaveTests()
    {
        var save = new SaveService(); save.UsePathForTests(_root + "/save.json"); AddChild(save);
        save.Data.Coins = 5000;
        Check(!save.PurchaseYangzhou(YangzhouCatalog.BoardId, _catalog, out _), "有钱也不能跳过升级日期");
        var first = Play(_catalog, 1, 1, 1); int before = save.Data.Coins;
        save.CommitYangzhou(first); int after = save.Data.Coins; save.CommitYangzhou(first);
        Check(after > before && after == save.Data.Coins && save.Data.Yangzhou.HighestUnlockedDay == 2, "共享金币入账、重复结算不刷钱、解锁次日");
        save.CommitYangzhou(Play(_catalog, 2, 1, 1));
        Check(save.PurchaseYangzhou(YangzhouCatalog.BoardId, _catalog, out _) && save.Data.Yangzhou.EquipmentLevels[YangzhouCatalog.BoardId] == 2, "Day2结束购买干丝Lv2");
        Check(save.Data.Yangzhou.EquipmentLevels[YangzhouCatalog.SteamerId] == 1, "Day3蒸笼免费解锁");
        var final = Play(_catalog, 12, 3, 3); save.CommitYangzhou(final);
        Check(save.Data.Yangzhou.BestStars == 3 && save.Data.Yangzhou.UnlockedCollectibleIds.Count == 2, "最终日三星收藏奖励");
        save.Data.Guangzhou.Completed = true; save.Data.Guangzhou.BestStars = 1; save.TrySave(out _); save.Load();
        Check(!save.HasLoadError && save.Data.UnlockedCityIds.Contains(YangzhouCatalog.CityId) && save.Data.Yangzhou.BestStars == 3, "存档往返与广州一星解锁扬州");
        var blank = new SaveService(); blank.UsePathForTests(_root + "/legacy-v3.json"); AddChild(blank);
        blank.TrySave(out _); blank.Load(); Check(!blank.HasLoadError && blank.Data.Yangzhou.HighestUnlockedDay == 1, "无扬州字段的v3存档仍兼容");
        var blocked = new SaveService(); string blockedPath = _root + "/blocked";
        Directory.CreateDirectory(ProjectSettings.GlobalizePath(blockedPath)); blocked.UsePathForTests(blockedPath); AddChild(blocked);
        bool rejected = false; try { blocked.CommitYangzhou(first); } catch (IOException) { rejected = true; }
        Check(rejected && blocked.Data.Coins == 0 && blocked.Data.Yangzhou.HighestUnlockedDay == 1, "写盘失败回滚金币与章节进度"); blocked.Free();
        save.Free(); blank.Free();
    }
}
