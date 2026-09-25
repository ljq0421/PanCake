using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Inventory;
using ProjectCake.UI;
using ProjectCake.Customers;
using ProjectCake.Fryer;
using ProjectCake.Orders;

namespace ProjectCake.Tests;

public partial class StageFourSelfTest
{
    private async Task TestCoinPayments(DataCatalog catalog)
    {
        var save = new SaveService(); AddChild(save);
        string savePath = $"user://coin-payments-{Guid.NewGuid():N}.json";
        save.UsePathForTests(savePath);
        var controller = new DayController(); AddChild(controller);
        var screen = ProjectCake.Core.SceneFactory.Instantiate<TianjinDayScreen>("res://Scenes/Gameplay/TianjinDayScreen.tscn"); AddChild(screen);
        screen.ConnectController(controller);
        screen.SetProcess(false);
        screen.Initialize(catalog, save, controller, 11);
        screen.BeginDay(); controller.Tick(3);
        for (int i = 0; i < 900 && controller.CustomerQueue!.Slots.Count < 3; i++)
        {
            controller.Tick(.1);
            foreach (CustomerRuntime customer in controller.CustomerQueue.Slots) customer.WaitSeconds = 0;
        }
        controller.Tick(CustomerQueue.EnterDurationSeconds);
        screen.RefreshForCapture(true);
        var station = screen.GetChildren().OfType<PancakeWorkstation>().Single();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        foreach (CustomerRuntime customer in controller.CustomerQueue!.Slots.Take(3).ToArray())
        {
            bool reduceMotion = customer.SlotIndex == 2;
            Variant originalMotion = ProjectSettings.GetSetting("accessibility/reduce_motion", false);
            if (reduceMotion) ProjectSettings.SetSetting("accessibility/reduce_motion", true);
            var zone = (DropZone)screen.FindChild($"CustomerDropZone{customer.SlotIndex + 1}", true, false);
            int before = controller.Ledger!.Build().TotalRevenue;
            int flightsBefore = screen.PaymentCoins.Count;
            Check(!zone.TryAccept("invalid_product") && controller.Ledger.Build().TotalRevenue == before
                && screen.PaymentCoins.Count == flightsBefore, "拒绝交付不记账也不产生金币动画");
            for (int i = 0; i < customer.Order.Lines.Count; i++)
            {
                OrderLineData line = customer.Order.Lines[i];
                for (int n = 0; n < line.Quantity; n++)
                {
                    string payload;
                    if (line.ProductKind == ProductKind.Pancake)
                    {
                        MakeBagged(station.Machine, catalog.RecipesById[line.DefinitionId]);
                        station.Tick(.3);
                        payload = "finished_pancake";
                    }
                    else if (line.ProductKind == ProductKind.Youtiao)
                    {
                        station.FryerMachine!.Inventory.TryStore(1, YoutiaoQuality.Golden);
                        payload = "stored_youtiao";
                    }
                    else { station.SoyMilkTray!.Tick(.3); payload = "soy_milk_cup"; }
                    Check(zone.TryAccept(payload), "通过顾客实际交付区域接收商品", $"slot={customer.SlotIndex}; state={customer.State}; payload={payload}");
                    screen.RefreshForCapture(true);
                    if (!customer.Progress.IsComplete)
                        Check(controller.Ledger.Build().TotalRevenue == before && screen.PaymentCoins.Count == flightsBefore,
                            "套餐部分交付不记账也不产生金币");
                }
            }
            int revenue = controller.Ledger.Build().TotalRevenue;
            Check(revenue > before && !station.CoinTray!.IsVisibleInTree()
                && screen.PaymentCoins.Count == flightsBefore + (reduceMotion ? 0 : 3),
                reduceMotion ? "减少动态效果时直接入账，不播放金币飞行" : "完成订单准确入账，仅播放一组挂件付款动画");
            ProjectSettings.SetSetting("accessibility/reduce_motion", originalMotion);
        }
        await WaitForAnimation(.68);
        Vector2 target = TianjinWorkbenchLayout.CashSlot;
        Check(screen.PaymentCoins.Count > 0 && screen.PaymentCoins.All(coin => coin.Position.DistanceTo(target - new Vector2(19, 19)) < 60),
            "付款金币飞向挂件投币口");
        screen._Notification((int)NotificationApplicationFocusOut);
        Check(screen.PaymentCoins.Count == 0, "失焦清理付款动画");
        screen._Notification((int)NotificationApplicationFocusIn);
        int ledgerRevenue = controller.Ledger!.Build().TotalRevenue;
        await WaitForAnimation(.5);
        Check(screen.PaymentCoins.Count == 0 && controller.Ledger.Build().TotalRevenue == ledgerRevenue,
            "动画结束清理节点，不重复入账");
        screen.Initialize(catalog, save, controller, 11);
        Check(station.CoinTray!.VisibleCoinCount == 0 && screen.PaymentCoins.Count == 0, "重开清除钱堆与残留付款动画");
        screen.Free(); controller.Free(); save.Free();
        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(savePath));
    }

    private async Task TestStockGestures(DataCatalog catalog)
    {
        var station = ProjectCake.Core.SceneFactory.Instantiate<PancakeWorkstation>(
            "res://Scenes/Gameplay/PancakeWorkstation.tscn");
        AddChild(station);
        station.Initialize(catalog, 1, 1, 1, catalog.DaysByNumber[11]);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var bell = (Control)station.FindChild("SupplyBell", true, false);
        var npc = (Control)station.FindChild("SupplyHelperClick", true, false);
        string[] order = { StableIds.Ingredients.Egg, StableIds.Ingredients.Crispy,
            StableIds.Ingredients.Scallion, StableIds.Ingredients.Ham, "soy_milk" };

        foreach (float scale in new[] { 1f, 2f / 3f })
        {
            station.Scale = Vector2.One * scale;
            station.ResetForDay();
            Check(Click(bell) && station.SupplyNpcCalled && npc.Visible,
                "满库存点铃仍响铃并叫出可点击 NPC，缩放 " + scale);
            Check(order.All(id => Count(id) == Capacity(id)), "满库存叫货不改变库存");
            using (var fryerClick = new InputEventMouseButton
            {
                ButtonIndex = MouseButton.Left, Pressed = true,
                Position = station.GetGlobalTransformWithCanvas() * new Vector2(180, 550),
            })
                Check(!station.HandleSupplyInput(fryerClick), "NPC 与炸锅重叠处不拦截炸锅点击");
            station.CancelInput();

            foreach (string id in order)
            {
                if (id == "soy_milk")
                {
                    Check(station.SoyMilkTray!.TryConsumeForDelivery(2), "准备两杯豆浆缺口");
                    station.SoyMilkTray.Tick(SoyMilkTrayRuntime.TakeSeconds);
                }
                else Check(station.Inventory.TryConsume(id, 2), "准备小料缺口 " + id);
            }
            Check(Click(bell) && station.SupplyNpcCalled && npc.Visible,
                "原料未满时点铃叫出 NPC，缩放 " + scale);
            foreach (string id in order)
            {
                int before = Count(id);
                for (int click = 1; click <= 2; click++)
                {
                    Check(Click(npc), "NPC 点击由输入路由接收 " + id);
                    Check(station.GetChildren().OfType<TextureRect>().Any(n => n.Name.ToString().StartsWith("SupplyDrop_" + id)),
                        "补货显示对应食材落入动画 " + id);
                    Check(Count(id) == before + click && !station.Inventory.IsAnyRefilling
                        && station.SoyMilkTray!.IsRefilling == false,
                        "每点一次只立即补一份 " + id + " #" + click);
                    TextureRect target = id == "soy_milk"
                        ? station.Descendants<SoyMilkStockView>().Single().Cups[Count(id) - 1]
                        : station.Descendants<IngredientStockSlotView>().Single(view => view.Name == "IngredientSlot_" + id)
                            .IngredientVisuals[Count(id) - 1];
                    TextureRect falling = station.GetChildren().OfType<TextureRect>().Last(node => !node.IsQueuedForDeletion());
                    Vector2 offset = new(0, 110 * scale);
                    Check(target.SelfModulate.A == 0 && falling.Size.DistanceTo(target.Size) < .001f
                        && (falling.GetGlobalTransform().Origin + offset).IsEqualApprox(target.GetGlobalTransform().Origin)
                        && falling.Material == target.Material,
                        "飞行中不重复显示，按实际库存位置与尺寸落入 " + id,
                        $"alpha={target.SelfModulate.A} size={falling.Size}/{target.Size} origin={falling.GetGlobalTransform().Origin + offset}/{target.GetGlobalTransform().Origin} material={falling.Material == target.Material}");
                    foreach (string other in order.Where(other => other != id))
                        Check(Count(other) == Capacity(other) - 2 || Count(other) == Capacity(other),
                            "本次点击不改变其他食材 " + other);
                }
                Check(Count(id) == Capacity(id), "补满后进入下一种 " + id);
            }
            Check(order.All(id => Count(id) == Capacity(id)), "五种食材依序补满");
            station.CancelInput();
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            Check(!station.GetChildren().OfType<TextureRect>().Any(n => n.Name.ToString().StartsWith("SupplyDrop_")),
                "中断补货清理全部落入动画");
            Check(station.Descendants<IngredientStockSlotView>().SelectMany(view => view.IngredientVisuals)
                .Concat(station.Descendants<SoyMilkStockView>().Single().Cups).All(unit => unit.SelfModulate.A == 1),
                "中断动画恢复所有已补入食材");

            station.Inventory.TryConsume(StableIds.Ingredients.Egg);
            var gesture = (StockGesture)station.FindChild("StockGesture_egg", true, false);
            using (var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true,
                Position = gesture.Size / 2 }) gesture._GuiInput(press);
            station.Tick(.6);
            using (var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left,
                Position = gesture.GetGlobalRect().GetCenter() }) gesture._Input(release);
            Check(station.Inventory.GetQuantity(StableIds.Ingredients.Egg)
                == station.Inventory.GetCapacity(StableIds.Ingredients.Egg) - 1
                && !station.Inventory.IsRefilling(StableIds.Ingredients.Egg),
                "料盒长按不再补货");
            Click(bell);
            using (var escape = new InputEventKey { Keycode = Key.Escape, Pressed = true })
                Check(station.HandleSupplyInput(escape), "Esc 关闭 NPC");
            Check(!station.SupplyNpcCalled && !npc.Visible, "Esc 后 NPC 隐藏");
            Click(bell);
            station.Paused = true; station.Tick(.1); station.Paused = false;
            Check(!station.SupplyNpcCalled && !npc.Visible, "暂停关闭 NPC");
            Click(bell);
            station.CancelInput();
            Check(!station.SupplyNpcCalled && !npc.Visible, "失焦关闭 NPC");
            Click(bell);
            station.ResetForDay();
            Check(!station.SupplyNpcCalled && !npc.Visible, "重开清除 NPC");
        }
        station.Free();

        bool Click(Control target)
        {
            using var input = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true,
                Position = target.GetGlobalTransformWithCanvas() * (target.Size * .5f) };
            return station.HandleSupplyInput(input);
        }
        int Count(string id) => id == "soy_milk" ? station.SoyMilkTray!.Quantity
            : station.Inventory.GetQuantity(id);
        int Capacity(string id) => id == "soy_milk" ? station.SoyMilkTray!.Capacity
            : station.Inventory.GetCapacity(id);
    }
}
