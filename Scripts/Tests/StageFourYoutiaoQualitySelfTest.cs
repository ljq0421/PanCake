using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class StageFourSelfTest
{
    private async Task TestYoutiaoQualityPresentation(DataCatalog catalog)
    {
        var station = new PancakeWorkstation { UseServingTray = true };
        AddChild(station);
        station.Initialize(catalog, 1, 1, 1, catalog.DaysByNumber[11]);
        var rack = (WorkstationSlotView)station.FindChild("FinishedYoutiaoArea", true, false);
        var input = (DragItem)station.FindChild("FinishedYoutiaoDrag", true, false);
        var drag = station.GetChildren().OfType<DragService>().Single();
        FryerStateMachine fryer = station.FryerMachine!;
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        foreach (YoutiaoQuality quality in new[] { YoutiaoQuality.Light, YoutiaoQuality.Golden, YoutiaoQuality.Deep })
        {
            station.ResetForDay();
            fryer.TryExecute(FryerCommand.LoadOne); fryer.TryExecute(FryerCommand.LowerBasket);
            fryer.Tick(quality == YoutiaoQuality.Light ? 3 : quality == YoutiaoQuality.Golden ? 6 : 9);
            fryer.TryExecute(FryerCommand.RaiseBasket); fryer.Tick(fryer.Level.DrainSeconds);
            Check(fryer.Inventory.TryPeek(out YoutiaoQuality stored) && stored == quality
                && rack.IngredientVisuals.Where(visual => visual.Visible).All(visual => visual.Modulate == YoutiaoPresentation.Tint(quality)),
                $"{quality} 沥油入成品架后保留实际品质颜色");
            input.TryBeginDrag();
            var preview = station.FindChild("YoutiaoQualityPreview", true, false) as TextureRect;
            Check(drag.IsDragging && preview?.Modulate == YoutiaoPresentation.Tint(quality)
                && fryer.Inventory.Count == 1, $"{quality} 拖拽预览使用队首品质且不提前扣库存");
            drag.CancelDrag();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            Check(fryer.Inventory.Count == 1 && input.TooltipText.Contains(YoutiaoPresentation.Name(quality)),
                $"{quality} 取消拖拽保留品质并提示下一根品质");

            foreach (bool internalYoutiao in new[] { false, true })
            {
                var order = Order("quality", "office_worker", 10,
                    internalYoutiao ? Pancake(StableIds.Recipes.Youtiao) : Youtiao(1));
                var progress = new OrderProgress(order);
                progress.TryAccept(internalYoutiao
                    ? new DeliveredItem(ProductKind.Pancake, StableIds.Recipes.Youtiao, PancakeQuality.Perfect, null, quality)
                    : new DeliveredItem(ProductKind.Youtiao, StableIds.Products.Youtiao, null, quality));
                DeliveryEvaluation result = new OrderEvaluator().EvaluateCompleted(progress, CustomerState.Happy, catalog.CustomersById["office_worker"]);
                bool golden = quality == YoutiaoQuality.Golden;
                Check(result.SaleRevenue == 10 && result.Tip == (golden ? 2 : 0)
                    && result.SatisfactionScore == (golden ? 100 : 85)
                    && result.Grade == (golden ? DeliveryGrade.Perfect : DeliveryGrade.Correct),
                    $"{quality}/{internalYoutiao} 单卖及煎饼内油条保留原价，按品质区分小费和评价");
                if (!golden) Check(result.Message.Contains(YoutiaoPresentation.Name(quality)) && result.Message.Contains("无小费"),
                    $"{quality}/{internalYoutiao} 结算明确说明品质与无小费原因");
            }
        }
        station.ResetForDay();
        foreach (YoutiaoQuality quality in new[] { YoutiaoQuality.Light, YoutiaoQuality.Deep, YoutiaoQuality.Golden })
            fryer.Inventory.TryStore(1, quality);
        Check(rack.VisibleIngredientVisualCount == 3 && rack.IngredientIsInsideTray(4)
            && rack.IngredientVisuals.Where(visual => visual.Visible).Select(visual => visual.Modulate).Distinct().Count() == 3,
            "混合库存同时显示三种品质颜色，均位于成品架范围内");
        foreach (YoutiaoQuality expected in new[] { YoutiaoQuality.Light, YoutiaoQuality.Deep, YoutiaoQuality.Golden })
        {
            Check(rack.IngredientVisuals.Last(visual => visual.Visible).Modulate == YoutiaoPresentation.Tint(expected),
                $"混合库存最前方显示下一根FIFO品质 {expected}");
            Check(fryer.Inventory.TryTake(out YoutiaoQuality actual) && actual == expected, "混合库存仍逐根先进先出");
        }
        Check(rack.VisibleIngredientVisualCount == 0, "混合库存取空后没有残留品质色块");
        var combo = new OrderProgress(Order("mixed", "normal", 10, Youtiao(2), SoyMilk()));
        combo.TryAccept(new DeliveredItem(ProductKind.Youtiao, StableIds.Products.Youtiao, null, YoutiaoQuality.Light));
        combo.TryAccept(new DeliveredItem(ProductKind.Youtiao, StableIds.Products.Youtiao, null, YoutiaoQuality.Deep));
        var evaluator = new OrderEvaluator();
        Check(evaluator.EvaluateCompleted(combo, CustomerState.Happy, catalog.CustomersById["normal"]).Grade == DeliveryGrade.Incomplete,
            "混合品质套餐仍等全部交齐才结算");
        combo.TryAccept(new DeliveredItem(ProductKind.SoyMilk, StableIds.Products.SoyMilk));
        DeliveryEvaluation mixed = evaluator.EvaluateCompleted(combo, CustomerState.Happy, catalog.CustomersById["normal"]);
        Check(mixed.SaleRevenue == 10 && mixed.Tip == 0 && mixed.SatisfactionScore == 85
            && mixed.Message.Contains("偏浅、偏深"), "混合品质整单仅一次按85评价结算，提示两种品质");
        station.Free();

        foreach (YoutiaoQuality quality in new[] { YoutiaoQuality.Light, YoutiaoQuality.Golden, YoutiaoQuality.Deep })
        {
            var controller = new DayController(); AddChild(controller);
            controller.TryPrepareDay(5, catalog, out _); controller.TryStartDay(out _); controller.Tick(3);
            CustomerRuntime? customer = null;
            for (int i = 0; i < 1800 && customer is null; i++)
            {
                controller.Tick(.1);
                customer = controller.CustomerQueue!.Slots.FirstOrDefault(candidate => candidate.State == CustomerState.Happy
                    && candidate.Order.Lines.Count == 1 && candidate.Order.Lines[0].ProductKind == ProductKind.Youtiao);
            }
            if (customer is null) { Fail("找到单卖油条顾客", "Day5未生成可交付顾客"); controller.Free(); continue; }
            var inventory = new YoutiaoInventory(8);
            inventory.TryStore(customer.Order.Lines[0].Quantity, quality);
            DeliveryEvaluation? delivered = null;
            for (int i = 0; i < customer.Order.Lines[0].Quantity; i++) delivered = controller.TryDeliverYoutiaoTo(customer.Id, inventory);
            var ledger = controller.Ledger!.Build();
            Check(delivered is not null && delivered.SaleRevenue == customer.Order.BasePrice
                && delivered.SatisfactionScore == (quality == YoutiaoQuality.Golden ? 100 : 85)
                && (quality == YoutiaoQuality.Golden ? delivered.Tip > 0 : delivered.Tip == 0)
                && ledger.TotalRevenue == delivered.TotalRevenue && ledger.Tips == delivered.Tip,
                $"{quality} 实际交付及账本金币按原价和品质小费准确记账");
            controller.Free();
        }
    }
}
