using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Inventory;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class VisualCapture : Node
{
    public override async void _Ready()
    {
        string[] args = OS.GetCmdlineUserArgs();
        bool captureFryerWorkstation = args.Contains("--capture-fryer-workstation", StringComparer.Ordinal);
        int captureFryerLevel = args.Contains("--capture-fryer-level2", StringComparer.Ordinal) ? 2
            : args.Contains("--capture-fryer-level3", StringComparer.Ordinal) ? 3 : 1;
        bool captureRunning = OS.GetCmdlineUserArgs().Contains("--capture-running", StringComparer.Ordinal);
        bool captureDay = captureFryerWorkstation || captureRunning || OS.GetCmdlineUserArgs().Contains("--capture-day", StringComparer.Ordinal);
        int phase4Day = captureFryerWorkstation || args.Contains("--capture-day5", StringComparer.Ordinal) ? 5
            : args.Contains("--capture-day9", StringComparer.Ordinal) ? 9
            : args.Contains("--capture-day15", StringComparer.Ordinal) ? 15 : 0;
        bool captureMap = args.Contains("--capture-map", StringComparer.Ordinal);
        bool capture720 = args.Contains("--capture-720", StringComparer.Ordinal);
        bool captureResult = args.Contains("--capture-result", StringComparer.Ordinal);
        bool captureLedger = args.Contains("--capture-ledger", StringComparer.Ordinal);
        string? expressionPageArg = args.FirstOrDefault(item => item.StartsWith("--capture-customer-expressions-page=", StringComparison.Ordinal));
        int expressionPage = expressionPageArg is not null && int.TryParse(expressionPageArg.Split('=')[1], out int parsedPage)
            ? Math.Clamp(parsedPage, 1, 6) : 1;
        bool captureExpressions = args.Contains("--capture-customer-expressions", StringComparer.Ordinal) || expressionPageArg is not null;
        bool captureFryerSlots = args.Contains("--capture-fryer-slots", StringComparer.Ordinal);
        string? temporarySave = null;
        if (phase4Day > 0 || captureMap || captureResult)
        {
            temporarySave = $"user://visual-capture-{Guid.NewGuid():N}.json";
            GetNode<SaveService>("/root/SaveService").UsePathForTests(temporarySave);
        }

        if (captureFryerSlots)
        {
            BuildFryerSlotGallery();
        }
        else if (captureExpressions)
        {
            BuildCustomerExpressionGallery(expressionPage);
        }
        else if (captureDay || phase4Day > 0 || captureResult)
        {
            Node main = GetNode("../Main");
            var dayScreen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            var controller = main.GetNode<DayController>("DayController");
            int day = captureResult ? 15 : phase4Day > 0 ? phase4Day : 1;
            var captureSave = GetNode<SaveService>("/root/SaveService");
            if (captureFryerWorkstation) captureSave.Data.PurchasedFryerLevel = captureFryerLevel;
            if (day == 15)
            {
                captureSave.Data.PurchasedStoveLevel = 3;
                captureSave.Data.PurchasedIngredientStationLevel = 3;
                captureSave.Data.PurchasedFryerLevel = 3;
            }
            dayScreen.Initialize(GetNode<DataCatalog>("/root/DataCatalog"), captureSave, controller, day);
            foreach (Control screen in main.GetNode("UI").GetChildren().OfType<Control>()) screen.Visible = screen == dayScreen;
            if (captureRunning || phase4Day > 0 || captureResult)
            {
                dayScreen.BeginDay();
                controller.Tick(3);
                if (captureResult)
                {
                    CompleteDayForCapture(controller, GetNode<DataCatalog>("/root/DataCatalog"));
                }
                else
                {
                    int steps = phase4Day == 15 ? 900 : 30;
                    for (int step = 0; step < steps; step++)
                    {
                        controller.Tick(.1);
                        if (phase4Day == 15 && controller.CustomerQueue is not null)
                        {
                            foreach (CustomerRuntime customer in controller.CustomerQueue.Slots)
                            {
                                customer.WaitSeconds = 0;
                                if (customer.State is CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry)
                                    customer.State = CustomerState.Happy;
                            }
                        }
                        if (phase4Day == 15 && controller.CustomerQueue?.Slots.Count >= 5) break;
                    }
                    if (captureFryerWorkstation)
                    {
                        PancakeWorkstation workstation = dayScreen.GetChildren().OfType<PancakeWorkstation>().Single();
                        FryerStateMachine fryer = workstation.FryerMachine!;
                        for (int quantity = 0; quantity < 4; quantity++) fryer.TryExecute(FryerCommand.LoadOne);
                        fryer.TryExecute(FryerCommand.LowerBasket);
                        fryer.Tick(fryer.Level.GoldenStartSeconds + 0.05);
                        if (fryer.Level.AutoRaise)
                            fryer.Tick(Math.Max(0, fryer.Level.AutoRaiseAtSeconds - fryer.Runtime.FrySeconds) + 0.05);
                        else
                            fryer.TryExecute(FryerCommand.RaiseBasket);
                        fryer.Tick(fryer.Level.DrainSeconds + 0.05);
                        for (int quantity = 0; quantity < 4; quantity++) fryer.TryExecute(FryerCommand.LoadOne);
                        fryer.TryExecute(FryerCommand.LowerBasket);
                    }
                }
            }
        }
        else if (captureMap)
        {
            Node main = GetNode("../Main");
            var save = GetNode<SaveService>("/root/SaveService");
            DataCatalog catalog = GetNode<DataCatalog>("/root/DataCatalog");
            DayConfig config = catalog.DaysByNumber[15];
            DayPlan plan = new OrderGenerator().Generate(config, catalog.RecipesById, catalog.ProductsById, catalog.CustomersById);
            save.CommitDay(new DayResult { Day = 15, PlannedCustomers = 26, CompletedCustomers = 24, PerfectOrders = 15, Satisfaction = 90 }, plan, config);
            var map = main.GetNode<TianjinMapScreen>("UI/TianjinMapScreen");
            foreach (Control screen in main.GetNode("UI").GetChildren().OfType<Control>()) screen.Visible = screen == map;
        }
        else if (captureLedger)
        {
            Node main = GetNode("../Main");
            main.GetNode<MorningHub>("UI/MorningHub").ShowLedger();
        }
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await ToSignal(GetTree().CreateTimer(2.6), SceneTreeTimer.SignalName.Timeout);
        Image image = GetViewport().GetTexture().GetImage();
        string sizeSuffix = capture720 ? "_720" : string.Empty;
        string output = captureResult ? $"res://.godot/phase4_result{sizeSuffix}.png"
            : captureFryerSlots ? $"res://.godot/fryer_slots{sizeSuffix}.png"
            : captureFryerWorkstation ? $"res://.godot/fryer_workstation_lv{captureFryerLevel}{sizeSuffix}.png"
            : captureExpressions ? $"res://.godot/customer_expressions_page{expressionPage}{sizeSuffix}.png"
            : phase4Day > 0 ? $"res://.godot/phase4_day{phase4Day}{sizeSuffix}.png"
            : captureMap ? $"res://.godot/phase4_map{sizeSuffix}.png"
            : captureLedger ? $"res://.godot/phase4_ledger{sizeSuffix}.png"
            : captureRunning ? "res://.godot/phase3_running.png" : captureDay ? "res://.godot/phase3_day.png" : $"res://.godot/phase4_hub{sizeSuffix}.png";
        Error error = image.SavePng(ProjectSettings.GlobalizePath(output));
        if (error != Error.Ok)
        {
            GD.PushError($"视觉录帧保存失败：{error}");
            GetTree().Quit(1);
            return;
        }

        GD.Print($"视觉录帧已保存：{output}");
        if (temporarySave is not null)
        {
            string absolute = ProjectSettings.GlobalizePath(temporarySave);
            if (File.Exists(absolute)) File.Delete(absolute);
        }
        GetTree().Quit(0);
    }

    private void BuildFryerSlotGallery()
    {
        Node main = GetNode("../Main");
        main.ProcessMode = ProcessModeEnum.Disabled;
        main.GetNode<Node2D>("ShopRoot").Visible = false;
        foreach (Control screen in main.GetNode("UI").GetChildren().OfType<Control>()) screen.Visible = false;

        var gallery = new ColorRect
        {
            Color = new Color("#FFF4D5"),
            Theme = TianjinUi.CreateTheme(),
        };
        TianjinUi.FullRect(gallery);
        AddChild(gallery);

        Label title = TianjinUi.Label("油条炸锅 · 固定槽位视觉验收", 34, TianjinUi.BrownDark, HorizontalAlignment.Center);
        title.Position = new Vector2(70, 20);
        title.Size = new Vector2(1780, 56);
        gallery.AddChild(title);

        var grid = new GridContainer { Columns = 4 };
        grid.Position = new Vector2(64, 88);
        grid.Size = new Vector2(1792, 930);
        grid.AddThemeConstantOverride("h_separation", 14);
        grid.AddThemeConstantOverride("v_separation", 14);
        gallery.AddChild(grid);

        DataCatalog catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var art = new TianjinArtCatalog();
        for (int level = 1; level <= 3; level++)
        {
            foreach (string state in new[] { "待下锅", "炸制中", "抬篮沥油", "焦糊素材" })
            {
                var machine = new FryerStateMachine(catalog.FryersByLevel[level]);
                for (int quantity = 0; quantity < machine.Level.Capacity; quantity++) machine.TryExecute(FryerCommand.LoadOne);
                if (state != "待下锅")
                {
                    machine.TryExecute(FryerCommand.LowerBasket);
                    machine.Tick(machine.Level.GoldenStartSeconds + 0.05);
                }
                if (state == "抬篮沥油")
                {
                    if (machine.Level.AutoRaise)
                        machine.Tick(Math.Max(0, machine.Level.AutoRaiseAtSeconds - machine.Runtime.FrySeconds) + 0.05);
                    else
                        machine.TryExecute(FryerCommand.RaiseBasket);
                }
                else if (state == "焦糊素材")
                {
                    // Lv3 normally auto-raises before burning. Force only the
                    // render state here so every body can validate the shared
                    // burnt sprite and lowered-basket alignment.
                    machine.Runtime.State = FryerState.Burnt;
                    machine.Runtime.Quality = YoutiaoQuality.Burnt;
                }

                var card = TianjinUi.Panel(new Color("#FFF9E8"), 16, 3, false);
                card.CustomMinimumSize = new Vector2(430, 292);
                grid.AddChild(card);
                var row = new HBoxContainer();
                row.AddThemeConstantOverride("separation", 8);
                card.AddChild(row);
                var view = new FryerVisualView
                {
                    CustomMinimumSize = new Vector2(210, 250),
                    MouseFilter = Control.MouseFilterEnum.Ignore,
                };
                view.Bind(art, machine);
                row.AddChild(view);
                var label = TianjinUi.Label($"Lv{level}\n{state}\n{machine.Level.Capacity}/{machine.Level.Capacity}", 24,
                    TianjinUi.BrownText, HorizontalAlignment.Center);
                label.CustomMinimumSize = new Vector2(175, 150);
                label.VerticalAlignment = VerticalAlignment.Center;
                row.AddChild(label);
            }
        }
    }

    private void BuildCustomerExpressionGallery(int page)
    {
        Node main = GetNode("../Main");
        main.ProcessMode = ProcessModeEnum.Disabled;
        main.GetNode<Node2D>("ShopRoot").Visible = false;
        foreach (Control screen in main.GetNode("UI").GetChildren().OfType<Control>()) screen.Visible = false;

        var gallery = new ColorRect
        {
            Color = new Color("#FFF4D5"),
            Theme = TianjinUi.CreateTheme(),
        };
        TianjinUi.FullRect(gallery);
        AddChild(gallery);

        Label title = TianjinUi.Label($"天津顾客 · 半身表情验收 {page}/6", 34, TianjinUi.BrownDark, HorizontalAlignment.Center);
        title.Position = new Vector2(70, 24);
        title.Size = new Vector2(1780, 58);
        gallery.AddChild(title);

        var grid = new GridContainer { Columns = 5 };
        grid.Position = new Vector2(65, 94);
        grid.Size = new Vector2(1790, 930);
        grid.AddThemeConstantOverride("h_separation", 12);
        grid.AddThemeConstantOverride("v_separation", 12);
        gallery.AddChild(grid);

        grid.AddChild(Header(string.Empty, 250));
        foreach (string expressionName in new[] { "开心", "正常", "不耐烦", "生气" })
            grid.AddChild(Header(expressionName, 365));

        var art = new TianjinArtCatalog();
        CustomerAppearanceDefinition[] customers = CustomerAppearanceCatalog.All.Skip((page - 1) * 4).Take(4).ToArray();
        CustomerExpression[] expressions = Enum.GetValues<CustomerExpression>();
        foreach (CustomerAppearanceDefinition appearance in customers)
        {
            grid.AddChild(Header(appearance.DisplayName, 250));
            foreach (CustomerExpression expression in expressions)
            {
                var panel = TianjinUi.Panel(TianjinUi.Paper, 14, 3, false);
                panel.CustomMinimumSize = new Vector2(365, 202);
                var portrait = new CustomerPortraitView();
                portrait.SetVisual(art.CustomerPortrait(appearance.Id, expression));
                portrait.SizeFlagsVertical = Control.SizeFlags.ExpandFill;
                panel.AddChild(portrait);
                grid.AddChild(panel);
            }
        }
    }

    private static Label Header(string text, float width)
    {
        Label label = TianjinUi.Label(text, 21, TianjinUi.BrownDark, HorizontalAlignment.Center);
        label.CustomMinimumSize = new Vector2(width, 52);
        label.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        return label;
    }

    private static void CompleteDayForCapture(DayController controller, DataCatalog catalog)
    {
        var pancake = new PancakeStateMachine(catalog.StovesByLevel[3]);
        var youtiao = new YoutiaoInventory(128);
        youtiao.TryStore(128, YoutiaoQuality.Golden);
        var soy = new SoyMilkTrayRuntime(128);
        for (int step = 0; step < 5000 && controller.State != DayState.Results; step++)
        {
            controller.Tick(.05);
            soy.Tick(.05);
            CustomerRuntime? customer = controller.CustomerQueue?.Slots.FirstOrDefault(item => item.State is CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry);
            if (customer is null) continue;
            controller.CustomerQueue!.TrySelect(customer.Id);
            for (int lineIndex = 0; lineIndex < customer.Order.Lines.Count; lineIndex++)
            {
                OrderLineData line = customer.Order.Lines[lineIndex];
                for (int quantity = customer.Progress.GetDeliveredQuantity(lineIndex); quantity < line.Quantity; quantity++)
                {
                    if (line.ProductKind == ProductKind.Pancake)
                    {
                        MakeBagged(pancake, catalog.RecipesById[line.DefinitionId]);
                        controller.TryDeliverSelected(pancake, catalog);
                        pancake.TryExecute(PancakeCommand.Discard);
                    }
                    else if (line.ProductKind == ProductKind.Youtiao) controller.TryDeliverYoutiaoSelected(youtiao);
                    else controller.TryDeliverSoyMilkSelected(soy);
                }
            }
        }
    }

    private static void MakeBagged(PancakeStateMachine machine, RecipeData recipe)
    {
        machine.TryExecute(PancakeCommand.PlaceBatter); machine.TryExecute(PancakeCommand.BeginSpread); machine.SetSpreadCoverage(1);
        machine.TryExecute(PancakeCommand.CompleteSpread); machine.TryExecute(PancakeCommand.AddEgg); machine.Tick(machine.Stove.SideAReadySeconds);
        machine.TryExecute(PancakeCommand.Flip); machine.Tick(machine.Stove.SideBReadySeconds); machine.TryExecute(PancakeCommand.BeginSauce);
        machine.SetSauceCoverage(1); machine.TryExecute(PancakeCommand.CompleteSauce);
        foreach (string ingredient in recipe.ExtraIngredients) machine.TryExecute(PancakeCommand.AddIngredient, ingredient);
        if (recipe.ExtraIngredients.Contains(StableIds.Ingredients.Youtiao)) machine.TrySetInternalYoutiaoQuality(YoutiaoQuality.Golden);
        machine.TryExecute(PancakeCommand.Fold); machine.TryExecute(PancakeCommand.Bag);
    }
}
