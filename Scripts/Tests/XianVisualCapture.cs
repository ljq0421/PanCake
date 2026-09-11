using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Xian;
using ProjectCake.Orders;

namespace ProjectCake.Tests;

/// <summary>Actual viewport input, rendered captures and interruption checks for the art-free chapter.</summary>
public partial class XianVisualCapture : Node
{
    private XianDayScreen _screen = null!;
    private int _passed;
    private Vector2 _lastPointer;
    private string _output = "";
    public override async void _Ready()
    {
        try
        {
            bool small = OS.GetCmdlineUserArgs().Contains("--capture-720");
            bool wide = OS.GetCmdlineUserArgs().Contains("--capture-16-10");
            GetWindow().Size = wide ? new(1600, 1000) : small ? new(1280, 720) : new(1920, 1080);
            _output = $"res://.tmp/xian-visual/{(wide ? "16-10" : small ? "720" : "1080")}";
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService(); save.UsePathForTests($"{_output}/capture-{Guid.NewGuid():N}.json"); AddChild(save);
            save.Data.Coins = 2000; save.Data.Xian.HighestUnlockedDay = 12;
            var hub = ProjectCake.Core.SceneFactory.Instantiate<XianHub>("res://Scenes/UI/XianHub.tscn"); AddChild(hub); hub.Initialize(catalog, save); await Shot("01-hub"); hub.Hide();
            var controller = new DayController(); AddChild(controller);
            _screen = ProjectCake.Core.SceneFactory.Instantiate<XianDayScreen>("res://Scenes/Gameplay/XianDayScreen.tscn"); AddChild(_screen); _screen.SetProcess(false); _screen.ConnectController(controller);
            Require(_screen.Initialize(catalog, save, controller, 1), "Day1初始化"); _screen.BeginDay(); Step(7);
            Require(!_screen.SoupWorkbenchVisible && _screen.Session.Oven is null, "初始图及馍炉日期限制");
            await Frames(2);
            await Click(new(1145, 900));
            Require(_screen.Session.Sandwich.State == RoujiamoState.Whole, "点击取馍");
            await Gesture(new(1050, 900), new[] { new Vector2(1080, 900), new(1110, 900), new(1170, 900) });
            Require(_screen.Session.Sandwich.State == RoujiamoState.Open, "横向划动实际切开馍");
            await Gesture(new(860, 650), Enumerable.Range(0, 10).Select(i => new Vector2(i % 2 == 0 ? 980 : 850, 650)).ToArray());
            Require(_screen.Session.Board.Portions == 2, "按住砧板左右拖动实际产肉");
            await Drag(new(830, 815), new(1110, 900));
            Require(_screen.Session.Sandwich.MeatPortions == 1 && _screen.Session.Board.Portions == 1, "原生拖拽肉馅进入馍");
            await Click(new(1070, 1020)); Require(_screen.Session.Sandwich.State == RoujiamoState.Wrapped, "点击包装");
            await Shot("02-day1-wrapped");
            var customer = controller.CustomerQueue!.Slots.FirstOrDefault(); Require(customer is not null, "顾客已入场");
            await Drag(new(1145, 900), new(215, 350));
            Require(controller.Ledger!.CompletedCustomers == 1 && _screen.Session.Sandwich.State == RoujiamoState.Empty, "肉夹馍拖给顾客完成交付");
            int revenue = controller.Ledger.Build().TotalRevenue;
            Require(_screen.CoinTray.PendingAmount == revenue && revenue > 0, "整单付款进入共享收钱展示");
            await Click(new(1635, 54)); double before = controller.DayElapsedSeconds; _screen._Process(4);
            Require(controller.IsPaused && controller.DayElapsedSeconds == before, "暂停按钮冻结时间");
            await Click(new(1720, 104)); Require(_screen.CoinTray.PendingAmount == revenue, "暂停不能收钱");
            await Click(new(1145, 900)); Require(_screen.Session.Sandwich.State == RoujiamoState.Empty, "暂停时制作输入无效");
            await Click(new(1635, 54)); Step(.1); Require(!controller.IsPaused && controller.DayElapsedSeconds > before, "继续按钮恢复营业");
            _screen._Notification((int)NotificationApplicationFocusOut); before = controller.DayElapsedSeconds; _screen._Process(4);
            Require(controller.DayElapsedSeconds == before, "失焦冻结时间"); _screen._Notification((int)NotificationApplicationFocusIn);
            await Click(new(1720, 104)); Require(_screen.CoinTray.PendingAmount == 0 && controller.Ledger.Build().TotalRevenue == revenue, "真实点击收钱不重复记账");
            await Click(new(1720, 104)); Require(_screen.CoinTray.PendingAmount == 0, "重复空点无收益");
            await Click(new(945, 550)); Step(.81); Require(_screen.Session.Meat.Count == _screen.Session.Meat.Capacity, "补肉入口可用");
            controller.AbandonDay();
            Require(_screen.Initialize(catalog, save, controller, 2), "Day2初始化"); _screen.BeginDay(); Step(5);
            await Click(new(1145, 900));
            await Gesture(new(1050, 900), new[] { new Vector2(1170, 900) });
            await Gesture(new(860, 650), Enumerable.Range(0, 10).Select(i => new Vector2(i % 2 == 0 ? 980 : 850, 650)).ToArray());
            await Drag(new(830, 815), new(1110, 900)); await Click(new(860, 920));
            Require(_screen.Session.Sandwich.HasJuice, "酱碗点击加汁");
            int juice = _screen.Session.Juice.Count; await Click(new(860, 920));
            Require(_screen.Session.Juice.Count == juice, "重复加汁不消耗库存");
            await Click(new(860, 1020)); Step(.61); Require(_screen.Session.Juice.Count == _screen.Session.Juice.Capacity, "补汁入口可用");
            controller.AbandonDay();
            foreach (int day in new[] { 3, 6, 9, 12 })
            {
                foreach (string eq in new[] { XianRules.Oven, XianRules.Board, XianRules.Soup }) save.Data.Xian.EquipmentLevels[eq] = day >= 9 ? 3 : 1;
                Require(_screen.Initialize(catalog, save, controller, day), $"Day{day}初始化"); _screen.BeginDay(); Step(5);
                Require(_screen.SoupWorkbenchVisible == (day >= 6) && _screen.CoinTray.PendingAmount == 0, $"Day{day}按日期切图并清理收钱余额");
                if (day == 3)
                {
                    await Click(new(170, 810)); Require(_screen.Session.Oven!.Quantity == 4, "整批下炉按钮");
                    Step(3); await Click(new(170, 810)); Require(_screen.Session.Oven.State == BunOvenState.SecondSide, "实际翻面按钮");
                    Step(3); await Click(new(170, 810)); Require(_screen.Session.Oven.State == BunOvenState.Ready && _screen.Session.Buns.Count == 4, "满库存拒绝整批转入");
                }
                if (day == 6)
                {
                    await Click(new(1635, 650)); Step(.61); Require(_screen.Session.Soup!.HasBowl, "点击汤锅完成盛汤");
                    Step(10);
                    var combo = controller.CustomerQueue!.CustomerAtSlot(0)!;
                    double patience = combo.PatienceProgress;
                    await Drag(new(1635, 900), new(215, 350));
                    Require(!combo.Progress.IsComplete && !_screen.Session.Soup.HasBowl && Math.Abs(combo.PatienceProgress - Math.Max(0, patience - .15)) < .002,
                        "托盘拖汤部分交付恢复15%耐心");
                    Require(controller.Ledger!.CompletedCustomers == 0 && _screen.CoinTray.PendingAmount == 0, "部分交付不结账");
                    await Click(new(1635, 650)); Step(.61); await Drag(new(1635, 900), new(215, 350));
                    Require(_screen.Session.Soup.HasBowl, "重复汤交付被拒绝并保留汤碗");
                    await Click(new(1530, 1020)); Step(.81);
                    Require(_screen.Session.Soup.Stock.Count == _screen.Session.Soup.Stock.Capacity, "补汤入口可用");
                }
                Step(day >= 9 ? 28 : 10); await Shot($"03-day{day}");
                if (day == 12)
                {
                    Step(220); Require(controller.State == DayState.Results, "完整关店收尾"); await Shot("04-results");
                    bool returned = false; void Returned() => returned = true;
                    _screen.HubRequested += Returned;
                    await Click(new(960, 775)); Require(returned, "结算返回按钮真实点击可用");
                    _screen.HubRequested -= Returned;
                }
                controller.AbandonDay();
            }
            Require(_screen.Initialize(catalog, save, controller, 1) && !_screen.SoupWorkbenchVisible && _screen.Session.Soup is null && _screen.Session.Oven is null,
                "已解锁汤锅后重玩Day1恢复初始图和教学权限");
            Require(_screen.Initialize(catalog, save, controller, 6), "五人输入场景初始化");
            foreach (var planned in controller.CurrentPlan!.Customers)
                planned.Order = new OrderData { OrderId = planned.Order.OrderId, CustomerTypeId = planned.CustomerTypeId,
                    CityId = StableIds.Cities.Xian, OrderTypeId = "xian_b", BasePrice = 6, Lines = new[] { new OrderLineData(ProductKind.Hulatang, "hulatang", 1) } };
            _screen.BeginDay();
            for (int i = 0; i < 100 && controller.CustomerQueue!.Slots.Count < 5; i++)
            {
                foreach (var waiting in controller.CustomerQueue.Slots) waiting.WaitSeconds = 0;
                Step(1);
            }
            Step(.4); Require(controller.CustomerQueue!.Slots.Count == 5, "真实队列同时显示五名顾客");
            await Shot("06-five-customers");
            for (int slot = 0; slot < 5; slot++)
            {
                var target = controller.CustomerQueue.CustomerAtSlot(slot)!;
                await Click(new(215 + slot * 372, 350));
                Require(controller.CustomerQueue.SelectedCustomerId == target.Id, $"顾客位置{slot + 1}可选中");
                if (_screen.Session.Soup!.Stock.Count == 0) { await Click(new(1530, 1020)); Step(.81); }
                await Click(new(1635, 650)); Step(.61);
                await Drag(new(1635, 900), new(215 + slot * 372, 350));
                Require(target.WasServed, $"顾客位置{slot + 1}真实拖拽交付");
                Step(.5);
            }
            Require(_screen.CoinTray.PendingAmount == controller.Ledger!.Build().TotalRevenue, "多单新收入独立累计");
            controller.AbandonDay();
            _screen.Hide(); save.Data.Wuhan.Completed = true; save.Data.Wuhan.BestStars = 1; save.Data.UnlockedCityIds.Add(StableIds.Cities.Xian);
            var map = ProjectCake.Core.SceneFactory.Instantiate<TianjinMapScreen>("res://Scenes/UI/TianjinMapScreen.tscn"); AddChild(map); map.Initialize(save); await Shot("05-map");
            map.QueueFree(); hub.QueueFree(); _screen.QueueFree(); await Frames(2);
            var globalSave = GetNode<SaveService>("/root/SaveService"); globalSave.UsePathForTests($"{_output}/navigation-{Guid.NewGuid():N}.json");
            globalSave.Data.Wuhan.Completed = true; globalSave.Data.Wuhan.BestStars = 1;
            globalSave.TrySave(out _); globalSave.Load();
            var main = ResourceLoader.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate(); AddChild(main); await Frames(2);
            var morning = main.GetNode<MorningHub>("UI/MorningHub");
            Find<Button>(morning, b => b.Text.Contains("地图")).EmitSignal(Button.SignalName.Pressed);
            var liveMap = main.GetNode<TianjinMapScreen>("UI/TianjinMapScreen");
            Require(liveMap.IsVisibleInTree(), "主场景首页进入地图");
            Find<Control>(liveMap, c => c.Name == "XianCityCard").EmitSignal(Control.SignalName.GuiInput, new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false });
            var liveHub = main.GetNode<XianHub>("UI/XianHub"); Require(liveHub.IsVisibleInTree(), "已通关武汉从地图进入西安首页");
            Find<Button>(liveHub, b => b.Text.StartsWith("Day 1 ·")).EmitSignal(Button.SignalName.Pressed);
            _screen = main.GetNode<XianDayScreen>("UI/XianDayScreen"); _screen.SetProcess(false);
            var liveController = main.GetNode<DayController>("DayController");
            Require(_screen.IsVisibleInTree() && liveController.CurrentConfig?.CityId == StableIds.Cities.Xian && !liveHub.Visible, "西安首页打开真实营业场景");
            Step(4); _screen.Workbench.GetNode<Button>("exit").EmitSignal(Button.SignalName.Pressed);
            double leavingAt = liveController.DayElapsedSeconds; _screen._Process(3);
            Require(liveController.DayElapsedSeconds == leavingAt, "退出确认期间冻结生产与来客");
            Find<ConfirmationDialog>(_screen, _ => true).GetOkButton().EmitSignal(Button.SignalName.Pressed);
            Require(liveHub.IsVisibleInTree() && !_screen.Visible && liveController.State == DayState.Preparing, "确认放弃后返回西安首页");
            GD.Print($"XIAN_VISUAL_RESULT passed={_passed} failed=0 output={_output}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GD.Print($"XIAN_VISUAL_RESULT passed={_passed} failed=1"); GetTree().Quit(1); }
    }
    private static T Find<T>(Node node, Func<T, bool> predicate) where T : Node
    {
        T? Search(Node current)
        {
            if (current is T target && predicate(target)) return target;
            foreach (Node child in current.GetChildren()) if (Search(child) is { } found) return found;
            return null;
        }
        return Search(node) ?? throw new InvalidOperationException($"Missing {typeof(T).Name} in {node.Name}");
    }
    private void Require(bool ok, string name) { if (!ok) throw new InvalidOperationException(name); _passed++; GD.Print("PASS " + name); }
    private void Step(double seconds)
    {
        _screen._Notification((int)NotificationApplicationFocusIn);
        while (seconds > .000001) { double dt = Math.Min(seconds, .1); _screen._Process(dt); seconds -= dt; }
        _screen.Render();
    }
    private Vector2 Position(Vector2 local) => _screen.Workbench.GetGlobalTransformWithCanvas() * local;
    private void Move(Vector2 local, bool held)
    {
        Vector2 p = Position(local); GetViewport().PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p, Relative = p - _lastPointer, ButtonMask = held ? MouseButtonMask.Left : 0 }, true); _lastPointer = p;
    }
    private void Mouse(Vector2 local, bool pressed)
    {
        Vector2 p = Position(local); GetViewport().PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = pressed }, true);
    }
    private async Task Click(Vector2 p) { _screen._Notification((int)NotificationApplicationFocusIn); _screen.Render(); Move(p, false); Mouse(p, true); Mouse(p, false); Step(.001); await Frames(1); }
    private async Task Gesture(Vector2 p, Vector2[] points)
    {
        _screen._Notification((int)NotificationApplicationFocusIn); Move(p, false); Mouse(p, true);
        foreach (var next in points) { Move(next, true); Step(.02); }
        Mouse(points[^1], false); Step(.001); await Frames(1);
    }
    private async Task Drag(Vector2 from, Vector2 to)
    {
        _screen._Notification((int)NotificationApplicationFocusIn); Move(from, false); Mouse(from, true);
        Move(from + new Vector2(30, 0), true); await Frames(2);
        Move(to, true); await Frames(2); Mouse(to, false); Step(.001); await Frames(2);
    }
    private async Task Frames(int count) { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Shot(string name)
    {
        await Frames(3); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string path = ProjectSettings.GlobalizePath($"{_output}/{name}.png"); Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        if (GetViewport().GetTexture().GetImage().SavePng(path) != Error.Ok) throw new IOException(path);
    }
}
