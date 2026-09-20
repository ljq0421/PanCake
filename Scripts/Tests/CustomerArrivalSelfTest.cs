using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class CustomerArrivalSelfTest : Node
{
    private int _checks;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private const string Output = "res://artifacts/customer-arrival";
    private void Check(bool value, string message)
    {
        if (!value) throw new InvalidOperationException(message);
        _checks++;
    }
    private async Task Frames()
    {
        for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Output + "/settings.cfg"); InterfaceLessons.MarkAllSeen(settings);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            if (Capture) GetWindow().Position = new(-10000, -10000);
            foreach (int width in new[] { 1920, 1280 })
            foreach (string city in new[] { "Tianjin", "Wuhan", "Xian" })
            {
                GetWindow().Size = new(width, width * 9 / 16);
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
                var save = new SaveService(); save.UsePathForTests(Output + $"/{city}-save.json"); AddChild(save);
                save.Data.Tianjin.HighestUnlockedDay = save.Data.Wuhan.HighestUnlockedDay = save.Data.Xian.HighestUnlockedDay = 12;
                var controller = new DayController(); AddChild(controller); controller.SetProcess(false);
                var screen = GD.Load<PackedScene>($"res://Scenes/Gameplay/{city}DayScreen.tscn").Instantiate<Control>();
                AddChild(screen); screen.SetProcess(false);
                switch (screen)
                {
                    case TianjinDayScreen s: s.ConnectController(controller); s.Initialize(catalog, save, controller, 2); s.BeginDay(); break;
                    case WuhanDayScreen s: s.ConnectController(controller); s.Initialize(catalog, save, controller, 2); s.BeginDay(); break;
                    case XianDayScreen s: s.ConnectController(controller); s.Initialize(catalog, save, controller, 2); s.BeginDay(); break;
                }
                controller.Tick(3.01);
                var queue = controller.CustomerQueue!;
                queue.Tick(controller.CurrentPlan!.Customers[0].ArrivalTime, 0, true);
                Check(queue.Slots.Count == 1, city + " first arrival");
                var customer = queue.Slots[0];
                void Render()
                {
                    screen._Notification((int)NotificationApplicationFocusIn);
                    switch (screen)
                    {
                        case TianjinDayScreen s: s.RefreshForCapture(true); break;
                        case WuhanDayScreen s: s.RefreshForCapture(); break;
                        case XianDayScreen s: s.Render(); break;
                    }
                }
                Render(); await Frames(); Render();
                var portraits = screen.Descendants<CustomerPortraitView>().ToArray();
                var cards = screen.Descendants<OrderBubbleView>().ToArray();
                var portrait = portraits[customer.SlotIndex];
                var card = cards[customer.SlotIndex];
                Rect2 portraitRect = portrait.GetGlobalRect();
                Rect2 cardRect = card.GetGlobalRect();
                var motion = portrait.GetNode<Control>("ArrivalMotion");
                foreach (double age in new[] { 0, .14, .28, .35, .44 })
                {
                    customer.State = age < .35 ? CustomerState.Entering : CustomerState.Happy;
                    customer.PhaseSeconds = age < .35 ? age : age - .35;
                    Render(); await Frames(); Render();
                    Check(portrait.GetGlobalRect().IsEqualApprox(portraitRect), city + " stable portrait/delivery bounds");
                    Check(card.GetGlobalRect().IsEqualApprox(cardRect), city + " fixed order layout");
                    Check(customer.WaitSeconds == 0, city + " presentation never consumes patience");
                    Check(!queue.TrySelect(customer.Id) == (age < .35), city + " original service boundary");
                    Check(Mathf.IsEqualApprox(card.Modulate.A, age < .24 ? 0 : age >= .35 ? 1 : (float)((age - .24) / .11)), city + " full order reveals together");
                    if (age >= .28) Check(motion.Position.IsEqualApprox(Vector2.Zero), city + " settled position before service");
                    if (Capture)
                    {
                        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                        using var image = GetViewport().GetTexture().GetImage();
                        Check(image.SavePng($"{Output}/{city}-{width}-{age:0.00}.png") == Error.Ok, "capture");
                    }
                }
                Check(motion.Scale.IsEqualApprox(Vector2.One) && motion.Rotation == 0, "rebound ends exactly at rest");
                customer.State = CustomerState.Entering; customer.PhaseSeconds = .14;
                Render(); var pausedPosition = motion.Position; await Frames(); Render();
                Check(motion.Position == pausedPosition, "unchanged business clock freezes motion");
                ProjectSettings.SetSetting("accessibility/reduce_motion", true); Render();
                Check(motion.Position == Vector2.Zero && motion.Scale == Vector2.One && motion.Rotation == 0, "reduced motion removes body displacement");
                customer.Tick(.21); Render();
                Check(customer.State == CustomerState.Happy && customer.WaitSeconds == 0 && card.Modulate.A == 1, "service starts independently of visual completion");
                CustomerArrivalMotion.Apply(portrait, card, null);
                Check(motion.Scale == Vector2.One && motion.Position == Vector2.Zero && card.Modulate.A == 1, "empty slot clears visual state");
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
                for (int t = 100; t <= 200 && queue.Slots.Count < 5; t += 2) queue.Tick(t, 0, true);
                Check(queue.Slots.Count == 5, "five customer capacity preserved");
                foreach (var c in queue.Slots) { c.State = CustomerState.Entering; c.PhaseSeconds = .28; }
                Render(); await Frames(); Render();
                if (Capture)
                {
                    await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                    using var image = GetViewport().GetTexture().GetImage();
                    Check(image.SavePng($"{Output}/{city}-{width}-full.png") == Error.Ok, "full capture");
                }
                screen.Free(); controller.Free(); save.Free(); await Frames();
            }
            GD.Print($"CUSTOMER_ARRIVAL_SELF_TEST passed={_checks} failed=0"); GetTree().Quit();
        }
        catch (Exception ex) { GD.PushError(ex.ToString()); GetTree().Quit(1); }
    }
}
