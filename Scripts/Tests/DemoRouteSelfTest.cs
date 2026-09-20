using System.Text.Json;
using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
namespace ProjectCake.Tests;

public partial class DemoRouteSelfTest : Node
{
    private int _checks;
    private void Check(bool ok, string message)
    { if (!ok) throw new Exception(message); _checks++; GD.Print("PASS " + message); }
    public override void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            Check(ExperienceProfile.IsDemo && catalog.IsValid, "shared content without pilot runtime catalog");
            string dir = ProjectSettings.GlobalizePath("user://demo-qa-artifacts/route-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(dir); string path = Path.Combine(dir, "demo.json");
            var save = GetNode<SaveService>("/root/SaveService"); save.UseDemoPathForTests(path);
            Check(save.ResetProgress(out _), "new route");
            var formal = new SaveService(); formal.UsePathForTests(Path.Combine(dir, "formal.json")); formal.ResetProgress(out _);
            var controller = new DayController();
            string CityState(CityProgressData city)
            {
                var json = System.Text.Json.Nodes.JsonNode.Parse(JsonSerializer.Serialize(city))!;
                json.AsObject().Remove("LastDayPlan"); return json.ToJsonString();
            }
            int days = 0;
            foreach (var (city, folder) in new[] { (StableIds.Cities.Tianjin, "Tianjin"), (StableIds.Cities.Wuhan, "Wuhan") })
            for (int day = 1; day <= SaveService.ChapterDays(city); day++)
            {
                Check(save.CanEnter(city, day), $"{city}/{day} unlocked by shared progression");
                Check(controller.TryPrepareDay(city, day, catalog, out _), "prepare shared day");
                var config = controller.CurrentConfig!;
                var source = new DayConfigLoader().LoadFile($"res://Data/Days/{folder}/day_{day:00}.json").Config!;
                Check(JsonSerializer.Serialize(config) == JsonSerializer.Serialize(source), "exact formal day config");
                var expected = new OrderGenerator().Generate(source, catalog.RecipesById, catalog.ProductsById, catalog.CustomersById);
                Check(JsonSerializer.Serialize(controller.CurrentPlan!.Customers) == JsonSerializer.Serialize(expected.Customers), "same seeded arrivals, customers, patience and order lines");
                Check(save.ApplyStartUnlocks(config, out _) && formal.ApplyStartUnlocks(config, out _), "same start unlocks");
                if (day == SaveService.ChapterDays(city))
                {
                    var empty = new DayResult { Day = day };
                    var failed = save.CommitDay(empty, new DayPlan { Day = day }, config);
                    Check(failed.EarnedStars == 0 && !save.Data.GetCity(city).Completed, "zero-star last day does not finish chapter");
                }
                var result = new DayResult { Day = day, CompletedCustomers = config.CustomerCount, PerfectOrders = config.CustomerCount, Satisfaction = 100, SaleRevenue = 100 };
                var actual = save.CommitDay(result, controller.CurrentPlan!, config);
                var reference = formal.CommitDay(result, expected, source);
                Check(actual.EarnedStars == reference.EarnedStars && actual.NewChapterCompletion == reference.NewChapterCompletion
                    && CityState(save.Data.GetCity(city)) == CityState(formal.Data.GetCity(city)),
                    "shared settlement and complete city state match formal");
                foreach (var upgrade in save.Data.GetCity(city).UnlockedContentIds.Where(id => id.StartsWith("equipment:") && (id.EndsWith("_lv2") || id.EndsWith("_lv3"))).OrderBy(id => id).ToArray())
                {
                    save.Data.Coins = formal.Data.Coins = 10000;
                    bool bought = save.TryPurchase(city, upgrade, catalog, out _);
                    bool other = formal.TryPurchase(city, upgrade, catalog, out _);
                    Check(bought == other && save.Data.Coins == formal.Data.Coins, "same upgrade eligibility and price " + upgrade);
                }
                Check(save.TrySave(out _), "persist day"); save.Load();
                Check(!save.HasLoadError && save.Data.GetCity(city).DayBestRecords.ContainsKey(day), "day history survives restart");
                days++;
            }
            Check(days == 27 && save.Data.Tianjin.Completed && save.Data.Wuhan.Completed, "both full chapters completed");
            Check(save.Data.Tianjin.EquipmentLevels["pancake_stove"] == 3 && save.Data.Wuhan.EquipmentLevels["noodle_cooker"] == 3
                && save.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"] == formal.Data.Wuhan.EquipmentLevels["egg_rice_wine_station"], "full equipment and current formal product availability match");
            foreach (var city in new[] { StableIds.Cities.Xian, StableIds.Cities.Guangzhou, StableIds.Cities.Yangzhou })
                Check(!save.CanEnter(city, 1) && !save.Data.UnlockedCityIds.Contains(city) && !controller.TryPrepareDay(city, 1, catalog, out _), "future city blocked " + city);
            catalog.TryGetDay(1, out var first);
            int coins = save.Data.Coins;
            var replay = new DayPlan { Day = 1 };
            save.CommitDay(new() { Day = 1, SaleRevenue = 7 }, replay, first);
            save.CommitDay(new() { Day = 1, SaleRevenue = 7 }, replay, first);
            Check(save.Data.Coins == coins + 7 && save.Data.Tianjin.Completed, "replay credits full revenue once and preserves chapter");
            formal.Free(); controller.Free();
            GD.Print($"DEMO_ROUTE_SELF_TEST_OK {_checks}"); GetTree().Quit();
        }
        catch (Exception ex) { GD.PushError(ex.ToString()); GetTree().Quit(1); }
    }
}
