using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class TianjinIngredientSelfTest : Node
{
    private const string Output = "res://artifacts/tianjin-ingredients";
    private PancakeWorkstation? _station;
    private int _checks;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    public override void _Process(double delta) => _station?.Tick(delta);
    private void Check(bool value, string message)
    {
        if (!value) throw new Exception(message);
        _checks++; GD.Print("INGREDIENT_PASS " + message);
    }
    private async Task Wait(double seconds = .03) => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
    private async Task Shot(string name)
    {
        if (!Capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        RenderingServer.ForceDraw(false);
        using var pixels = GetViewport().GetTexture().GetImage();
        Check(pixels.SavePng($"{Output}/{name}.png") == Error.Ok, "viewport capture saved: " + name);
    }
    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests($"{Output}/settings.cfg"); InterfaceLessons.MarkAllSeen(settings);
            if (Capture) GetWindow().Position = new(-10000, -10000);
            if (Capture) RenderingServer.ViewportSetUpdateMode(GetViewport().GetViewportRid(), RenderingServer.ViewportUpdateMode.Always);
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (int width in new[] { 1920, 1280 })
            {
                GetWindow().Size = new(width, width * 9 / 16);
                var save = new SaveService(); save.UsePathForTests($"{Output}/save-{width}.json"); AddChild(save);
                save.Data.PurchasedStoveLevel = save.Data.PurchasedIngredientStationLevel = save.Data.PurchasedFryerLevel = 3;
                var controller = new DayController(); AddChild(controller);
                var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
                AddChild(screen); screen.SetProcess(false); screen.ConnectController(controller); screen.Initialize(catalog, save, controller, 15);
                screen.BeginDay(); screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
                _station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
                var canvas = _station.Descendants<PancakeCanvas>().Single();
                var stroke = _station.Descendants<StrokeInteractor>().Single();
                var stove = (DropZone)_station.FindChild("PancakeDropZone", true, false);
                var drag = _station.Descendants<DragService>().Single();
                void Click(string id) => ((Button)_station.FindChild("IngredientInput_" + id, true, false)).EmitSignal(Button.SignalName.Pressed);
                Vector2 Point(float x, float y) => stroke.GetGlobalTransform().AffineInverse() * (canvas.GetGlobalTransform() * (canvas.GetSurfaceRect().Position + canvas.GetSurfaceRect().Size * new Vector2(x, y)));
                void Press(float x, float y) => stroke._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = Point(x, y) });
                void Move(float x, float y) => stroke._GuiInput(new InputEventMouseMotion { Position = Point(x, y) });
                void Release() => stroke._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false });
                await Wait();
                Check(canvas.SauceReveal is not null, "independent sauce layer is wired to actual workbench");
                Check(stove.TryAccept("batter"), "batter accepted");
                // Pin the real tween at contact so expensive framebuffer readback cannot miss it.
                var pour = (Tween)typeof(PancakeWorkstation).GetField("_batterTween", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)!.GetValue(_station)!;
                pour.Pause(); pour.CustomStep(.12);
                var stream = _station.Descendants<TextureRect>().Single(n => n.Name == "BatterPourStream");
                Check(stream.Visible && stream.Modulate.A > .9f, "pour stream visible at liquid contact");
                await Shot($"{width}-batter-pour");
                Press(.5f, .5f);
                Check(!stream.Visible, "spreading clears the pour stream immediately");
                Check(_station.Machine.Runtime.State == PancakeState.Spreading, "spreading interrupts pour without waiting");
                Release();
                _station.Machine.SetSpreadCoverage(1); stroke.StrokeCompleted?.Invoke(StrokeMode.Spread);
                int eggStock = _station.Inventory.GetQuantity("egg");
                if (Capture) Engine.TimeScale = .2;
                Click("egg"); Click("egg");
                Check(_station.Machine.Runtime.HasEgg && _station.Inventory.GetQuantity("egg") == eggStock - 1, "rapid egg clicks commit only once");
                await Wait(.16); await Shot($"{width}-egg-shells");
                Check(_station.Descendants<TextureRect>().Where(n => n.GetParent().Name == "EggCrack").All(n => n.Size.X < 50), "shells retain portion scale after entering tree");
                await Wait(.24);
                Engine.TimeScale = 1;
                _station.Machine.Runtime.State = PancakeState.SideBReady; _station.RefreshForCapture(); Click("sauce");
                var reveal = canvas.SauceReveal!;
                Press(.20f, .5f); Move(.80f, .5f); Release();
                Check(reveal.Sample(new(.5f, .5f)) > .9f, "fast stroke fills the path between input events");
                Check(reveal.Sample(new(.5f, .25f)) == 0, "unbrushed sauce remains hidden");
                Press(.5f, .2f); Release();
                Check(reveal.Sample(new(.5f, .34f)) == 0, "lifting prevents a bridge to the next stroke");
                double amount = _station.Machine.Runtime.SauceCoverage;
                await Wait(); await Shot($"{width}-sauce-trail");
                if (Capture)
                {
                    using var painted = GetViewport().GetTexture().GetImage();
                    Vector2 p = canvas.GetGlobalTransformWithCanvas() * canvas.GetSurfaceRect().GetCenter();
                    p *= painted.GetSize() / GetViewport().GetVisibleRect().Size;
                    Color withSauce = painted.GetPixel((int)p.X, (int)p.Y);
                    reveal.SelfModulate = new Color(1, 1, 1, 0);
                    await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                    RenderingServer.ForceDraw(false);
                    using var plain = GetViewport().GetTexture().GetImage();
                    Color withoutSauce = plain.GetPixel((int)p.X, (int)p.Y);
                    Check(Mathf.Abs(withSauce.G - withoutSauce.G) > .025f, "painted sauce changes actual rendered food pixels");
                    reveal.SelfModulate = Colors.White;
                }
                Check(_station.Machine.Runtime.SauceCoverage == amount, "visual updates never add sauce quantity");
                reveal.ResetReveal();
                Press(.2f, .5f); Move(-.2f, .5f); Move(.8f, .5f); Release();
                Check(reveal.Sample(new(.5f, .5f)) == 0, "leaving pancake breaks the visual path");
                reveal.ResetReveal();
                Press(.2f, .5f);
                _station.Paused = true; _station.Tick(.01); _station.Paused = false;
                Press(.8f, .5f); Release();
                Check(reveal.Sample(new(.5f, .5f)) == 0, "pause and resume cannot join unrelated strokes");
                reveal.ResetReveal();
                Press(.2f, .5f); Move(.8f, .5f); Release();
                _station.Machine.SetSauceCoverage(1);
                Check(_station.TryInvokeProductionShortcut(Key.F), "existing finish-sauce action still accepts");
                Check(reveal.Sample(new(.5f, .25f)) == 0, "finish does not auto-paint untouched food");
                int scallions = _station.Inventory.GetQuantity("scallion");
                Click("scallion"); Click("scallion");
                Check(_station.Inventory.GetQuantity("scallion") == scallions - 1, "scallion clicks consume once before animation ends");
                await Wait(.20); await Shot($"{width}-scallions-falling"); await Wait(.25);
                Check(stove.TryAccept("crispy"), "crispy accepted with scatter intact");
                Check(stove.TryAccept("ham"), "ham accepts while crispy settles");
                await Wait(.15); await Shot($"{width}-toppings");
                Check(_station.Machine.Runtime.ExtraIngredients.Count == 3, "all accepted ingredients remain recorded");
                var preview = canvas.CreateFoodPreview(new(150, 120));
                {
                    AddChild(preview);
                    var previewFood = preview.GetChildren().OfType<PancakeCanvas>().Single();
                    Check(previewFood.SauceReveal!.Sample(new(.5f, .5f)) > .9f, "trash preview carries actual painted sauce");
                    Check(!ReferenceEquals(previewFood.SauceReveal.Material, reveal.Material), "preview has an independent mask material");
                    preview.QueueFree();
                }
                Check(_station.TryInvokeProductionShortcut(Key.F), "fold accepts during landing tails");
                await Wait();
                Check(!_station.Descendants<Control>().Any(n => n.Name == "IngredientFlight" || n.Name == "EggCrack"), "fold removes all flying food");
                Check(_station.TryInvokeProductionShortcut(Key.F), "bag immediately follows fold");
                Check(_station.CanDeliverProduct("finished_pancake"), "new material effects preserve delivery readiness");
                _station.ResetForDay(); await Wait();
                Check(reveal.Sample(new(.5f, .5f)) == 0, "new pancake clears old sauce");
                // A late egg flight must not survive discard and attach to a replacement pancake.
                stove.TryAccept("batter"); _station.CancelInput();
                _station.Machine.TryExecute(PancakeCommand.BeginSpread); _station.Machine.SetSpreadCoverage(1);
                stroke.StrokeCompleted?.Invoke(StrokeMode.Spread); Click("egg");
                _station.Machine.TryExecute(PancakeCommand.Discard); _station.Tick(.01); stove.TryAccept("batter");
                await Wait(.4);
                Check(!_station.Machine.Runtime.HasEgg && !_station.Descendants<Control>().Any(n => n.Name == "EggCrack"), "discard cancels old shells and callbacks");
                _station.ResetForDay();
                ProjectSettings.SetSetting("accessibility/reduce_motion", true);
                stove.TryAccept("batter");
                Check(canvas.BatterDropProgress == 1, "reduced motion pours straight to static state");
                _station.Machine.TryExecute(PancakeCommand.BeginSpread); _station.Machine.SetSpreadCoverage(1);
                stroke.StrokeCompleted?.Invoke(StrokeMode.Spread); Click("egg");
                Check(_station.Machine.Runtime.HasEgg && !_station.Descendants<Control>().Any(n => n.Name == "EggCrack"), "reduced motion preserves egg without flying shells");
                ProjectSettings.SetSetting("accessibility/reduce_motion", false);
                _station = null; screen.QueueFree(); controller.QueueFree(); save.QueueFree(); await Wait();
            }
            GD.Print($"TIANJIN_INGREDIENT_TEST: {_checks} passed, 0 failed"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
}
