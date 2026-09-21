using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Fryer;
using ProjectCake.Interaction;
using ProjectCake.Pancake;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

public partial class CookingFeelSelfTest : Node
{
    private const string Output = "res://.tmp/cooking-feel";
    private int _checks;
    private bool Capture => OS.GetCmdlineUserArgs().Contains("--capture");
    private DataCatalog _catalog = null!;
    private void Check(bool condition, string message)
    { if (!condition) throw new Exception(message); _checks++; GD.Print("FEEL_PASS " + message); }
    private async Task Frames()
    { for (int i = 0; i < 2; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Shot(string name)
    {
        if (!Capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var pixels = GetViewport().GetTexture().GetImage();
        Check(pixels.SavePng($"{Output}/{name}.png") == Error.Ok, "capture " + name);
    }
    public override async void _Ready()
    {
        try
        {
            Directory.CreateDirectory(ProjectSettings.GlobalizePath(Output));
            _catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Output + "/settings.cfg"); InterfaceLessons.MarkAllSeen(settings);
            ProjectSettings.SetSetting("accessibility/reduce_motion", false);
            if (Capture)
            {
                GetWindow().Position = new(-10000, -10000);
                RenderingServer.ViewportSetUpdateMode(GetViewport().GetViewportRid(), RenderingServer.ViewportUpdateMode.Always);
            }
            foreach (int width in new[] { 1920, 1280 })
            {
                GetWindow().Size = new(width, width * 9 / 16);
                await Tianjin(width); await Wuhan(width, 1); await Wuhan(width, 4);
            }
            GD.Print($"COOKING_FEEL_RESULT passed={_checks} failed=0 demo={ExperienceProfile.IsDemo}"); GetTree().Quit();
        }
        catch (Exception ex) { GD.PushError(ex.ToString()); GetTree().Quit(1); }
    }
    private SaveService Save()
    {
        var save = new SaveService(); AddChild(save);
        save.UsePathForTests($"{Output}/fixture-{Guid.NewGuid():N}.json");
        return save;
    }
    private async Task Tianjin(int width)
    {
        var save = Save();
        save.Data.PurchasedStoveLevel = save.Data.PurchasedFryerLevel = save.Data.PurchasedIngredientStationLevel = 3;
        var day = new DayController(); AddChild(day);
        var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(screen);
        screen.ConnectController(day); screen.Initialize(_catalog, save, day, 6); screen.SetProcess(false);
        screen.BeginDay(); screen._Notification((int)NotificationApplicationFocusIn); screen._Process(3.1); screen.RefreshForCapture(true);
        var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
        station.ConfigureTutorial(PancakeWorkstation.AllWorkbenchActions);
        var canvas = station.Descendants<PancakeCanvas>().Single();
        var stroke = station.Descendants<StrokeInteractor>().Single();
        await Frames();
        station.Machine.TryExecute(PancakeCommand.PlaceBatter);
        station.Tick(.001);
        var geometry = stroke.ResolveSpreadGeometry!();
        Vector2 StrokePoint(float angle) => geometry.Center + geometry.Radii * Vector2.FromAngle(angle) * .4f;
        stroke._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = StrokePoint(0) });
        for (int i = 1; i <= 20; i++) stroke._GuiInput(new InputEventMouseMotion { Position = StrokePoint(i * .18f), ButtonMask = MouseButtonMask.Left });
        double spread = station.Machine.Runtime.SpreadCoverage;
        station.Tick(.01); Check(canvas.SpreadMarkCount > 0 && spread > 0 && spread < 1, "real partial spreading input produces a local trace");
        await Shot($"{width}-tianjin-spread");
        station.Tick(.2); Check(canvas.SpreadMarkCount == 0 && station.Machine.Runtime.SpreadCoverage == spread, "stopped spread settles without advancing progress");
        stroke._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false });
        station.Machine.SetSpreadCoverage(1); stroke.StrokeCompleted?.Invoke(StrokeMode.Spread);
        ((Button)station.FindChild("IngredientInput_egg", true, false)).EmitSignal(Button.SignalName.Pressed);
        Check(station.Machine.Runtime.HasEgg && station.Descendants<Control>().Any(n => n.Name == "EggPour"), "egg input starts liquid presentation immediately");
        Check(station.Descendants<Control>().First(n => n.Name == "EggPour").GetChild<TextureRect>(0).Size == new Vector2(15, 42), "egg liquid keeps its intended small size");
        if (Capture)
        {
            await ToSignal(GetTree().CreateTimer(.12), SceneTreeTimer.SignalName.Timeout);
            await Shot($"{width}-egg-liquid");
        }
        station.CancelInput();
        await Frames();
        foreach (bool scallion in new[] { false, true })
        {
            station.Machine.TryExecute(PancakeCommand.Discard);
            station.Tick(.001);
            var runtime = station.Machine.Runtime;
            runtime.State = PancakeState.Toppings; runtime.HasEgg = runtime.HasSauce = true;
            runtime.SauceCoverage = .8; runtime.SpreadCoverage = 1;
            runtime.AddIngredient("crispy"); if (scallion) runtime.AddIngredient("scallion");
            station.RefreshForCapture();
            string[] order = runtime.ExtraIngredientOrder.ToArray();
            int stock = station.Inventory.GetQuantity("scallion");
            Check(station.TryInvokeProductionShortcut(Key.F), "fold accepts through existing shortcut");
            station.Tick(.17);
            Check(runtime.ExtraIngredientOrder.SequenceEqual(order) && station.Inventory.GetQuantity("scallion") == stock, "fold preserves actual toppings and stock");
            await Shot($"{width}-folded-{(scallion ? "scallion" : "plain")}");
            Check(station.TryInvokeProductionShortcut(Key.F), "bag interrupts fold without adding a wait");
            station.Tick(.23);
            Check(!station.IsTransferringBag && !station.Descendants<Control>().Any(n => n.Name == "IngredientFlight" || n.Name == "EggPour"), "bag transfer clears old ingredient visuals");
            await Shot($"{width}-bag-{scallion}");
        }
        station.ResetForDay(); Check(canvas.SpreadMarkCount == 0, "new day removes transient pancake visuals");
        var fryer = station.FryerMachine!;
        for (int piece = 0; piece < fryer.Level.Capacity; piece++) Check(fryer.TryExecute(FryerCommand.LoadOne).Success, "load one real fryer slot");
        Check(fryer.TryExecute(FryerCommand.LowerBasket).Success, "lower loaded basket");
        station.Tick(.2); await Shot($"{width}-fryer-cooking");
        station.Tick(fryer.Level.AutoRaiseAtSeconds);
        Check(fryer.Runtime.State is FryerState.Raised or FryerState.Draining, "upgraded fryer raises through equipment logic");
        station.Tick(.12); await Shot($"{width}-fryer-draining");
        Check(fryer.Runtime.Quantity == fryer.Level.Capacity, "dripping changes no batch quantity");
        screen.Free(); day.Free(); save.Free(); await Frames();
    }
    private async Task Wuhan(int width, int businessDay)
    {
        var save = Save(); save.Data.Wuhan.HighestUnlockedDay = 12;
        save.Data.Wuhan.EquipmentLevels["noodle_cooker"] = 3;
        save.Data.Wuhan.EquipmentLevels["ingredient_station"] = 3;
        if (businessDay >= 4) save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 3;
        var day = new DayController(); AddChild(day);
        var screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); AddChild(screen);
        screen.ConnectController(day); screen.Initialize(_catalog, save, day, businessDay); screen.SetProcess(false);
        screen.BeginDay(); screen._Notification((int)NotificationApplicationFocusIn); screen._Process(3.1);
        var view = screen.Workstation;
        screen.Bowl.TryAddNoodles(NoodleQuality.Optimal); screen.Bowl.TryAddBaseSeasoning();
        screen.Bowl.TryAddTopping(StableIds.Ingredients.WuhanScallion);
        view._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = view.BowlCenter });
        view._Input(new InputEventMouseMotion { ButtonMask = MouseButtonMask.Left, Position = view.GetGlobalTransformWithCanvas() * (view.BowlCenter + new Vector2(25, 0)) });
        Check(view.FoodPull.Length() > 0 && view.FoodPull.Length() <= 6.001f, "real mix input pulls local noodles within six design pixels");
        double progress = screen.Bowl.MixProgress;
        Rect2 food = WuhanWorkbenchLayout.ForStage(businessDay >= 4).BowlFood;
        bool fixedEdge = Enumerable.Range(0, 32).All(i => {
            Vector2 uv = Vector2.One * .5f + Vector2.FromAngle(i * Mathf.Tau / 32) * .5f;
            return view.NoodleVertex(uv, food).DistanceTo(food.Position + food.Size * uv) < .001f;
        });
        Check(fixedEdge, "mixing does not move the food boundary across the bowl rim");
        await Shot($"{width}-wuhan-day{businessDay}-mix-pull");
        screen._Process(.2);
        Check(view.FoodPull == Vector2.Zero && screen.Bowl.MixProgress == progress, "held stationary mouse settles food without auto mixing");
        Check(screen.Bowl.Toppings.Contains(StableIds.Ingredients.WuhanScallion), "mixing preserves separate order toppings");
        view.CancelInput(); Check(view.FoodPull == Vector2.Zero && !view.IsMixing, "cancel clears tool and residual pull");
        await Shot($"{width}-wuhan-day{businessDay}-rest");
        screen.Bowl.Reset(); screen.BasketAction(0); screen._Process(1.31); screen._Process(.9);
        screen.BasketAction(0); screen._Process(.39);
        await Shot($"{width}-wuhan-day{businessDay}-pour");
        screen._Process(.3);
        Check(screen.Bowl.State == NoodleBowlState.Noodles && screen.Cooker.Baskets[0].State == NoodleBasketState.Empty, "staggered pour commits one bowl once");
        screen.IngredientAction(StableIds.Ingredients.WuhanBaseSeasoning); screen._Process(.35);
        await Shot($"{width}-wuhan-day{businessDay}-sesame"); screen._Process(.2);
        screen.IngredientAction(StableIds.Ingredients.WuhanScallion); screen._Process(.37);
        await Shot($"{width}-wuhan-day{businessDay}-scallion"); screen._Process(.15);
        if (businessDay == 4)
        {
            screen.PourDoupiBatter(); screen._Process(.4); screen.AddDoupiEgg(); screen._Process(2.51);
            screen._Process(.15); await Shot($"{width}-doupi-auto-flip");
            screen._Process(.5); screen.AddDoupiFilling(); screen._Process(3.6);
            Check(screen.CutDoupi(DoupiCutLine.Horizontal), "first cut accepts");
            var quality = screen.Doupi!.Quality; screen._Process(.4);
            Check(screen.CutDoupi(DoupiCutLine.Center), "one vertical gesture commits all three vertical lines");
            screen._Process(.27); await Shot($"{width}-doupi-seams");
            screen._Process(.4); screen._Process(.55);
            Check(screen.DoupiStock.Count == 8 && screen.DoupiStock.PieceAt(0).Quality == quality, "one pan produces eight pieces with first-cut quality");
            await Shot($"{width}-doupi-stock");
        }
        ProjectSettings.SetSetting("accessibility/reduce_motion", true);
        view.Tick(.2); Check(view.FoodPull == Vector2.Zero, "reduced motion clears local deformation");
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
        screen.Hide(); Check(view.ActiveMotionCount == 0, "leaving city clears all production motions");
        screen.Free(); day.Free(); save.Free(); await Frames();
    }
}
