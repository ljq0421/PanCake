using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Guangzhou;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Real viewport input and render QA, using an isolated save and an off-screen window.</summary>
public partial class GuangzhouVisualCapture : Node
{
    private string _output = "";
    private Vector2 _lastPointer;
    private int _checks;
    public override async void _Ready()
    {
        string savePath = Path.Combine(Path.GetTempPath(), "guangzhou-visual-" + Guid.NewGuid().ToString("N") + ".json");
        try
        {
            bool small = OS.GetCmdlineUserArgs().Contains("--capture-720");
            GetWindow().Size = small ? new(1280, 720) : new(1920, 1080);
            GetWindow().Position = new(-10000, -10000);
            _output = ProjectSettings.GlobalizePath($"res://.godot/guangzhou-qa/{(small ? "720" : "1080")}"); Directory.CreateDirectory(_output);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog"); var save = GetNode<SaveService>("/root/SaveService"); save.UsePathForTests(savePath);
            save.Data.Coins = 800; save.Data.Guangzhou.HighestUnlockedDay = 12;
            foreach (string id in GuangzhouRules.Equipment) save.Data.Guangzhou.EquipmentLevels[id] = 2;
            var hub = new GuangzhouHub(); AddChild(hub); hub.Initialize(catalog, save); await Shot("hub"); hub.Free();
            var controller = new DayController(); AddChild(controller);
            var day = new GuangzhouDayScreen(); AddChild(day); day.ConnectController(controller);
            Require(day.Initialize(catalog, save, controller, 9, true), "Day9独立练习初始化"); day.SetProcess(false); day.BeginDay();
            var canvas = day.GetNode<Control>("Canvas");
            void Step(double seconds)
            {
                day._Notification((int)NotificationApplicationFocusIn);
                while (seconds > 1e-8) { double dt = Math.Min(1.0 / 60, seconds); day._Process(dt); seconds -= dt; }
            }
            Vector2 Point(Vector2 design) => canvas.GetGlobalTransformWithCanvas() * design;
            async Task Click(Vector2 design) { await ClickAt(Point(design)); Step(.01); }
            async Task Drag(Vector2 start, params Vector2[] points)
            {
                day._Notification((int)NotificationApplicationFocusIn);
                await PressAt(Point(start));
                foreach (var point in points) { Move(Point(point), true); await Frames(2); }
                Release(); await Frames(2); Step(.01);
            }
            Step(16); await Shot("day9-empty");
            var target = controller.CustomerQueue!.Slots.First(c => c.Progress.CanAccept(ProductKind.RiceRoll) && c.State != CustomerState.Entering);
            string recipe = target.Order.Lines.First(l => l.ProductKind == ProductKind.RiceRoll).DefinitionId;
            var trayView = day.TrayViews[0]; var tray = day.Session.Trays[0];
            Vector2 OnPlate(float x, float y) => trayView.Position + trayView.Plate.Position + trayView.Plate.Size * new Vector2(x, y);
            double startTime = controller.DayElapsedSeconds;
            await Drag(new(223, 948), new(236, 948), OnPlate(.5f, .5f)); Step(.25);
            Require(tray.State == RiceRollState.Spreading, "真实拖拽米浆进入蒸盘");
            await Drag(OnPlate(.12f, .5f), OnPlate(.85f, .5f), OnPlate(.12f, .5f)); Step(1.1);
            Require(tray.SpreadProgress == 1, "真实铺浆手势吸附100%");
            foreach (string ingredient in catalog.RecipesById[recipe].ExtraIngredients)
            {
                int index = Array.IndexOf(GuangzhouRules.Ingredients, ingredient);
                await Click(new(223 + index * 369, 948)); Step(.18);
            }
            Vector2 handle = trayView.Position + trayView.Handle.GetCenter();
            await Drag(handle, handle - new Vector2(0, 65)); Step(.2);
            Require(tray.State == RiceRollState.Steaming, "真实向上推屉");
            Step(2.5); await Shot("day9-steaming");
            await Drag(handle, handle + new Vector2(0, 65)); Step(.25);
            Require(tray.State == RiceRollState.Rolling, "真实向下拉屉");
            await Drag(OnPlate(.05f, .5f), OnPlate(.91f, .5f)); Step(1.35);
            Require(tray.RollProgress == 1, "真实单向刮卷吸附100%"); await Shot("day9-rolled");
            await Click(new(522, 851)); Step(.2); Require(tray.State == RiceRollState.Cut, "点击切段");
            await Click(new(1699, 948)); await Drag(OnPlate(.4f, .5f), OnPlate(.6f, .5f)); Step(.3);
            Require(tray.State == RiceRollState.Ready && tray.RecipeId == recipe, "豉油短划完成正确配方");
            GD.Print($"GUANGZHOU_INPUT_RICE_ROLL_SECONDS {controller.DayElapsedSeconds - startTime:0.00}");
            await Shot("day9-ready");
            int slot = controller.CustomerQueue.Slots.ToList().IndexOf(target);
            await Drag(new(710, 851), new(723, 851), new(270 + slot * 460, 208)); Step(.25);
            Require(tray.State == RiceRollState.Empty && target.Progress.DeliveredItems.Count > 0, "成品拖给真实顾客且库存消费一次");
            await Click(new(150, 458)); Step(4.3); await Click(new(242, 524));
            Require(day.Session.DimSum.Count(GuangzhouRules.SiuMai) == 1, "烧卖通过真实按钮入柜和取出");
            await Click(new(1688, 470)); Step(.3); Require(day.Session.Tea!.HasCup, "早茶真实点击完成取用");
            await Click(new(1610, 56)); double before = controller.DayElapsedSeconds; Step(3); Require(controller.DayElapsedSeconds == before, "暂停按钮冻结营业时间");
            await Shot("paused"); await Click(new(1610, 56));
            day._Notification((int)NotificationApplicationFocusOut); before = controller.DayElapsedSeconds; day._Process(3); Require(controller.DayElapsedSeconds == before, "失焦冻结营业");
            day._Notification((int)NotificationApplicationFocusIn); Step(.1); await Shot("day9-workbench");
            Step(200); Require(controller.State == DayState.Results && day.Practice, "完整收尾与练习结算"); await Shot("results");
            Require(day.Initialize(catalog, save, controller, 12, true), "Day12家庭订单布局初始化"); day.BeginDay();
            bool familyVisible = false;
            for (int i = 0; i < 2300 && controller.State != DayState.Results; i++)
            {
                Step(.1);
                if (controller.CustomerQueue!.Slots.Count == 4 && controller.CustomerQueue.Slots.Any(c => c.Type.Id == "gz_family"))
                { familyVisible = true; break; }
            }
            Require(familyVisible, "四名顾客与家庭大单同时展示"); await Shot("day12-family");
            controller.AbandonDay();
            day.Free(); controller.Free(); await Frames(2);
            save.Data.Cities[StableIds.Cities.Guangzhou] = SaveService.NewGuangzhouProgress();
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate(); AddChild(main); await Frames(3);
            var ui = main.GetNode("UI"); var map = main.GetNode<TianjinMapScreen>("UI/TianjinMapScreen");
            foreach (var control in ui.GetChildren().OfType<Control>()) control.Visible = control == map;
            await Shot("map");
            var entry = map.FindChildren("*", "Button", true, false).OfType<Button>().Single(b => b.Text == "测试直达广州");
            await ClickAt(entry.GetGlobalTransformWithCanvas() * (entry.Size * .5f)); await Frames(3);
            Require(ui.GetChildren().OfType<GuangzhouHub>().Single().Visible && ui.GetChildren().OfType<Control>().Count(c => c.Visible) == 1, "主地图临时入口仅显示广州首页");
            Require(!save.Data.UnlockedCityIds.Contains(StableIds.Cities.Guangzhou), "临时入口不解锁正式广州");
            await Shot("main-guangzhou-hub");
            var mainHub = ui.GetChildren().OfType<GuangzhouHub>().Single();
            var firstDay = mainHub.FindChildren("*", "Button", true, false).OfType<Button>().Single(b => b.Text.StartsWith("DAY 01"));
            await ClickAt(firstDay.GetGlobalTransformWithCanvas() * (firstDay.Size * .5f)); await Frames(3);
            var mainDay = ui.GetChildren().OfType<GuangzhouDayScreen>().Single();
            Require(mainDay.Visible && !mainDay.Practice && mainDay.Session.Config.Day == 1 && mainDay.Session.Trays.Count == 1, "主场景正常进入Day1并使用初始设备");
            Require(ui.GetChildren().OfType<Control>().Count(c => c.Visible) == 1, "广州营业时其他城市界面隐藏");
            await Shot("main-day1");
            GD.Print($"GUANGZHOU_VISUAL_RESULT checks={_checks} resolution={(small ? 720 : 1080)} path={_output}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
        finally { if (File.Exists(savePath)) File.Delete(savePath); }
    }
    private void Require(bool condition, string message)
    { if (!condition) throw new InvalidOperationException(message); _checks++; GD.Print("INPUT_PASS " + message); }
    private async Task Frames(int n) { for (int i = 0; i < n; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Shot(string name)
    {
        await Frames(3); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        var image = GetViewport().GetTexture().GetImage(); Require(!image.IsEmpty(), "渲染图像 " + name);
        image.SavePng(Path.Combine(_output, name + ".png"));
    }
    private void Move(Vector2 point, bool held)
    {
        GetViewport().PushInput(new InputEventMouseMotion { Position = point, GlobalPosition = point, Relative = point - _lastPointer, ButtonMask = held ? MouseButtonMask.Left : 0 }, true);
        _lastPointer = point;
    }
    private async Task PressAt(Vector2 point)
    {
        Move(point, false); GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point, GlobalPosition = point }, true); await Frames(2);
    }
    private void Release() => GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = _lastPointer, GlobalPosition = _lastPointer }, true);
    private async Task ClickAt(Vector2 point) { await PressAt(point); Release(); await Frames(2); }
}
