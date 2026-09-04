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
        bool captureRunning = OS.GetCmdlineUserArgs().Contains("--capture-running", StringComparer.Ordinal);
        bool captureDay = captureRunning || OS.GetCmdlineUserArgs().Contains("--capture-day", StringComparer.Ordinal);
        int phase4Day = args.Contains("--capture-day5", StringComparer.Ordinal) ? 5
            : args.Contains("--capture-day9", StringComparer.Ordinal) ? 9
            : args.Contains("--capture-day15", StringComparer.Ordinal) ? 15 : 0;
        bool captureMap = args.Contains("--capture-map", StringComparer.Ordinal);
        bool capture720 = args.Contains("--capture-720", StringComparer.Ordinal);
        bool captureResult = args.Contains("--capture-result", StringComparer.Ordinal);
        bool captureLedger = args.Contains("--capture-ledger", StringComparer.Ordinal);
        string? temporarySave = null;
        if (phase4Day > 0 || captureMap || captureResult)
        {
            temporarySave = $"user://visual-capture-{Guid.NewGuid():N}.json";
            GetNode<SaveService>("/root/SaveService").UsePathForTests(temporarySave);
        }

        if (captureDay || phase4Day > 0 || captureResult)
        {
            Node main = GetNode("../Main");
            var dayScreen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
            var controller = main.GetNode<DayController>("DayController");
            int day = captureResult ? 15 : phase4Day > 0 ? phase4Day : 1;
            var captureSave = GetNode<SaveService>("/root/SaveService");
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
                        if (phase4Day == 15 && controller.CustomerQueue?.Slots.Count >= 5) break;
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
