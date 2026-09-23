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
    private void CheckSkipGuidance(Control screen, TutorialFocusLayer focus)
    {
        var skip = focus.Descendants<Godot.Button>().Single(b => b.Name == "SkipGuidance");
        var pause = screen.Descendants<Godot.Button>().Single(b => b.Name == "HudPause");
        Check(skip.IsVisibleInTree() && skip.Text == "跳过教学" && !skip.HasFocus(), "normal business exposes skip without default focus");
        Check(skip.GetGlobalRect().Position == new Vector2(1620, 28)
            && !skip.GetGlobalRect().Intersects(pause.GetGlobalRect())
            && !skip.GetGlobalRect().Intersects(focus.CardBounds), $"skip stays at right edge clear of pause and teaching card: skip={skip.GetGlobalRect()}, pause={pause.GetGlobalRect()}, card={focus.CardBounds}");
    }
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
            string outputRoot = OS.GetCmdlineUserArgs().FirstOrDefault(arg => arg.StartsWith("--output="))
                ?.Substring("--output=".Length) ?? "res://.tmp/tutorial-focus";
            _directory = ProjectSettings.GlobalizePath($"{outputRoot}/{(small ? 720 : 1080)}"); Directory.CreateDirectory(_directory);
            _viewport = new SubViewport { Size = small ? new Vector2I(1280, 720) : new Vector2I(1920, 1080),
                Size2DOverride = new Vector2I(1920, 1080), Size2DOverrideStretch = true, Disable3D = true, RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
            AddChild(_viewport); _viewport.NotifyMouseEntered();
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            string savePath = Path.Combine(_directory, Guid.NewGuid() + ".json");
            var save = new SaveService(); save.UsePathForTests(savePath); AddChild(save);
            if (OS.GetCmdlineUserArgs().Contains("--sesame-only")) await WuhanSesame(catalog, save);
            else if (OS.GetCmdlineUserArgs().Contains("--order-paper-only")) await OrderPaper(catalog, save);
            else if (OS.GetCmdlineUserArgs().Contains("--sauce-only")) await TianjinSauce(catalog, save);
            else if (OS.GetCmdlineUserArgs().Contains("--beef-only")) await WuhanBeef(catalog, save);
            else if (OS.GetCmdlineUserArgs().Contains("--wuhan-only")) await Wuhan(catalog, save, savePath);
            else
            {
                await TianjinMaintenance(catalog, save);
                if (!OS.GetCmdlineUserArgs().Contains("--maintenance-only")) { await Tianjin(catalog, save); await Wuhan(catalog, save, savePath); }
            }
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
    private async Task WuhanSesame(DataCatalog catalog, SaveService save)
    {
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        settings.UsePathForTests(Path.Combine(_directory, "sesame-settings.cfg"));
        InterfaceLessons.MarkAllSeen(settings);
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");
        _viewport.AddChild(screen); screen.ConnectController(controller); screen.SetProcess(false);
        Check(screen.Initialize(catalog, save, controller, 1), "sesame lesson initializes");
        screen.ForceDemoTutorial = true; screen.BeginDay();
        void Step(double dt) { screen._Notification((int)NotificationApplicationFocusIn); screen._Process(dt); }
        Step(.5); await Frames();
        var view = screen.Workstation; var focus = screen.TeachingFocus;
        var order = TutorialOrders.Pending(controller, catalog).Single();
        Check(order.Toppings.Count > 0, "lesson has ordered toppings");
        screen.Bowl.TryAddNoodles(NoodleQuality.Optimal); Step(.01); focus.Refresh();
        Check(focus.CurrentAction == "take:" + StableIds.Ingredients.WuhanBaseSeasoning, "sesame is taught before ordered toppings");
        await Shot("sesame-first");
        foreach (string topping in new[] { StableIds.Ingredients.WuhanScallion, StableIds.Ingredients.WuhanChiliOil })
        {
            Click(view, view.IngredientCenter(Array.IndexOf(WuhanWorkstationView.IngredientIds, topping))); Step(.8); focus.Refresh();
            Check(screen.Bowl.Toppings.Contains(topping) && !screen.Bowl.HasBaseSeasoning
                && !screen.Bowl.AddMixDistance(500), "early topping does not add sesame or enable mixing");
            Check(WuhanWorkstationView.BowlLayers(new Rect2(0, 0, 200, 200), screen.Bowl.HasBaseSeasoning,
                0, screen.Bowl.Quality, screen.Bowl.Toppings).All(l => l.Id != "unmixed"), "early topping does not render sesame");
            await Shot(topping == StableIds.Ingredients.WuhanScallion ? "scallion-without-sesame" : "chili-without-sesame");
            screen.Bowl.Reset(); screen.Bowl.TryAddNoodles(NoodleQuality.Optimal);
        }
        Click(view, view.IngredientCenter(0)); Step(.8); focus.Refresh();
        Check(screen.Bowl.HasBaseSeasoning && order.Toppings.Any(t => focus.CurrentAction == "take:" + t), "adding sesame advances to ordered topping");
        Check(WuhanWorkstationView.BowlLayers(new Rect2(0, 0, 200, 200), screen.Bowl.HasBaseSeasoning,
            0, screen.Bowl.Quality, screen.Bowl.Toppings).Any(l => l.Id == "unmixed"), "sesame appears after its actual click");
        await Shot("sesame-added");
        foreach (string topping in order.Toppings)
        { Click(view, view.IngredientCenter(Array.IndexOf(WuhanWorkstationView.IngredientIds, topping))); Step(.8); }
        focus.Refresh(); Check(focus.CurrentAction == "mix:noodles", "seasoning steps lead to mixing");
        Move(view, view.BowlCenter); Button(view, view.BowlCenter, true);
        for (int i = 0; i < 12; i++) Move(view, view.BowlCenter + new Vector2(i % 2 == 0 ? 45 : -45, 0), true);
        Button(view, view.BowlCenter, false); Step(.01);
        Check(screen.DeliverToCustomer(order.CustomerId, ProductKind.HotDryNoodles) && !screen.DemoLessonFailed, "seasoned meal completes tutorial");
        await Shot("sesame-lesson-complete");
        screen.QueueFree(); controller.QueueFree(); await Frames();
    }
    private async Task OrderPaper(DataCatalog catalog, SaveService save)
    {
        foreach (bool wuhan in new[] { false, true })
        {
            var controller = new DayController(); AddChild(controller);
            Control screen = wuhan
                ? SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn")
                : SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
            _viewport.AddChild(screen); screen.SetProcess(false);
            TutorialFocusLayer focus;
            if (screen is WuhanDayScreen ws)
            { ws.ConnectController(controller); Check(ws.Initialize(catalog, save, controller, 1), "Wuhan paper initializes"); ws.BeginDay(); focus = ws.TeachingFocus; }
            else
            { var ts = (TianjinDayScreen)screen; ts.ConnectController(controller); Check(ts.Initialize(catalog, save, controller, 1), "Tianjin paper initializes"); ts.BeginDay(); focus = ts.TeachingFocus; }
            controller.Tick(3.1); controller.Tick(.5);
            await Frames();
            screen._Notification((int)NotificationApplicationFocusIn);
            if (screen is WuhanDayScreen refresh) refresh.RefreshForCapture(); else ((TianjinDayScreen)screen).RefreshForCapture(true);
            await Frames(); focus.Refresh();
            Check(focus.Visible, "order paper checked under active teaching shade");
            var card = screen.Descendants<OrderBubbleView>().First(c => c.IsVisibleInTree());
            var target = TutorialFocusTarget.Control(card, false);
            Check(target.Texture is not null && !target.Outline && target.Bounds.Position.Y < 0 && target.Bounds.End.Y > card.Size.Y,
                "teaching includes paper ornaments and tail without a rectangular outline");
            using Image matte = target.Texture!.GetImage();
            Check(matte.GetPixel(0, 0).A < .01f && matte.GetPixel(matte.GetWidth() / 2, matte.GetHeight() / 2).A > .99f,
                "paper center stays bright and surrounding corner remains shaded");
            Check(matte.GetPixel(matte.GetWidth() / 2, matte.GetHeight() - 4).A > .99f,
                "paper tail stays bright");
            await Shot(wuhan ? "wuhan-order-paper" : "tianjin-order-paper");
            screen.QueueFree(); controller.QueueFree(); await Frames();
        }
    }

    private async Task TianjinSauce(DataCatalog catalog, SaveService save)
    {
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn");
        _viewport.AddChild(screen); screen.ConnectController(controller); screen.SetProcess(false);
        Check(screen.Initialize(catalog, save, controller, 1), "sauce lesson initializes");
        screen.BeginDay();
        string recipe = catalog.RecipesById.Values.First(r => r.Id.StartsWith("pancake") && r.ExtraIngredients.Count == 0).Id;
        OneOrder(controller, StableIds.Cities.Tianjin, new OrderLineData(ProductKind.Pancake, recipe, 1));
        controller.Tick(3.1); controller.Tick(.5);
        var station = screen.Descendants<PancakeWorkstation>().Single();
        var machine = station.Machine;
        void Do(PancakeCommand command) => Check(machine.TryExecute(command).Success, "sauce setup " + command);
        Do(PancakeCommand.PlaceBatter); Do(PancakeCommand.BeginSpread); Do(PancakeCommand.CompleteSpread); Do(PancakeCommand.AddEgg);
        machine.Tick(machine.Stove.SideAReadySeconds + .01); Do(PancakeCommand.Flip);
        machine.Tick(machine.Stove.SideBReadySeconds + .01); Do(PancakeCommand.BeginSauce);
        machine.SetSauceCoverage(.65);
        await Frames();
        screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
        var stroke = station.Descendants<StrokeInteractor>().Single();
        stroke.RefreshVisualState(); screen.TeachingFocus.Refresh();
        Check(screen.TeachingFocus.CurrentAction == "sauce" && stroke.SauceMeterVisible,
            "sauce teaching and meter are visible together");
        Check(!screen.TeachingFocus.CardBounds.Intersects(stroke.GetGlobalTransform() * stroke.SauceMeterBounds()),
            "sauce teaching card avoids meter");
        await Shot("tianjin-sauce-meter-teaching");
        screen.QueueFree(); controller.QueueFree(); await Frames();
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
        CheckSkipGuidance(screen, focus);
        var skip = focus.Descendants<Godot.Button>().Single(b => b.Name == "SkipGuidance");
        Click(skip, skip.Size / 2); focus.Refresh(); Check(!focus.Visible && focus.Dismissed, "right-edge skip suppresses this shift");
        Check(controller.State == DayState.Running && !controller.TutorialActive, "skip preserves normal business");
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
                Move(station, TianjinWorkbenchLayout.EmbeddedSurface.GetCenter());
                await Frames(); focus.Refresh();
                Check(focus.CurrentAction == "sauce", "brush targets pancake surface"); await Shot("tianjin-brush");
                var stroke = station.Descendants<StrokeInteractor>().Single();
                Check(stroke.SauceMeterVisible && !focus.CardBounds.Intersects(stroke.GetGlobalTransform() * stroke.SauceMeterBounds()),
                    "brush teaching card stays clear of the visible sauce meter");
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
                focus.Refresh();
                Check(focus.CurrentAction == "deliver:stored_youtiao", "held youtiao spotlights actual recipient");
                CheckRecipientCrop(focus);
                await Shot("tianjin-youtiao-customer");
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
    private async Task WuhanBeef(DataCatalog catalog, SaveService save)
    {
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        settings.UsePathForTests(Path.Combine(_directory, "beef-settings.cfg"));
        InterfaceLessons.MarkAllSeen(settings);
        save.Data.Wuhan.HighestUnlockedDay = 3;
        save.Data.Wuhan.LearnedWorkbenchActions.UnionWith(new[] { "take:noodles", "pour:noodles", "mix:noodles", "deliver:hot_dry_noodles" });
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");
        _viewport.AddChild(screen); screen.ConnectController(controller); screen.SetProcess(false);
        Check(screen.Initialize(catalog, save, controller, 3), "beef day initializes");
        screen.BeginDay();
        void Step(double dt) { screen._Notification((int)NotificationApplicationFocusIn); screen._Process(dt); }
        Step(.5); await Frames();
        var focus = screen.TeachingFocus; var view = screen.Workstation;
        var guest = controller.CustomerQueue!.Slots.Single();
        Check(controller.TutorialActive && controller.CurrentConfig!.Day == 3, "day three starts an independent beef lesson");
        Check(guest.Order.Lines.Single().DefinitionId == StableIds.Recipes.HotDryNoodlesBeef, "lesson guest orders one beef noodle bowl");
        double elapsed = controller.DayElapsedSeconds;
        double patience = guest.WaitSeconds;
        Step(120);
        Check(controller.DayElapsedSeconds == elapsed && guest.WaitSeconds == patience
            && controller.CustomerQueue.Slots.Count == 1, "lesson freezes clocks and admits no later guests");
        screen.Bowl.TryAddNoodles(NoodleQuality.Optimal); screen.Bowl.TryAddBaseSeasoning();
        screen.IngredientAction(StableIds.Ingredients.WuhanBraisedBeef);
        Check(screen.Bowl.Toppings.Count == 0, "lesson rejects beef before mixing");
        focus.Refresh(); Check(focus.CurrentAction == "mix:noodles" && focus.CurrentText.Contains("再加牛肉"), "known mixing action is explained again for beef");
        CheckAdjacent(focus); await Shot("wuhan-beef-before-mix");
        Move(view, view.BowlCenter); Button(view, view.BowlCenter, true);
        for (int i = 0; i < 12; i++) Move(view, view.BowlCenter + new Vector2(i % 2 == 0 ? 45 : -45, 0), true);
        Button(view, view.BowlCenter, false); Step(.01); focus.Refresh();
        Check(focus.CurrentAction == "take:" + StableIds.Ingredients.WuhanBraisedBeef && focus.CurrentText.Contains("无需再次搅拌"), "mixed bowl highlights beef");
        CheckAdjacent(focus); await Shot("wuhan-beef-add");
        Click(view, view.IngredientCenter(3)); Step(.8); focus.Refresh();
        Check(focus.CurrentAction == "deliver:hot_dry_noodles", "beef goes straight to delivery");
        Check(screen.DeliverToCustomer(guest.Id, ProductKind.HotDryNoodles), "beef lesson accepts correct meal");
        Check(controller.Ledger!.SaleRevenue == 0 && controller.Ledger.Tips == 0, "lesson earns no business revenue");
        await Shot("wuhan-beef-complete");
        screen.FinishWuhanDemoLesson(); Step(.5);
        Check(!controller.TutorialActive && controller.CurrentConfig!.Day == 3, "completion starts actual day three");
        Check(save.Data.Wuhan.LearnedWorkbenchActions.Contains("take:" + StableIds.Ingredients.WuhanBraisedBeef), "successful beef action is saved");
        Check(controller.CurrentPlan!.Customers.First().Order.Lines.Single().DefinitionId == StableIds.Recipes.HotDryNoodlesBeef, "first business guest also orders beef");
        controller.AbandonDay(); screen.QueueFree(); await Frames();
        save.Data.Wuhan.LearnedWorkbenchActions.Remove("take:" + StableIds.Ingredients.WuhanBraisedBeef);
        screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");
        _viewport.AddChild(screen); screen.ConnectController(controller); screen.SetProcess(false);
        Check(screen.Initialize(catalog, save, controller, 3), "retry fixture initializes"); screen.BeginDay(); Step(.5);
        screen.Bowl.TryAddNoodles(NoodleQuality.Optimal); screen.Bowl.TryAddBaseSeasoning(); screen.Bowl.AddMixDistance(1000);
        screen.DeliverToCustomer(controller.CustomerQueue!.Slots.Single().Id, ProductKind.HotDryNoodles);
        Check(screen.DemoLessonFailed, "missing beef fails the lesson");
        screen.RetryWuhanDemoLesson(); Step(.5);
        Check(!screen.DemoLessonFailed && controller.TutorialActive && controller.CurrentConfig!.Day == 3
            && controller.CustomerQueue!.Slots.Single().Order.Lines.Single().DefinitionId == StableIds.Recipes.HotDryNoodlesBeef, "retry stays on the beef lesson");
        screen.FinishWuhanDemoLesson(); Step(.5);
        Check(!controller.TutorialActive && !save.Data.Wuhan.LearnedWorkbenchActions.Contains("take:" + StableIds.Ingredients.WuhanBraisedBeef), "skip starts business without falsely learning beef or reopening the lesson");
        controller.AbandonDay(); screen.ForceDemoTutorial = true; screen.BeginDay(); Step(.5);
        Check(controller.TutorialActive && controller.CurrentConfig!.Day == 1, "explicit replay still opens the original day-one lesson");
        var firstLesson = controller.CustomerQueue!.Slots.Single();
        screen.Bowl.TryAddNoodles(NoodleQuality.Optimal); screen.Bowl.TryAddBaseSeasoning();
        foreach (string topping in catalog.RecipesById[firstLesson.Order.Lines.Single().DefinitionId].ExtraIngredients)
            screen.IngredientAction(topping);
        view = screen.Workstation; view.CancelAnimations(); screen.Bowl.AddMixDistance(1000);
        Check(screen.DeliverToCustomer(firstLesson.Id, ProductKind.HotDryNoodles) && !screen.DemoLessonFailed, "original lesson still accepts its correct recipe");
        screen.FinishWuhanDemoLesson(); Step(.5);
        Check(!controller.TutorialActive && controller.CurrentConfig!.Day == 3, "original lesson replay returns to the requested business day");
        screen.QueueFree(); controller.QueueFree(); await Frames();
    }
    private void CheckRecipientCrop(TutorialFocusLayer focus)
    {
        var targets = focus.Resolve()!.Targets;
        Check(targets.Length > 0, "recipient focus contains artwork");
        foreach (var target in targets)
        {
            Check(target.ClipBounds is not null, "recipient carries portrait clipping into teaching overlay");
            Rect2 clip = target.ClipBounds!.Value;
            Check(target.Points.All(p => p.X >= clip.Position.X - .01f && p.X <= clip.End.X + .01f
                && p.Y >= clip.Position.Y - .01f && p.Y <= clip.End.Y + .01f),
                "recipient spotlight stays inside visible portrait window");
            Check(target.Bounds.End.Y > clip.End.Y, "fixture includes hidden lower body beyond the counter");
        }
    }
    private async Task Wuhan(DataCatalog catalog, SaveService save, string savePath)
    {
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); _viewport.AddChild(screen);
        screen.ConnectController(controller); screen.SetProcess(false); save.Data.Wuhan.HighestUnlockedDay = 12;
        Check(screen.Initialize(catalog, save, controller, 1), "Wuhan initializes"); screen.BeginDay();
        string recipe = catalog.RecipesById.Values.First(r => r.Id.StartsWith("hot_dry_noodles_") && r.ExtraIngredients.Count == 0).Id;
        OneOrder(controller, StableIds.Cities.Wuhan, new OrderLineData(ProductKind.HotDryNoodles, recipe, 1));
        void Step(double dt) { screen._Notification((int)NotificationApplicationFocusIn); screen._Process(dt); }
        Step(3.1); Step(.5); for (int i = 0; i < 30 && TutorialOrders.Pending(controller, catalog).Count == 0; i++) Step(1); await Frames();
        screen._Notification((int)NotificationApplicationFocusIn);
        var view = screen.Workstation; var focus = screen.TeachingFocus; focus.Refresh();
        CheckSkipGuidance(screen, focus);
        var skip = focus.Descendants<Godot.Button>().Single(b => b.Name == "SkipGuidance");
        Click(skip, skip.Size / 2); focus.Refresh();
        Check(focus.Dismissed && !focus.Visible && controller.State == DayState.Running, "Wuhan right-edge skip preserves normal business");
        focus.ResetSession(); focus.Refresh();
        Check(focus.CurrentAction == "take:noodles", "Wuhan first action highlights raw tray"); await Shot("wuhan-raw");
        CheckAdjacent(focus);
        Vector2 rawCardPosition = focus.CardBounds.Position;
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
        CheckAdjacent(focus);
        Check(focus.CardBounds.Position != rawCardPosition, "Wuhan card moves from raw noodles to seasoning");
        foreach (string topping in new[] { StableIds.Ingredients.WuhanScallion, StableIds.Ingredients.WuhanChiliOil })
        {
            screen.IngredientAction(topping); Step(.8); focus.Refresh();
            Check(!screen.Bowl.HasBaseSeasoning && !screen.Bowl.AddMixDistance(500), "topping alone neither adds sesame sauce nor enables mixing");
            var layers = WuhanWorkstationView.BowlLayers(new Rect2(0, 0, 200, 200), screen.Bowl.HasBaseSeasoning,
                (float)screen.Bowl.MixProgress, screen.Bowl.Quality, screen.Bowl.Toppings).Select(l => l.Id).ToArray();
            Check(layers.Length == 2 && !layers.Contains("unmixed"), "topping without sauce renders only noodles and its own topping");
            Check(focus.CurrentAction == "take:" + StableIds.Ingredients.WuhanBaseSeasoning, "missing sauce remains the teaching target after a topping");
            await Shot(topping == StableIds.Ingredients.WuhanScallion ? "wuhan-scallion-without-sauce" : "wuhan-chili-without-sauce");
            screen.Bowl.Reset(); screen.Bowl.TryAddNoodles(NoodleQuality.Optimal);
        }
        screen.IngredientAction(StableIds.Ingredients.WuhanBraisedBeef);
        Check(!save.Data.Wuhan.LearnedWorkbenchActions.Contains("take:" + StableIds.Ingredients.WuhanBraisedBeef), "failed topping is not learned");
        Click(view, view.IngredientCenter(0)); Step(.8); focus.Refresh();
        Check(save.Data.Wuhan.LearnedWorkbenchActions.Contains("take:" + StableIds.Ingredients.WuhanBaseSeasoning), "valid seasoning click passes through shade");
        Check(WuhanWorkstationView.BowlLayers(new Rect2(0, 0, 200, 200), screen.Bowl.HasBaseSeasoning,
            (float)screen.Bowl.MixProgress, screen.Bowl.Quality, screen.Bowl.Toppings).Any(l => l.Id == "unmixed"), "actual sesame addition renders the sauce layer");
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
        controller.AbandonDay();
        Check(screen.Initialize(catalog, save, controller, 1), "Wuhan replay initializes");
        screen.ForceDemoTutorial = true; screen.BeginDay(); Step(.5); focus.Refresh();
        var lesson = screen.GetNode<Panel>("DemoLesson");
        Check(controller.TutorialActive && focus.CurrentAction == "take:noodles", "replay teaches raw noodles despite learned actions");
        Check(!focus.DefaultCardVisible && focus.CardBounds == lesson.GetGlobalRect()
            && lesson.Descendants<Label>().Any(l => l.Visible && l.Text == focus.CurrentText), "replay uses one card for title and current instruction");
        CheckAdjacent(focus); await Shot("wuhan-lesson-raw");
        Move(view, view.RawCenter); Button(view, view.RawCenter, true); Move(view, view.BasketRect(0).GetCenter(), true); focus.Refresh();
        CheckAdjacent(focus); await Shot("wuhan-lesson-held");
        view.CancelInput(); Button(view, view.RawCenter, false);
        Drag(view, view.RawCenter, view.BasketRect(0).GetCenter()); Step(.3); Step(catalog.NoodleCookersByLevel[1].OptimalSeconds + .01);
        Check(screen.RaiseBasket(0), "replay raising succeeds"); Step(.4); screen.Cooker.TryQuickDrain(0);
        Check(screen.ReservePour(0), "replay pour succeeds"); Step(1); await Frames(); Step(.01); focus.Refresh();
        Check(TutorialOrders.Pending(controller, catalog).Single().Toppings.Count > 0
            && focus.CurrentAction == "take:" + StableIds.Ingredients.WuhanBaseSeasoning, "lesson teaches sesame before ordered toppings");
        CheckAdjacent(focus); await Shot("wuhan-lesson-seasoning");
        Click(view, view.IngredientCenter(0)); Step(.8); focus.Refresh();
        Check(screen.Bowl.HasBaseSeasoning && TutorialOrders.Pending(controller, catalog).Single().Toppings
            .Any(t => focus.CurrentAction == "take:" + t), "lesson teaches ordered toppings only after adding sesame");
        CheckAdjacent(focus); await Shot("wuhan-lesson-topping");
        foreach (string topping in TutorialOrders.Pending(controller, catalog).Single().Toppings)
        {
            Click(view, view.IngredientCenter(Array.IndexOf(WuhanWorkstationView.IngredientIds, topping))); Step(.8);
        }
        focus.Refresh(); Check(focus.CurrentAction == "mix:noodles", "lesson targets the bowl after required toppings");
        CheckAdjacent(focus); await Shot("wuhan-lesson-mix");
        Move(view, view.BowlCenter); Button(view, view.BowlCenter, true);
        for (int i = 0; i < 12; i++) Move(view, view.BowlCenter + new Vector2(i % 2 == 0 ? 45 : -45, 0), true);
        Button(view, view.BowlCenter, false); Step(.01);
        Check(screen.DeliverToCustomer(controller.CustomerQueue!.Slots.Single().Id, ProductKind.HotDryNoodles), "lesson completes through actual delivery");
        focus.Refresh();
        var lessonAction = lesson.Descendants<Godot.Button>().Single(b => b.Name == "LessonAction");
        Check(!focus.Visible && lessonAction.IsVisibleInTree() && lessonAction.Text == "开始营业", "completion clears spotlight and restores the action card");
        await Shot("wuhan-lesson-complete");
        Directory.CreateDirectory(savePath + ".tmp");
        screen.FinishWuhanDemoLesson(); focus.Refresh();
        Check(controller.TutorialActive && lessonAction.Text == "重试保存"
            && lesson.Descendants<Label>().Any(l => l.Visible && l.Text.Contains("未保存")), "save failure keeps retry message in the single card");
        Directory.Delete(savePath + ".tmp");
        screen.FinishWuhanDemoLesson();
        Check(!lesson.Visible && !controller.TutorialActive, "successful save closes the lesson");
        controller.AbandonDay(); screen.ForceDemoTutorial = true; screen.BeginDay(); Step(.5);
        screen.Bowl.TryAddNoodles(NoodleQuality.Optimal); screen.Bowl.TryAddBaseSeasoning();
        screen.Bowl.AddMixDistance(500); screen.Bowl.TryAddTopping(StableIds.Ingredients.WuhanBraisedBeef);
        screen.DeliverToCustomer(controller.CustomerQueue!.Slots.Single().Id, ProductKind.HotDryNoodles); focus.Refresh();
        Check(screen.DemoLessonFailed && !focus.Visible && lessonAction.Text == "重新练习", "incorrect delivery restores failure card without spotlight");
        await Shot("wuhan-lesson-failed");
        screen.RetryWuhanDemoLesson(); Step(.5); focus.Refresh();
        Check(!screen.DemoLessonFailed && focus.CurrentAction == "take:noodles" && !focus.DefaultCardVisible, "retry resumes the single moving card");
        screen.FinishWuhanDemoLesson();
        Check(!lesson.Visible && !controller.TutorialActive, "skip closes the moving lesson card and starts business");
        screen.Hide(); focus.Refresh(); Check(!focus.Visible, "Wuhan hidden city clears mask"); screen.QueueFree(); controller.QueueFree(); await Frames();
    }
    private void CheckAdjacent(TutorialFocusLayer focus)
    {
        Rect2 card = focus.CardBounds;
        var points = focus.FocusPolygons.SelectMany(p => p).ToArray();
        var anchor = new Rect2(points[0], Vector2.Zero);
        foreach (var point in points) anchor = anchor.Expand(point);
        float dx = Mathf.Max(0, Mathf.Max(anchor.Position.X - card.End.X, card.Position.X - anchor.End.X));
        float dy = Mathf.Max(0, Mathf.Max(anchor.Position.Y - card.End.Y, card.Position.Y - anchor.End.Y));
        Check(!card.Intersects(anchor) && new Vector2(dx, dy).Length() <= 40, "instruction sits beside the operation without covering it");
        Check(new Rect2(0, 0, 1920, 1080).Encloses(card), "instruction stays within the viewport");
    }
}
