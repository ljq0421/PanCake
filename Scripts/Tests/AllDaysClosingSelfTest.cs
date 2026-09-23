using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Inventory;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class AllDaysClosingSelfTest : Node
{
    private static void Require(bool ok, string message)
    { if (!ok) throw new InvalidOperationException(message); }

    public override void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            Require(catalog.IsValid, "valid catalog");
            CheckEmptyShop(catalog);
            int days = 0;
            foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou })
                foreach (int day in catalog.GetDays(city).Keys)
                {
                    CheckDay(catalog, city, day, false);
                    CheckDay(catalog, city, day, true);
                    days++;
                }
            // The standalone teaching example must never produce a business settlement.
            var lesson = new DayController();
            AddChild(lesson);
            Require(lesson.TryPrepareTutorial(StableIds.Cities.Tianjin, 1, catalog, out _), "prepare lesson");
            lesson.TryStartDay(out _); lesson.Tick(3); lesson.Tick(.4);
            lesson.CustomerQueue!.ForceLoseAll(); lesson.Tick(1000);
            Require(lesson.TutorialActive && lesson.State == DayState.Running && lesson.DayElapsedSeconds == 0,
                "isolated teaching remains protected even with an empty queue");
            lesson.Free();
            if (!ExperienceProfile.IsDemo)
            {
                var yangzhou = YangzhouCatalog.Load();
                foreach (var day in yangzhou.Days)
                {
                    var played = YangzhouSelfTest.Play(yangzhou, day.Day, 3, 3, productionAdvancesBusiness: false);
                    Require(played.Phase == YangzhouPhase.Results && played.Waiting.Count == 0
                        && played.Result().Completed + played.Result().Lost == day.Customers,
                        $"Yangzhou {day.Day} whole-tray production resolves every customer");
                    Require(played.Elapsed < day.Duration, $"Yangzhou {day.Day} avoids empty countdown waiting");
                    if (day.Day != 1) CheckYangzhouLoss(yangzhou, day.Day);
                    days++;
                    GD.Print($"PASS Yangzhou Day {day.Day} whole-tray early closing");
                }
            }
            GD.Print($"ALL_DAYS_CLOSING_SELF_TEST_OK days={days} demo={ExperienceProfile.IsDemo}");
            GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }

    private void CheckDay(DataCatalog catalog, string city, int day, bool withLoss)
    {
        var controller = new DayController();
        AddChild(controller);
        Require(controller.TryPrepareDay(city, day, catalog, out _), $"prepare {city} {day}");
        int finished = 0;
        controller.DayFinished += _ => finished++;
        Require(controller.TryStartDay(out _) && controller.State == DayState.Running
            && controller.DayElapsedSeconds == 0 && controller.OpeningRemainingSeconds == 0,
            $"{city} {day} starts immediately without spending business time");
        bool lostOne = false;
        for (int tick = 0; tick < 20000 && controller.State != DayState.Results; tick++)
        {
            var queue = controller.CustomerQueue!;
            bool unresolvedBefore = !queue.IsResolved;
            controller.Tick(.05);
            Require(controller.State != DayState.Running || !queue.HasUnscheduled
                || queue.Slots.Count > 0 || queue.DoorQueue.Count > 0,
                $"{city} {day} immediately refills an empty shop");
            if (controller.State == DayState.Results)
            {
                Require(unresolvedBefore && queue.IsResolved, "settles on resolution, not on a later empty countdown tick");
                break;
            }
            foreach (var customer in queue.Slots.Where(c => c.State is CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry).ToArray())
            {
                if (withLoss && !lostOne)
                {
                    customer.WaitSeconds = customer.LeaveAtSeconds;
                    lostOne = true;
                    continue;
                }
                for (int index = 0; index < customer.Order.Lines.Count; index++)
                {
                    var line = customer.Order.Lines[index];
                    int count = customer.Progress.GetRemainingQuantity(index);
                    for (int item = 0; item < count; item++)
                    {
                        if (customer.Progress.GetRemainingQuantity(index) == 0) break;
                        var evaluation = Deliver(controller, catalog, customer.Id, line);
                        Require(evaluation.ItemAccepted, $"{city} {day} rejected {line.DefinitionId}: {evaluation.Message}");
                        Require(controller.State != DayState.Results && finished == 0, "delivery waits for the final exit");
                    }
                }
            }
            if (queue.HasUnscheduled || queue.DoorQueue.Count > 0 || queue.Slots.Count > 0)
                Require(finished == 0, "future, queued and on-screen guests prevent settlement");
        }
        var result = controller.Ledger!.Build();
        Require(controller.State == DayState.Results && finished == 1 && controller.CustomerQueue!.IsResolved,
            $"{city} {day} resolves and settles once");
        Require(result.CompletedCustomers + result.LostCustomers == controller.CurrentPlan!.Customers.Count
            && result.LostCustomers == (withLoss ? 1 : 0), $"{city} {day} preserves completed/lost accounting");
        double lastArrival = controller.CurrentPlan.Customers.Max(c => c.ArrivalTime);
        if (lastArrival + CustomerQueue.EnterDurationSeconds + CustomerQueue.LeaveDurationSeconds + .15 < controller.CurrentConfig!.DurationSeconds)
            Require(controller.DayRemainingSeconds > 0, $"{city} {day} closes early withLoss={withLoss}");
        else
            Require(controller.ClosingRemainingSeconds > DayController.ClosingDurationSeconds - 1,
                $"{city} {day} late arrival settles immediately after its exit");
        controller.Tick(1000);
        Require(finished == 1, "further frames do not repeat settlement");
        GD.Print($"PASS {city} Day {day} closes on final exit withLoss={withLoss}");
        controller.Free();
    }

    private void CheckEmptyShop(DataCatalog catalog)
    {
        foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou })
        {
            if (!ExperienceProfile.IsCityAvailable(city, ExperienceProfile.IsDemo)) continue;
            var controller = new DayController(); AddChild(controller);
            Require(controller.TryPrepareDay(city, 6, catalog, out _), "prepare empty-shop fixture");
            var plan = new DayPlan { Customers = controller.CurrentPlan!.Customers.Take(3).Select((c, i) => new PlannedCustomer
            {
                CustomerId = c.CustomerId, CustomerTypeId = c.CustomerTypeId,
                ArrivalTime = 100 + i * 100, Order = c.Order,
            }).ToArray() };
            var queue = new CustomerQueue(plan, catalog.CustomersById, 1, 5);
            int resolved = 0; queue.ResolveBeforeArrival = (c, _) => { resolved++; return c.Order; };
            queue.Tick(0, 0, false);
            Require(queue.Slots.Count == 0, "closed arrivals do not refill");
            queue.Tick(0, 0, true);
            Require(queue.Slots.Count == 1 && resolved == 1, "empty shop immediately admits exactly one guest");
            var first = queue.Slots[0];
            queue.Tick(.4, .4, true);
            Require(queue.Slots.Count == 1 && resolved == 1, "occupied shop keeps future schedule");
            Require(queue.TryMarkServed(first.Id), "serve first guest");
            queue.Tick(.5, .1, true);
            Require(queue.Slots.Count == 1 && queue.Slots[0] == first, "exit animation blocks refill");
            queue.Tick(.9, .4, true);
            Require(queue.Slots.Count == 1 && queue.Slots[0].Id == plan.Customers[1].CustomerId && resolved == 2,
                "same tick as final exit admits next guest and resolves its order once");
            queue.Tick(1.3, .4, true);
            queue.Slots[0].WaitSeconds = queue.Slots[0].LeaveAtSeconds;
            queue.Tick(1.4, .1, true);
            queue.Tick(2, .6, true);
            Require(queue.Slots.Count == 1 && queue.Slots[0].Id == plan.Customers[2].CustomerId && resolved == 3,
                "timeout exit also immediately refills");
            Require(plan.Customers[1].ArrivalTime == 200, "planned schedule stays intact");
            controller.Free();
        }
    }

    private static DeliveryEvaluation Deliver(DayController c, DataCatalog catalog, string id, OrderLineData line)
    {
        if (line.ProductKind == ProductKind.Pancake)
            return c.TryDeliverPreparedPancakeTo(id, new PreparedPancake(PancakeQuality.Perfect,
                catalog.RecipesById[line.DefinitionId].ExtraIngredients.ToHashSet(), YoutiaoQuality.Golden,
                line.Sauce == SaucePreference.Light ? .25 : line.Sauce == SaucePreference.Extra ? 1.25 : 1), catalog, () => true);
        if (line.ProductKind == ProductKind.Youtiao)
        {
            var stock = new YoutiaoInventory(1); stock.TryStore(1, YoutiaoQuality.Golden);
            return c.TryDeliverYoutiaoTo(id, stock);
        }
        if (line.ProductKind == ProductKind.SoyMilk) return c.TryDeliverSoyMilkTo(id, new SoyMilkTrayRuntime());
        var food = new DeliveredItem(line.ProductKind, line.DefinitionId, WuhanQuality: WuhanFoodQuality.MixedComplete,
            BunQuality: ProjectCake.Xian.BunQuality.Golden, MeatPortions: ProjectCake.Xian.XianRules.Meat(line.DefinitionId),
            HasJuice: ProjectCake.Xian.XianRules.Juice(line.DefinitionId),
            GuangzhouQuality: new(true, ProjectCake.Guangzhou.RiceRollQuality.Perfect, false, ProjectCake.Guangzhou.DimSumQuality.Perfect));
        return c.CurrentConfig!.CityId switch
        {
            StableIds.Cities.Wuhan => c.TryDeliverWuhanTo(id, food, () => true),
            StableIds.Cities.Xian => c.TryDeliverXianTo(id, food, () => true),
            _ => c.TryDeliverGuangzhouTo(id, food, () => true),
        };
    }

    private static void CheckYangzhouLoss(YangzhouCatalog catalog, int day)
    {
        var session = new YangzhouSession(catalog, day, 3, 3);
        session.Tick(5);
        for (int tick = 0; tick < 10000 && session.Phase != YangzhouPhase.Results; tick++)
        {
            foreach (var customer in session.Waiting) customer.Tick(customer.Patience, false);
            session.Tick(.05);
            Require(session.Phase != YangzhouPhase.Running || session.Waiting.Count > 0,
                "Yangzhou immediately refills after timeout while customers remain");
        }
        var result = session.Result();
        Require(session.Phase == YangzhouPhase.Results && session.Elapsed < session.Day.Duration
            && result.Lost == result.Planned && result.Completed == 0 && result.Revenue == 0,
            $"Yangzhou {day} all-lost day closes early without revenue");
        Require(session.BusinessRecords.All(r => r.Lost && !r.Unreceived), "lost guests all actually arrived");
        session.Tick(1000);
        Require(session.Result() == result, "Yangzhou result remains stable");
    }
}
