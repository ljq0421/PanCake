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
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests($"user://wuhan-menu-settings-{Guid.NewGuid():N}.cfg");
            InterfaceLessons.MarkAllSeen(settings);
            var save = new SaveService();
            AddChild(save);
            string path = $"user://wuhan-workbench-{Guid.NewGuid():N}.json";
            if (ExperienceProfile.IsDemo)
            {
                save.UseDemoPathForTests(ProjectSettings.GlobalizePath(path));
                save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
                Check(save.TrySave(out _), "save isolated Demo entry fixture");
                save.Load();
            }
            else save.UsePathForTests(path);
            var controller = new DayController(); AddChild(controller);
            var screen = SceneFactory.Instantiate<WuhanDayScreen>("res://Scenes/Gameplay/WuhanDayScreen.tscn");
            AddChild(screen); screen.ConnectController(controller); screen.SetProcess(false);
            var art = new WuhanArtCatalog();
            Check(art.MissingRequiredAssets().Count == 0, "integrated sheet and dynamic assets load");
            Check(art.WorkbenchBackground(false) != art.WorkbenchBackground(true), "unlock stages use distinct v2 sheets");

            // Production/gestures have their own timed viewport tests. This loop supplies valid
            // production states without advancing cooking time, to isolate all real order routes.
            for (int day = 1; day <= 12; day++)
            {
                if (day >= 4 && save.Data.Wuhan.EquipmentLevels.GetValueOrDefault("doupi_griddle") == 0)
                    save.Data.Wuhan.EquipmentLevels["doupi_griddle"] = 1;
                Check(screen.Initialize(catalog, save, controller, day), $"Day {day}: initializes");
                screen.BeginDay();
                screen._Notification((int)NotificationApplicationFocusIn);
                if (controller.TutorialActive) screen.FinishWuhanDemoLesson();
                Check(!controller.TutorialActive, $"Day {day}: tests normal business after tutorial");
                screen._Notification((int)NotificationApplicationFocusIn);
                screen._Process(3.1);
                if (controller.State == DayState.Preparing)
                    Check(controller.TryStartDay(out _), $"Day {day}: starts business after unlock presentation");
                string[] recipes = controller.CurrentConfig!.AvailableRecipeIds.ToArray();
                Check(recipes.Length == (day == 1 ? 3 : day == 2 ? 4 : 6), $"Day {day}: correct menu size");
                Check(recipes.Contains("hot_dry_noodles_scallion_chili") == (day >= 2), $"Day {day}: double topping unlock");
                Check(recipes.Contains("hot_dry_noodles_beef") == (day >= 3)
                    && recipes.Contains("hot_dry_noodles_beef_chili") == (day >= 3), $"Day {day}: both beef recipes unlock together");
                Check(screen.Workstation.BeefUnlocked == (day >= 3), $"Day {day}: beef input follows the menu");
                Check(screen.GetNode<TextureRect>("WorkbenchBackground").Texture == art.WorkbenchBackground(day >= 4, day >= 3),
                    $"Day {day}: background follows the menu");
                // Test both direct action and actual click input on the locked/available beef bowl.
                screen.Bowl.TryAddNoodles(NoodleQuality.Optimal);
                screen.Bowl.TryAddBaseSeasoning();
                screen.Bowl.AddMixDistance(1000);
                screen.IngredientAction(StableIds.Ingredients.WuhanBraisedBeef);
                screen.Workstation.CancelAnimations();
                screen.Workstation._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true,
                    Position = screen.Workstation.IngredientCenter(3) });
                Check(screen.Bowl.Toppings.Contains(StableIds.Ingredients.WuhanBraisedBeef) == (day >= 3),
                    $"Day {day}: beef action and click respect the unlock (state={controller.State}, stock={screen.Ingredients.Count(StableIds.Ingredients.WuhanBraisedBeef)}, canUse={screen.Ingredients.CanUse(StableIds.Ingredients.WuhanBraisedBeef)}, bowl={screen.Bowl.State})");
                screen.Workstation.CancelAnimations(); screen.Bowl.Reset();
                Check((screen.Doupi is not null) == (day >= 4), $"Day {day}: original doupi unlock");
                Check(screen.Workstation.Descendants<EquipmentProgressView>().All(view => !view.ShowCaption), $"Day {day}: progress bars have no text captions");
                void EnsureIngredient(string id)
                {
                    if (screen.Ingredients.CanUse(id)) return;
                    Check(screen.Ingredients.TryRefillOne(id), $"Day {day}: {id} can be replenished when empty");
                    Check(screen.Ingredients.CanUse(id), $"Day {day}: {id} can be used after replenishment");
                }
                if (day < 4)
                {
                    screen.PourDoupiBatter();
                    Check(screen.Doupi is null && screen.DoupiStock.Count == 0 && !screen.Workstation.CanDeliver(ProductKind.Doupi),
                        "locked stage cannot make or deliver doupi");
                }
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
                                    // Exercise the visible sesame bowl, including duplicate protection.
                                    Vector2 source = screen.Workstation.IngredientCenter(0);
                                    EnsureIngredient(StableIds.Ingredients.WuhanBaseSeasoning);
                                    screen.Workstation._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = source });
                                    screen.Workstation.CancelAnimations();
                                    screen.Workstation._GuiInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = screen.Workstation.IngredientCenter(0) });
                                    Check(screen.Bowl.State == NoodleBowlState.Seasoned && !screen.Workstation.Busy("bowl"), "repeated sesame clicks season once");
                                    var toppings = catalog.RecipesById[line.DefinitionId].ExtraIngredients;
                                    foreach (string ingredient in toppings.Where(id => id != StableIds.Ingredients.WuhanBraisedBeef))
                                    {
                                        EnsureIngredient(ingredient);
                                        screen.IngredientAction(ingredient); screen.Workstation.CancelAnimations();
                                    }
                                    screen.Bowl.AddMixDistance(1000);
                                    if (toppings.Contains(StableIds.Ingredients.WuhanBraisedBeef))
                                    {
                                        EnsureIngredient(StableIds.Ingredients.WuhanBraisedBeef);
                                        screen.IngredientAction(StableIds.Ingredients.WuhanBraisedBeef);
                                        screen.Workstation.CancelAnimations();
                                    }
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
                Check(controller.State == DayState.Results, $"Day {day}: reaches results (state={controller.State}, paused={controller.IsPaused}, elapsed={controller.DayElapsedSeconds}, iterations={iterations})");
                Check(save.Data.Wuhan.DayBestRecords[day].CompletedCustomers == controller.CurrentPlan!.Customers.Count,
                    $"Day {day}: every generated customer's order can be completed");
                Check(save.Data.Wuhan.DayBestRecords[day].IncorrectOrders == 0, $"Day {day}: every recipe matches");
                Check(save.Data.Wuhan.HighestUnlockedDay == day + 1, $"Day {day}: unlimited progression");
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            }

            save.Data.Coins = 10000;
            foreach (int level in new[] { 2, 3 })
            {
                foreach (string equipment in new[] { "noodle_cooker", "doupi_griddle" })
                    Check(save.TryPurchase(StableIds.Cities.Wuhan, $"equipment:{equipment}_lv{level}", catalog, out _), $"purchase {equipment} Lv{level}");
                screen.Initialize(catalog, save, controller, 12);
                Check(screen.Cooker.Baskets.Count == (level == 3 ? 2 : 1), "upgrade keeps functional basket capacity");
                Check(screen.Ingredients.IsUnlimited(StableIds.Ingredients.WuhanNoodles),
                    "equipment upgrades preserve unlimited raw supply");
                Check(screen.GetNode<TextureRect>("WorkbenchBackground").Texture == art.WorkbenchBackground(true), "upgrade preserves integrated equipment appearance");
            }
            screen.Free(); controller.Free(); save.Free();
            GD.Print($"WUHAN_WORKBENCH_RESULT passed={_passed} failed=0"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GD.Print($"WUHAN_WORKBENCH_RESULT passed={_passed} failed=1"); GetTree().Quit(1); }
    }
}
