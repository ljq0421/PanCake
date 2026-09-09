using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Inventory;
using ProjectCake.Interaction;
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
        bool captureLowStock = args.Contains("--capture-low-stock", StringComparer.Ordinal);
        bool captureInteraction = args.Contains("--capture-interaction", StringComparer.Ordinal);
        bool captureDirectDelivery = args.Contains("--capture-direct-delivery", StringComparer.Ordinal);
        bool capturePancakeReady = args.Contains("--capture-pancake-ready", StringComparer.Ordinal);
        bool captureSauceReady = args.Contains("--capture-sauce-ready", StringComparer.Ordinal);
        bool captureThreeCustomers = args.Contains("--capture-three-customers", StringComparer.Ordinal);
        bool capturePause = args.Contains("--capture-pause", StringComparer.Ordinal);
        bool capturePartialOrder = args.Contains("--capture-partial-order", StringComparer.Ordinal);
        bool captureBagged = args.Contains("--capture-bagged", StringComparer.Ordinal);
        bool captureMultiple = args.Contains("--capture-multiple-pancakes", StringComparer.Ordinal);
        bool captureClosingBag = args.Contains("--capture-closing-bag", StringComparer.Ordinal);
        bool captureRefilling = args.Contains("--capture-refilling", StringComparer.Ordinal);
        bool captureDay = captureFryerWorkstation || captureRunning || capturePause || capturePartialOrder
            || OS.GetCmdlineUserArgs().Contains("--capture-day", StringComparer.Ordinal);
        int phase4Day = args.Contains("--capture-day11", StringComparer.Ordinal) ? 11
            : captureDirectDelivery || captureThreeCustomers || capturePause || capturePartialOrder ? 15
            : captureLowStock || captureInteraction || capturePancakeReady || captureSauceReady ? 9
            : args.Contains("--capture-day1", StringComparer.Ordinal) ? 1
            : captureFryerWorkstation || args.Contains("--capture-day5", StringComparer.Ordinal) ? 5
            : args.Contains("--capture-day9", StringComparer.Ordinal) ? 9
            : args.Contains("--capture-day15", StringComparer.Ordinal) ? 15 : 0;
        bool captureMap = args.Contains("--capture-map", StringComparer.Ordinal);
        bool capture720 = args.Contains("--capture-720", StringComparer.Ordinal);
        GetWindow().Size = capture720 ? new Vector2I(1280, 720) : new Vector2I(1920, 1080);
        bool captureResult = args.Contains("--capture-result", StringComparer.Ordinal);
        bool captureLedger = args.Contains("--capture-ledger", StringComparer.Ordinal);
        string? expressionPageArg = args.FirstOrDefault(item => item.StartsWith("--capture-customer-expressions-page=", StringComparison.Ordinal));
        int expressionPage = expressionPageArg is not null && int.TryParse(expressionPageArg.Split('=')[1], out int parsedPage)
            ? Math.Clamp(parsedPage, 1, 6) : 1;
        bool captureExpressions = args.Contains("--capture-customer-expressions", StringComparer.Ordinal) || expressionPageArg is not null;
        bool captureFryerSlots = args.Contains("--capture-fryer-slots", StringComparer.Ordinal);
        bool captureRefillGallery = args.Contains("--capture-refill-gallery", StringComparer.Ordinal);
        bool captureStockGallery = captureRefillGallery || args.Contains("--capture-stock-gallery", StringComparer.Ordinal);
        bool captureYoutiaoQuality = args.Contains("--capture-youtiao-quality", StringComparer.Ordinal);
        string? temporarySave = null;
        if (phase4Day > 0 || captureMap || captureResult)
        {
            temporarySave = $"user://visual-capture-{Guid.NewGuid():N}.json";
            GetNode<SaveService>("/root/SaveService").UsePathForTests(temporarySave);
        }

        if (captureYoutiaoQuality)
        {
            BuildYoutiaoQualityGallery();
        }
        else if (captureStockGallery)
        {
            BuildIngredientStockGallery(captureRefillGallery);
        }
        else if (captureFryerSlots)
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
            if (capturePancakeReady || captureSauceReady) captureSave.Data.PurchasedStoveLevel = 2;
            if (day == 15)
            {
                captureSave.Data.PurchasedStoveLevel = 3;
                captureSave.Data.PurchasedIngredientStationLevel = 3;
                captureSave.Data.PurchasedFryerLevel = 3;
            }
            string? equipmentArg = args.FirstOrDefault(arg => arg.StartsWith("--capture-workbench-level=", StringComparison.Ordinal));
            if (equipmentArg is not null && int.TryParse(equipmentArg.Split('=')[1], out int captureLevel))
            {
                captureSave.Data.PurchasedStoveLevel = Math.Clamp(captureLevel, 1, 3);
                captureSave.Data.PurchasedFryerLevel = Math.Clamp(captureLevel, 1, 3);
                captureSave.Data.PurchasedIngredientStationLevel = Math.Clamp(captureLevel, 1, 3);
            }
            dayScreen.Initialize(GetNode<DataCatalog>("/root/DataCatalog"), captureSave, controller, day);
            foreach (Control screen in main.GetNode("UI").GetChildren().OfType<Control>()) screen.Visible = screen == dayScreen;
            if (captureRunning || phase4Day > 0 || captureResult)
            {
                controller.IsPaused = false;
                dayScreen.BeginDay();
                controller.IsPaused = false;
                controller.Tick(3);
                if (captureResult)
                {
                    CompleteDayForCapture(controller, GetNode<DataCatalog>("/root/DataCatalog"));
                }
                else
                {
                    int targetCustomerCount = captureThreeCustomers ? 3 : phase4Day is 11 or 15 ? 5 : 1;
                    int steps = phase4Day is 11 or 15 ? 900 : 80;
                    for (int step = 0; step < steps; step++)
                    {
                        controller.IsPaused = false;
                        controller.Tick(.1);
                        if (phase4Day is 11 or 15 && controller.CustomerQueue is not null)
                        {
                            foreach (CustomerRuntime customer in controller.CustomerQueue.Slots)
                            {
                                customer.WaitSeconds = 0;
                                if (customer.State is CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry)
                                    customer.State = CustomerState.Happy;
                            }
                        }
                        if (controller.CustomerQueue?.Slots.Count >= targetCustomerCount) break;
                    }
                    PancakeWorkstation workstation = dayScreen.GetChildren().OfType<PancakeWorkstation>().Single();
                    if (captureLowStock)
                    {
                        ReduceTo(workstation.Inventory, StableIds.Ingredients.Batter, 5);
                        ReduceTo(workstation.Inventory, StableIds.Ingredients.Egg, 2);
                        ReduceTo(workstation.Inventory, StableIds.Ingredients.Sauce, 0);
                    }
                    string? stockArg = args.FirstOrDefault(arg => arg.StartsWith("--capture-stock=", StringComparison.Ordinal));
                    if (stockArg is not null && int.TryParse(stockArg.Split('=')[1], out int stockQuantity))
                    {
                        foreach (string ingredient in TianjinWorkbenchLayout.IngredientOrder)
                            ReduceTo(workstation.Inventory, ingredient, Math.Max(0, stockQuantity));
                        while (workstation.SoyMilkTray is { Quantity: > 0 } soy && soy.Quantity > stockQuantity)
                        {
                            soy.TryConsumeForDelivery();
                            soy.Tick(1);
                        }
                    }
                    if (captureInteraction)
                    {
                        CustomerRuntime? target = controller.CustomerQueue?.Slots.FirstOrDefault(customer => customer.State is
                            CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry);
                        for (int step = 0; target is null && step < 100; step++)
                        {
                            controller.IsPaused = false;
                            controller.Tick(.1);
                            target = controller.CustomerQueue?.Slots.FirstOrDefault(customer => customer.State is
                                CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry);
                        }
                        if (target is not null) controller.CustomerQueue!.TrySelect(target.Id);
                        MakeBagged(workstation.Machine, GetNode<DataCatalog>("/root/DataCatalog").RecipesById[StableIds.Recipes.Basic]);
                        if (workstation.FindChild("DeliveryDropZone", true, false) is DropZone delivery)
                            delivery.SetDragState(DropZoneVisualState.Eligible);
                    }
                    if (capturePancakeReady)
                    {
                        PancakeStateMachine machine = workstation.Machine;
                        machine.TryExecute(PancakeCommand.PlaceBatter);
                        machine.TryExecute(PancakeCommand.BeginSpread);
                        machine.SetSpreadCoverage(1);
                        machine.TryExecute(PancakeCommand.CompleteSpread);
                        machine.TryExecute(PancakeCommand.AddEgg);
                        machine.Tick(machine.Stove.SideAReadySeconds);
                    }
                    if (captureSauceReady)
                    {
                        PancakeStateMachine machine = workstation.Machine;
                        machine.TryExecute(PancakeCommand.PlaceBatter);
                        machine.TryExecute(PancakeCommand.BeginSpread);
                        machine.SetSpreadCoverage(1);
                        machine.TryExecute(PancakeCommand.CompleteSpread);
                        machine.TryExecute(PancakeCommand.AddEgg);
                        machine.Tick(machine.Stove.SideAReadySeconds);
                        machine.TryExecute(PancakeCommand.Flip);
                        machine.Tick(machine.Stove.SideBReadySeconds);
                    }
                    dayScreen.RefreshForCapture(captureInteraction || capturePancakeReady || captureSauceReady);
                    if (captureFryerWorkstation)
                    {
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
                    if (capturePartialOrder)
                    {
                        DeliverPartialOrderForCapture(controller, workstation, GetNode<DataCatalog>("/root/DataCatalog"));
                        workstation.RefreshForCapture();
                    }
                    if (captureBagged || captureMultiple || captureClosingBag)
                        MakeBagged(workstation.Machine, GetNode<DataCatalog>("/root/DataCatalog").RecipesById[StableIds.Recipes.Basic]);
                    if (captureMultiple)
                    {
                        workstation.Tick(.3);
                        MakeBagged(workstation.Machine, GetNode<DataCatalog>("/root/DataCatalog").RecipesById[StableIds.Recipes.Ham]);
                        workstation.Tick(.3);
                        ((Button)workstation.FindChild("NextPancake", true, false)).EmitSignal(Button.SignalName.Pressed);
                        workstation.Machine.TryExecute(PancakeCommand.PlaceBatter);
                        workstation.Machine.TryExecute(PancakeCommand.BeginSpread);
                        workstation.Machine.TryExecute(PancakeCommand.CompleteSpread);
                    }
                    if (captureRefilling)
                    {
                        ReduceTo(workstation.Inventory, StableIds.Ingredients.Batter, 0);
                        workstation.Inventory.TryBeginRefill(StableIds.Ingredients.Batter);
                        workstation.Inventory.Tick(.5);
                        ReduceTo(workstation.Inventory, StableIds.Ingredients.Egg, 0);
                        while (workstation.SoyMilkTray?.Quantity > 0)
                        {
                            workstation.SoyMilkTray.TryConsumeForDelivery();
                            workstation.SoyMilkTray.Tick(1);
                        }
                    }
                    if (phase4Day == 11)
                    {
                        if (args.Contains("--capture-low-patience", StringComparer.Ordinal)
                            && controller.CustomerQueue?.Slots.FirstOrDefault() is CustomerRuntime impatient)
                        {
                            impatient.WaitSeconds = impatient.LeaveAtSeconds * .9;
                            impatient.State = CustomerState.Angry;
                        }
                        dayScreen.RefreshForCapture(true);
                        workstation.Tick(.3);
                        dayScreen.SetProcess(false);
                        ((Control)dayScreen.FindChild("FeedbackPanel", true, false)).Visible = captureRefilling || capturePartialOrder;
                    }
                    if (capturePause && dayScreen.FindChild("PauseButton", true, false) is Button pause)
                        pause.EmitSignal(Button.SignalName.Pressed);
                    if (captureClosingBag)
                    {
                        // Close while a newly bagged pancake is still in flight.
                        workstation.ResetForDay();
                        MakeBagged(workstation.Machine, GetNode<DataCatalog>("/root/DataCatalog").RecipesById[StableIds.Recipes.Basic]);
                        workstation.Tick(.08);
                        var drag = workstation.GetChildren().OfType<DragService>().Single();
                        drag.BeginDrag(workstation, "soy_milk_cup", "豆浆", TianjinUi.Cream);
                        controller.Tick(controller.CurrentConfig!.DurationSeconds);
                        controller.Tick(DayController.ClosingDurationSeconds);
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
        if ((captureInteraction || capturePancakeReady || captureSauceReady) && phase4Day > 0)
        {
            Node main = GetNode("../Main");
            main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen").RefreshForCapture(true);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        if (captureDirectDelivery)
        {
            Node main = GetNode("../Main");
            var screen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            var controller = main.GetNode<DayController>("DayController");
            var workstation = screen.GetChildren().OfType<PancakeWorkstation>().Single();
            screen.RefreshForCapture(true);
            CustomerRuntime customer = controller.CustomerQueue!.Slots[2];
            RecipeData recipe = GetNode<DataCatalog>("/root/DataCatalog").RecipesById[
                customer.Order.Lines.First(line => line.ProductKind == ProductKind.Pancake).DefinitionId];
            MakeBagged(workstation.Machine, recipe);
            workstation.Tick(.3);
            workstation.RefreshForCapture();
            var drag = workstation.GetChildren().OfType<DragService>().Single();
            var zone = (DropZone)screen.FindChild("CustomerDropZone3", true, false);
            drag.BeginDrag((Control)workstation.FindChild("FinishedPancakeSlot", true, false), "finished_pancake", "煎饼", TianjinUi.Cream,
                new DragVisualSpec(new TianjinArtCatalog().FinishedPancake, new Vector2(150, 125)));
            using var motion = new InputEventMouseMotion { Position = zone.GetGlobalRect().GetCenter() };
            drag._Input(motion);
            await ToSignal(GetTree().CreateTimer(.2), SceneTreeTimer.SignalName.Timeout);
        }
        if (captureMultiple)
        {
            var screen = GetNode("../Main").GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            Control food = (Control)screen.FindChild("FinishedPancakeDrag", true, false);
            using var motion = new InputEventMouseMotion { Position = food.GetGlobalRect().GetCenter() };
            GetViewport().PushInput(motion, true);
            await ToSignal(GetTree().CreateTimer(1.2), SceneTreeTimer.SignalName.Timeout);
        }
        if (captureSauceReady && args.Contains("--capture-held-brush", StringComparer.Ordinal))
        {
            var screen = GetNode("../Main").GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
            screen.RefreshForCapture(true);
            ((Button)station.FindChild("IngredientInput_sauce", true, false)).EmitSignal(Button.SignalName.Pressed);
            Control jar = (Control)station.FindChild("IngredientInput_sauce", true, false);
            using var motion = new InputEventMouseMotion { Position = jar.GetGlobalRect().GetCenter() + new Vector2(-50, -65) };
            GetViewport().PushInput(motion, true);
            await ToSignal(GetTree().CreateTimer(.2), SceneTreeTimer.SignalName.Timeout);
        }
        if (args.Contains("--capture-hold", StringComparer.Ordinal) || args.Contains("--capture-coins", StringComparer.Ordinal))
        {
            var screen = GetNode("../Main").GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
            screen.SetProcess(false);
            screen.RefreshForCapture(true);
            if (args.Contains("--capture-coins", StringComparer.Ordinal))
            {
                var controller = GetNode("../Main").GetNode<DayController>("DayController");
                var catalog = GetNode<DataCatalog>("/root/DataCatalog");
                foreach (CustomerRuntime customer in controller.CustomerQueue!.Slots.Take(3).ToArray())
                {
                    var zone = (DropZone)screen.FindChild($"CustomerDropZone{customer.SlotIndex + 1}", true, false);
                    for (int i = 0; i < customer.Order.Lines.Count; i++)
                    {
                        OrderLineData line = customer.Order.Lines[i];
                        for (int n = 0; n < line.Quantity; n++)
                        {
                            string payload;
                            if (line.ProductKind == ProductKind.Pancake)
                            {
                                MakeBagged(station.Machine, catalog.RecipesById[line.DefinitionId]);
                                station.Tick(.3);
                                payload = "finished_pancake";
                            }
                            else if (line.ProductKind == ProductKind.Youtiao)
                            {
                                station.FryerMachine!.Inventory.TryStore(1, YoutiaoQuality.Golden);
                                payload = "stored_youtiao";
                            }
                            else { station.SoyMilkTray!.Tick(.3); payload = "soy_milk_cup"; }
                            if (!zone.TryAccept(payload)) throw new InvalidOperationException("收款截图交付失败：" + payload);
                        }
                    }
                }
                screen.RefreshForCapture(true);
                await ToSignal(GetTree().CreateTimer(1.1), SceneTreeTimer.SignalName.Timeout);
            }
            if (args.Contains("--capture-hold", StringComparer.Ordinal))
            {
                ReduceTo(station.Inventory, "egg", 1);
                var gesture = (StockGesture)station.FindChild("StockGesture_egg", true, false);
                using var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = new Vector2(100, 60) };
                gesture._GuiInput(press);
                gesture.Tick(.28);
            }
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }
        Image image = GetViewport().GetTexture().GetImage();
        string sizeSuffix = capture720 ? "_720" : string.Empty;
        string? outputArg = args.FirstOrDefault(arg => arg.StartsWith("--capture-output=", StringComparison.Ordinal));
        string output = outputArg is not null ? outputArg["--capture-output=".Length..]
            : captureYoutiaoQuality ? $"res://.godot/youtiao_quality{sizeSuffix}.png"
            : captureRefillGallery ? $"res://.godot/ingredient_refill_gallery{sizeSuffix}.png"
            : captureStockGallery ? $"res://.godot/ingredient_stock_gallery{sizeSuffix}.png"
            : captureBagged ? $"res://.godot/phase4_bagged{sizeSuffix}.png"
            : captureRefilling ? $"res://.godot/phase4_refilling{sizeSuffix}.png"
            : captureDirectDelivery ? $"res://.godot/direct_delivery{sizeSuffix}.png"
            : captureResult ? $"res://.godot/phase4_result{sizeSuffix}.png"
            : captureFryerSlots ? $"res://.godot/fryer_slots{sizeSuffix}.png"
            : captureFryerWorkstation ? $"res://.godot/fryer_workstation_lv{captureFryerLevel}{sizeSuffix}.png"
            : captureExpressions ? $"res://.godot/customer_expressions_page{expressionPage}{sizeSuffix}.png"
            : captureLowStock ? $"res://.godot/phase4_low_stock{sizeSuffix}.png"
            : captureInteraction ? $"res://.godot/phase4_interaction{sizeSuffix}.png"
            : capturePancakeReady ? $"res://.godot/phase4_pancake_ready{sizeSuffix}.png"
            : captureSauceReady ? $"res://.godot/phase4_sauce_ready{sizeSuffix}.png"
            : capturePause ? $"res://.godot/phase4_pause{sizeSuffix}.png"
            : capturePartialOrder ? $"res://.godot/phase4_partial_order{sizeSuffix}.png"
            : captureThreeCustomers ? $"res://.godot/phase4_three_customers{sizeSuffix}.png"
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

    private void BuildIngredientStockGallery(bool refillPreview = false)
    {
        Node main = GetNode("../Main");
        main.ProcessMode = ProcessModeEnum.Disabled;
        main.GetNode<Node2D>("ShopRoot").Visible = false;
        foreach (Control screen in main.GetNode("UI").GetChildren().OfType<Control>()) screen.Visible = false;

        var gallery = new ColorRect
        {
            Color = TianjinUi.Cream,
            Theme = TianjinUi.CreateTheme(),
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        TianjinUi.FullRect(gallery);
        AddChild(gallery);

        Label title = TianjinUi.Label("天津工作台 · 小料库存变化", 36, TianjinUi.BrownDark, HorizontalAlignment.Center);
        title.Position = new Vector2(100, 28);
        title.Size = new Vector2(1720, 58);
        gallery.AddChild(title);

        Label subtitle = TianjinUi.Label(refillPreview
            ? "Lv3 配料台 · 1 秒补货 · 随进度逐步补入，完成后恢复取料"
            : "Lv3 配料台 · 同一盘面尺寸与固定位置 · 从满盘到空盘，再完成补货", 22,
            TianjinUi.Brown, HorizontalAlignment.Center);
        subtitle.Position = new Vector2(100, 92);
        subtitle.Size = new Vector2(1720, 40);
        gallery.AddChild(subtitle);

        var counter = new ColorRect
        {
            Color = TianjinUi.Orange.Lerp(TianjinUi.CreamMuted, .42f),
            Position = new Vector2(144, 200),
            Size = new Vector2(1640, 756),
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        gallery.AddChild(counter);

        string[] states = refillPreview ? new[] { "开始补货", "25%", "50%", "75%", "补货完成" }
            : new[] { "满盘", "半盘", "剩 3 份", "空盘", "补货完成" };
        for (int column = 0; column < states.Length; column++)
        {
            Label heading = TianjinUi.Label(states[column], 27, TianjinUi.BrownDark, HorizontalAlignment.Center);
            heading.Position = new Vector2(184 + column * 318, 144);
            heading.Size = new Vector2(280, 44);
            gallery.AddChild(heading);
        }

        DataCatalog catalog = GetNode<DataCatalog>("/root/DataCatalog");
        var level = catalog.IngredientStationsByLevel[3];
        var art = new TianjinArtCatalog();
        (string Id, string Name)[] ingredients =
        {
            (StableIds.Ingredients.Crispy, "薄脆"),
            (StableIds.Ingredients.Egg, "鸡蛋"),
            (StableIds.Ingredients.Ham, "火腿"),
            (StableIds.Ingredients.Scallion, "香葱"),
        };

        for (int row = 0; row < ingredients.Length; row++)
        {
            (string id, string displayName) = ingredients[row];
            for (int column = 0; column < states.Length; column++)
            {
                var inventory = new IngredientInventory(level);
                int capacity = inventory.GetCapacity(id);
                int target = refillPreview ? 0 : column switch
                {
                    0 => capacity,
                    1 => capacity / 2,
                    2 => Math.Min(3, capacity),
                    _ => 0,
                };
                ReduceTo(inventory, id, target);
                var slot = new IngredientStockSlotView
                {
                    Name = $"StockGallery_{id}_{column}",
                    Position = new Vector2(184 + column * 318, 212 + row * 190),
                    Size = TianjinWorkbenchLayout.IngredientSlot(id).MinimumSize,
                };
                gallery.AddChild(slot);
                slot.ConfigureStock(art.IngredientTray, art.Ingredient(id), displayName,
                    TianjinWorkbenchLayout.IngredientSlot(id), id == StableIds.Ingredients.Scallion
                        ? IngredientVisualMode.LooseStock : IngredientVisualMode.HybridStock);
                slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id), 0, true);

                if (refillPreview)
                {
                    inventory.TryBeginRefill(id);
                    inventory.Tick(level.RefillSeconds * column / 4d);
                    slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id),
                        inventory.GetRefillProgress(id), true);
                }
                else if (column == 4)
                {
                    // Exercise a real refill before capturing its completed state.
                    inventory.TryBeginRefill(id);
                    inventory.Tick(level.RefillSeconds * .5);
                    slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id),
                        inventory.GetRefillProgress(id), true);
                    inventory.Tick(level.RefillSeconds);
                    slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id),
                        inventory.GetRefillProgress(id), true);
                }
            }
        }

        Label note = TianjinUi.Label(refillPreview
            ? "补货时标牌显示进度，盘内逐步补入食材；完成前不能取料，香葱按簇增加。"
            : "高库存看疏密，少量逐份可数；标牌保留实际数量。补货完成后恢复满盘。", 22,
            TianjinUi.BrownDark, HorizontalAlignment.Center);
        note.Position = new Vector2(100, 980);
        note.Size = new Vector2(1720, 52);
        gallery.AddChild(note);
    }

    private void BuildYoutiaoQualityGallery()
    {
        Node main = GetNode("../Main");
        main.ProcessMode = ProcessModeEnum.Disabled;
        main.GetNode<Node2D>("ShopRoot").Visible = false;
        foreach (Control screen in main.GetNode("UI").GetChildren().OfType<Control>()) screen.Hide();
        var gallery = new ColorRect { Color = new Color("#FFF4D5"), Theme = TianjinUi.CreateTheme() };
        TianjinUi.FullRect(gallery); AddChild(gallery);
        var art = new TianjinArtCatalog();
        string[] titles = { "偏浅", "金黄", "偏深", "混合品质 · 先取偏浅" };
        YoutiaoQuality[][] stocks = {
            Enumerable.Repeat(YoutiaoQuality.Light, 6).ToArray(),
            Enumerable.Repeat(YoutiaoQuality.Golden, 6).ToArray(),
            Enumerable.Repeat(YoutiaoQuality.Deep, 6).ToArray(),
            new[] { YoutiaoQuality.Light, YoutiaoQuality.Light, YoutiaoQuality.Golden, YoutiaoQuality.Golden, YoutiaoQuality.Deep, YoutiaoQuality.Deep },
        };
        for (int column = 0; column < stocks.Length; column++)
        {
            var card = new Control { Position = new Vector2(40 + column * 470, 80), Size = new Vector2(430, 880) };
            gallery.AddChild(card);
            Label title = TianjinUi.Label(titles[column], 30, TianjinUi.BrownDark, HorizontalAlignment.Center);
            title.Size = new Vector2(430, 56); card.AddChild(title);
            var machine = new FryerStateMachine(GetNode<DataCatalog>("/root/DataCatalog").FryersByLevel[1]);
            for (int i = 0; i < 6; i++) machine.TryExecute(FryerCommand.LoadOne);
            machine.Runtime.State = FryerState.Draining;
            machine.Runtime.Quality = stocks[column][0];
            var fryer = new FryerVisualView { Position = new Vector2(35, 72), Size = new Vector2(360, 340) };
            card.AddChild(fryer); fryer.Bind(art, machine);
            var rack = new WorkstationSlotView { Position = new Vector2(35, 400), Scale = Vector2.One * 1.5f };
            card.AddChild(rack);
            rack.Configure(art.YoutiaoRack, art.Ingredient(StableIds.Ingredients.Youtiao), "熟油条",
                TianjinWorkbenchLayout.FinishedYoutiaoSlot(), IngredientVisualMode.WideStock);
            rack.HideNameplate(); rack.SetStock(6, 6);
            rack.SetWideStockTints(YoutiaoPresentation.RackTints(stocks[column], rack.StockTier));
            var preview = TianjinUi.Texture(art.Ingredient(StableIds.Ingredients.Youtiao), new Vector2(160, 110));
            preview.Position = new Vector2(135, 665);
            preview.Modulate = YoutiaoPresentation.Tint(stocks[column][0]); card.AddChild(preview);
            Label caption = TianjinUi.Label(column == 1 ? "下一根金黄 · 有小费 · 评价100" : "下一根" + YoutiaoPresentation.Name(stocks[column][0]) + " · 无小费 · 评价85",
                23, TianjinUi.BrownDark, HorizontalAlignment.Center);
            caption.Position = new Vector2(0, 800); caption.Size = new Vector2(430, 50); card.AddChild(caption);
        }
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

    private static void DeliverPartialOrderForCapture(DayController controller, PancakeWorkstation workstation, DataCatalog catalog)
    {
        CustomerRuntime? customer = controller.CustomerQueue?.Slots.FirstOrDefault(item => item.Order.Lines.Count > 1);
        if (customer is null || controller.CustomerQueue?.TrySelect(customer.Id) != true) return;
        OrderLineData? line = customer.Order.Lines.FirstOrDefault(item => item.ProductKind == ProductKind.SoyMilk)
            ?? customer.Order.Lines.FirstOrDefault(item => item.ProductKind == ProductKind.Youtiao)
            ?? customer.Order.Lines.FirstOrDefault();
        if (line is null) return;
        if (line.ProductKind == ProductKind.SoyMilk && workstation.SoyMilkTray is not null)
        {
            controller.TryDeliverSoyMilkSelected(workstation.SoyMilkTray);
            return;
        }
        if (line.ProductKind == ProductKind.Youtiao && workstation.FryerMachine is not null)
        {
            workstation.FryerMachine.Inventory.TryStore(1, YoutiaoQuality.Golden);
            controller.TryDeliverYoutiaoSelected(workstation.FryerMachine.Inventory);
            return;
        }
        if (line.ProductKind == ProductKind.Pancake)
        {
            MakeBagged(workstation.Machine, catalog.RecipesById[line.DefinitionId]);
            workstation.Tick(.3);
            workstation.DeliverPancakeTo(controller, controller.CustomerQueue?.SelectedCustomerId, catalog);
        }
    }

    private static void ReduceTo(IngredientInventory inventory, string ingredientId, int target)
    {
        int amount = Math.Max(0, inventory.GetQuantity(ingredientId) - target);
        if (amount > 0) inventory.TryConsume(ingredientId, amount);
    }
}
