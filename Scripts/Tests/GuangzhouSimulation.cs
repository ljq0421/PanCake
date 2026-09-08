using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Guangzhou;
using ProjectCake.Orders;

namespace ProjectCake.Tests;

public partial class GuangzhouSelfTest
{
    private void SimulateDays(DataCatalog catalog)
    {
        var metrics = new List<object>();
        for (int seed = 4100; seed < 4110; seed++) metrics.Add(Simulate(catalog, 9, seed, 2));
        foreach (int day in new[] { 1, 5, 8, 10, 12 }) metrics.Add(Simulate(catalog, day, 4000 + day, day < 5 ? 1 : day == 12 ? 3 : 2));
        string path = ProjectSettings.GlobalizePath("res://.godot/guangzhou-simulation.json");
        File.WriteAllText(path, System.Text.Json.JsonSerializer.Serialize(metrics, new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
    }
    private object Simulate(DataCatalog catalog, int day, int seed, int level)
    {
        var config = catalog.GetDays(StableIds.Cities.Guangzhou)[day]; int oldSeed = config.RandomSeed;
        var controller = new DayController(); AddChild(controller);
        var city = SaveService.NewGuangzhouProgress(); foreach (string id in GuangzhouRules.Equipment) city.EquipmentLevels[id] = level;
        config.RandomSeed = seed;
        try
        {
            Check(controller.TryPrepareDay(StableIds.Cities.Guangzhou, day, catalog, out _), "模拟准备成功");
            var session = new GuangzhouSession(catalog, city, config); controller.GuangzhouStockCount = session.DimSum.Count;
            controller.TryStartDay(out _);
            double wall = 0, actionLeft = 0, waitingTotal = 0; int samples = 0, maxQueue = 0, loads = 0, refills = 0;
            Action? pending = null;
            var targets = new string?[session.Trays.Count]; var starts = new double[session.Trays.Count]; var productionTimes = new List<double>();
            DayResult? result = null; controller.DayFinished += r => result = r;
            void Schedule(double seconds, Action action) { actionLeft = seconds; pending = action; }
            IReadOnlyList<CustomerRuntime> Active() => controller.CustomerQueue!.Slots.Where(c => c.State is CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry).ToArray();
            bool Needs(CustomerRuntime c, ProductKind kind, string? id = null) => c.Order.Lines.Select((l, i) => l.ProductKind == kind && (id is null || l.DefinitionId == id) && c.Progress.GetRemainingQuantity(i) > 0).Any(x => x);
            bool Refill(string id)
            {
                var stock = session.Ingredients[id];
                if (stock.Count > 0 && !stock.Refilling) return false;
                if (!stock.Refilling) Schedule(.1, () => { if (stock.TryRefill()) refills++; });
                return true;
            }
            bool Act()
            {
                var customers = Active().OrderByDescending(c => c.PatienceProgress).ToArray();
                for (int i = 0; i < session.Trays.Count; i++)
                {
                    int index = i; var tray = session.Trays[i];
                    if (tray.State != RiceRollState.Ready) continue;
                    var customer = customers.FirstOrDefault(c => Needs(c, ProductKind.RiceRoll, tray.RecipeId));
                    if (customer is null) continue;
                    var item = new DeliveredItem(ProductKind.RiceRoll, tray.RecipeId, GuangzhouQuality: tray.FoodQuality);
                    Schedule(.25, () =>
                    {
                        if (controller.TryDeliverGuangzhouTo(customer.Id, item, tray.TryTake).ItemAccepted)
                        { productionTimes.Add(wall - starts[index]); targets[index] = null; }
                    }); return true;
                }
                foreach (var id in new[] { GuangzhouRules.SiuMai, GuangzhouRules.HarGow })
                {
                    var customer = customers.FirstOrDefault(c => Needs(c, GuangzhouRules.DimSumKind(id)));
                    if (customer is null || !session.DimSum.TryPeek(id, out var quality)) continue;
                    Schedule(.2, () => controller.TryDeliverGuangzhouTo(customer.Id, new(GuangzhouRules.DimSumKind(id), id, GuangzhouQuality: new(true, DimSum: quality)), () => session.DimSum.TryTake(id))); return true;
                }
                var teaCustomer = customers.FirstOrDefault(c => Needs(c, ProductKind.MorningTea));
                if (teaCustomer is not null && session.Tea?.HasCup == true)
                { Schedule(.2, () => controller.TryDeliverGuangzhouTo(teaCustomer.Id, new(ProductKind.MorningTea, GuangzhouRules.Tea, GuangzhouQuality: new(true)), session.Tea.TryTakeCup)); return true; }
                for (int i = 0; i < session.Trays.Count; i++)
                {
                    var tray = session.Trays[i];
                    if (tray.Cooked) { Schedule(.25, () => tray.TryPull()); return true; }
                }
                if (session.Cabinet is { } cabinet)
                {
                    for (int i = 0; i < cabinet.Baskets.Count; i++)
                    {
                        int slot = i; var basket = cabinet.Baskets[i];
                        if (basket.Cooked && session.DimSum.Count(basket.ProductId) < 4)
                        { Schedule(.18, () => cabinet.TryStock(slot, session.DimSum)); return true; }
                    }
                    foreach (string id in config.Guangzhou!.DimSumWeights.Keys)
                    {
                        int desired = Math.Min(4, Math.Max(1, customers.Count(c => Needs(c, GuangzhouRules.DimSumKind(id)))));
                        int available = session.DimSum.Count(id) + cabinet.Baskets.Count(b => b.ProductId == id);
                        int empty = Enumerable.Range(0, cabinet.Baskets.Count).FirstOrDefault(i => cabinet.Baskets[i].Empty, -1);
                        if (available < desired && empty >= 0) { Schedule(.18, () => { if (session.LoadBasket(empty, id)) loads++; }); return true; }
                    }
                }
                if (teaCustomer is not null && session.Tea is { } tea && !tea.HasCup && tea.PourRemaining == 0)
                {
                    if (tea.Stock.Count > 0 && !tea.Stock.Refilling) { Schedule(.1, () => tea.TryPour()); return true; }
                    if (!tea.Stock.Refilling) { Schedule(.1, () => tea.Stock.TryRefill()); return true; }
                }
                for (int i = 0; i < session.Trays.Count; i++)
                {
                    int index = i; var tray = session.Trays[i];
                    if (tray.State == RiceRollState.Rolling)
                    {
                        if (tray.RollProgress < 1) Schedule(1.35, () => tray.Roll(.9)); else Schedule(.2, () => tray.TryCut());
                        return true;
                    }
                    if (tray.State == RiceRollState.Cut)
                    {
                        if (Refill(GuangzhouRules.Sauce)) { if (pending is not null) return true; continue; }
                        Schedule(.3, () => tray.TrySauce(session.Ingredients[GuangzhouRules.Sauce])); return true;
                    }
                    if (tray.State == RiceRollState.Spreading)
                    {
                        if (tray.SpreadProgress < 1) { Schedule(1.1, () => tray.Spread(.8)); return true; }
                        string? missing = catalog.RecipesById[targets[i]!].ExtraIngredients.FirstOrDefault(id => !tray.Ingredients.Contains(id));
                        if (missing is not null)
                        {
                            if (Refill(missing)) { if (pending is not null) return true; continue; }
                            Schedule(.18, () => session.AddIngredient(index, missing)); return true;
                        }
                        Schedule(.2, () => tray.TryPush()); return true;
                    }
                }
                for (int i = 0; i < session.Trays.Count; i++)
                {
                    int index = i; var tray = session.Trays[i]; if (tray.State != RiceRollState.Empty) continue;
                    var remaining = customers.SelectMany(c => c.Order.Lines.Select((l, n) => (Line: l, Remaining: c.Progress.GetRemainingQuantity(n))))
                        .Where(x => x.Line.ProductKind == ProductKind.RiceRoll).GroupBy(x => x.Line.DefinitionId);
                    string? recipe = remaining.FirstOrDefault(g => g.Sum(x => x.Remaining) > targets.Count(t => t == g.Key))?.Key;
                    if (recipe is null) continue;
                    if (Refill(GuangzhouRules.Batter)) { if (pending is not null) return true; continue; }
                    targets[i] = recipe; starts[i] = wall;
                    Schedule(.25, () => tray.TryPour(session.Ingredients[GuangzhouRules.Batter])); return true;
                }
                return false;
            }
            while (result is null && wall < config.DurationSeconds + 25)
            {
                const double step = .05; wall += step; controller.Tick(step);
                if (controller.State is not (DayState.Running or DayState.Closing)) continue;
                session.Tick(step); samples++; maxQueue = Math.Max(maxQueue, controller.CustomerQueue!.Slots.Count); waitingTotal += Active().Count;
                if (pending is not null)
                {
                    actionLeft -= step;
                    if (actionLeft <= 1e-8) { var callback = pending; pending = null; callback(); }
                }
                else Act();
            }
            Check(result is not null && result.CompletedCustomers + result.LostCustomers == config.CustomerCount && maxQueue <= 4, "模拟全日账目与队列守恒");
            var output = new { day, seed, equipmentLevel = level, completed = result?.CompletedCustomers, lost = result?.LostCustomers,
                perfect = result?.PerfectOrders, satisfaction = result?.Satisfaction, revenue = result?.TotalRevenue, maxQueue,
                meanWaiting = Math.Round(waitingTotal / Math.Max(1, samples), 2), meanRiceRollSeconds = productionTimes.Count == 0 ? 0 : Math.Round(productionTimes.Average(), 2), basketsLoaded = loads, ingredientRefills = refills };
            GD.Print("GUANGZHOU_SIM " + System.Text.Json.JsonSerializer.Serialize(output)); return output;
        }
        finally { config.RandomSeed = oldSeed; controller.QueueFree(); }
    }
}
