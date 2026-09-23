using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class ButtonHoverSelfTest : Node
{
    private const string Output = "res://artifacts/button-hover";
    private SubViewport _viewport = null!;
    private int _checks;
    private void Require(bool value, string message)
    { if (!value) throw new Exception(message); _checks++; }
    private async Task Frames(int count = 5)
    { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Settle()
    { await ToSignal(GetTree().CreateTimer(.22), SceneTreeTimer.SignalName.Timeout); await Frames(); }
    private void Move(Vector2 point) => _viewport.PushInput(new InputEventMouseMotion { Position = point, GlobalPosition = point }, true);
    private async Task Shot(string name)
    {
        if (DisplayServer.GetName() == "headless") return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = _viewport.GetTexture().GetImage();
        Require(image.SavePng(ProjectSettings.GlobalizePath(Output + "/" + name + ".png")) == Error.Ok, "capture " + name);
    }
    private async Task CheckHover(BaseButton button, string name, Control? visual = null)
    {
        visual ??= button;
        Require(button.GetNodeOrNull<ButtonHoverFeedback>("ButtonHoverFeedback") is not null, name + " attached");
        // Reproduce the default focus on Continue and the selected map node.
        button.GrabFocus(); Move(new(1918, 1078)); await Settle();
        Require(visual.Scale.IsEqualApprox(Vector2.One), name + " focus leaves room for hover feedback");
        Vector2 rest = visual.Scale, position = visual.Position;
        Vector2 center = visual.GetGlobalTransform() * (visual.Size * .5f);
        Move(button.GetGlobalTransform() * (button.Size * .5f)); await Settle();
        Require(button.IsHovered(), name + " receives native hover");
        Require(visual.Scale.IsEqualApprox(rest * 1.04f), name + " grows uniformly");
        Require(visual.Position.IsEqualApprox(position), name + " does not move up");
        Require((visual.GetGlobalTransform() * (visual.Size * .5f)).DistanceTo(center) < .05f, name + " center fixed");
        await Shot(name + "-hover");
        // Interrupt the animation repeatedly, then leave; no accumulation or stale tween.
        for (int i = 0; i < 4; i++) { Move(new(1918, 1078)); await Frames(1); Move(button.GetGlobalRect().GetCenter()); await Frames(1); }
        Move(new(1918, 1078)); await Settle();
        Require(visual.Scale.IsEqualApprox(rest), name + " exit restores scale");
        button.GrabFocus(); await Settle();
        Require(visual.Scale.IsEqualApprox(rest), name + " retained keyboard focus does not latch hover");
        Move(button.GetGlobalRect().GetCenter()); await Settle();
        button.Disabled = true; await Frames();
        Require(visual.Scale.IsEqualApprox(rest), name + " disabled resets");
        button.Disabled = false; button.ReleaseFocus(); await Settle();
    }

    private void CheckMenuCoverage(Node root)
    {
        foreach (var button in root.Descendants<BaseButton>())
            if (button.GetSignalConnectionList(BaseButton.SignalName.Pressed).Count > 0)
                Require(button.GetNodeOrNull<ButtonHoverFeedback>("ButtonHoverFeedback") is not null,
                    "menu click coverage: " + button.GetPath());
    }

    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            GetWindow().Position = new(-10000, -10000);
            var save = GetNode<SaveService>("/root/SaveService");
            save.UsePathForTests(Output + "/fixture.json"); Require(save.ResetProgress(out _), "isolated save");
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(ProjectSettings.GlobalizePath(Output + "/settings.cfg"));
            InterfaceLessons.MarkAllSeen(settings);
            save.Data.Coins = 10000;
            foreach (string city in new[] { "tianjin", "wuhan", "xian", "guangzhou", "yangzhou" })
            { string id = "city:" + city; if (!save.Data.UnlockedCityIds.Contains(id)) save.Data.UnlockedCityIds.Add(id); save.Data.GetCity(id).HighestUnlockedDay = 1; }
            Require(save.TrySave(out _), "fixture saved");
            _viewport = new SubViewport { Size = new(1920, 1080), GuiEmbedSubwindows = true, RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
            AddChild(_viewport); _viewport.NotifyMouseEntered();
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
            _viewport.AddChild(main);
            await Frames(); // Navigation transitions may reorder root children after scene setup.
            var start = main.GetNode<StartScreen>("UI/StartScreen"); start.PresentHome(); await Settle();
            foreach (var menu in main.GetNode("UI").GetChildren().Where(n => n is not
                (TianjinDayScreen or WuhanDayScreen or XianDayScreen or GuangzhouDayScreen or YangzhouDayScreen or XianHub)))
                CheckMenuCoverage(menu);
            if (OS.GetCmdlineUserArgs().Contains("--scope-check-only"))
            {
                start.Hide();
                var excluded = main.GetNode("UI").GetChildren().OfType<XianHub>().Single();
                excluded.Show(); await Settle();
                var originalButton = excluded.Descendants<Button>().First(b => b.IsVisibleInTree() && !b.Disabled);
                Move(new(1918, 1078)); originalButton.GrabFocus(); await Settle();
                Require(originalButton.Scale.IsEqualApprox(Vector2.One * 1.04f), "Xi'an keeps its preexisting focus scale");
                originalButton.ReleaseFocus(); excluded.Hide();
                var legacy = main.GetNode("UI").GetChildren().OfType<TianjinMapScreen>().Single();
                save.Data.Tianjin.Completed = true; legacy.Show(); await Frames();
                var card = legacy.Descendants<PanelContainer>().First(c => c.GetMeta("_scene_bindings", Array.Empty<string>())
                    .AsStringArray().Any(binding => binding.EndsWith("|_tianjinCard")));
                Move(card.GetGlobalRect().GetCenter()); await Settle();
                Require(card.Scale.IsEqualApprox(Vector2.One * 1.04f), "native card hover coexists with reveal");
                await ToSignal(GetTree().CreateTimer(.8), SceneTreeTimer.SignalName.Timeout);
                Require(card.Scale.IsEqualApprox(Vector2.One * 1.04f), "reveal does not reset card hover");
                Move(new(1918, 1078)); await Settle();
                Require(card.Scale.IsEqualApprox(Vector2.One), "native card exits hover");
                legacy.Hide(); start.PresentHome(); await Settle();
                await CheckHover(start.Descendants<Button>().First(b => b.Name == "Continue"), "home");
                GD.Print($"BUTTON_HOVER_SCOPE_CHECK_OK checks={_checks}"); GetTree().Quit(); return;
            }
            var home = start.Descendants<Button>().First(b => b.Name == "Continue");
            if (OS.GetCmdlineUserArgs().Contains("--audio-only"))
            {
                await CheckAudio(start, home, settings);
                GD.Print($"BUTTON_HOVER_AUDIO_OK checks={_checks}"); GetTree().Quit(); return;
            }
            Require(home.HasFocus(), "Continue has production default focus");
            Move(new(1918, 1078)); await Settle(); await Shot("home-rest");
            await CheckHover(home, "home");
            foreach (string name in new[] { "NewGame", "BreakfastRecords", "WorldMap", "Settings", "Help", "Quit" })
                await CheckHover(start.Descendants<Button>().First(b => b.Name == name), "home-" + name);
            start.PresentMap(); await Settle();
            Require(start.Descendants<Button>().Any(b => b.Name.ToString().StartsWith("Node") && b.HasFocus()), "map has production default focus");
            await Shot("map-rest");
            foreach (var node in start.Descendants<Button>().Where(b => b.Name.ToString().StartsWith("Node")).ToArray())
            {
                Move(node.GetGlobalRect().GetCenter()); await Settle();
                Require(node.IsHovered() && node.GetNode<Control>("Art/Highlight").Visible, "map marker highlights on hover");
                Require(node.Scale.IsEqualApprox(Vector2.One), "map marker keeps leader attached");
            }
            start.PresentHome(); await Settle();
            var settingsButton = start.Descendants<Button>().First(b => b.Name == "Settings");
            settingsButton.EmitSignal(BaseButton.SignalName.Pressed); await Settle();
            await CheckHover(start.Descendants<Button>().First(b => b.Name == "Windowed"), "settings");
            CheckMenuCoverage(start);
            foreach (var slider in start.Descendants<HSlider>())
            {
                Move(new(1918, 1078)); await Settle();
                var position = slider.Position;
                Move(slider.GetGlobalRect().GetCenter()); await Settle();
                Require(slider.Scale.IsEqualApprox(Vector2.One * 1.04f) && slider.Position == position, slider.Name + " centered hover");
                slider.Editable = false; await Frames();
                Require(slider.Scale.IsEqualApprox(Vector2.One), slider.Name + " unavailable resets");
                slider.Editable = true;
            }
            start.Descendants<Button>().First(b => b.Name == "Close" && b.IsVisibleInTree()).EmitSignal(BaseButton.SignalName.Pressed);
            foreach (string city in new[] { "tianjin", "wuhan", "guangzhou", "yangzhou" })
            {
                Require(main.StartCityBusiness("city:" + city, 1), city + " started"); await Settle();
                var screen = main.GetNode<Control>("UI/" + char.ToUpperInvariant(city[0]) + city[1..] + "DayScreen");
                screen._Notification((int)NotificationApplicationFocusIn);
                await Settle();
                screen.SetProcess(false);
                main.GetNode<DayController>("DayController").SetProcess(false);
                var hud = screen.Descendants<BusinessHud>().First();
                var pause = hud.PauseButton.IsVisibleInTree() ? hud.PauseButton
                    : screen.Descendants<Button>().First(b => b.IsVisibleInTree() && b.Text == "暂停");
                await CheckHover(pause, city + "-pause");
                foreach (var entry in screen.Descendants<Button>().Where(b => b.Name == "OpenBusinessBook" && b.IsVisibleInTree()))
                    await CheckHover(entry, city + "-book-entry");
                if (screen is TianjinDayScreen t)
                {
                    await CheckHover(t.CashPendant, "tianjin-pendant", t.GetNode<Control>("LivingWorkbench/PendantHover"));
                    main.GetNode<DayController>("DayController").Tick(3.1);
                    t.RefreshForCapture(true);
                    var living = t.GetNode<TianjinLivingWorkbench>("LivingWorkbench");
                    Move(t.CashPendant.GetGlobalRect().GetCenter()); await Settle();
                    living.ReceivePayment();
                    await ToSignal(GetTree().CreateTimer(.06), SceneTreeTimer.SignalName.Timeout);
                    Require(Math.Abs(living.PendantRotation) > .01f && Math.Abs(living.PendantRotation) <= 4.01f, "payment swing coexists with hover");
                    Require(living.GetNode<Control>("PendantHover").Scale.IsEqualApprox(Vector2.One * 1.04f), "payment preserves hover scale");
                    await ToSignal(GetTree().CreateTimer(.5), SceneTreeTimer.SignalName.Timeout);
                    Require(Math.Abs(living.PendantRotation) < .01f, "payment swing settles");
                }
                if (screen is WuhanDayScreen w)
                    await CheckHover(w.CashPendant, "wuhan-pendant", w.CashPendantArtwork);
                Require(!screen.Descendants<ProjectCake.Interaction.ClickInteractable>().Any(b => b.GetNodeOrNull<ButtonHoverFeedback>("ButtonHoverFeedback") is not null), city + " ingredients unchanged");
            }
            GD.Print($"BUTTON_HOVER_SELF_TEST_OK checks={_checks}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
