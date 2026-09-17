using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class BusinessHudSelfTest : Node
{
    public override async void _Ready()
    {
        try
        {
            bool capture = OS.GetCmdlineUserArgs().Contains("--capture");
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests("res://.tmp/hud-review/settings.cfg");
            InterfaceLessons.MarkAllSeen(settings);
            string? selectedCity = OS.GetCmdlineUserArgs().FirstOrDefault(arg => arg.StartsWith("--city="))?.Split('=')[1];
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService();
            save.UsePathForTests("res://.tmp/hud-review/fixture.json"); AddChild(save);
            save.Data.Coins = 5000;
            save.Data.Tianjin.HighestUnlockedDay = 15;
            save.Data.Wuhan.HighestUnlockedDay = save.Data.Xian.HighestUnlockedDay = 12;
            save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 3;
            save.Data.Wuhan.EquipmentLevels["ingredient_station"] = 3;
            save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 3;
            foreach (int width in new[] { 1920, 1280 })
            foreach (string city in new[] { "Tianjin", "Wuhan", "Xian" }.Where(city => selectedCity is null || selectedCity == city))
            {
                var viewport = new SubViewport { Size = new(width, width * 9 / 16),
                    Size2DOverride = new(1920, 1080), Size2DOverrideStretch = true,
                    RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
                AddChild(viewport); viewport.NotifyMouseEntered();
                var controller = new DayController(); AddChild(controller); controller.SetProcess(false);
                var screen = GD.Load<PackedScene>($"res://Scenes/Gameplay/{city}DayScreen.tscn").Instantiate<Control>();
                viewport.AddChild(screen); screen.SetProcess(false);
                switch (screen)
                {
                    case TianjinDayScreen t: t.ConnectController(controller); t.Initialize(catalog, save, controller, 15); t.BeginDay(); break;
                    case WuhanDayScreen w: w.ConnectController(controller); w.Initialize(catalog, save, controller, 12); w.BeginDay(); break;
                    case XianDayScreen x: x.ConnectController(controller); Require(x.Initialize(catalog, save, controller, 12), "Xian initialize"); x.BeginDay(); break;
                }
                controller.Tick(3.1);
                for (int i = 0; i < 30 && controller.CustomerQueue!.Slots.Count < 5; i++) controller.Tick(.5);
                void Refresh()
                {
                    switch (screen) { case TianjinDayScreen t: t.RefreshForCapture(true); break;
                        case WuhanDayScreen w: w.RefreshForCapture(); break; case XianDayScreen x: x.Render(); break; }
                }
                Refresh();
                await Frames();
                var hud = screen.FindChild("BusinessHud", true, false) as BusinessHud ?? throw new Exception("HUD absent");
                Require(hud.IsVisibleInTree(), "HUD visible");
                Require(hud.GetNode<Control>("DaySign").GetGlobalRect().End.X < hud.GetNode<Control>("ProgressSign").GetGlobalRect().Position.X, "separate signs");
                Require(hud.PauseButton.GetGlobalRect().End.X <= 1920, "pause in viewport");
                Require(hud.PauseButton.GetThemeStylebox("focus") is StyleBoxEmpty, "art pause has no rectangular focus frame");
                hud.PauseButton.GrabFocus(); await Frames();
                Require(hud.PauseButton.HasFocus(), "pause remains keyboard focusable");
                if (capture) await Shot(viewport, $"{city}-{width}-focus-pause");
                hud.PauseButton.ReleaseFocus();
                if (screen is XianDayScreen cashScreen)
                {
                    controller.Ledger!.RecordDelivery(new DeliveryEvaluation(DeliveryGrade.Correct, 10, 2, 100, "fixture"));
                    cashScreen.Render(); await Frames();
                    Require(cashScreen.CoinTray.PendingAmount == 12, "Xian income waits for collection");
                    Click(viewport, cashScreen.CoinTray);
                    await Frames();
                    Require(cashScreen.CoinTray.PendingAmount == 0 && controller.Ledger.Build().TotalRevenue == 12, "Xian real coin click collects without changing ledger");
                }
                if (capture) await Shot(viewport, $"{city}-{width}-running");
                var feedback = (BusinessSceneFeedback)screen.FindChild("SceneFeedback", true, false);
                feedback.Clear();
                var order = screen.Descendants<OrderBubbleView>().First(o => o.IsVisibleInTree());
                await Frames();
                foreach (string message in new[] { "开始抹酱。", "煎饼已折叠。", "煎饼已经装袋。", "食物已丢弃。",
                    "切块完成，将自动补入备餐盘。", "已离火，品质锁定；继续沿其余虚线切块。", "提篮，开始沥水。" })
                {
                    feedback.Report(message, false, new Vector2(960, 620));
                    Require(feedback.GetChildCount() == (city == "Xian" ? 1 : 0), "only deliveries show checkmarks in Tianjin and Wuhan");
                    feedback.Clear(); await Frames();
                }
                feedback.Delivery(new DeliveryEvaluation(DeliveryGrade.Correct, 10, 0, 100, "正确"), order);
                Require(feedback.Descendants<TextureRect>().Any(c => c.Texture?.ResourcePath.Contains("正确反馈小勾") == true), "correct delivery retains checkmark");
                if (capture) await Shot(viewport, $"{city}-{width}-correct-delivery");
                feedback.Clear(); await Frames();
                feedback.Delivery(new DeliveryEvaluation(DeliveryGrade.Perfect, 10, 1, 100, "Perfect"), order);
                Require(feedback.Descendants<TextureRect>().Any(c => c.Texture?.ResourcePath.Contains("Perfect 小星章") == true), "perfect delivery retains star");
                feedback.Report("这份餐品不符合订单，请检查配料。", true, screen.GetGlobalTransform() * new Vector2(1300, 620));
                if (capture) await Shot(viewport, $"{city}-{width}-feedback");
                Require(feedback.GetChildren().OfType<Control>().All(c => c.MouseFilter == Control.MouseFilterEnum.Ignore), "feedback does not intercept input");
                Require(feedback.Descendants<TextureRect>().All(c => c.Size.X <= 64 && c.Size.Y <= 64), "large source artwork stays within feedback icon bounds");
                double remaining = controller.DayRemainingSeconds;
                screen._Notification((int)NotificationApplicationFocusIn);
                Click(viewport, hud.PauseButton);
                controller.Tick(2);
                Require(controller.IsPaused && controller.DayRemainingSeconds == remaining, "pause freezes time");
                await Frames(); Require(feedback.GetChildCount() == 0, "pause clears scene feedback");
                var pausePanel = city switch
                {
                    "Tianjin" => screen.FindChild("PausePanel", true, false) as Control,
                    "Wuhan" => screen.FindChild("HudPausePanel", true, false) as Control,
                    _ => screen.GetNode<Control>("Workbench/PauseMenu/Panel"),
                };
                Require(pausePanel?.GetThemeStylebox("panel") is StyleBoxTexture
                    && (city is "Tianjin" or "Wuhan"
                        ? pausePanel.GetNode<Control>("IllustratedContents").GetChildren().OfType<Label>().Any(label => label.IsVisibleInTree() && label.Text.Length > 0)
                        : screen.FindChild(city + "PauseTitleTape", true, false) is Control { Visible: true }),
                    "pause uses the shared illustrated panel treatment");
                if (capture) await Shot(viewport, $"{city}-{width}-paused");
                if (screen is WuhanDayScreen)
                {
                    var resume = screen.FindChild("HudPauseMenu", true, false)!.Descendants<Button>().First(b => b.Text == "继续营业");
                    controller.SetPauseReason("test-focus", true); resume.EmitSignal(Button.SignalName.Pressed);
                    Require(controller.IsPaused, "resume preserves another pause reason");
                    controller.SetPauseReason("test-focus", false);
                }
                else if (screen is TianjinDayScreen) screen.FindButton("继续营业").EmitSignal(Button.SignalName.Pressed);
                else screen.GetNode<Button>("Workbench/PauseMenu/Panel/resume").EmitSignal(Button.SignalName.Pressed);
                Require(!controller.IsPaused, "resume works");
                controller.Tick(.25); Require(controller.DayRemainingSeconds < remaining, "time resumes");
                if (screen is WuhanDayScreen restartScreen)
                {
                    Click(viewport, hud.PauseButton);
                    Require(controller.IsPaused, "Wuhan can pause again");
                    restartScreen.Initialize(catalog, save, controller, 12);
                    Require(!controller.IsPaused && !screen.GetNode<Control>("HudPauseMenu").Visible, "Wuhan reinitialization clears its own manual pause");
                }
                viewport.QueueFree(); controller.QueueFree(); await Frames();
                GD.Print($"HUD_PASS {city} {width}");
            }
            GD.Print("BUSINESS_HUD_TEST_PASS"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private static void Require(bool condition, string message) { if (!condition) throw new Exception(message); }
    private static void Click(Viewport viewport, Control control)
    {
        Vector2 p = control.GetGlobalRect().GetCenter();
        viewport.PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p }, true);
        viewport.PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = true }, true);
        viewport.PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = false }, true);
    }
    private async Task Frames() { for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Shot(SubViewport viewport, string name)
    {
        await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string directory = ProjectSettings.GlobalizePath("res://.tmp/hud-review"); Directory.CreateDirectory(directory);
        Error result = viewport.GetTexture().GetImage().SavePng(Path.Combine(directory, name + ".png"));
        Require(result == Error.Ok, "screenshot saved");
    }
}
