using Godot;
using System.Reflection;
using System.Text.Json;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Pancake;
using ProjectCake.Fryer;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

// Isolated promotional capture. Uses production scenes, input handlers and cooking clocks.
// Never included in the normal startup path. No customer orders or cooking states are replaced.
public partial class SteamTrailerCapture : Node
{
    private Action<double>? _step;
    private int _frame;
    private readonly List<string> _marks = new();
    private DataCatalog _catalog = null!;
    private SaveService _save = null!;
    private string _mode = "tianjin";
    private static object? Invoke(object target, string method, params object?[] args) =>
        target.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.NonPublic)!.Invoke(target, args);
    private void Mark(string name) { string line = $"{_frame / 30.0:F3}\t{name}"; _marks.Add(line); GD.Print("SHOT " + line); }
    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
        {
            _step?.Invoke(1.0 / 30);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            _frame++;
        }
    }
    private async Task Until(Func<bool> condition, string label, int max = 600)
    {
        for (int i = 0; i < max && !condition(); i++) await Frames(1);
        if (!condition()) throw new InvalidOperationException("Timed out: " + label);
    }
    public override async void _Ready()
    {
        try
        {
            _mode = OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--shot="))?.Split('=')[1] ?? "tianjin";
            GetWindow().Size = new(1920, 1080);
            _catalog = GetNode<DataCatalog>("/root/DataCatalog");
            _save = GetNode<SaveService>("/root/SaveService");
            _save.UsePathForTests($"res://output/steam-trailer-zh/work/{_mode}-save.json");
            _save.ResetProgress(out _);
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests($"res://output/steam-trailer-zh/work/{_mode}-settings.cfg");
            InterfaceLessons.MarkAllSeen(settings);
            if (_mode == "seed") { await Tianjin(7); await Wuhan(); }
            else if (_mode is "journey" or "journey64") await Journey();
            else if (_mode == "wuhan") await Wuhan();
            else if (_mode == "pages") await Pages();
            else await Tianjin(_mode == "rush" ? 15 : 6);
            File.WriteAllLines(ProjectSettings.GlobalizePath($"res://output/steam-trailer-zh/work/{_mode}-marks.tsv"), _marks);
            GD.Print("TRAILER_CAPTURE_OK " + _mode);
            GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private async Task Tianjin(int dayNumber)
    {
        _save.Data.PurchasedStoveLevel = 3;
        _save.Data.PurchasedFryerLevel = 3;
        _save.Data.PurchasedIngredientStationLevel = 3;
        if (_mode == "seed") _save.Data.Tianjin.HighestUnlockedDay = 15;
        _save.Data.Tianjin.LearnedWorkbenchActions.UnionWith(PancakeWorkstation.AllWorkbenchActions);
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(screen);
        screen.ConnectController(controller); screen.Initialize(_catalog, _save, controller, dayNumber); screen.SetProcess(false);
        screen.BeginDay();
        _step = dt => { screen._Notification((int)NotificationApplicationFocusIn); screen._Process(dt); };
        await Frames(105);
        var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
        station.ConfigureTutorial(PancakeWorkstation.AllWorkbenchActions);
        if (dayNumber == 15) await Frames(240);
        Mark("workbench");
        for (int round = 0; round < (_mode == "seed" ? 50 : 2) && controller.State != DayState.Results; round++)
        {
            if (_mode == "seed")
            {
                foreach (var pair in station.Inventory.Quantities.Where(p => p.Value <= 1).ToArray())
                    if (station.Inventory.CanRefill(pair.Key)) Invoke(station, "Refill", pair.Key);
                if (station.Inventory.IsAnyRefilling) await Until(() => !station.Inventory.IsAnyRefilling, "refill");
                if (station.SoyMilkTray?.Quantity == 0) { Invoke(station, "RefillSoyMilk"); await Frames(22); }
                await ServeSides();
            }
            var customer = controller.CustomerQueue!.Slots.FirstOrDefault(c => controller.CanDeliverTo(c.Id, ProductKind.Pancake));
            if (customer is null && _mode == "seed") { await Frames(30); continue; }
            if (customer is null) { await Until(() => controller.CustomerQueue.Slots.Any(c => controller.CanDeliverTo(c.Id, ProductKind.Pancake)), "next pancake customer", 1200); customer = controller.CustomerQueue.Slots.First(c => controller.CanDeliverTo(c.Id, ProductKind.Pancake)); }
            var line = customer.Order.Lines.Where((l, i) => l.ProductKind == ProductKind.Pancake && customer.Progress.GetDeliveredQuantity(i) < l.Quantity).First();
            var recipe = _catalog.RecipesById[line.DefinitionId];
            if (station.FryerMachine is not null && station.FryerMachine.Inventory.Count == 0)
            {
                Mark("fryer-load");
                for (int i = 0; i < 3; i++) { Invoke(station, "ExecuteFryer", FryerCommand.LoadOne); await Frames(8); }
                Invoke(station, "ExecuteFryer", FryerCommand.LowerBasket);
            }
            Mark("batter"); Invoke(station, "TryPlaceBatter"); await Frames(20);
            var stroke = station.Descendants<StrokeInteractor>().Single();
            var geometry = stroke.ResolveSpreadGeometry!();
            Vector2 point = geometry.Center + geometry.Radii * new Vector2(.65f, 0);
            stroke._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point });
            Mark("spread");
            int spreadFrames = _mode == "seed" ? 24 : 64;
            for (int i = 1; i <= spreadFrames; i++)
            {
                point = geometry.Center + geometry.Radii * Vector2.FromAngle(i * Mathf.Tau / spreadFrames) * .65f;
                stroke._GuiInput(new InputEventMouseMotion { Position = point, ButtonMask = MouseButtonMask.Left }); await Frames(1);
            }
            stroke._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = point });
            if (station.Machine.Runtime.SpreadCoverage < .99) throw new Exception("Spread gesture incomplete");
            Mark("egg"); ((Button)station.FindChild("IngredientInput_egg", true, false)).EmitSignal(Button.SignalName.Pressed);
            try { await Until(() => station.Machine.Runtime.State == PancakeState.SideAReady || controller.State == DayState.Results, "side A"); }
            catch { throw new Exception($"Side A stalled: {station.Machine.Runtime.State}, paused={controller.IsPaused}, day={controller.State}, seconds={station.Machine.Runtime.CookingSeconds}, egg={station.Machine.Runtime.HasEgg}, active={station.InteractionEnabled}"); }
            if (controller.State == DayState.Results) break;
            Mark("flip"); Execute(station, PancakeCommand.Flip); await Frames(25);
            await Until(() => station.Machine.Runtime.State == PancakeState.SideBReady, "side B");
            Mark("sauce"); Invoke(station, "PickUpSauceBrush"); await Frames(5);
            double sauceTarget = line.Sauce == SaucePreference.Light ? .25 : line.Sauce == SaucePreference.Extra ? 1.2 : .72;
            point = geometry.Center + new Vector2(geometry.Radii.X * .15f, 0);
            stroke._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point });
            for (int i = 1; i <= 240 && station.Machine.Runtime.SauceCoverage < sauceTarget; i++)
            {
                float radius = .15f + .8f * i / 240;
                point = geometry.Center + geometry.Radii * Vector2.FromAngle(i * .28f) * radius;
                stroke._GuiInput(new InputEventMouseMotion { Position = point, ButtonMask = MouseButtonMask.Left });
                if (_mode != "seed" || i % 3 == 0) await Frames(1);
            }
            stroke._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = point });
            if (!SauceRules.Matches(line.Sauce, station.Machine.Runtime.SauceCoverage)) throw new Exception("Sauce input does not match the order");
            if (station.Machine.Runtime.State == PancakeState.Saucing) Execute(station, PancakeCommand.CompleteSauce);
            await Frames(15);
            if (_mode == "seed" && recipe.ExtraIngredients.Contains("youtiao") && station.FryerMachine!.Inventory.Count == 0)
                await Until(() => station.FryerMachine.Inventory.Count > 0 || controller.State == DayState.Results, "fried youtiao");
            if (controller.State == DayState.Results) break;
            foreach (string ingredient in recipe.ExtraIngredients)
            { Execute(station, PancakeCommand.AddIngredient, ingredient); await Frames(12); }
            Mark("fold"); Execute(station, PancakeCommand.Fold); await Frames(15);
            Execute(station, PancakeCommand.Bag); await Frames(24);
            Mark("delivery");
            bool accepted = station.DeliverToCustomer("finished_pancake", () => (bool)Invoke(screen, "SubmitToCustomer", customer.Id, customer.SlotIndex, "finished_pancake")!);
            if (!accepted && _mode != "seed") throw new Exception("Pancake delivery rejected");
            await Frames(35);
            await ServeSides();
            await Frames(15);
        }
        async Task ServeSides()
        {
            foreach (var kind in new[] { ProductKind.Youtiao, ProductKind.SoyMilk })
            for (int serving = 0; serving < 3; serving++)
            {
                var recipient = controller.CustomerQueue!.Slots.FirstOrDefault(c => controller.CanDeliverTo(c.Id, kind));
                if (recipient is null) continue;
                string payload = kind == ProductKind.Youtiao ? "stored_youtiao" : "soy_milk_cup";
                if (!station.CanDeliverProduct(payload)) continue;
                Mark(payload);
                station.DeliverToCustomer(payload, () => (bool)Invoke(screen, "SubmitToCustomer", recipient.Id, recipient.SlotIndex, payload)!);
                await Frames(25);
            }
        }
        Mark("outro"); await Frames(60);
        if (_mode == "seed")
        {
            await Until(() => controller.State == DayState.Results, "Tianjin settlement", 12000);
            await Frames(180); _step = null;
            var model = screen.Descendants<BusinessDetailsView>().Single(v => v.Visible).Model;
            if (model.Challenge?.Achieved(model.Result) != true || !model.ChallengeClaimed)
                throw new Exception("Recorded settlement must have a genuinely completed and claimed challenge");
            var upgrades = model.Upgrades; model.Upgrades = null;
            File.WriteAllText(ProjectSettings.GlobalizePath("res://output/steam-trailer-zh/work/earned-summary.json"), JsonSerializer.Serialize(model));
            model.Upgrades = upgrades;
            GD.Print($"EARNED_SUMMARY revenue={model.Result.TotalRevenue} challenge={model.ChallengeCaption}");
            screen.QueueFree(); controller.QueueFree(); await Frames(3);
        }
    }
    private static void Execute(PancakeWorkstation station, PancakeCommand command, string? ingredient = null)
    {
        if (!(bool)Invoke(station, "Execute", command, ingredient)!) throw new Exception($"Rejected {command} {ingredient}: {station.Machine.Runtime.State}");
    }
    private async Task Wuhan()
    {
        var progress = _save.Data.Wuhan; progress.HighestUnlockedDay = 12;
        progress.LearnedWorkbenchActions.UnionWith(new[] { "take:noodles", "raise:noodles", "pour:noodles", "mix:noodles", "deliver:hot_dry_noodles", "deliver:doupi", "doupi:batter", "doupi:egg", "doupi:flip", "doupi:filling", "doupi:cut", "discard" });
        progress.LearnedWorkbenchActions.UnionWith(WuhanWorkstationView.IngredientIds.Select(id => "take:" + id));
        progress.EquipmentLevels["noodle_cooker"] = 3; progress.EquipmentLevels["doupi_griddle"] = 3;
        progress.EquipmentLevels["ingredient_station"] = 3;
        var controller = new DayController(); AddChild(controller);
        var screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn"); AddChild(screen);
        screen.ConnectController(controller); screen.Initialize(_catalog, _save, controller, 8); screen.SetProcess(false); screen.BeginDay();
        _step = dt => { screen._Notification((int)NotificationApplicationFocusIn); screen._Process(dt); };
        await Frames(160); Mark("wuhan-workbench");
        for (int round = 0; round < 2; round++)
        {
            Mark("noodles-drop"); screen.BasketAction(0); await Frames(75);
            screen.BasketAction(0); await Frames(30);
            if (screen.Bowl.State != NoodleBowlState.Noodles) throw new Exception("No noodles in bowl");
            var recipient = controller.CustomerQueue!.Slots.First(c => controller.CanDeliverTo(c.Id, ProductKind.HotDryNoodles));
            var recipe = _catalog.RecipesById[recipient.Order.Lines.First(l => l.ProductKind == ProductKind.HotDryNoodles).DefinitionId];
            Mark("seasoning"); screen.IngredientAction(WuhanWorkstationView.IngredientIds[0]); await Frames(18);
            foreach (string ingredient in recipe.ExtraIngredients)
            { if (ingredient != WuhanWorkstationView.IngredientIds[0] && ingredient != StableIds.Ingredients.WuhanBraisedBeef) { screen.IngredientAction(ingredient); await Frames(18); } }
            Mark("mix");
            Vector2 center = screen.Workstation.GetGlobalTransformWithCanvas() * screen.Workstation.BowlCenter;
            GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = center }, true);
            for (int i = 0; i < 45; i++)
            {
                GetViewport().PushInput(new InputEventMouseMotion { Position = center + new Vector2(Mathf.Sin(i * .35f) * 75, 0), ButtonMask = MouseButtonMask.Left }, true);
                await Frames(1);
            }
            GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = center }, true);
            if (screen.Bowl.State != NoodleBowlState.Ready) throw new Exception("Mix not ready");
            if (recipe.ExtraIngredients.Contains(StableIds.Ingredients.WuhanBraisedBeef)) { screen.IngredientAction(StableIds.Ingredients.WuhanBraisedBeef); await Frames(18); }
            Mark("noodle-delivery"); if (!screen.DeliverToCustomer(recipient.Id, ProductKind.HotDryNoodles)) throw new Exception("Noodle rejected");
            await Frames(35);
        }
        Mark("doupi-batter"); if (!screen.PourDoupiBatter()) throw new Exception("Doupi batter"); await Frames(20);
        Mark("doupi-egg"); screen.AddDoupiEgg(); await Frames(95);
        Mark("doupi-filling"); screen.AddDoupiFilling(); await Frames(120);
        Mark("doupi-cut"); screen.CutDoupi(DoupiCutLine.Horizontal); await Frames(15); screen.CutDoupi(DoupiCutLine.Left); await Frames(35);
        if (screen.DoupiStock.Count == 0) throw new Exception("Doupi stock empty");
        var target = controller.CustomerQueue!.Slots.FirstOrDefault(c => controller.CanDeliverTo(c.Id, ProductKind.Doupi));
        if (target is not null) { Mark("doupi-delivery"); screen.DeliverToCustomer(target.Id, ProductKind.Doupi); }
        await Frames(70);
        if (_mode == "seed")
        {
            await Until(() => controller.State == DayState.Results, "Wuhan settlement", 12000);
            await Frames(180); _step = null;
            GD.Print("EARNED_COLLECTION " + string.Join(",", _save.CollectedBreakfastIds));
            screen.QueueFree(); controller.QueueFree(); await Frames(3);
        }
    }
    private async Task Journey()
    {
        GetNode<JourneySettings>("/root/JourneySettings").SetVolume("music", 0);
        var main = SceneFactory.Instantiate<GameController>("res://Scenes/Main/Main.tscn"); AddChild(main);
        var screen = main.GetNode<StartScreen>("UI/StartScreen");
        await Frames(20);
        screen.PresentMap(); await Frames(35); Mark("tianjin-map"); await Frames(120);
        _save.UsePathForTests("res://output/steam-trailer-zh/work/seed-save.json");
        if (!_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan)) throw new Exception("Earned Wuhan unlock missing");
        // Replay only the existing route reveal; don't show a chapter-completed postcard for Day 7.
        typeof(StartScreen).GetField("_completedCity", BindingFlags.Instance | BindingFlags.NonPublic)!.SetValue(screen, StableIds.Cities.Tianjin);
        typeof(StartScreen).GetField("_completionContinueBusiness", BindingFlags.Instance | BindingFlags.NonPublic)!.SetValue(screen, (Action)(() => { }));
        Mark("wuhan-unlock"); Invoke(screen, "RevealRoute"); await Frames(180);
        screen.PresentMap(); await Frames(30); Mark("world-map"); await Frames(190);
        screen.PresentBreakfastCollection(); await Frames(35); Mark("collection-tianjin"); await Frames(100);
        var noodle = screen.Descendants<Button>().First(b => b.Name == "Breakfast_noodles");
        noodle.EmitSignal(Button.SignalName.Pressed); await Frames(15); Mark("collection-wuhan"); await Frames(100);
        screen.PresentCity(StableIds.Cities.Tianjin); await Frames(30);
        var summary = JsonSerializer.Deserialize<BusinessBookModel>(File.ReadAllText(ProjectSettings.GlobalizePath("res://output/steam-trailer-zh/work/earned-summary.json")))!;
        summary.Closing = true;
        var book = new BusinessDetailsView(); main.GetNode("UI").AddChild(book);
        Mark("summary"); book.Open(summary); await Frames(220);
        GD.Print($"VERIFIED_SUMMARY revenue={summary.Result.TotalRevenue} orders={summary.Orders.Count}");
    }
    private async Task Pages()
    {
        _save.Data.Coins = 680;
        _save.Data.Tianjin.HighestUnlockedDay = 15;
        _save.Data.Tianjin.UnlockedContentIds = _catalog.GetDays(StableIds.Cities.Tianjin).Values.SelectMany(d => d.StartUnlocks.Concat(d.CompletionUnlocks)).Distinct().ToList();
        for (int day = 1; day < 15; day++) _save.Data.Tianjin.DayBestRecords[day] = new();
        _save.Data.PurchasedStoveLevel = 2; _save.Data.PurchasedFryerLevel = 2;
        var main = SceneFactory.Instantiate<GameController>("res://Scenes/Main/Main.tscn"); AddChild(main);
        var screen = main.GetNode<StartScreen>("UI/StartScreen");
        await Frames(20); Mark("title"); await Frames(150);
        screen.PresentCity(StableIds.Cities.Tianjin); await Frames(40); Mark("city"); await Frames(65);
        screen.PresentUpgrades(); await Frames(40); Mark("upgrade"); await Frames(100);
        var buy = screen.Descendants<Button>().FirstOrDefault(b => b.Name == "UpgradeEquipment" && !b.Disabled);
        if (buy is not null) { Mark("purchase"); buy.EmitSignal(Button.SignalName.Pressed); }
        await Frames(100);
        screen.PresentHome(); await Frames(40); Mark("title-end"); await Frames(100);
    }
}
