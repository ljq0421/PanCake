using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.UI;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class BusinessHudSelfTest : Node
{
    public override async void _Ready()
    {
        try
        {
            bool capture = OS.GetCmdlineUserArgs().Contains("--capture");
            bool hudOnly = OS.GetCmdlineUserArgs().Contains("--hud-only");
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
                foreach (var close in screen.Descendants<Button>().Where(b => b.IsVisibleInTree() && b.Text == "本次关闭").ToArray())
                    close.EmitSignal(Button.SignalName.Pressed);
                Refresh(); await Frames();
                if (hudOnly && city is "Tianjin" or "Wuhan")
                {
                    foreach (var skip in screen.Descendants<Button>().Where(b => b.IsVisibleInTree() && b.Text == "跳过教学").ToArray())
                        skip.EmitSignal(Button.SignalName.Pressed);
                    Refresh(); await Frames();
                }
                var hud = screen.FindChild("BusinessHud", true, false) as BusinessHud ?? throw new Exception("HUD absent");
                Require(hud.IsVisibleInTree(), "HUD visible");
                CheckArtwork(hud);
                if (city is "Tianjin" or "Wuhan")
                {
                    int target = BusinessRevenueGoal.Target(controller.CurrentConfig!, controller.CurrentPlan!);
                    Require(hud.GetNode<Label>("HudArtwork/IncomeSign").Text == $"0/{target}",
                        "coin column shows current revenue over this run's goal");
                    Require(hud.FindChild("RevenueGoal", true, false) is null,
                        "goal does not create a separate strip below the HUD");
                }
                if (hudOnly)
                {
                    if (capture) await Shot(viewport, $"{city}-{width}-running");
                    await CheckChallengePendant(screen, hud, controller, viewport, city, width, capture);
                    viewport.QueueFree(); controller.QueueFree(); await Frames();
                    GD.Print($"HUD_PASS {city} {width}");
                    continue;
                }
                Require(hud.PauseButton.Size == new Vector2(84, 84), "pause uses the 1.5x display size");
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
                    screen._Notification((int)NotificationApplicationFocusIn);
                    feedback.Report(message, false, new Vector2(960, 620));
                    Require(feedback.GetChildCount() == (city == "Xian" ? 1 : 0), "only deliveries show checkmarks in Tianjin and Wuhan");
                    feedback.Clear(); await Frames();
                }
                screen._Notification((int)NotificationApplicationFocusIn);
                feedback.Delivery(new DeliveryEvaluation(DeliveryGrade.Correct, 10, 0, 100, "正确"), order);
                Require(feedback.Descendants<TextureRect>().Any(c => c.Texture?.ResourcePath.Contains("正确反馈小勾") == true), "correct delivery retains checkmark");
                if (capture) await Shot(viewport, $"{city}-{width}-correct-delivery");
                feedback.Clear(); await Frames();
                screen._Notification((int)NotificationApplicationFocusIn);
                feedback.Delivery(new DeliveryEvaluation(DeliveryGrade.Perfect, 10, 1, 100, "Perfect"), order);
                Require(feedback.Descendants<TextureRect>().Any(c => c.Texture?.ResourcePath.Contains("Perfect 小星章") == true), "perfect delivery retains star");
                feedback.Report("这份餐品不符合订单，请检查配料。", true, screen.GetGlobalTransform() * new Vector2(1300, 620));
                if (capture) await Shot(viewport, $"{city}-{width}-feedback");
                ulong feedbackClock = 1000;
                feedback.Clock = () => feedbackClock;
                feedback.Clear();
                await Frames();
                feedback.Report("请先完成餐品。", true, new Vector2(960, 620));
                feedback.Report("请先完成餐品。", true, new Vector2(960, 620));
                Require(feedback.GetChildCount() == 1, "repeated mistakes show only one cross");
                feedbackClock += BusinessSceneFeedback.ErrorIntervalMs;
                feedback.Report("请先完成餐品。", true, new Vector2(960, 620));
                Require(feedback.GetChildCount() == 2, "cross can reappear after cooldown");
                feedback.Clock = Time.GetTicksMsec;
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
                        : pausePanel.GetNode<Label>("Title").IsVisibleInTree()),
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
            await CheckRemainingCities(catalog, save, capture, selectedCity, hudOnly);
            GD.Print("BUSINESS_HUD_TEST_PASS"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private static void Require(bool condition, string message) { if (!condition) throw new Exception(message); }
    private static void CheckArtwork(BusinessHud hud)
    {
        var art = hud.GetNode<TextureRect>("HudArtwork");
        Require(art.Texture is AtlasTexture { Atlas.ResourcePath: BusinessHud.ArtworkPath }, "shared HUD artwork");
        Require(Math.Abs(art.GetGlobalRect().GetCenter().X - 960) < 1, "HUD centered");
        Require(art.GetGlobalRect().End.Y <= 108, "HUD clears customer row and hints");
        var atlas = (AtlasTexture)art.Texture;
        Require(new Rect2(Vector2.Zero, atlas.Atlas.GetSize()).Encloses(atlas.Region), "HUD atlas stays inside current source image");
        Require(Math.Abs(art.Size.X / art.Size.Y - atlas.Region.Size.X / atlas.Region.Size.Y) < .001f, "artwork keeps aspect ratio");
        Require(art.GetChildren().OfType<Label>().Count() == 3, "only day, clock and income remain");
        foreach (var label in art.GetChildren().OfType<Label>())
        {
            // Read actual source-space bounds, catching stale label coordinates after an asset replacement.
            float scale = art.Size.X / atlas.Region.Size.X;
            Rect2 source = new(label.Position / scale + atlas.Region.Position, label.Size / scale);
            Rect2 safe = label.Name.ToString() switch
            {
                "DaySign" => new(512, 335, 200, 150),
                "TimeSign" => new(949, 335, 224, 150),
                _ => new(1400, 335, 275, 150),
            };
            Require(safe.Encloses(source), "HUD number clears source icons, separators and side ornaments");
            Require(art.GetGlobalRect().Encloses(label.GetGlobalRect()), "HUD text stays inside artwork");
            Require(label.GetThemeFont("font").GetStringSize(label.Text, fontSize: label.GetThemeFontSize("font_size")).X <= label.Size.X,
                "HUD number fits its region");
        }
        Require(!InterfaceLessons.Business.Any(lesson => lesson.Target == "ProgressSign"), "teaching no longer refers to order progress");
    }

    private async Task CheckRemainingCities(DataCatalog catalog, SaveService save, bool capture, string? selectedCity, bool hudOnly)
    {
        save.Data.Guangzhou.HighestUnlockedDay = save.Data.Yangzhou.HighestUnlockedDay = 12;
        foreach (int width in new[] { 1920, 1280 })
        foreach (string city in new[] { "Guangzhou", "Yangzhou" }.Where(city => selectedCity is null || selectedCity == city))
        {
            var viewport = new SubViewport { Size = new(width, width * 9 / 16), Size2DOverride = new(1920, 1080),
                Size2DOverrideStretch = true, RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
            AddChild(viewport); viewport.NotifyMouseEntered();
            var controller = new DayController(); AddChild(controller); controller.SetProcess(false);
            var screen = GD.Load<PackedScene>($"res://Scenes/Gameplay/{city}DayScreen.tscn").Instantiate<Control>();
            viewport.AddChild(screen); screen.SetProcess(false);
            if (screen is GuangzhouDayScreen g)
            { Require(g.Initialize(catalog, save, controller, 12), "Guangzhou initialize"); g.BeginDay(); }
            else Require(((YangzhouDayScreen)screen).Initialize(YangzhouCatalog.Load(), save, 12), "Yangzhou initialize");
            void Step(double seconds) { screen._Notification((int)NotificationApplicationFocusIn); screen._Process(seconds); }
            double Remaining() => screen is YangzhouDayScreen y ? y.Session.Elapsed : controller.DayElapsedSeconds;
            Step(6); await Frames();
            var hud = (BusinessHud)screen.FindChild("BusinessHud", true, false);
            CheckArtwork(hud);
            Require(hud.IsVisibleInTree() && !hud.PauseButton.IsVisibleInTree(), "shared art retains native city pause control");
            if (capture) await Shot(viewport, $"{city}-{width}-running");
            if (hudOnly)
            {
                viewport.QueueFree(); controller.QueueFree(); await Frames();
                GD.Print($"HUD_PASS {city} {width}");
                continue;
            }
            Button pause = screen.FindButton("暂停");
            Click(viewport, pause); Step(0); double before = Remaining(); Step(2);
            Require(Remaining() == before, "city pause freezes time");
            Click(viewport, pause); Step(.25); Require(Remaining() > before, "city resume advances time");
            var book = (Button)screen.FindChild("OpenBusinessBook", true, false);
            Require(!book.GetGlobalRect().Intersects(hud.GetNode<Control>("HudArtwork").GetGlobalRect()), "book remains outside HUD artwork");
            Click(viewport, book); await Frames();
            var details = (BusinessDetailsView)screen.FindChild("BusinessDetails", true, false);
            Require(details.Visible, "book remains clickable");
            before = Remaining(); Step(2); Require(Remaining() == before, "book freezes time");
            viewport.QueueFree(); controller.QueueFree(); await Frames();
            GD.Print($"HUD_PASS {city} {width}");
        }
    }
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
