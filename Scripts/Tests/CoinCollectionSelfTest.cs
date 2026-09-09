using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class CoinCollectionSelfTest : Node
{
    private int _passed;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private void Check(bool ok, string message)
    {
        if (!ok) throw new InvalidOperationException(message);
        _passed++; GD.Print("PASS " + message);
    }
    private async Task Frames()
    {
        for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    public override async void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (bool wuhan in new[] { true, false })
            foreach (bool reduced in new[] { false, true })
            foreach (int width in new[] { 1920, 1280 })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                ProjectSettings.SetSetting("accessibility/reduce_motion", reduced);
                var save = new SaveService(); save.UsePathForTests($"res://.tmp/coin-test-{Guid.NewGuid():N}.json"); AddChild(save);
                save.Data.Wuhan.HighestUnlockedDay = 12;
                save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 3;
                save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 3;
                save.Data.Wuhan.EquipmentLevels["ingredient_station"] = 3;
                save.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"] = 1;
                var controller = new DayController(); AddChild(controller);
                Control screen = wuhan ? new WuhanDayScreen() : new TianjinDayScreen(); AddChild(screen); screen.SetProcess(false);
                void Init()
                {
                    if (screen is WuhanDayScreen ws) { ws.ConnectController(controller); ws.Initialize(catalog, save, controller, 8); ws.BeginDay(); }
                    else { var ts = (TianjinDayScreen)screen; ts.ConnectController(controller); ts.Initialize(catalog, save, controller, 11); ts.BeginDay(); }
                    controller.Tick(3.1);
                    screen._Notification((int)NotificationApplicationFocusIn);
                }
                Init();
                var tray = wuhan ? ((WuhanDayScreen)screen).CoinTray : screen.GetChildren().OfType<PancakeWorkstation>().Single().CoinTray!;
                var feedback = screen.GetChildren().OfType<CoinCollectionFeedback>().Single(); feedback.SetProcess(false);
                await Frames();
                var resting = tray.Coins.Select(c => c.GetTransform()).ToArray();
                for (int pileCount = 0; pileCount <= 12; pileCount++)
                {
                    tray.RenderRevenue(pileCount * 10);
                    Check(tray.Coins.Where(c => c.Visible).All(c => new[]
                    {
                        Vector2.Zero, new Vector2(c.Size.X, 0), c.Size, new Vector2(0, c.Size.Y),
                    }.All(p => tray.SurfaceBounds.HasPoint(c.GetGlobalTransform() * p))),
                        $"{width}px scatter {pileCount}: all rotated corners remain within tray");
                    Check(tray.Coins.Select((c, i) => c.GetTransform() == resting[i]).All(same => same),
                        "revenue refresh preserves settled coin positions");
                }
                if (Capture && !reduced) await Shot($"{(wuhan ? "wuhan" : "tianjin")}-{width}-full-pile");
                tray.RenderRevenue(0);
                void Render() => screen._Process(.00001);
                void Pay(int amount) { controller.Ledger!.RecordDelivery(new(DeliveryGrade.Correct, amount, 0, 100, "fixture", true)); Render(); }
                void Click()
                {
                    Vector2 p = tray.GetGlobalTransformWithCanvas() * new Vector2(125, 43);
                    GetViewport().PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p }, true);
                    foreach (bool pressed in new[] { true, false })
                        GetViewport().PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = pressed }, true);
                }
                await Frames(); Pay(56); await Frames();
                string context = $"{(wuhan ? "wuhan" : "tianjin")}-{width}-{(reduced ? "reduced" : "normal")}";
                Check(tray.PendingAmount == 56 && tray.VisibleCoinCount == 6, context + " auto-booked money awaits visual collection");
                if (Capture && !reduced) await Shot(context + "-before");
                feedback.PaymentFrom(tray.LandingPoint - new Vector2(0, 100));
                if (reduced) Check(feedback.Effects.Count == 0, "reduced motion omits payment scatter and bounce");
                else
                {
                    var incoming = feedback.Effects.ToArray();
                    feedback.Advance(.28);
                    var impact = incoming.Select(c => c.Position).ToArray();
                    feedback.Advance(.04);
                    Check(incoming.Select((c, i) => c.Position.DistanceTo(impact[i]) > 1).All(moved => moved),
                        "payment coins spread and hop after reaching tray");
                    screen._Notification((int)NotificationApplicationFocusOut);
                    var paused = incoming.Select(c => c.Position).ToArray();
                    feedback._Process(.2);
                    Check(incoming.Select((c, i) => c.Position == paused[i]).All(same => same), "focus loss freezes landing hop");
                    screen._Notification((int)NotificationApplicationFocusIn);
                    if (Capture) await Shot(context + "-landing");
                    feedback.Advance(.22);
                    Check(incoming.Select((c, i) => (c.GetGlobalTransform() * (c.Size * .5f))
                        .DistanceTo(tray.Coins[i].GetGlobalTransform() * (tray.Coins[i].Size * .5f)) < .1f).All(settled => settled),
                        "all three payment coins settle at distinct pile positions");
                }
                Click();
                Check(tray.PendingAmount == 0 && tray.VisibleCoinCount == 0, context + " real viewport click empties tray");
                Check(controller.Ledger!.Build().TotalRevenue == 56 && save.Data.Coins == 0, "collection does not modify ledger or permanent money");
                Check(feedback.Effects.OfType<Label>().Single().Text == "+¥56", "floating amount matches collected pile");
                Check(reduced ? feedback.Effects.Count == 1 : feedback.Effects.Count == 8, "reduced motion keeps amount and omits flying coins");
                int count = feedback.Effects.Count; Click(); Check(feedback.Effects.Count == count, "empty repeat click cannot replay reward");
                Render(); Check(tray.PendingAmount == 0, "render does not refill already collected money");
                feedback.Advance(.12);
                if (Capture && !reduced) await Shot(context + "-collect");
                var positions = feedback.Effects.ToDictionary(c => c, c => c.Position);
                screen._Notification((int)NotificationApplicationFocusOut); feedback._Process(.3);
                Check(positions.All(p => p.Key.Position.IsEqualApprox(p.Value)), "focus loss freezes collection animation");
                screen._Notification((int)NotificationApplicationFocusIn);
                Pay(9); controller.IsPaused = true; Click();
                Check(tray.PendingAmount == 9, "paused click retains new payment");
                controller.IsPaused = false; Click();
                Check(tray.PendingAmount == 0 && controller.Ledger.Build().TotalRevenue == 65, "new payment can be collected during prior feedback without duplicate accounting");
                feedback.Advance(2); Check(feedback.Effects.Count == 0, "all transient nodes clean up after completion");
                Pay(7); Click(); screen.Hide();
                Check(feedback.Effects.Count == 0 && controller.Ledger.Build().TotalRevenue == 72, "leaving screen clears feedback without changing income");
                screen.Show(); Pay(3);
                if (screen is WuhanDayScreen ws2) ws2.Initialize(catalog, save, controller, 8);
                else ((TianjinDayScreen)screen).Initialize(catalog, save, controller, 11);
                Check(tray.PendingAmount == 0 && feedback.Effects.Count == 0, "restart clears pending visual balance and feedback");
                if (screen is WuhanDayScreen ws3) ws3.BeginDay(); else ((TianjinDayScreen)screen).BeginDay();
                controller.Tick(3.1); Pay(19); Click(); Pay(6);
                controller.Tick(1000); controller.Tick(1000);
                Check(controller.State == DayState.Results && controller.Ledger!.Build().TotalRevenue == 25
                    && save.Data.Coins == 25, "settlement preserves both collected and unclicked income exactly once");
                Check(feedback.Effects.Count == 0 && !tray.TryCollect(), "settlement clears ongoing feedback and blocks collection");
                screen.Free(); controller.Free(); save.Free(); await Frames();
            }
            GC.Collect(); GC.WaitForPendingFinalizers(); await Frames();
            GD.Print($"COIN_COLLECTION_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private async Task Shot(string name)
    {
        await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string directory = ProjectSettings.GlobalizePath("res://.tmp/coin-collection"); Directory.CreateDirectory(directory);
        GetViewport().GetTexture().GetImage().SavePng(Path.Combine(directory, name + ".png"));
    }
}
