using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Inventory;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class StageFourSelfTest
{
    private void TestCookingAndPatienceFixes(DataCatalog catalog)
    {
        var machine = new PancakeStateMachine(catalog.StovesByLevel[1]);
        Spread();
        machine.Tick(1);
        Check(machine.Runtime.State == PancakeState.SideACooking && !machine.Runtime.HasEgg
            && Close(machine.Runtime.CookingSeconds, 1), "不放鸡蛋，摊匀后立即加热");
        int eggs = 0;
        Check(machine.TryExecute(PancakeCommand.AddEgg, tryConsume: _ => { eggs++; return true; }).Success
            && Close(machine.Runtime.CookingSeconds, 1), "中途加蛋不重置火候计时");
        Check(!machine.TryExecute(PancakeCommand.AddEgg, tryConsume: _ => { eggs++; return true; }).Success
            && eggs == 1, "重复打蛋不扣库存");
        machine.Tick(3.3);
        Check(machine.Runtime.Quality == PancakeQuality.Overdone, "加蛋后保留已累计的偏焦判定");
        machine.TryExecute(PancakeCommand.Discard);
        Spread();
        machine.Tick(machine.Stove.SideABurnSeconds);
        Check(machine.Runtime.State == PancakeState.Burnt, "未打蛋的饼仍会烧焦");
        machine.TryExecute(PancakeCommand.Discard);
        Spread();
        machine.Tick(machine.Stove.SideAReadySeconds);
        Check(machine.TryExecute(PancakeCommand.Flip).Success && !machine.Runtime.HasEgg, "无蛋煎饼可以正常翻面");
        Check(machine.TryExecute(PancakeCommand.BeginSauce).Success && machine.Runtime.CookingSeconds == 0,
            "翻面后零等待即可加酱");
        machine.TryExecute(PancakeCommand.CompleteSauce);
        machine.TryExecute(PancakeCommand.Fold);
        Check(machine.TryExecute(PancakeCommand.Bag).Success && machine.TryGetPrepared(out _), "无蛋煎饼可以折叠装袋出餐");

        var controller = CreateFixController(catalog);
        CustomerRuntime customer = controller.CustomerQueue!.Slots.First();
        customer.WaitSeconds = customer.LeaveAtSeconds * .7;
        customer.Tick(0);
        var soy = new SoyMilkTrayRuntime();
        Check(controller.TryDeliverSoyMilkTo(customer.Id, soy).ItemAccepted
            && Close(customer.PatienceProgress, .55) && customer.State == CustomerState.Normal,
            "交付正确商品恢复15%耐心且立即更新顾客表情");
        double wait = customer.WaitSeconds;
        int stock = soy.Quantity;
        Check(!controller.TryDeliverSoyMilkTo(customer.Id, soy).ItemAccepted && soy.Quantity == stock
            && Close(customer.WaitSeconds, wait), "重复交付不恢复耐心也不扣库存");
        var wrong = new PancakeStateMachine(catalog.StovesByLevel[2]);
        MakeBagged(wrong, catalog.RecipesById[StableIds.Recipes.Crispy]);
        Check(controller.TryDeliverPancakeTo(customer.Id, wrong, catalog).ItemAccepted
            && Close(customer.WaitSeconds, wait), "错配煎饼交付不恢复耐心");
        var correct = new PancakeStateMachine(catalog.StovesByLevel[2]);
        MakeBagged(correct, catalog.RecipesById[StableIds.Recipes.Ham]);
        customer.WaitSeconds = 1;
        Check(controller.TryDeliverPancakeTo(customer.Id, correct, catalog).CompletesOrder
            && customer.WaitSeconds == 0, "恢复耐心最多到满值，整单仍正常结算");
        controller.QueueFree();

        void Spread()
        {
            machine.TryExecute(PancakeCommand.PlaceBatter);
            machine.TryExecute(PancakeCommand.BeginSpread);
            machine.TryExecute(PancakeCommand.CompleteSpread);
        }
    }

    private DayController CreateFixController(DataCatalog catalog)
    {
        var controller = new DayController(); AddChild(controller);
        controller.TryPrepareDay(15, catalog, out _);
        var first = controller.CurrentPlan!.Customers[0];
        first.Order = new OrderData
        {
            OrderId = "gameplay-fix-order", CustomerTypeId = first.CustomerTypeId,
            Lines = new[] { new OrderLineData(ProductKind.Pancake, StableIds.Recipes.Basic, 1),
                new OrderLineData(ProductKind.Pancake, StableIds.Recipes.Ham, 1),
                new OrderLineData(ProductKind.SoyMilk, StableIds.Products.SoyMilk, 1) }, BasePrice = 20,
        };
        controller.TryStartDay(out _); controller.Tick(3);
        controller.Tick(first.ArrivalTime + .01);
        controller.CustomerQueue!.Tick(controller.DayElapsedSeconds, CustomerQueue.EnterDurationSeconds, false);
        return controller;
    }

    private async Task TestMultiPancakeTray(DataCatalog catalog)
    {
        var station = new PancakeWorkstation { UseServingTray = true, DirectCustomerDelivery = true, Theme = TianjinUi.CreateTheme() };
        AddChild(station);
        station.Initialize(catalog, 2, 1, 0, catalog.DaysByNumber[15]);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        MakeBagged(station.Machine, catalog.RecipesById[StableIds.Recipes.Basic]); station.Tick(.3);
        MakeBagged(station.Machine, catalog.RecipesById[StableIds.Recipes.Ham]); station.Tick(.3);
        Check(station.PancakeTray.Count == 2 && station.Machine.Runtime.State == PancakeState.Empty,
            "托盘有成品时可连续完成第二张，炉面自动腾空");
        station.Machine.TryExecute(PancakeCommand.PlaceBatter);
        station.Machine.TryExecute(PancakeCommand.BeginSpread);
        station.Machine.TryExecute(PancakeCommand.CompleteSpread);
        station.Tick(.5);
        var next = (Button)station.FindChild("NextPancake", true, false);
        next.EmitSignal(Button.SignalName.Pressed);
        Check(station.PancakeTray.Selected?.ExtraIngredients.Contains(StableIds.Ingredients.Ham) == true
            && ((Control)station.FindChild("FinishedPancakeDrag", true, false)).TooltipText.Contains("火腿"),
            "切换成品后配料提示指向第二张煎饼");
        var drag = station.GetChildren().OfType<DragService>().Single();
        drag.BeginDrag(station, "finished_pancake", "成品", Colors.White);
        next.EmitSignal(Button.SignalName.Pressed);
        Check(station.PancakeTray.SelectedIndex == 1, "拖动过程中不切换待交付成品");
        drag.CancelDrag();
        var controller = CreateFixController(catalog);
        CustomerRuntime customer = controller.CustomerQueue!.Slots.First();
        Check(station.DeliverToCustomer("finished_pancake", () => station.DeliverPancakeTo(controller, customer.Id, catalog).ItemAccepted)
            && station.PancakeTray.Count == 1 && customer.Progress.GetDeliveredQuantity(1) == 1
            && station.Machine.Runtime.State == PancakeState.SideACooking && Close(station.Machine.Runtime.CookingSeconds, .5),
            "交付选中的第二张成品不影响炉面第三张煎饼和其加热进度");
        var trash = (DropZone)station.FindChild("TrashZone", true, false);
        using (var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true })
            ((DragItem)station.FindChild("FinishedPancakeDrag", true, false))._GuiInput(press);
        using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = trash.GetGlobalRect().GetCenter() })
            drag._Input(release);
        await WaitForAnimation(.4);
        Check(station.PancakeTray.Count == 0 && station.Machine.Runtime.State == PancakeState.SideACooking,
            "丢弃托盘成品不清掉炉面新饼");
        station.Machine.TryExecute(PancakeCommand.AddEgg);
        station.Machine.Tick(station.Machine.Stove.SideAReadySeconds);
        station.Machine.TryExecute(PancakeCommand.Flip);
        int sauce = station.Inventory.GetQuantity(StableIds.Ingredients.Sauce);
        var sauceInput = (Button)station.FindChild("IngredientInput_sauce", true, false);
        var stroke = (StrokeInteractor)station.FindChild("PancakeStrokeInput", true, false);
        EllipseGeometry geometry = stroke.ResolveSpreadGeometry!();
        using (var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = geometry.Center })
            stroke._GuiInput(press);
        Check(station.Machine.Runtime.State == PancakeState.SideBCooking, "尚未取刷时点击饼面不会自动刷酱");
        sauceInput.EmitSignal(Button.SignalName.Pressed);
        Check(station.Machine.Runtime.State == PancakeState.Saucing && station.Machine.Runtime.SauceCoverage == 0
            && !station.Machine.Runtime.HasSauce && station.Machine.Runtime.CookingSeconds == 0
            && station.Inventory.GetQuantity(StableIds.Ingredients.Sauce) == sauce && stroke.IsToolHeld?.Invoke() == true,
            "翻面后零等待点击酱罐只拿刷子，不自动上酱或扣库存");
        using (var hover = new InputEventMouseMotion { Position = geometry.Center }) stroke._GuiInput(hover);
        Check(station.Machine.Runtime.SauceCoverage == 0, "手持酱刷悬停不增加刷酱进度");
        using (var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = geometry.Center })
            stroke._GuiInput(press);
        using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = geometry.Center })
            stroke._GuiInput(release);
        double partial = station.Machine.Runtime.SauceCoverage;
        sauceInput.EmitSignal(Button.SignalName.Pressed);
        Check(partial > 0 && partial < 1 && station.Machine.Runtime.SauceCoverage == partial
            && !station.Machine.TryExecute(PancakeCommand.Fold).Success, "重复取刷保留部分覆盖，尚未刷匀不能折叠");
        foreach (float radius in new[] { .375f, .625f, .875f })
        {
            Vector2 start = geometry.Center + new Vector2(geometry.Radii.X * radius, 0);
            using (var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = start })
                stroke._GuiInput(press);
            for (int step = 1; step <= 32 && station.Machine.Runtime.State == PancakeState.Saucing; step++)
            {
                float angle = Mathf.Tau * step / 32;
                Vector2 point = geometry.Center + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * geometry.Radii * radius;
                using var motion = new InputEventMouseMotion { Position = point, ButtonMask = MouseButtonMask.Left };
                stroke._GuiInput(motion);
            }
            using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left }) stroke._GuiInput(release);
            if (station.Machine.Runtime.State == PancakeState.Sauced) break;
        }
        Check(station.Machine.Runtime.State == PancakeState.Sauced && station.Machine.Runtime.SauceCoverage == 1.5
            && station.Inventory.GetQuantity(StableIds.Ingredients.Sauce) == sauce && stroke.IsToolHeld?.Invoke() == false,
            "在饼面实际划动达到150%自动收刷，无限酱料不扣库存");
        station.ResetForDay();
        Check(station.PancakeTray.Count == 0 && !station.IsTransferringBag, "重开清空托盘和装袋动画");
        station.QueueFree(); controller.QueueFree();
    }
}
