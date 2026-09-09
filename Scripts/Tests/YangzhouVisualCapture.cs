using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class YangzhouVisualCapture : Node
{
    private YangzhouDayScreen _screen = null!;
    private Vector2 _pointer;
    private int _passed;
    private string _output = "";
    public override async void _Ready()
    {
        try
        {
            bool small = OS.GetCmdlineUserArgs().Contains("--capture-720");
            GetWindow().Size = small ? new(1280, 720) : new(1920, 1080); GetWindow().Position = new(-10000, -10000);
            _output = ProjectSettings.GlobalizePath($"res://.tmp/yangzhou-visual/{(small ? "720" : "1080")}"); Directory.CreateDirectory(_output);
            var catalog = YangzhouCatalog.Load(); var save = GetNode<SaveService>("/root/SaveService"); save.UsePathForTests(_output + $"/capture-{Guid.NewGuid():N}.json");
            save.Data.Yangzhou.HighestUnlockedDay = 12; save.Data.Coins = 1000;
            var hub = ProjectCake.Core.SceneFactory.Instantiate<YangzhouHub>("res://Scenes/UI/YangzhouHub.tscn"); AddChild(hub); hub.Initialize(catalog, save); await Shot("01-hub"); hub.Hide();
            _screen = ProjectCake.Core.SceneFactory.Instantiate<YangzhouDayScreen>("res://Scenes/Gameplay/YangzhouDayScreen.tscn"); AddChild(_screen); _screen.SetProcess(false);
            Require(_screen.Initialize(catalog, save, 1), "Day1初始化"); await Frames(2); Step(15);
            Move(new(730, 580), false); Mouse(new(730, 580), true);
            for (int i = 0; i < 240 && _screen.Session.Kitchen.Board.Portions == 0; i++)
            {
                await ToSignal(GetTree().CreateTimer(.02), SceneTreeTimer.SignalName.Timeout);
                Move(new(i % 2 == 0 ? 820 : 670, 580), true); Step(.02);
            }
            Mouse(new(730, 580), false);
            Require(_screen.Session.Kitchen.Board.Portions == 4, "真实按住往复切丝产生4份库存");
            await Drag(new(730, 825), new(1160, 565));
            Require(_screen.Session.Kitchen.Scald.Loaded && _screen.Session.Kitchen.Board.Portions == 3, "原生拖拽备料进入漏勺");
            Move(new(1150, 570), false); Mouse(new(1150, 570), true);
            for (int i = 0; i < 3; i++) { Move(new(1150, 690), true); Step(.31); Move(new(1150, 570), true); Step(.05); }
            Mouse(new(1150, 570), false);
            Require(_screen.Session.Kitchen.Scald.Dips == 3, "真实下压提起三次手势");
            await Click(new(1160, 835)); Step(.31);
            Require(_screen.Session.Kitchen.Scald.Ready, "调味按钮等待0.3秒产出成品"); await Shot("02-day1-gansi");
            await Drag(new(1160, 565), new(1630, 750));
            Require(_screen.Session.Selected?.Complete == true && _screen.Session.Served.Count == 0, "拖入托盘后等待明确整套出餐");
            await Click(new(1640, 943)); Require(_screen.Session.Served.Count == 1, "点击整套出餐服务顾客");
            await Click(new(1580, 58)); double before = _screen.Session.Elapsed; Step(4);
            Require(_screen.Session.Paused && before == _screen.Session.Elapsed, "暂停冻结游戏");
            await Click(new(1580, 58)); Step(.1); Require(!_screen.Session.Paused && _screen.Session.Elapsed > before, "继续营业恢复");
            _screen._Notification((int)NotificationApplicationFocusOut); before = _screen.Session.Elapsed; _screen._Process(4);
            Require(before == _screen.Session.Elapsed && _screen.Session.Paused, "失焦自动暂停且需要明确继续");
            _screen._Notification((int)NotificationApplicationFocusIn); _screen.Session.Pause(false);
            save.Data.Yangzhou.EquipmentLevels[YangzhouCatalog.BoardId] = 3; save.Data.Yangzhou.EquipmentLevels[YangzhouCatalog.SteamerId] = 3;
            Require(_screen.Initialize(catalog, save, 12), "Day12双层初始化"); Step(5.1);
            await Click(new(120, 654)); await Click(new(430, 654)); Step(6.1); await Click(new(430, 654)); await Click(new(430, 654));
            Require(_screen.Session.Kitchen.Buns.Count == 2, "实际按钮装笼、盖笼、揭盖、出笼");
            await Drag(new(985, 1004), new(275, 755));
            Require(_screen.Session.Kitchen.Steamers[1].Quantity == 1 && _screen.Session.Kitchen.Steamers[1].ProductId == "B02", "原生拖拽单个烧卖生坯装入第二层");
            Step(45); await Shot("03-day12-four-tables");
            Require(_screen.Session.Waiting.Count == 4, "四桌订单同时显示");
            Step(150); Require(_screen.Session.Phase == YangzhouPhase.Results, "最终日自动结束并结算"); await Shot("04-results");
            if (OS.GetCmdlineUserArgs().Contains("--dev-ui"))
            {
                string beforePractice = System.Text.Json.JsonSerializer.Serialize(save.Data);
                Require(_screen.Initialize(catalog, save, 8, true), "开发模式允许Day8练习"); Step(200);
                Require(beforePractice == System.Text.Json.JsonSerializer.Serialize(save.Data), "练习完成不改变真实存档");
            }
            else Require(!_screen.Initialize(catalog, save, 8, true), "正常模式拒绝开发练习入口");
            _screen.Hide(); save.Data.Guangzhou.Completed = true; save.Data.Guangzhou.BestStars = 1; save.TrySave(out _); save.Load();
            var map = ProjectCake.Core.SceneFactory.Instantiate<TianjinMapScreen>("res://Scenes/UI/TianjinMapScreen.tscn"); AddChild(map); map.Initialize(save); await Shot("05-map");
            Require(!Find<Button>(map, b => b.Name == "EnterYangzhou").Disabled, "广州一星后地图扬州入口开放");
            map.Free(); hub.Free(); _screen.Free();
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate(); AddChild(main); await Frames(2);
            var morning = main.GetNode<MorningHub>("UI/MorningHub"); Find<Button>(morning, b => b.Text.Contains("地图")).EmitSignal(Button.SignalName.Pressed);
            var liveMap = main.GetNode<TianjinMapScreen>("UI/TianjinMapScreen"); Find<Button>(liveMap, b => b.Name == "EnterYangzhou").EmitSignal(Button.SignalName.Pressed);
            var liveHub = main.GetNode<YangzhouHub>("UI/YangzhouHub"); Require(liveHub.IsVisibleInTree(), "主场景地图进入扬州首页");
            Find<Button>(liveHub, b => b.Name == "Day1").EmitSignal(Button.SignalName.Pressed);
            _screen = main.GetNode<YangzhouDayScreen>("UI/YangzhouDayScreen"); _screen.SetProcess(false);
            Require(_screen.IsVisibleInTree() && !liveHub.Visible, "主场景打开扬州营业并隐藏首页");
            Find<Button>(_screen, b => b.Name == "Exit").EmitSignal(Button.SignalName.Pressed); await Frames(2);
            Require(_screen.Session.Paused, "退出确认暂停游戏");
            Find<ConfirmationDialog>(_screen, _ => true).EmitSignal(ConfirmationDialog.SignalName.Confirmed);
            Require(liveHub.IsVisibleInTree() && !_screen.Visible, "确认放弃回到扬州首页");
            GD.Print($"YANGZHOU_VISUAL_RESULT passed={_passed} failed=0 output={_output}"); GetTree().Quit();
        }
        catch (Exception exception) { GD.PushError(exception.ToString()); GD.Print($"YANGZHOU_VISUAL_RESULT passed={_passed} failed=1"); GetTree().Quit(1); }
    }
    private static T Find<T>(Node node, Func<T, bool> predicate) where T : Node
    {
        if (node is T found && predicate(found)) return found;
        foreach (var child in node.GetChildren()) { try { return Find<T>(child, predicate); } catch (KeyNotFoundException) { } }
        throw new KeyNotFoundException(typeof(T).Name);
    }
    private void Require(bool condition, string name) { if (!condition) throw new InvalidOperationException(name); _passed++; GD.Print("PASS " + name); }
    private void Step(double dt) { _screen._Notification((int)NotificationApplicationFocusIn); _screen._Process(dt); }
    private Vector2 Point(Vector2 design) => _screen.GetNode<Control>("Canvas").GetGlobalTransformWithCanvas() * design;
    private void Move(Vector2 design, bool held)
    {
        var point = Point(design); GetViewport().PushInput(new InputEventMouseMotion { Position = point, GlobalPosition = point, Relative = point - _pointer, ButtonMask = held ? MouseButtonMask.Left : 0 }, true); _pointer = point;
    }
    private void Mouse(Vector2 design, bool pressed)
    {
        var point = Point(design); GetViewport().PushInput(new InputEventMouseButton { Position = point, GlobalPosition = point, ButtonIndex = MouseButton.Left, Pressed = pressed }, true);
    }
    private async Task Click(Vector2 at) { Move(at, false); Mouse(at, true); Mouse(at, false); Step(.001); await Frames(2); }
    private async Task Drag(Vector2 from, Vector2 to)
    {
        Move(from, false); Mouse(from, true); Move(from + new Vector2(35, 0), true); await Frames(2); Move(to, true); await Frames(2); Mouse(to, false); Step(.001); await Frames(2);
    }
    private async Task Frames(int count) { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Shot(string name)
    {
        await Frames(3); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        if (GetViewport().GetTexture().GetImage().SavePng(Path.Combine(_output, name + ".png")) != Error.Ok) throw new IOException(name);
    }
}
