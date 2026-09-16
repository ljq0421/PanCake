using System.Text.Json;
using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
namespace ProjectCake.Tests;
public partial class DemoRouteSelfTest : Node
{
    private int _checks;
    private void Check(bool ok, string text) { if (!ok) throw new Exception(text); GD.Print("PASS " + text); _checks++; }
    public override void _Ready()
    {
        try
        {
            var c = GetNode<DataCatalog>("/root/DataCatalog"); var route = c.Demo!;
            Check(c.IsValid && route is not null, "valid Demo manifest");
            string dir = ProjectSettings.GlobalizePath("res://.tmp/demo-route-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(dir);
            var save = new SaveService(); save.UseDemoPathForTests(Path.Combine(dir, "route.json"), route!);
            Check(save.ResetProgress(out _), "fresh route");
            int[] expected = {28,46,65,48,84,106,123,50,76,98,72,125,159}; int total = 0;
            foreach (var pair in route!.Stages.Select((stage, index) => (stage, index)))
            {
                var s = pair.stage; var config = s.Config(c.RecipesById, c.ProductsById); var plan = s.Plan(c);
                Check(save.CanEnter(s.CityId, s.Day), s.Id + " unlocked in order");
                Check(config.ExpectedRevenue == expected[pair.index] && plan.Customers.Sum(p => p.Order.BasePrice) == expected[pair.index], s.Id + " exact price baseline");
                Check(config.MaxWaitingCustomers == 5 && plan.Customers.Count == s.Arrivals.Length, s.Id + " customer capacity and schedule");
                Check(save.ApplyStartUnlocks(config, out _), s.Id + " free equipment and recipes");
                var result = new DayResult { Day = s.Day, CompletedCustomers = 1, SaleRevenue = expected[pair.index] };
                save.CommitDay(result, plan, config); total += expected[pair.index];
                Check(save.CommitDay(result, plan, config).PermanentCoinGain == 0 && save.Data.Coins == total, s.Id + " idempotent settlement");
                save.Load();
                Check(!save.HasLoadError && save.Data.Coins == total && save.DemoProgress.CompletedStages.Contains(s.Id), s.Id + " reload");
            }
            Check(!save.CanEnter(StableIds.Cities.Xian, 1) && !save.CanEnter(StableIds.Cities.Tianjin, 8)
                && !save.CanEnter(StableIds.Cities.Wuhan, 7), "unshipped content inaccessible");
            Check(save.TryPurchase("equipment:fryer_lv2", c, out _) && save.Data.PurchasedFryerLevel == 2, "fryer upgrade uses actual saved balance");

            var controller = new DayController(); AddChild(controller);
            var screen = GD.Load<PackedScene>("res://Scenes/Gameplay/TianjinDayScreen.tscn").Instantiate<TianjinDayScreen>(); AddChild(screen);
            screen.ConnectController(controller); screen.SetProcess(false); controller.SetProcess(false);
            foreach (int day in new[] {2,4,6})
            {
                Check(screen.Initialize(c, save, controller, day), "prepare new Tianjin lesson " + day);
                screen.BeginDay();
                Check(controller.TutorialActive && controller.CurrentPlan!.Customers.Count == 1, "isolated example " + day);
                var station = screen.GetNode<PancakeWorkstation>("PancakeWorkstation");
                screen._Notification((int)NotificationApplicationFocusIn); screen.RefreshForCapture(true);
                if (day == 4)
                {
                    station.FryerMachine!.TryExecute(ProjectCake.Fryer.FryerCommand.LoadOne);
                    station.FryerMachine.TryExecute(ProjectCake.Fryer.FryerCommand.LowerBasket);
                    station.Tick(1000);
                    Check(station.FryerMachine.Runtime.Quality == ProjectCake.Fryer.YoutiaoQuality.Golden, "oil tutorial waits safely at golden heat");
                }
                if (day == 6)
                {
                    controller.Tick(.6); screen.RefreshForCapture(true);
                    var customer = controller.CustomerQueue!.Slots[0]; double beforePatience = customer.WaitSeconds;
                    var delivery = controller.TryDeliverSoyMilkTo(customer.Id, station.SoyMilkTray!);
                    Check(beforePatience > 0 && delivery.ItemAccepted && !delivery.CompletesOrder
                        && Math.Abs(customer.WaitSeconds - (beforePatience - customer.LeaveAtSeconds * .15)) < .001
                        && controller.CurrentPlan!.PendingBreakfastRecords.Count == 0, "teaching soy delivery visibly restores 15 percent without collection");
                }
                screen.FinishDemoLesson();
                Check(!controller.TutorialActive && controller.CurrentConfig!.Day == day
                    && station.PancakeTray.Count == 0 && (station.FryerMachine?.Inventory.Count ?? 0) == 0, "skip clears example and restores main resources");
            }
            screen.QueueFree(); controller.QueueFree();
            if (route.CityStages(StableIds.Cities.Wuhan).Length > 0)
            {
                var wc = new DayController(); AddChild(wc); wc.SetProcess(false);
                var ws = GD.Load<PackedScene>("res://Scenes/Gameplay/WuhanDayScreen.tscn").Instantiate<WuhanDayScreen>(); AddChild(ws); ws.SetProcess(false); ws.ConnectController(wc);
                foreach (int day in new[] {1,4})
                {
                    Check(ws.Initialize(c, save, wc, day), "Wuhan lesson prepared " + day);
                    ws._Notification((int)NotificationApplicationFocusIn); ws.BeginDay(); wc.Tick(.6);
                    Check(wc.TutorialActive && wc.DayElapsedSeconds == 0, "Wuhan example clock isolated");
                    if (day == 1)
                    {
                        ws.Cooker.TryStart(0); ws.Cooker.Tick(1000);
                        Check(ws.Cooker.Baskets[0].Quality == ProjectCake.Wuhan.NoodleQuality.Optimal, "teaching noodles never overcook");
                        ws.Cooker.TryRaise(0); ws.Cooker.Tick(1000); ws.Cooker.TryTransferTo(0, ws.Bowl);
                        ws.Bowl.TryAddBaseSeasoning(); ws.Bowl.AddMixDistance(1000);
                    }
                    else
                    {
                        ws.Doupi!.TryPourBatter(); ws.Doupi.Tick(1000);
                        Check(ws.Doupi.State == ProjectCake.Wuhan.DoupiState.Batter, "teaching waits for egg");
                        ws.Doupi.TryAddEgg(); ws.Doupi.Tick(1000);
                        Check(ws.Doupi.State == ProjectCake.Wuhan.DoupiState.ReadyToFlip, "teaching waits for flip");
                        ws.Doupi.TryFlip(); ws.Doupi.Tick(1000); ws.Doupi.TryAddFilling(); ws.Doupi.Tick(1000);
                        Check(ws.Doupi.State == ProjectCake.Wuhan.DoupiState.ReadyToCut, "teaching waits for cutting");
                        ws.Doupi.TryCut(ProjectCake.Wuhan.DoupiCutLine.Horizontal); ws.Doupi.TryCut(ProjectCake.Wuhan.DoupiCutLine.Center);
                        ws.Doupi.TransferAvailable(ws.DoupiStock);
                    }
                    int coins = save.Data.Coins;
                    Check(ws.DeliverToCustomer(wc.CustomerQueue!.Slots[0].Id, day == 1 ? ProductKind.HotDryNoodles : ProductKind.Doupi), "real Wuhan lesson delivery");
                    Check(wc.Ledger!.Build().TotalRevenue == 0 && save.Data.Coins == coins, "Wuhan lesson no revenue");
                    ws.FinishWuhanDemoLesson();
                    Check(!wc.TutorialActive && ws.Bowl.State == ProjectCake.Wuhan.NoodleBowlState.Empty
                        && ws.DoupiStock.Count == 0 && !ws.Cooker.ProtectTeachingHeat, "Wuhan example clears before normal shift");
                }
                ws.QueueFree(); wc.QueueFree();
                Check(save.TryPurchase(StableIds.Cities.Wuhan, "equipment:noodle_cooker_lv2", c, out _), "Wuhan upgrade purchase");
                Check(save.TryRecordDemoStart(StableIds.Cities.Wuhan, 3, out _), "record Wuhan replay");
                save.Load(); Check(save.ContinueCityId == StableIds.Cities.Wuhan && save.ContinueDay == 3, "continue preserves Wuhan stage");
            }
            var legacy = new DemoSaveFile { SchemaVersion = 1, ContentRevision = 1, Coins = 19,
                LastStartedStageId = "demo_tj_03", CompletedStages = new() { "demo_tj_01", "demo_tj_02", "demo_tj_03" } };
            legacy.Equipment["pancake_stove"] = 2; legacy.LearnedActions.Add("spread");
            legacy.BestRecords["demo_tj_03"] = new() { TotalRevenue = 65, CompletedCustomers = 8 };
            string old = Path.Combine(dir, "legacy.json"); string original = JsonSerializer.Serialize(legacy, DemoCatalog.JsonOptions); File.WriteAllText(old, original);
            var migrated = new SaveService(); migrated.UseDemoPathForTests(old, route);
            Check(!migrated.HasLoadError && migrated.ContinueDay == 4 && migrated.Data.Coins == 19
                && migrated.Data.PurchasedStoveLevel == 2 && migrated.Data.Tianjin.LearnedWorkbenchActions.Contains("spread"), "pilot migration preserves assets and opens T4");
            Check(File.ReadAllText(old + ".before-v2-r" + route.ContentRevision + ".bak") == original, "migration preserves original bytes");
            migrated.Load(); Check(migrated.Data.Coins == 19, "migration never reissues income");
            GD.Print("DEMO_ROUTE_SELF_TEST_OK " + _checks); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
