using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

public partial class WuhanTrashSelfTest : Node
{
    private int _passed;
    private WuhanDayScreen _screen = null!;
    private WuhanWorkstationView View => _screen.Workstation;
    private void Check(bool ok, string message)
    { if (!ok) throw new InvalidOperationException(message); _passed++; GD.Print("PASS " + message); }
    private void Button(Vector2 local, bool pressed, MouseButton button = MouseButton.Right)
    {
        Vector2 p = View.GetGlobalTransformWithCanvas() * local;
        GetViewport().PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = button, Pressed = pressed }, true);
    }
    private void Move(Vector2 local)
    {
        Vector2 p = View.GetGlobalTransformWithCanvas() * local;
        GetViewport().PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p, ButtonMask = MouseButtonMask.Right }, true);
    }
    private void Hold(Vector2 point) { Button(point, true); View.Tick(.45); }
    private void Drop() { Move(WuhanWorkbenchLayout.EmbeddedTrash.GetCenter()); Button(WuhanWorkbenchLayout.EmbeddedTrash.GetCenter(), false); }
    private async Task Frames() { for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private static void State<T>(object machine, T state) => machine.GetType().GetProperty("State")!.SetValue(machine, state);

    public override async void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (int width in new[] { 1920, 1280 })
            foreach (bool doupi in new[] { false, true })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                GetWindow().ContentScaleSize = new Vector2I(1920, 1080);
                ProjectSettings.SetSetting("accessibility/reduce_motion", true);
                var save = new SaveService(); save.UsePathForTests($"res://.tmp/wuhan-trash/{Guid.NewGuid():N}.json"); AddChild(save);
                save.Data.Wuhan.HighestUnlockedDay = 12;
                save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 1;
                if (doupi) save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 1;
                else save.Data.Wuhan.EquipmentLevels.Remove("doupi_griddle");
                var controller = new DayController(); AddChild(controller);
                _screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); AddChild(_screen);
                _screen.ConnectController(controller); _screen.Initialize(catalog, save, controller, doupi ? 8 : 1);
                _screen.SetProcess(false); _screen.BeginDay(); controller.Tick(3.1);
                _screen._Notification((int)NotificationApplicationFocusIn); await Frames();
                double revenue = controller.Ledger!.Build().TotalRevenue;
                Check(View.TrashZone.FixedHitRect == WuhanWorkbenchLayout.EmbeddedTrash, "fixed trash geometry");
                Vector2 globalTarget = View.GetGlobalTransform() * WuhanWorkbenchLayout.EmbeddedTrash.GetCenter();
                Vector2 globalOutside = View.GetGlobalTransform() * (WuhanWorkbenchLayout.EmbeddedTrash.Position - Vector2.One);
                View.TrashZone.Scale = Vector2.One * 1.03f;
                Check(View.TrashZone.ContainsPoint(globalTarget) && !View.TrashZone.ContainsPoint(globalOutside), "highlight scale never enlarges destructive hit area");
                View.TrashZone.Scale = Vector2.One;
                Button(View.RawCenter, true); View.Tick(.5);
                Check(!_screen.DeliveryDrag.IsDragging, "raw ingredients cannot be discarded"); Button(View.RawCenter, false);
                Hold(View.BowlCenter); Check(!_screen.DeliveryDrag.IsDragging, "empty bowl rejected"); Button(View.BowlCenter, false);
                foreach (NoodleBasketState state in Enum.GetValues<NoodleBasketState>().Where(s => s != NoodleBasketState.Empty))
                {
                    _screen.Cooker.TryStart(0); _screen.Cooker.Baskets[0].State = state;
                    View.RememberProductionState(); Hold(View.BasketRect(0).GetCenter());
                    Check(_screen.DeliveryDrag.IsDragging, $"{state} basket starts drag"); Drop();
                    Check(_screen.Cooker.Baskets[0].State == NoodleBasketState.Empty, $"{state} basket discarded");
                }
                foreach (NoodleBowlState state in Enum.GetValues<NoodleBowlState>().Where(s => s != NoodleBowlState.Empty))
                {
                    _screen.Bowl.TryAddNoodles(NoodleQuality.Optimal); State(_screen.Bowl, state);
                    Hold(View.BowlCenter); Check(_screen.DeliveryDrag.IsDragging, $"{state} bowl starts drag");
                    Button(WuhanWorkbenchLayout.EmbeddedTrash.GetCenter(), false, MouseButton.Left);
                    Check(_screen.Bowl.State == state && _screen.DeliveryDrag.IsDragging, "left release cannot discard");
                    Check(WuhanWorkstationView.DeliveryProduct(WuhanWorkstationView.TrashPayload) is null, "trash cannot deliver");
                    Drop(); Check(_screen.Bowl.State == NoodleBowlState.Empty, "whole bowl removed");
                }
                _screen.Bowl.TryAddNoodles(NoodleQuality.Optimal);
                Hold(View.BowlCenter);
                Check(!View.TrashZone.CanAccept(WuhanWorkstationView.DeliveryPayload(ProductKind.HotDryNoodles)), "left delivery payload rejected by trash");
                double elapsed = controller.DayElapsedSeconds;
                _screen._Process(.1);
                Check(controller.DayElapsedSeconds > elapsed && _screen.DeliveryDrag.IsDragging, "business clock continues during trash drag"); View.CancelInput();
                Button(View.BowlCenter, true); View.Tick(.44); Check(!_screen.DeliveryDrag.IsDragging, "hold threshold");
                Button(View.BowlCenter, false); View.Tick(.1); Check(_screen.Bowl.State != NoodleBowlState.Empty, "short tap preserves food");
                Button(View.BowlCenter, true); View.Tick(.44); View.Tick(.01);
                Check(_screen.DeliveryDrag.IsDragging, "split ticks reach exactly 0.45 seconds"); View.CancelInput();
                Button(View.BowlCenter, true); _screen.Bowl.Reset(); _screen.Bowl.TryAddNoodles(NoodleQuality.Optimal); View.Tick(.5);
                Check(!_screen.DeliveryDrag.IsDragging, "replacement during hold cancels before pickup"); Button(View.BowlCenter, false);
                Button(View.BowlCenter, true); Move(View.BowlCenter + new Vector2(40, 0)); View.Tick(.5);
                Check(!_screen.DeliveryDrag.IsDragging, "early movement cancels"); Button(View.BowlCenter, false);
                Hold(View.BowlCenter); _screen.Bowl.Reset(); _screen.Bowl.TryAddNoodles(NoodleQuality.Optimal);
                Check(!View.TrashZone.CanAccept(WuhanWorkstationView.TrashPayload), "replacement bowl rejects old drag"); View.CancelInput();
                Hold(View.BowlCenter); GetViewport().PushInput(new InputEventKey { Keycode = Key.Escape, Pressed = true }, true);
                Check(!_screen.DeliveryDrag.IsDragging && _screen.Bowl.State != NoodleBowlState.Empty, "escape cancels");
                Hold(View.BowlCenter); Button(Vector2.Zero, false);
                await ToSignal(GetTree().CreateTimer(.3), SceneTreeTimer.SignalName.Timeout);
                Check(_screen.Bowl.State != NoodleBowlState.Empty && !_screen.DeliveryDrag.IsDragging, "outside release preserves food");
                Hold(View.BowlCenter); controller.IsPaused = true; _screen._Process(.01);
                Check(!_screen.DeliveryDrag.IsDragging, "pause cancels drag"); controller.IsPaused = false;
                Button(View.BowlCenter, true); _screen._Notification((int)NotificationApplicationFocusOut); View.Tick(.5);
                Check(!_screen.DeliveryDrag.IsDragging, "focus loss cancels pending hold");
                _screen._Notification((int)NotificationApplicationFocusIn);
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
                Hold(View.BowlCenter); Drop(); controller.IsPaused = true; _screen._Process(.01);
                await ToSignal(GetTree().CreateTimer(.3), SceneTreeTimer.SignalName.Timeout);
                Check(_screen.Bowl.State != NoodleBowlState.Empty, "pause during snap prevents late commit"); controller.IsPaused = false;
                Hold(View.BowlCenter); Drop(); await ToSignal(GetTree().CreateTimer(.3), SceneTreeTimer.SignalName.Timeout);
                Check(_screen.Bowl.State == NoodleBowlState.Empty, "normal snap commits once");
                ProjectSettings.SetSetting("accessibility/reduce_motion", true);
                _screen.Cooker.TryStart(0); _screen.Cooker.Baskets[0].State = NoodleBasketState.Draining;
                _screen.Cooker.TryReservePour(0, _screen.Bowl); View.RememberProductionState();
                Hold(View.BasketRect(0).GetCenter()); Drop();
                Check(_screen.Cooker.PendingPourBasket is null && _screen.Bowl.State == NoodleBowlState.Empty, "discard cancels reserved pour");
                _screen.Cooker.TryStart(0); _screen.Cooker.Baskets[0].State = NoodleBasketState.Drained; View.RememberProductionState();
                Hold(View.BasketRect(0).GetCenter()); _screen.Cooker.TryTransferTo(0, _screen.Bowl); _screen.Cooker.TryStart(0);
                Check(!View.TrashZone.CanAccept(WuhanWorkstationView.TrashPayload), "transferred basket cannot delete next batch"); View.CancelInput();
                _screen.Cooker.TryDiscard(0); _screen.Bowl.Reset();
                _screen.Cooker.TryStart(0); Hold(View.BasketRect(0).GetCenter()); _screen.Cooker.Tick(100);
                Check(View.TrashZone.CanAccept(WuhanWorkstationView.TrashPayload), "cooking progression preserves batch identity"); Drop();
                if (doupi)
                {
                    foreach (DoupiState state in Enum.GetValues<DoupiState>().Where(s => s != DoupiState.Empty))
                    {
                        State(_screen.Doupi!, state); View.RememberProductionState();
                        Hold(View.PanCenter); Check(_screen.DeliveryDrag.IsDragging, $"{state} pan starts drag"); Drop();
                        Check(_screen.Doupi!.State == DoupiState.Empty, $"{state} pan discarded");
                    }
                    State(_screen.Doupi!, DoupiState.Burnt);
                    Button(View.PanCenter, true, MouseButton.Left); Button(View.PanCenter, false, MouseButton.Left);
                    Check(_screen.Doupi!.State == DoupiState.Burnt, "left click no longer clears burnt pan"); _screen.Doupi.Discard();
                    _screen.DoupiStock.TryAddBatch(3); Hold(View.StockCenter); Drop();
                    Check(_screen.DoupiStock.Count == 2, "stock loses exactly one piece"); Drop();
                    Check(_screen.DoupiStock.Count == 2, "repeat release does not consume twice");
                    Hold(View.StockCenter); _screen.DoupiStock.TryTake(1, out _);
                    Check(!View.TrashZone.CanAccept(WuhanWorkstationView.TrashPayload), "changed stock head invalidates drag"); View.CancelInput();
                    State(_screen.Doupi, DoupiState.ReadyToCut);
                    foreach (DoupiCutLine line in Enum.GetValues<DoupiCutLine>()) _screen.Doupi.TryCut(line);
                    View.RememberProductionState(); Hold(View.PanCenter); _screen.Doupi.TransferAvailable(_screen.DoupiStock);
                    Check(!View.TrashZone.CanAccept(WuhanWorkstationView.TrashPayload), "automatic stock transfer invalidates pan drag"); View.CancelInput();
                    _screen.Doupi.TryPourBatter(); View.PlayDoupi(DoupiState.Empty); Hold(View.PanCenter);
                    Check(!_screen.DeliveryDrag.IsDragging, "busy source rejected"); Button(View.PanCenter, false); View.CancelAnimations(); _screen.Doupi.Discard();
                    while (_screen.DoupiStock.Count > 0) _screen.DoupiStock.TryTake(1, out _);
                    _screen.DoupiStock.TryAddBatch(DoupiInventory.Capacity - 1);
                    State(_screen.Doupi, DoupiState.ReadyToCut);
                    foreach (DoupiCutLine line in Enum.GetValues<DoupiCutLine>()) _screen.Doupi.TryCut(line);
                    View.RememberProductionState(); Hold(View.PanCenter); _screen.Doupi.TransferAvailable(_screen.DoupiStock);
                    Check(_screen.Doupi.RemainingPieces > 0 && !View.TrashZone.CanAccept(WuhanWorkstationView.TrashPayload), "partial stock transfer invalidates old pan drag"); View.CancelInput();
                    _screen.Doupi.Discard(); while (_screen.DoupiStock.Count > 0) _screen.DoupiStock.TryTake(1, out _);
                }
                Check(controller.Ledger.Build().TotalRevenue == revenue, "discard never changes revenue");
                if (OS.GetCmdlineUserArgs().Contains("--capture"))
                {
                    _screen._Process(2.5); // Let transient test feedback expire before the layout capture.
                    _screen.RefreshForCapture(); await Frames();
                    await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                    string root = ProjectSettings.GlobalizePath("res://.tmp/wuhan-trash/captures"); Directory.CreateDirectory(root);
                    GetViewport().GetTexture().GetImage().SavePng($"{root}/{width}-{(doupi ? "doupi" : "noodles")}.png");
                    _screen.Bowl.TryAddNoodles(NoodleQuality.Optimal); Hold(View.BowlCenter); Move(WuhanWorkbenchLayout.EmbeddedTrash.GetCenter());
                    await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                    GetViewport().GetTexture().GetImage().SavePng($"{root}/{width}-{(doupi ? "doupi" : "noodles")}-hover.png"); View.CancelInput();
                    if (doupi)
                    {
                        foreach (bool filled in new[] { false, true })
                        {
                            _screen.Doupi!.Discard();
                            if (filled) { State(_screen.Doupi, DoupiState.Spreading); DoupiTestFixture.Spread(_screen.Doupi); }
                            State(_screen.Doupi, DoupiState.Burnt); View.RememberProductionState();
                            Hold(View.PanCenter); Move(new Vector2(1320, 490));
                            await Frames(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                            GetViewport().GetTexture().GetImage().SavePng($"{root}/{width}-burnt-{(filled ? "filled" : "skin")}.png");
                            View.CancelInput();
                        }
                    }
                }
                _screen.Free(); controller.Free(); save.Free(); await Frames();
            }
            GD.Print($"WUHAN_TRASH_OK {_passed}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
