using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

/// <summary>Integrated-sheet unlocks, capability upgrades and all twelve real day plans.</summary>
public partial class WuhanWorkbenchSelfTest : Node
{
    private int _passed;
    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        _passed++; GD.Print("PASS " + message);
    }

    public override async void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var save = new SaveService();
            save.UsePathForTests($"res://.tmp/wuhan-workbench-{Guid.NewGuid():N}.json"); AddChild(save);
            var controller = new DayController(); AddChild(controller);
            var screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");
            AddChild(screen); screen.ConnectController(controller); screen.SetProcess(false);
            var art = new WuhanArtCatalog();
            Check(art.MissingRequiredAssets().Count == 0, "integrated sheet and dynamic assets load");
            Check(art.WorkbenchBackground(false) == art.WorkbenchBackground(true), "both unlock stages temporarily share v1");

            // Production/gestures have their own timed viewport tests. This loop supplies valid
            // production states without advancing cooking time, to isolate all real order routes.
            for (int day = 1; day <= 12; day++)
            {
                screen.Initialize(catalog, save, controller, day); screen.BeginDay();
                screen._Notification((int)NotificationApplicationFocusIn);
                screen._Process(3.1);
                Check((screen.Doupi is not null) == (day >= 4), $"Day {day}: original doupi unlock");
                Check(screen.EggUnlocked == (day >= 6), $"Day {day}: original egg unlock");
                if (day < 4)
                {
                    screen.DoupiAction();
                    Check(screen.Doupi is null && screen.DoupiStock.Count == 0 && !screen.Workstation.CanDeliver(ProductKind.Doupi),
                        "visible locked pan cannot make or deliver food");
                }
                if (day < 6) Check(!screen.Workstation.CanDeliver(ProductKind.EggRiceWine), "locked egg UI cannot deliver");
                int iterations = 0;
                while (controller.State is DayState.Running or DayState.Closing && iterations++ < 5000)
                {
                    foreach (var customer in controller.CustomerQueue!.Slots.ToArray())
                    {
                        for (int lineIndex = 0; lineIndex < customer.Plan.Order.Lines.Count; lineIndex++)
                        {
                            var line = customer.Plan.Order.Lines[lineIndex];
                            while (customer.Progress.GetRemainingQuantity(lineIndex) > 0 && controller.CanDeliverTo(customer.Id, line.ProductKind))
                            {
                                if (line.ProductKind == ProductKind.HotDryNoodles)
                                {
                                    screen.Bowl.Reset();
                                    Check(screen.Bowl.TryAddNoodles(NoodleQuality.Optimal), "new bowl accepts noodles");
                                    // Exercise both real click aliases, including duplicate protection.
                                    Vector2 source = lineIndex % 2 == 0 ? screen.Workstation.SauceCenter : screen.Workstation.IngredientCenter(0);
                                    screen.Workstation._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = source });
                                    screen.Workstation.CancelAnimations();
                                    screen.Workstation._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = screen.Workstation.IngredientCenter(0) });
                                    Check(screen.Bowl.State == NoodleBowlState.Seasoned && !screen.Workstation.Busy("bowl"), "sauce aliases season once");
                                    foreach (string ingredient in catalog.RecipesById[line.DefinitionId].ExtraIngredients)
                                    {
                                        screen.IngredientAction(ingredient); screen.Workstation.CancelAnimations();
                                    }
                                    screen.Bowl.AddMixDistance(1000);
                                }
                                else if (line.ProductKind == ProductKind.Doupi)
                                {
                                    Check(screen.Doupi is not null, "real doupi order has unlocked production");
                                    screen.DoupiStock.TryAddBatch(DoupiInventory.Capacity - screen.DoupiStock.Count);
                                }
                                screen.Workstation.CancelAnimations(); screen.RefreshForCapture();
                                Check(screen.DeliverToCustomer(customer.Id, line.ProductKind), $"Day {day}: {line.DefinitionId} accepted");
                            }
                        }
                    }
                    screen._Process(.2);
                }
                Check(controller.State == DayState.Results, $"Day {day}: reaches results");
                Check(save.Data.Wuhan.DayBestRecords[day].CompletedCustomers == controller.CurrentPlan!.Customers.Count,
                    $"Day {day}: every generated customer's order can be completed");
                Check(save.Data.Wuhan.DayBestRecords[day].IncorrectOrders == 0, $"Day {day}: every recipe matches");
                Check(save.Data.Wuhan.HighestUnlockedDay == Math.Min(12, day + 1), $"Day {day}: original progression");
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            }

            save.Data.Coins = 10000;
            foreach (int level in new[] { 2, 3 })
            {
                foreach (string equipment in new[] { "noodle_cooker", "doupi_griddle", "wuhan_ingredient_station" })
                    Check(save.TryPurchase(StableIds.Cities.Wuhan, $"equipment:{equipment}_lv{level}", catalog, out _), $"purchase {equipment} Lv{level}");
                screen.Initialize(catalog, save, controller, 12);
                Check(screen.Cooker.Baskets.Count == (level == 3 ? 2 : 1), "upgrade keeps functional basket capacity");
                Check(screen.Ingredients.Capacity(StableIds.Ingredients.WuhanNoodles) == catalog.WuhanIngredientStationsByLevel[level].NoodlesCapacity,
                    "upgrade changes inventory capacity");
                Check(screen.GetNode<TextureRect>("WorkbenchBackground").Texture == art.WorkbenchBackground(true), "upgrade preserves integrated equipment appearance");
            }
            screen.Free(); controller.Free(); save.Free();
            GD.Print($"WUHAN_WORKBENCH_RESULT passed={_passed} failed=0"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GD.Print($"WUHAN_WORKBENCH_RESULT passed={_passed} failed=1"); GetTree().Quit(1); }
    }
}
