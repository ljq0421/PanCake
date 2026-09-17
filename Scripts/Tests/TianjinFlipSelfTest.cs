using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class TianjinFlipSelfTest : Node
{
    private const string Output = "res://artifacts/tianjin-flip-20260917";
    private int _checks;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private void Check(bool value, string message)
    {
        if (!value) throw new Exception(message);
        _checks++; GD.Print("FLIP_PASS " + message);
    }
    private async Task Frames(int count = 2)
    {
        for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    private async Task Shot(string name)
    {
        if (!Capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage();
        image.SavePng($"{Output}/{name}.png");
    }
    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests($"{Output}/settings.cfg");
            InterfaceLessons.MarkAllSeen(settings);
            if (Capture) GetWindow().Position = new Vector2I(-10000, -10000);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (int width in new[] { 1920, 1280 })
            {
                GetWindow().Size = new Vector2I(width, width * 9 / 16);
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
                var save = new SaveService(); save.UsePathForTests($"{Output}/save-{width}.json"); AddChild(save);
                save.Data.PurchasedStoveLevel = 3; save.Data.PurchasedIngredientStationLevel = 3;
                save.Data.PurchasedFryerLevel = 3;
                var controller = new DayController(); AddChild(controller);
                var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
                AddChild(screen); screen.SetProcess(false); screen.ConnectController(controller);
                screen.Initialize(catalog, save, controller, 15); screen.BeginDay(); controller.Tick(3.1);
                screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
                await Frames();
                var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
                var living = screen.GetNode<TianjinLivingWorkbench>("LivingWorkbench");
                var canvas = station.Descendants<PancakeCanvas>().Single();
                var flip = (Button)station.FindChild("PancakeFlipAction", true, false);
                var sauce = (Button)station.FindChild("IngredientInput_sauce", true, false);
                var fold = (Button)station.FindChild("PancakeFoldAction", true, false);
                var bag = (Button)station.FindChild("PancakeBagAction", true, false);
                void Ready(bool egg = true)
                {
                    station.CancelInput();
                    station.Machine.TryExecute(PancakeCommand.Discard);
                    station.Machine.Runtime.State = PancakeState.SideAReady;
                    station.Machine.Runtime.HasEgg = egg;
                    station.RefreshForCapture();
                }
                void Start()
                {
                    Ready();
                    Check(station.TryInvokeProductionShortcut(Key.F), "F starts a valid flip");
                }
                Ready();
                await Shot($"before-{width}");
                flip.EmitSignal(Button.SignalName.Pressed);
                Check(station.IsFlipping && station.Machine.Runtime.State == PancakeState.SideBCooking,
                    "button starts animation and commits exactly one flip");
                int stock = station.Inventory.GetQuantity("sauce");
                for (int n = 0; n < 5; n++)
                {
                    Check(!station.TryInvokeProductionShortcut(Key.F), "repeated F cannot advance the recipe");
                    flip.EmitSignal(Button.SignalName.Pressed);
                    sauce.EmitSignal(Button.SignalName.Pressed);
                    fold.EmitSignal(Button.SignalName.Pressed);
                    bag.EmitSignal(Button.SignalName.Pressed);
                }
                Check(station.Machine.Runtime.State == PancakeState.SideBCooking
                    && station.Inventory.GetQuantity("sauce") == stock, "airborne inputs do not change food or stock");
                Check(!station.TryBeginTrashDrag(canvas.GetGlobalRect().GetCenter()), "airborne pancake cannot be picked up for trash");
                Check(station.CanDeliverProduct("soy_milk_cup"), "other work remains available during the flip");
                // Capture consecutive actual viewport frames at a deterministic 60 Hz.
                for (int frame = 0; frame <= 21; frame++)
                {
                    if (frame > 0) station.Tick(1.0 / 60);
                    await Frames();
                    if (frame == 8) Check(!living.ToolsAtRest, $"spatula accompanies the rising pancake (active={living.Active()}, state={controller.State}, paused={controller.IsPaused}, progress={station.FlipProgress})");
                    await Shot($"frame-{width}-{frame:D2}");
                }
                Check(!station.IsFlipping && living.ToolsAtRest, "food and spatula finish together at 0.35 seconds");
                Check(station.Machine.Runtime.HasEgg, "egg state survives the flip");
                sauce.EmitSignal(Button.SignalName.Pressed);
                Check(station.Machine.Runtime.State == PancakeState.Saucing, "sauce becomes available after landing");

                Start(); station.Tick(.12); screen.OpenBusinessDetails(); await Frames();
                Check(!station.IsFlipping && living.ToolsAtRest, "business details settle the food and restore the spatula");
                screen.CloseBusinessDetails(); await Frames();
                Check(!station.IsFlipping, "closing details does not replay animation");
                Start(); station.Tick(.12); screen._Notification((int)NotificationApplicationFocusOut); await Frames();
                Check(!station.IsFlipping && living.ToolsAtRest, "focus loss clears the animation");
                screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true); await Frames();
                Start(); station.Tick(.12); ProjectSettings.SetSetting("accessibility/reduce_motion", true);
                station.Tick(0); await Frames();
                Check(!station.IsFlipping && living.ToolsAtRest, "changing reduced motion mid-flip settles immediately");
                Ready(); Check(station.TryInvokeProductionShortcut(Key.F) && !station.IsFlipping,
                    "reduced motion preserves successful flip without travel or input delay");
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
                Start(); station.Tick(.12); station.Paused = true; station.Tick(.1); await Frames();
                Check(!station.IsFlipping, "paused workstation releases animation lock");
                station.Paused = false;
                Ready(false); flip.EmitSignal(Button.SignalName.Pressed); station.Tick(.2); await Frames();
                await Shot($"no-egg-{width}");
                station.ResetForDay(); await Frames();
                Check(!station.IsFlipping && living.ToolsAtRest && station.Machine.Runtime.State == PancakeState.Empty,
                    "day reset removes moving food and unlocks the next pancake");
                Start(); station.Tick(.12); screen.Hide(); await Frames();
                Check(!station.IsFlipping && living.ToolsAtRest, "leaving clears both food and tool motion");
                screen.QueueFree(); controller.QueueFree(); save.QueueFree(); await Frames();
            }
            GD.Print($"TIANJIN_FLIP_TEST: {_checks} passed, 0 failed"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
