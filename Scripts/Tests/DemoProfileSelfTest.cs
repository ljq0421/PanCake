using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Pancake;

namespace ProjectCake.Tests;

public partial class DemoProfileSelfTest : Node
{
    private int _checks;
    private void Check(bool value, string description)
    { if (!value) throw new InvalidOperationException(description); _checks++; GD.Print("PASS " + description); }

    public override void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            Check(ExperienceProfile.IsDemo && catalog.IsValid && catalog.Demo is not null, "Demo profile loads before autoload saves");
            var content = catalog.Demo!;
            Check(catalog.DaysByNumber.Count == content.CityStages(StableIds.Cities.Tianjin).Length
                && !catalog.TryGetDay(StableIds.Cities.Xian, 1, out _), "Demo exposes configured city boundaries");
            int[] totals = { 28, 46, 65 };
            foreach (var stage in content.Stages.Take(3))
            {
                var plan = stage.Plan(catalog.RecipesById, catalog.CustomersById["normal"]);
                var replay = stage.Plan(catalog.RecipesById, catalog.CustomersById["normal"]);
                Check(plan.RunId != replay.RunId && plan.StageId == replay.StageId, "runs have distinct identities and stable stages");
                Check(plan.Customers.Sum(c => c.Order.BasePrice) == totals[stage.Day - 1]
                    && plan.Customers.Select(c => c.ArrivalTime).SequenceEqual(stage.Arrivals)
                    && plan.Customers.All(c => c.Order.Lines.Single().Sauce == SaucePreference.Normal), "fixed recipe, arrival and price baseline");
            }
            string directory = ProjectSettings.GlobalizePath($"res://.tmp/demo-tests/{Guid.NewGuid():N}");
            Directory.CreateDirectory(directory);
            string path = Path.Combine(directory, "demo.json"), formal = Path.Combine(directory, "project_cake_save_v3.json");
            File.WriteAllText(formal, "formal-progress-sentinel");
            using var save = new SaveService(); save.UseDemoPathForTests(path, content);
            Check(!save.HasSavedGame && !save.MigratedLegacySave && save.ResetProgress(out _), "new isolated Demo does not migrate formal progress");
            var first = content.Stages[0];
            DayPlan Plan(DemoStage stage) => stage.Plan(catalog.RecipesById, catalog.CustomersById["normal"]);
            DayResult Result(int day, int revenue, int completed) => new() { Day = day, SaleRevenue = revenue, CompletedCustomers = completed };
            save.CommitDay(Result(1, 0, 0), Plan(first), first.Config(catalog.RecipesById));
            Check(save.Data.Tianjin.HighestUnlockedDay == 1 && save.Data.Coins == 0 && save.CanEnter(StableIds.Cities.Tianjin, 1), "zero completed orders permit free retry but do not advance");
            foreach (var stage in content.Stages.Take(3))
            {
                var plan = Plan(stage); var result = Result(stage.Day, totals[stage.Day - 1], stage.ExplicitOrders.Length);
                save.CommitDay(result, plan, stage.Config(catalog.RecipesById));
                Check(save.CommitDay(result, plan, stage.Config(catalog.RecipesById)).PermanentCoinGain == 0, "duplicate successful submission is idempotent");
            }
            Check(save.Data.Coins == 139 && save.Data.UnlockedCityIds.SequenceEqual(new[] { StableIds.Cities.Tianjin })
                && !save.Data.Tianjin.Completed, "pilot completion does not grant full-city completion or Wuhan access");
            Check(save.TryPurchase("equipment:pancake_stove_lv2", catalog, out _) && save.Data.Coins == 19
                && save.Data.PurchasedStoveLevel == 2, "real upgrade uses baseline price");
            var third = content.Stages[2];
            save.CommitDay(Result(3, 65, 8), Plan(third), third.Config(catalog.RecipesById));
            Check(save.Data.Coins == 84, "same-revenue upgraded replay awards the full income");
            save.CommitDay(Result(3, 70, 8), Plan(third), third.Config(catalog.RecipesById));
            Check(save.Data.Coins == 154, "new best replay awards the full income");
            save.CommitDay(Result(3, 40, 8), Plan(third), third.Config(catalog.RecipesById));
            Check(save.Data.Coins == 194 && save.Data.Tianjin.DayBestRecords[3].TotalRevenue == 70,
                "lower-revenue replay awards full income and retains the best record");
            save.CommitDay(Result(3, 0, 0), Plan(third), third.Config(catalog.RecipesById));
            Check(save.Data.Tianjin.HighestUnlockedDay == Math.Min(4, content.CityStages(StableIds.Cities.Tianjin).Length) && save.Data.Coins == 194, "zero-order replay never regresses progress or charges admission");
            Check(save.TryRecordDemoStart(2, out _), "records the actual last-started main stage");
            save.Load();
            Check(save.ContinueDay == 2 && save.Data.PurchasedStoveLevel == 2 && save.Data.Coins == 194, "restart restores actual stage, equipment and money");
            Check(!save.CanEnter(StableIds.Cities.Xian, 1) && !save.CanEnter(StableIds.Cities.Wuhan, 1)
                && !save.CanEnter(StableIds.Cities.Tianjin, 8), "save guards all unshipped stage and city entries");
            string temporary = path + ".tmp";
            Directory.CreateDirectory(temporary);
            var retryPlan = Plan(third);
            bool failed = false;
            try { save.CommitDay(Result(3, 80, 8), retryPlan, third.Config(catalog.RecipesById)); }
            catch (IOException) { failed = true; }
            Check(failed && save.Data.Coins == 194 && !save.DemoProgress.AcceptedRuns.Contains(retryPlan.RunId), "write failure rolls back money and submission identity");
            Directory.Delete(temporary);
            save.CommitDay(Result(3, 80, 8), retryPlan, third.Config(catalog.RecipesById));
            Check(save.Data.Coins == 274, "the same failed result retries once after storage recovers");
            save.Load();
            Check(save.CommitDay(Result(3, 80, 8), retryPlan, third.Config(catalog.RecipesById)).PermanentCoinGain == 0
                && save.Data.Coins == 274, "reloaded Demo still rejects duplicate settlement");
            string corrupt = "{broken-demo-save"; File.WriteAllText(path, corrupt); save.Load();
            Check(save.HasLoadError && !save.TrySave(out _) && File.ReadAllText(path) == corrupt, "corrupt file is retained and cannot be silently overwritten");
            Check(File.ReadAllText(formal) == "formal-progress-sentinel", "formal progress stays byte-for-byte unchanged");
            string json = Godot.FileAccess.GetFileAsString(ExperienceProfile.ManifestPath);
            bool rejected = false;
            try { var invalid = System.Text.Json.Nodes.JsonNode.Parse(json)!; invalid["stages"]![0]!["arrivals"]![2] = 16; DemoCatalog.Parse(invalid.ToJsonString(), catalog.RecipesById, catalog.ProductsById, catalog.CustomersById); }
            catch (InvalidDataException) { rejected = true; }
            Check(rejected, "invalid arrival schedule fails validation");
            using var lowIncome = new SaveService(); lowIncome.UseDemoPathForTests(Path.Combine(directory, "low-income.json"), content); lowIncome.ResetProgress(out _);
            lowIncome.CommitDay(Result(1, 0, 1), Plan(first), first.Config(catalog.RecipesById));
            Check(lowIncome.ContinueDay == 2 && lowIncome.Data.Coins == 0, "one completed order unlocks and continues to next stage even with zero income");
            foreach (var s in content.Stages.Skip(1))
                lowIncome.CommitDay(Result(s.Day, 0, 1), s.Plan(catalog), s.Config(catalog.RecipesById, catalog.ProductsById));
            Check(lowIncome.Data.Coins == 0 && lowIncome.Data.Wuhan.Completed, "entire route advances with zero income and no upgrade purchase");
            using var stationFirst = new SaveService(); stationFirst.UseDemoPathForTests(Path.Combine(directory, "station-first.json"), content); stationFirst.ResetProgress(out _);
            foreach (var stage in content.Stages.Take(3)) stationFirst.CommitDay(Result(stage.Day, totals[stage.Day - 1], 1), Plan(stage), stage.Config(catalog.RecipesById));
            Check(stationFirst.TryPurchase("equipment:ingredient_station_lv2", catalog, out _) && stationFirst.Data.Coins == 79
                && stationFirst.CanEnter(StableIds.Cities.Tianjin, 3), "buying the ingredient station first remains playable at the unchanged price");
            GD.Print($"DEMO_PROFILE_SELF_TEST_OK {_checks}"); GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
}
