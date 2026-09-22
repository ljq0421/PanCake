using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class WuhanCustomersSelfTest : Node
{
    private int _checks;
    private const string Output = "res://output/wuhan-customers";
    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        _checks++;
    }

    public override async void _Ready()
    {
        try
        {
            bool capture = OS.GetCmdlineUserArgs().Contains("--capture");
            var art = new WuhanArtCatalog();
            Check(art.MissingRequiredAssets().Count == 0, "Wuhan assets load");
            Check(CustomerAppearanceCatalog.All.Count == 34 && CustomerAppearanceCatalog.Wuhan.Count == 10, "appearance counts");
            foreach (string type in new[] { "normal", "office_worker", "regular", "big_order" })
            {
                var original = CustomerAppearanceCatalog.CandidatesFor(type);
                var wuhan = CustomerAppearanceCatalog.CandidatesFor("wuhan_" + type);
                Check(original.Where(CustomerAppearanceCatalog.Generic.Contains).All(wuhan.Contains), "generic pool retained: " + type);
                Check(wuhan.All(id => CustomerAppearanceCatalog.Generic.Contains(id) || CustomerAppearanceCatalog.Wuhan.Any(a => a.Id == id)), "no Tianjin-specific customers: " + type);
                Check(original.All(id => !id.StartsWith("wuhan_")), "Wuhan excluded from Tianjin: " + type);
                var seen = new HashSet<string>();
                for (int seed = 0; seed < 400; seed++)
                    seen.Add(CustomerAppearanceCatalog.Select("wuhan_" + type, seed, "customer" + seed));
                Check(wuhan.All(seen.Contains), "every candidate reachable: " + type);
                var unavailable = wuhan.Take(wuhan.Count - 1).ToHashSet();
                Check(!unavailable.Contains(CustomerAppearanceCatalog.Select("wuhan_" + type, 42, "test", unavailable)), "avoid duplicate appearance");
            }
            foreach (var appearance in CustomerAppearanceCatalog.Wuhan)
            {
                var visuals = Enum.GetValues<CustomerExpression>().Select(e => art.CustomerPortrait(appearance.Id, e)).ToArray();
                Check(visuals.Select(v => v.Head).Distinct().Count() == 4 && visuals.All(v => v.Body == visuals[0].Body), "four heads, one body: " + appearance.Id);
                var layout = art.CustomerLayout(appearance.Id);
                foreach (var visual in visuals)
                {
                    Check(visual.Head.GetWidth() == 1086 && visual.Head.GetHeight() == 1448, "canvas: " + appearance.Id);
                    using var image = visual.Head.GetImage();
                    var bounds = image.GetUsedRect();
                    Check(bounds.Position.X > 0 && bounds.Position.Y > 0 && bounds.End.X < 1086 && bounds.End.Y < 1448, "head not clipped: " + appearance.Id);
                    float area = bounds.Size.X * bounds.Size.Y;
                    float normal = layout.NormalVisibleBounds.Size.X * layout.NormalVisibleBounds.Size.Y;
                    Check(area / normal is > .90f and < 1.10f, "stable expression size: " + appearance.Id);
                }
            }

            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Output + "/settings.cfg"); InterfaceLessons.MarkAllSeen(settings);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService(); save.UsePathForTests(Output + "/test-save.json"); AddChild(save);
            save.Data.Wuhan.HighestUnlockedDay = 12;
            save.Data.Wuhan.LearnedWorkbenchActions.Add("take:noodles");
            var controller = new DayController(); AddChild(controller); controller.SetProcess(false);
            var screen = GD.Load<PackedScene>("res://Scenes/Gameplay/WuhanDayScreen.tscn").Instantiate<WuhanDayScreen>();
            AddChild(screen); screen.SetProcess(false);
            screen.ConnectController(controller); screen.Initialize(catalog, save, controller, 2); screen.BeginDay();
            screen._Notification((int)NotificationApplicationFocusIn);
            if (controller.TutorialActive) screen.FinishWuhanDemoLesson();
            Check(!controller.TutorialActive, "normal business after tutorial");
            controller.Tick(3.01);
            var queue = controller.CustomerQueue!;
            for (int t = 0; t <= 180 && queue.Slots.Count < 5; t += 2) queue.Tick(t, 0, true);
            queue.Tick(180, .4, false);
            Check(queue.Slots.Count == 5, "five customers in real Wuhan screen");
            foreach (int width in new[] { 1920, 1280 })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                for (int page = 0; page < 3; page++)
                foreach (var expression in Enum.GetValues<CustomerExpression>())
                {
                    if (page == 2 && expression != CustomerExpression.Normal) continue;
                    for (int slot = 0; slot < 5; slot++)
                    {
                        var customer = queue.CustomerAtSlot(slot)!;
                        customer.AppearanceId = page == 2
                            ? new[] { "young_woman", "wuhan_grandma", "male_office", "wuhan_student", "tourist" }[slot]
                            : CustomerAppearanceCatalog.Wuhan[page * 5 + slot].Id;
                        customer.State = expression switch { CustomerExpression.Happy => CustomerState.Happy, CustomerExpression.Impatient => CustomerState.Impatient, CustomerExpression.Angry => CustomerState.Angry, _ => CustomerState.Normal };
                    }
                    screen._Notification((int)NotificationApplicationFocusIn);
                    screen.RefreshForCapture();
                    await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
                    if (capture && (width == 1920 || expression == CustomerExpression.Normal))
                    {
                        // Capture must finish even when another game/editor window covers this test window.
                        RenderingServer.ForceDraw(false);
                        using var image = GetViewport().GetTexture().GetImage();
                        Check(image.SavePng(ProjectSettings.GlobalizePath($"{Output}/final-{width}-{page}-{expression}.png")) == Error.Ok, "capture");
                    }
                }
            }
            GD.Print($"WUHAN_CUSTOMERS_SELF_TEST passed={_checks} failed=0 demo={ExperienceProfile.IsDemo}");
            GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
}
