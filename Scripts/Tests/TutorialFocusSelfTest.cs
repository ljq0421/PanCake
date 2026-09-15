using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

/// <summary>Native focus, input, success-only memory and lifecycle regression/capture fixture.</summary>
public partial class TutorialFocusSelfTest : Node
{
    private int _checks;
    private SubViewport _viewport = null!;
    private bool _capture;
    private string _directory = "";
    private async Task Frames(int count = 3) { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private void Check(bool value, string text) { if (!value) throw new InvalidOperationException(text); _checks++; GD.Print("PASS " + text); }
    private async Task Shot(string name)
    {
        await Frames(4);
        if (!_capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using Image image = _viewport.GetTexture().GetImage();
        Check(image.SavePng(Path.Combine(_directory, name + ".png")) == Error.Ok, "capture " + name);
    }
    private void Move(Control owner, Vector2 point, bool held = false)
    {
        Vector2 p = owner.GetGlobalTransformWithCanvas() * point;
        _viewport.PushInput(new InputEventMouseMotion { Position = p, GlobalPosition = p, ButtonMask = held ? MouseButtonMask.Left : 0 }, true);
    }
    private void Button(Control owner, Vector2 point, bool pressed)
    {
        Vector2 p = owner.GetGlobalTransformWithCanvas() * point;
        _viewport.PushInput(new InputEventMouseButton { Position = p, GlobalPosition = p, ButtonIndex = MouseButton.Left, Pressed = pressed }, true);
    }
    private void Drag(Control owner, Vector2 from, Vector2 to)
    { Move(owner, from); Button(owner, from, true); Move(owner, to, true); Button(owner, to, false); }
    private void Click(Control owner, Vector2 at) => Drag(owner, at, at);
    private void OneOrder(DayController controller, string city, params OrderLineData[] lines)
    {
        controller.CustomerQueue!.ResolveBeforeArrival = (p, _) => new OrderData { OrderId = p.Order.OrderId, CityId = city,
            CustomerTypeId = p.CustomerTypeId, PatienceSeconds = 1000, Lines = lines, BasePrice = p.Order.BasePrice };
    }
    public override async void _Ready()
    {
        try
        {
            _capture = OS.GetCmdlineUserArgs().Contains("--capture");
            bool small = OS.GetCmdlineUserArgs().Contains("--small");
            _directory = ProjectSettings.GlobalizePath($"res://.tmp/tutorial-focus/{(small ? 720 : 1080)}"); Directory.CreateDirectory(_directory);
            _viewport = new SubViewport { Size = small ? new Vector2I(1280, 720) : new Vector2I(1920, 1080),
                Size2DOverride = new Vector2I(1920, 1080), Size2DOverrideStretch = true, Disable3D = true, RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
            AddChild(_viewport); _viewport.NotifyMouseEntered();
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            string savePath = Path.Combine(_directory, Guid.NewGuid() + ".json");
            var save = new SaveService(); save.UsePathForTests(savePath); AddChild(save);
            await Tianjin(catalog, save); await Wuhan(catalog, save);
            Check(save.TrySave(out _), "learned operations persist");
            var reloaded = new SaveService(); reloaded.UsePathForTests(savePath); AddChild(reloaded);
            Check(reloaded.Data.Tianjin.LearnedWorkbenchActions.SetEquals(save.Data.Tianjin.LearnedWorkbenchActions)
                && reloaded.Data.Wuhan.LearnedWorkbenchActions.SetEquals(save.Data.Wuhan.LearnedWorkbenchActions), "both cities reload learned operations");
            var legacy = System.Text.Json.Nodes.JsonNode.Parse(File.ReadAllText(savePath))!;
            foreach (var entry in legacy["Cities"]!.AsObject()) entry.Value!.AsObject().Remove("LearnedWorkbenchActions");
            string legacyPath = Path.Combine(_directory, "legacy-no-teaching.json"); File.WriteAllText(legacyPath, legacy.ToJsonString());
            var oldSave = new SaveService(); oldSave.UsePathForTests(legacyPath); AddChild(oldSave);
            Check(!oldSave.HasLoadError && oldSave.Data.Tianjin.LearnedWorkbenchActions.Count == 0 && oldSave.Data.Wuhan.LearnedWorkbenchActions.Count == 0,
                "old saves without teaching records load as unlearned");
            GD.Print($"TUTORIAL_FOCUS_SELF_TEST_OK {_checks}"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
    private async Task Tianjin(DataCatalog catalog, SaveService save)
    {
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); _viewport.AddChild(screen);
        screen.ConnectController(controller); screen.SetProcess(false);
        Check(screen.Initialize(catalog, save, controller, 1), "Tianjin initializes");
        string recipe = catalog.RecipesById.Values.First(r => r.Id.StartsWith("pancake") && r.ExtraIngredients.Count == 0).Id;
        screen.BeginDay(); OneOrder(controller, StableIds.Cities.Tianjin, new OrderLineData(ProductKind.Pancake, recipe, 1));
        controller.Tick(3.1); controller.Tick(.5); for (int i = 0; i < 30 && TutorialOrders.Pending(controller, catalog).Count == 0; i++) controller.Tick(1); screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
        var station = screen.Descendants<PancakeWorkstation>().Single(); var focus = screen.TeachingFocus;
        focus.Refresh(); Check(focus.CurrentAction == "take:batter", $"Tianjin first action highlights batter: action={focus.CurrentAction}, state={controller.State}, pending={TutorialOrders.Pending(controller,catalog).Count}, slots={controller.CustomerQueue!.Slots.Count}, visible={screen.IsVisibleInTree()}, station={station.IsVisibleInTree()}, paused={controller.IsPaused}"); await Shot("tianjin-batter");
        var batterTarget = focus.Resolve()!.Targets.Single();
        Check(batterTarget.Texture is not null, "painted tutorial source uses the hover artwork matte");
        using (Image matte = batterTarget.Texture!.GetImage())
            Check(matte.GetPixel(0,0).A < .1f && matte.GetPixel(matte.GetWidth()/2,matte.GetHeight()/2).A > .9f,
                "spotlight leaves empty matte corners shaded and the ingredient center clear");
        Check(InteractionHighlightPresentation.ColorFor(InteractionHighlightState.Hover, focus) == new Color("FFF06A"), "Tianjin tutorial inherits hover color");
        var batter = station.Descendants<DragItem>().Single(d => d.PayloadId == "batter");
        batter.TryBeginDrag(); focus.Refresh();
        Check(focus.CurrentAction == "take:batter" && focus.FocusPolygons[0].Average(p => p.X) < 1000, "held batter targets stove instead of source"); await Shot("tianjin-held-batter");
        station.CancelInput(); focus.Refresh();
        Check(!save.Data.Tianjin.LearnedWorkbenchActions.Contains("take:batter"), "cancelled batter drag does not teach");
        var machine = station.Machine;
        void Do(PancakeCommand command) { Check(machine.TryExecute(command).Success, "fixture " + command); }
        Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Do(PancakeCommand.CompleteSpread); screen.RefreshForCapture(true);
        focus.Refresh(); Check(focus.CurrentAction == "take:egg", "egg is highlighted after spreading"); await Shot("tianjin-egg");
        station.Descendants<Button>().Single(b => b.Name == "IngredientInput_egg").EmitSignal(Godot.Button.SignalName.Pressed);
        Check(save.Data.Tianjin.LearnedWorkbenchActions.Contains("take:egg"), "successful egg operation is learned");
        station.Tick(.1); focus.Refresh(); Check(focus.CurrentAction == "flip", "heat wait targets current stove");
        focus.Dismiss(); focus.Refresh(); Check(!focus.Visible && focus.Dismissed, "close suppresses this shift");
        station.LearnWorkbenchAction("spread"); focus.Refresh(); Check(!focus.Visible, "success does not reopen dismissed guidance");
        controller.AbandonDay(); Check(screen.Initialize(catalog, save, controller, 1), "next Tianjin shift initializes");
        screen.BeginDay(); OneOrder(controller, StableIds.Cities.Tianjin, new OrderLineData(ProductKind.Pancake, recipe, 1)); controller.Tick(3.1); controller.Tick(.5); for (int i = 0; i < 30 && TutorialOrders.Pending(controller, catalog).Count == 0; i++) controller.Tick(1); screen.RefreshForCapture(true); focus.Refresh();
        Check(!focus.Dismissed && focus.CurrentAction == "take:batter", "new shift resumes unlearned actions");
        screen._Notification((int)NotificationApplicationFocusOut); focus.Refresh(); Check(!focus.Visible, "Tianjin focus loss hides mask");
        screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true); focus.Refresh(); Check(focus.Visible, "Tianjin focus return resolves again");
        controller.AbandonDay(); save.Data.Tianjin.HighestUnlockedDay = 12;
        foreach (int day in new[] { 3, 5, 9 })
        {
            Check(screen.Initialize(catalog, save, controller, day), $"Tianjin stage {day} initializes");
            string id = day == 3 ? controller.CurrentConfig!.AvailableRecipeIds.First(r => catalog.RecipesById[r].ExtraIngredients.Count > 0)
                : day == 5 ? StableIds.Products.Youtiao : StableIds.Products.SoyMilk;
            ProductKind kind = day == 3 ? ProductKind.Pancake : day == 5 ? ProductKind.Youtiao : ProductKind.SoyMilk;
            screen.BeginDay(); OneOrder(controller, StableIds.Cities.Tianjin, new OrderLineData(kind, id, 1));
            controller.Tick(3.1); for (int i = 0; i < 30 && TutorialOrders.Pending(controller, catalog).Count == 0; i++) controller.Tick(1);
            screen.RefreshForCapture(true); focus.Refresh();
            if (day == 3)
            {
                machine = station.Machine;
                Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Do(PancakeCommand.CompleteSpread); Do(PancakeCommand.AddEgg);
                station.Tick(machine.Stove.SideAReadySeconds + .01); Do(PancakeCommand.Flip); station.Tick(machine.Stove.SideBReadySeconds + .01);
                screen.RefreshForCapture(true); focus.Refresh(); Check(focus.CurrentAction == "take:sauce", "Tianjin sauce source is highlighted"); await Shot("tianjin-sauce");
                Do(PancakeCommand.BeginSauce); machine.SetSauceCoverage(1); screen.RefreshForCapture(true); focus.Refresh();
                Check(focus.CurrentAction == "sauce", "brush targets pancake surface"); await Shot("tianjin-brush");
                Do(PancakeCommand.CompleteSauce); screen.RefreshForCapture(true); focus.Refresh();
                Check(catalog.RecipesById[id].ExtraIngredients.Any(t => focus.CurrentAction == "take:" + t), "new topping follows the actual order"); await Shot("tianjin-topping");
            }
            else if (day == 5)
            {
                Check(focus.CurrentAction == "fryer:load", "new fryer introduces loading"); await Shot("tianjin-fryer-load");
                station.Descendants<PressRepeatGesture>().Single().Activate!(); screen.RefreshForCapture(true); focus.Refresh();
                Check(focus.CurrentAction == "fryer:lower", "loaded fryer targets lower button"); await Shot("tianjin-fryer-lower");
                machine = station.Machine;
                Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Do(PancakeCommand.CompleteSpread); Do(PancakeCommand.AddEgg);
                station.Tick(machine.Stove.SideAReadySeconds + .01); Do(PancakeCommand.Flip); station.Tick(machine.Stove.SideBReadySeconds + .01);
                Do(PancakeCommand.BeginSauce); machine.SetSauceCoverage(1); Do(PancakeCommand.CompleteSauce);
                station.FryerMachine!.Inventory.TryStore(1, ProjectCake.Fryer.YoutiaoQuality.Golden); screen.RefreshForCapture(true);
                station.Descendants<DragItem>().Single(d => d.PayloadId == "stored_youtiao").TryBeginDrag();
                var toppingOrder = new TutorialOrder("fixture", ProductKind.Pancake, "fixture", new[] { "scallion", "youtiao" });
                Check(station.ResolveFocus(new[] { toppingOrder }, (_, _) => Array.Empty<TutorialFocusTarget>())?.ActionId == "take:youtiao",
                    "held youtiao takes priority over another missing topping");
                Check(station.ResolveFocus(new[] { new TutorialOrder("fixture", ProductKind.Youtiao, StableIds.Products.Youtiao, Array.Empty<string>()) },
                    (_, _) => new[] { TutorialFocusTarget.Area(screen, new Rect2(500, 200, 200, 200)) })?.ActionId == "deliver:stored_youtiao",
                    "held youtiao targets customer when pancake does not need it");
                station.CancelInput();
            }
            else
            {
                Check(focus.CurrentAction == "deliver:soy_milk_cup", "new soy milk highlights its tray"); await Shot("tianjin-soy");
            }
            controller.AbandonDay();
        }
        screen.Hide(); focus.Refresh(); Check(!focus.Visible, "hidden city has no mask"); screen.QueueFree(); controller.QueueFree(); await Frames();
    }
    private async Task Wuhan(DataCatalog catalog, SaveService save)
    {
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); _viewport.AddChild(screen);
        screen.ConnectController(controller); screen.SetProcess(false); save.Data.Wuhan.HighestUnlockedDay = 12;
        Check(screen.Initialize(catalog, save, controller, 1), "Wuhan initializes"); screen.BeginDay();
        string recipe = catalog.RecipesById.Values.First(r => r.Id.StartsWith("hot_dry_noodles_") && r.ExtraIngredients.Count == 0).Id;
        OneOrder(controller, StableIds.Cities.Wuhan, new OrderLineData(ProductKind.HotDryNoodles, recipe, 1));
        void Step(double dt) { screen._Notification((int)NotificationApplicationFocusIn); screen._Process(dt); }
        Step(3.1); Step(.5); for (int i = 0; i < 30 && TutorialOrders.Pending(controller, catalog).Count == 0; i++) Step(1); await Frames();
        var view = screen.Workstation; var focus = screen.TeachingFocus; focus.Refresh();
        Check(focus.CurrentAction == "take:noodles", "Wuhan first action highlights raw tray"); await Shot("wuhan-raw");
        Check(InteractionHighlightPresentation.ColorFor(InteractionHighlightState.Hover, focus) == new Color("20B8AA"), "Wuhan tutorial inherits hover color");
        Move(view, view.RawCenter); Button(view, view.RawCenter, true); Move(view, view.BasketRect(0).GetCenter(), true); focus.Refresh();
        Check(view.HasProductionGesture && focus.CurrentAction == "take:noodles" && focus.CurrentText.Contains("松手"), "actual raw drag switches to basket"); await Shot("wuhan-held-noodles");
        view.CancelInput(); Button(view, view.RawCenter, false); focus.Refresh();
        Check(!save.Data.Wuhan.LearnedWorkbenchActions.Contains("take:noodles"), "cancelled noodles do not teach");
        Drag(view, view.RawCenter, view.BasketRect(0).GetCenter());
        Check(save.Data.Wuhan.LearnedWorkbenchActions.Contains("take:noodles"), "successful raw drag is learned through shade");
        Step(.3); Step(catalog.NoodleCookersByLevel[1].OptimalSeconds + .01); await Frames();
        Check(screen.RaiseBasket(0), "raising succeeds"); Step(.4); screen.Cooker.TryQuickDrain(0);
        Check(screen.ReservePour(0), "pour reservation succeeds"); Step(1); await Frames(); Step(.01); focus.Refresh();
        Check(save.Data.Wuhan.LearnedWorkbenchActions.Contains("pour:noodles"), "actual pour completion is learned");
        Check(focus.CurrentAction == "take:" + StableIds.Ingredients.WuhanBaseSeasoning, "seasoning is the next target"); await Shot("wuhan-seasoning");
        screen.IngredientAction(StableIds.Ingredients.WuhanBraisedBeef);
        Check(!save.Data.Wuhan.LearnedWorkbenchActions.Contains("take:" + StableIds.Ingredients.WuhanBraisedBeef), "failed topping is not learned");
        Click(view, view.IngredientCenter(0)); Step(.8); focus.Refresh();
        Check(save.Data.Wuhan.LearnedWorkbenchActions.Contains("take:" + StableIds.Ingredients.WuhanBaseSeasoning), "valid seasoning click passes through shade");
        Check(focus.CurrentAction == "mix:noodles", "mixing targets bowl"); await Shot("wuhan-mix");
        Move(view, view.BowlCenter); Button(view, view.BowlCenter, true);
        for (int i = 0; i < 12; i++) Move(view, view.BowlCenter + new Vector2(i % 2 == 0 ? 45 : -45, 0), true);
        Button(view, view.BowlCenter, false); Step(.01); focus.Refresh();
        Check(save.Data.Wuhan.LearnedWorkbenchActions.Contains("mix:noodles"), "completed real mixing is learned");
        Check(focus.CurrentAction == "deliver:hot_dry_noodles", "ready meal targets delivery source"); await Shot("wuhan-ready");
        view.GetNode<DragItem>("WuhanDrag_HotDryNoodles").TryBeginDrag(); focus.Refresh();
        Check(focus.FocusPolygons.Count > 0 && focus.FocusPolygons[0].Min(p => p.Y) < 500 && focus.FocusPolygons[0].Max(p => p.Y) < 850, "held meal highlights recipient"); await Shot("wuhan-customer"); view.CancelInput();
        string recipient = TutorialOrders.Pending(controller, catalog).First(o => o.Kind == ProductKind.HotDryNoodles).CustomerId;
        Check(screen.DeliverToCustomer(recipient, ProductKind.HotDryNoodles) && save.Data.Wuhan.LearnedWorkbenchActions.Contains("deliver:hot_dry_noodles"), "accepted noodle delivery is learned");
        controller.SetPauseReason("test", true); focus.Refresh(); Check(!focus.Visible, "paused shift hides guidance"); controller.SetPauseReason("test", false);
        focus.Dismiss(); controller.AbandonDay(); Check(screen.Initialize(catalog, save, controller, 4), "doupi unlock stage initializes");
        screen.BeginDay(); OneOrder(controller, StableIds.Cities.Wuhan, new OrderLineData(ProductKind.Doupi, StableIds.Products.Doupi, 1)); Step(3.1); Step(.5); for (int i = 0; i < 30 && TutorialOrders.Pending(controller, catalog).Count == 0; i++) Step(1); focus.Refresh();
        Check(!focus.Dismissed && focus.CurrentAction == "doupi:batter", "new stage introduces unlearned doupi"); await Shot("wuhan-doupi-batter");
        Drag(view, view.BatterCenter, view.PanCenter); Step(.8); focus.Refresh();
        Check(save.Data.Wuhan.LearnedWorkbenchActions.Contains("doupi:batter") && focus.CurrentAction == "doupi:egg", "doupi batter succeeds then targets egg"); await Shot("wuhan-doupi-egg");
        Click(view, view.DoupiEggCenter); Step(catalog.DoupiGriddlesByLevel[1].StageSeconds + .1);
        Drag(view, view.PanCenter, view.PanCenter - new Vector2(0, 60)); Step(.8); focus.Refresh();
        Check(save.Data.Wuhan.LearnedWorkbenchActions.Contains("doupi:flip") && focus.CurrentAction == "doupi:filling", "flip succeeds then targets filling"); await Shot("wuhan-doupi-filling");
        Drag(view, view.FillingCenter, view.PanCenter); Step(.5); Step(catalog.DoupiGriddlesByLevel[1].SecondStageReadySeconds + .1); focus.Refresh();
        Check(focus.CurrentAction == "doupi:cut", "cooked doupi targets knife"); await Shot("wuhan-knife");
        Click(view, view.KnifeCenter); focus.Refresh(); Check(view.IsKnifeHeld && focus.CurrentText.Contains("横划"), "held knife targets pan"); await Shot("wuhan-held-knife");
        view.CancelInput(); Check(!save.Data.Wuhan.LearnedWorkbenchActions.Contains("doupi:cut"), "picking up then cancelling knife is not mastery");
        foreach (bool horizontal in new[] { true, false })
        {
            if (!view.IsKnifeHeld) Click(view, view.KnifeCenter);
            Drag(view, horizontal ? view.PanPoint(.05f, .5f) : view.PanPoint(.5f, .05f), horizontal ? view.PanPoint(.95f, .5f) : view.PanPoint(.5f, .95f));
            Step(.4);
        }
        Step(.6); focus.Refresh();
        Check(save.Data.Wuhan.LearnedWorkbenchActions.Contains("doupi:cut") && screen.DoupiStock.Count == 8, "complete cut gesture teaches and transfers eight pieces"); await Shot("wuhan-doupi-ready");
        screen.Hide(); focus.Refresh(); Check(!focus.Visible, "Wuhan hidden city clears mask"); screen.QueueFree(); controller.QueueFree(); await Frames();
    }
}
