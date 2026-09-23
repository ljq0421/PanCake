using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class TianjinLivingWorkbenchSelfTest : Node
{
    private int _checks;
    private PancakeWorkstation? _motionStation;
    public override void _Process(double delta)
    {
        if (IsInstanceValid(_motionStation) && _motionStation!.IsFlipping) _motionStation.Tick(delta);
    }
    private void Flip(PancakeWorkstation station)
    {
        station.Machine.Runtime.State = PancakeState.SideAReady;
        station.RefreshForCapture();
        Check(station.TryInvokeProductionShortcut(Key.F), "real flip action accepted");
    }
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private bool Film => OS.GetCmdlineUserArgs().Contains("--living-film");
    private void Check(bool value, string message)
    {
        if (!value) throw new Exception(message);
        _checks++; GD.Print("LIVING_PASS " + message);
    }
    private async Task Frames(int count = 3)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    private async Task Delay(double seconds) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
    private async Task Shot(string name)
    {
        if (!Capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage();
        image.SavePng($"res://.tmp/tianjin-living/{name}.png");
    }
    public override async void _Ready()
    {
        try
        {
            InterfaceLessons.MarkAllSeen(GetNode<JourneySettings>("/root/JourneySettings"));
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (int width in Film ? new[] { 1920 } : new[] { 1920, 1280 })
            foreach (int day in Film ? new[] { 15 } : new[] { 1, 5, 15 })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
                var save = new SaveService(); save.UsePathForTests($"res://.tmp/tianjin-living/save-{width}-{day}.json"); AddChild(save);
                save.Data.PurchasedStoveLevel = 3; save.Data.PurchasedFryerLevel = 3; save.Data.PurchasedIngredientStationLevel = 3;
                var controller = new DayController(); AddChild(controller);
                var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
                AddChild(screen); screen.SetProcess(false); screen.ConnectController(controller);
                screen.Initialize(catalog, save, controller, day);
                if (day == 15)
                    foreach (var planned in controller.CurrentPlan!.Customers.Take(3))
                        planned.Order = new OrderData { OrderId = planned.Order.OrderId, CustomerTypeId = planned.CustomerTypeId,
                            Lines = new[] { new OrderLineData(ProductKind.SoyMilk, "soy_milk", 1) }, BasePrice = 3 };
                screen.BeginDay(); controller.Tick(3.1); controller.CustomerQueue!.Tick(1000, .4, true);
                screen._Notification((int)NotificationApplicationFocusIn);
                screen.RefreshForCapture(true); await Frames();
                var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
                _motionStation = station;
                var living = screen.GetNode<TianjinLivingWorkbench>("LivingWorkbench");
                var hud = screen.GetNode<BusinessHud>("BusinessHud");
                var cards = screen.Descendants<OrderBubbleView>().Where(c => c.Name == "OrderBubble").ToArray();
                Check(cards.Length == 5 && cards.All(c => c.CustomMinimumSize.X == OrderBubbleView.CompactWidth), "five papers use the current compact width");
                Check(cards.All(c => ((StyleBoxFlat)c.GetThemeStylebox("panel")).BorderWidthLeft == 2), "thin private warm paper styles");
                Check(cards.All(c => c.Patience.CustomMinimumSize.Y == 6), "six-unit patience strip");
                using (var sprite = Image.LoadFromFile(ProjectSettings.GlobalizePath("res://resource/art/TianJin/LivingWorkbench/pendant.png")))
                    Check(living.ToolsAtRest && sprite.GetPixel(0, 0).A == 0, "independent alpha sprites at rest");
                await Shot($"stage-{day}-{width}");
                if (day != 15) { screen.QueueFree(); controller.QueueFree(); save.QueueFree(); await Frames(); continue; }

                // Controlled presentation states; real delivery is exercised below and in CoinCollectionSelfTest.
                var runtime = station.Machine.Runtime;
                station.FryerMachine!.Runtime.State = FryerState.Frying;
                station.FryerMachine.Runtime.Quantity = 3;
                var fryer = station.Descendants<FryerVisualView>().Single();
                fryer.SetProcess(true);
                var stroke = station.Descendants<StrokeInteractor>().Single();
                var canvas = station.Descendants<PancakeCanvas>().Single();
                runtime.State = PancakeState.BatterPlaced; station.RefreshForCapture();
                var geometry = stroke.ResolveSpreadGeometry!();
                Vector2 point = geometry.Center + geometry.Radii * new Vector2(.7f, 0);
                stroke.EmitSignal(Control.SignalName.MouseEntered);
                stroke._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point });
                for (int n = 1; n <= 18; n++)
                    stroke._GuiInput(new InputEventMouseMotion { Position = geometry.Center + geometry.Radii * new Vector2(Mathf.Cos(n * .06f), Mathf.Sin(n * .06f)) * .7f });
                Vector2 pointer = stroke.GetGlobalTransformWithCanvas() * (geometry.Center + geometry.Radii * new Vector2(.4f, .6f));
                GetViewport().PushInput(new InputEventMouseMotion { Position = pointer, GlobalPosition = pointer }, true);
                station.Tick(.016); await Frames();
                Check(stroke.IsSpreading && !living.GetNode<TextureRect>("scraper").Visible, "active stroke removes resting scraper");
                Check(canvas.EdgeRelaxation > 0 && canvas.EdgeRelaxation <= .01f, "batter edge responds within one percent");
                await Shot($"spreading-{width}");
                stroke._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = point });
                double spread = runtime.SpreadCoverage;
                station.Tick(.21); await Frames();
                Check(canvas.EdgeRelaxation == 0 && runtime.SpreadCoverage == spread && living.ToolsAtRest, "edge settles without modifying coverage and scraper returns");
                stroke.EmitSignal(Control.SignalName.MouseExited);
                runtime.State = PancakeState.SideACooking; station.RefreshForCapture(); await Frames();
                runtime.State = PancakeState.SideAReady; station.RefreshForCapture(); await Frames();
                Check(living.SteamRemaining > 0, "ready transition emits steam once");
                await Shot($"steam-{width}");
                await Delay(.95); Check(living.SteamRemaining == 0, "mature pancake does not loop steam");
                Flip(station); await Frames(2); Check(!living.ToolsAtRest, "flip hides the resting spatula");
                await Shot($"flip-{width}");
                await Delay(.4); Check(living.ToolsAtRest && !station.IsFlipping, "pancake lands and the resting spatula returns to its fixed slot");

                var stock = station.Descendants<SoyMilkStockView>().Single();
                var drag = station.Descendants<DragService>().Single();
                var source = station.Descendants<DragItem>().First(i => i.PayloadId == "soy_milk_cup");
                int quantity = station.SoyMilkTray!.Quantity;
                source.TryBeginDrag(); await Frames();
                Check(stock.VisibleCupCount == quantity - 1 && station.SoyMilkTray.Quantity == quantity,
                    $"held cup is visual reservation only (visible={stock.VisibleCupCount}, stock={quantity}, dragging={drag.IsDragging}, paused={station.Paused})");
                drag.CancelDrag(); await Frames();
                Check(stock.VisibleCupCount == quantity && station.SoyMilkTray.Quantity == quantity, "cancel restores cup without changing inventory");

                // Feed two real customers a one-cup order to cover immediate money and queued flights.
                int beforeIncome = controller.Ledger!.Build().TotalRevenue;
                var paymentCustomers = controller.CustomerQueue.Slots.Take(3).ToArray();
                foreach (var customer in paymentCustomers.Take(2))
                {
                    var zone = (DropZone)screen.FindChild($"CustomerDropZone{customer.SlotIndex + 1}", true, false);
                    Check(zone.TryAccept("soy_milk_cup"), "real cup delivery completes the fixture order");
                    station.SoyMilkTray.Tick(.3);
                }
                Check(controller.Ledger.Build().TotalRevenue > beforeIncome && screen.PaymentCoins.Count == 6, "money is recorded before the two sets of flights finish");
                await Shot($"payment-{width}");
                await Delay(1.05);
                Check(screen.PaymentCoins.Count == 0, "flight callbacks clean up their coins");
                var thirdZone = (DropZone)screen.FindChild($"CustomerDropZone{paymentCustomers[2].SlotIndex + 1}", true, false);
                Check(thirdZone.TryAccept("soy_milk_cup") && screen.PaymentCoins.Count == 3, "third payment begins a fresh flight");
                living.ReceivePayment(); hud.EmphasizeIncome();
                ProjectSettings.SetSetting("accessibility/reduce_motion", true); await Frames();
                Check(screen.PaymentCoins.Count == 0 && living.PendantRotation == 0 && hud.IncomeTarget.Scale == Vector2.One,
                    "switching reduced motion clears already running payment effects");
                ProjectSettings.SetSetting("accessibility/reduce_motion", false); await Frames();
                screen._Notification((int)NotificationApplicationFocusOut); await Frames();
                Check(living.CompletedPaperCount == 0 && living.ToolsAtRest, "focus loss clears completion and tools");
                screen._Notification((int)NotificationApplicationFocusIn); await Frames();
                // Use existing fixture customers' real orders for an independent paper copy test.
                screen.OpenBusinessDetails(); await Frames(); screen.CloseBusinessDetails(); await Frames();
                int nodes = (int)Performance.GetMonitor(Performance.Monitor.ObjectNodeCount);
                for (int i = 0; i < 8; i++) living.CompleteOrder(cards[i % cards.Length], i % 2 == 0);
                Check(living.CompletedPaperCount <= 5, "completion copies have a bounded lifetime and count");
                await Shot($"completion-{width}");
                living.ReceivePayment(); hud.EmphasizeIncome(); await Frames(4);
                Check(Math.Abs(living.PendantRotation) <= 4.01f && Math.Abs(living.PendantRotation) > .01f, "payment swing stays within four degrees");
                living.ReceivePayment(); await Frames(3);
                Check(Math.Abs(living.PendantRotation) <= 4.01f, "consecutive payment replaces swing");
                screen.OpenBusinessDetails(); await Frames();
                Check(living.CompletedPaperCount == 0 && living.ToolsAtRest && living.PendantRotation == 0, "modal clears transient feedback and restores tools");
                Check(hud.IncomeTarget.Scale == Vector2.One && screen.PaymentCoins.Count == 0, "modal clears income emphasis and flights");
                screen.CloseBusinessDetails(); await Frames();
                Check(living.SteamRemaining == 0, "resume does not replay maturity");
                Check((int)Performance.GetMonitor(Performance.Monitor.ObjectNodeCount) <= nodes + 10, "completion nodes return to baseline");
                ProjectSettings.SetSetting("accessibility/reduce_motion", true); await Frames();
                living.ReceivePayment(); Flip(station); living.CompleteOrder(cards[0], true); await Frames();
                Check(living.PendantRotation == 0 && living.ToolsAtRest, "reduced motion suppresses swing and tool travel");
                Check(living.CompletedPaperCount == 1, "reduced motion retains static completion feedback");
                await Delay(.6); Check(living.CompletedPaperCount == 0, "reduced completion cleans up");
                ProjectSettings.SetSetting("accessibility/reduce_motion", false); await Frames();

                // Same five-guest scene, warmed assets: compare the presentation with dynamics off/on.
                foreach (bool reduced in new[] { true, false })
                {
                    ProjectSettings.SetSetting("accessibility/reduce_motion", reduced); await Delay(1.2);
                    double sum = 0, peak = 0;
                    for (int sample = 0; sample < 60; sample++)
                    {
                        fryer.Tick(1.0 / 60);
                        await Frames(1);
                        double ms = Performance.GetMonitor(Performance.Monitor.TimeProcess) * 1000;
                        sum += ms; peak = Math.Max(peak, ms);
                    }
                    GD.Print($"LIVING_PERF width={width} reduced={reduced} cpu_process_mean_ms={sum / 60:F3} peak_ms={peak:F3} nodes={Performance.GetMonitor(Performance.Monitor.ObjectNodeCount)}");
                }

                if (Film)
                {
                    for (int cycle = 0; cycle < 3; cycle++)
                    {
                        runtime.State = PancakeState.SideACooking; await Frames(10);
                        runtime.State = PancakeState.SideAReady; station.RefreshForCapture();
                        fryer.Tick(.2);
                        living.CompleteOrder(cards[cycle], cycle == 2);
                        living.ReceivePayment(); hud.EmphasizeIncome(); await Frames(20);
                        Flip(station); await Frames(50);
                    }
                }
                screen.Hide(); await Frames(); Check(living.CompletedPaperCount == 0 && living.ToolsAtRest, "leaving clears all temporary visuals");
                screen.QueueFree(); controller.QueueFree(); save.QueueFree(); await Frames();
            }
            GD.Print($"TIANJIN_LIVING_TEST: {_checks} passed, 0 failed"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
