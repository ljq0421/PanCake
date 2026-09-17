using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Fryer;
using ProjectCake.Data;
using ProjectCake.Pancake;

namespace ProjectCake.Tests;

public partial class TianjinDayFourClosingSelfTest : Node
{
    private static void Check(bool ok, string message)
    {
        if (!ok) throw new InvalidOperationException(message);
        GD.Print("PASS " + message);
    }

    public override void _Ready()
    {
        try
        {
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            using var controller = new DayController();
            Check(catalog.Demo is not null && controller.TryPrepareDay(4, catalog, out _), "prepare Demo Tianjin Day 4");
            int finished = 0;
            controller.DayFinished += _ => finished++;
            controller.TryStartDay(out _);
            controller.Tick(DayController.OpeningDurationSeconds);
            for (int served = 0; served < 8; served++)
            {
                for (int tick = 0; tick < 300 && !controller.CustomerQueue!.Slots.Any(c => c.State == CustomerState.Happy); tick++)
                    controller.Tick(.1);
                var customer = controller.CustomerQueue!.Slots.Single(c => c.State == CustomerState.Happy);
                var line = customer.Order.Lines.Single();
                int quantity = line.Quantity;
                var inventory = new YoutiaoInventory(quantity);
                inventory.TryStore(quantity, YoutiaoQuality.Golden);
                int drags = line.ProductKind == ProductKind.Youtiao ? 1 : quantity;
                for (int item = 0; item < drags; item++)
                {
                    var result = line.ProductKind == ProductKind.Youtiao
                        ? controller.TryDeliverYoutiaoTo(customer.Id, inventory)
                        : controller.TryDeliverPreparedPancakeTo(customer.Id,
                            new PreparedPancake(PancakeQuality.Perfect, catalog.RecipesById[line.DefinitionId].ExtraIngredients.ToHashSet()), catalog, () => true);
                    Check(result.ItemAccepted && result.CompletesOrder == (item == drags - 1), "Day 4 actual order delivery");
                    Check(controller.State == DayState.Running && finished == 0, "partial orders and customer exits must finish before settlement");
                }
                if (served < 7)
                {
                    controller.Tick(.5);
                    Check(controller.State == DayState.Running && controller.CustomerQueue.HasUnscheduled,
                        "empty counter preserves future arrivals");
                }
            }
            controller.IsPaused = true;
            controller.Tick(10);
            Check(finished == 0, "pause preserves final exit");
            controller.IsPaused = false;
            controller.Tick(.44);
            Check(finished == 0, "final exit animation is preserved");
            controller.Tick(.02);
            Check(controller.State == DayState.Results && finished == 1 && controller.DayRemainingSeconds > 0,
                "8 completed customers settle without waiting for the countdown");
            var resultDay = controller.Ledger!.Build();
            Check(resultDay.CompletedCustomers == 8 && resultDay.LostCustomers == 0 && resultDay.SaleRevenue == 48,
                "all eight orders retain their revenue and completion counts");
            controller.Tick(1000);
            Check(finished == 1, "settlement fires only once");
            GD.Print("TIANJIN_DAY_FOUR_CLOSING_SELF_TEST_OK");
            GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
