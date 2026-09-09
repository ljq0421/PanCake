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
        var screen = new TianjinDayScreen(); AddChild(screen);
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
            Check(revenue > before && station.CoinTray!.VisibleCoinCount == Math.Min(12, (int)Math.Ceiling(revenue / 10.0))
                && screen.PaymentCoins.Count == flightsBefore + (reduceMotion ? 0 : 3),
                reduceMotion ? "减少动态效果时直接更新钱堆，不播放金币飞行" : "完成订单准确入账，钱堆同步并仅播放一组付款动画");
            ProjectSettings.SetSetting("accessibility/reduce_motion", originalMotion);
        }
        screen._Notification((int)NotificationApplicationFocusOut);
        var positions = screen.PaymentCoins.ToDictionary(coin => coin, coin => coin.Position);
        await WaitForAnimation(.2);
        Check(positions.All(entry => entry.Key.Position.IsEqualApprox(entry.Value)), "失焦暂停金币飞行动画");
        screen._Notification((int)NotificationApplicationFocusIn);
        await WaitForAnimation(.68);
        Vector2 target = screen.GetGlobalTransform().AffineInverse() * station.CoinTray!.LandingPoint;
        Check(screen.PaymentCoins.Count > 0 && screen.PaymentCoins.All(coin => coin.Position.DistanceTo(target - new Vector2(19, 19)) < 60),
            "付款金币飞向桌面托盘而非顶部收入");
        int ledgerRevenue = controller.Ledger!.Build().TotalRevenue;
        await WaitForAnimation(.5);
        Check(screen.PaymentCoins.Count == 0 && controller.Ledger.Build().TotalRevenue == ledgerRevenue,
            "动画结束清理节点，不重复入账");
        screen.Initialize(catalog, save, controller, 11);
        Check(station.CoinTray.VisibleCoinCount == 0 && screen.PaymentCoins.Count == 0, "重开清除钱堆与残留付款动画");
        screen.Free(); controller.Free(); save.Free();
        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(savePath));
    }

    private async Task TestStockGestures(DataCatalog catalog)
    {
        var station = new PancakeWorkstation { UseServingTray = true };
        AddChild(station);
        station.Initialize(catalog, 1, 1, 1, catalog.DaysByNumber[11]);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var drag = station.GetChildren().OfType<DragService>().Single();
        foreach (float scale in new[] { 1f, 2f / 3f })
        {
            station.Scale = Vector2.One * scale;
            foreach (string id in TianjinWorkbenchLayout.IngredientOrder)
            {
                station.ResetForDay();
                var gesture = (StockGesture)station.FindChild($"StockGesture_{id}", true, false);
                if (station.Inventory.IsUnlimited(id))
                {
                    Press(gesture); station.Tick(.6); Release(gesture);
                    Check(!station.Inventory.IsRefilling(id) && station.Inventory.HasAvailable(id)
                        && !station.Inventory.CanRefill(id), $"{id}/{scale} 无限原料长按不补货且始终可用");
                    continue;
                }
                int capacity = station.Inventory.GetCapacity(id);
                station.Inventory.TryConsume(id, capacity);
                Press(gesture);
                station.Tick(.449);
                Check(!station.Inventory.IsRefilling(id) && gesture.HoldProgress > .99, $"{id}/{scale} 长按临界时间前不补货");
                Release(gesture);
                Check(!station.Inventory.IsRefilling(id) && station.Inventory.GetQuantity(id) == 0, $"{id}/{scale} 空盘短按不补货");
                Press(gesture);
                station.Tick(.45);
                Check(station.Inventory.IsRefilling(id) && station.Inventory.GetQuantity(id) == 0, $"{id}/{scale} 空盘长按触发且不提前入库");
                Release(gesture);
                Press(gesture); station.Tick(.45); Release(gesture);
                Check(station.Inventory.GetRefillProgress(id) > 0, $"{id}/{scale} 重复长按不重置补货进度");
                var slot = (IngredientStockSlotView)station.FindChild($"IngredientSlot_{id}", true, false);
                int previewQuantity = (int)Math.Floor(capacity * station.Inventory.GetRefillProgress(id));
                bool liquid = id is StableIds.Ingredients.Batter or StableIds.Ingredients.Sauce;
                Check(liquid ? slot.LiquidTier == slot.StockTier && slot.LiquidTier > 0
                    : slot.VisibleIngredientVisualCount == previewQuantity,
                    $"{id}/{scale} 真实长按补货将新增份数同步到盘内实物或液面");
                int pausedVisualCount = slot.VisibleIngredientVisualCount, pausedLiquidTier = slot.LiquidTier;
                station.Paused = true; station.Tick(1); station.Paused = false;
                Check(slot.VisibleIngredientVisualCount == pausedVisualCount && slot.LiquidTier == pausedLiquidTier,
                    $"{id}/{scale} 暂停冻结盘内补货显示");
                station.Tick(station.Inventory.LevelData.RefillSeconds);
                Check(station.Inventory.GetQuantity(id) == capacity && !station.Inventory.IsRefilling(id), $"{id}/{scale} 松手后按原耗时补满");
                Check(liquid ? slot.LiquidTier == 3 : slot.VisibleIngredientVisualCount == capacity,
                    $"{id}/{scale} 补满后显示完整容量");
                Press(gesture); station.Tick(.45); Release(gesture);
                Check(!station.Inventory.IsRefilling(id) && station.Inventory.GetQuantity(id) == capacity, $"{id}/{scale} 满盘长按不补货也不取料");
                station.Inventory.TryConsume(id);
                Press(gesture); station.Tick(.2); station.Paused = true; station.Tick(1); station.Paused = false;
                station.Tick(1); Release(gesture);
                Check(!station.Inventory.IsRefilling(id), $"{id}/{scale} 暂停取消蓄力，恢复后不误触");
                Press(gesture); station.Tick(.2); station.CancelInput(); station.Tick(1); Release(gesture);
                Check(!station.Inventory.IsRefilling(id), $"{id}/{scale} 失焦或取消输入清除蓄力");
                Press(gesture); station.Tick(.2); station.ResetForDay(); station.Tick(1); Release(gesture);
                Check(!station.Inventory.IsRefilling(id), $"{id}/{scale} 重开清除蓄力");
                station.Inventory.TryConsume(id);
                Press(gesture); station.Tick(.45); Release(gesture);
                Check(station.Inventory.IsRefilling(id), $"{id}/{scale} 非当前制作步骤也可以提前补料");
            }
            station.ResetForDay();
            var batter = (StockGesture)station.FindChild("StockGesture_batter", true, false);
            Press(batter);
            Vector2 origin = batter.GetGlobalTransform() * new Vector2(100, 60);
            using (var motion = new InputEventMouseMotion { Position = origin + new Vector2(7 * scale, 0) }) batter._Input(motion);
            Check(!drag.IsDragging, $"缩放{scale} 轻微移动不启动拖动");
            using (var motion = new InputEventMouseMotion { Position = origin + new Vector2(9 * scale, 0) }) batter._Input(motion);
            Check(drag.IsDragging && batter.HoldProgress == 0, $"缩放{scale} 超过8设计像素启动拖料并取消长按");
            station.Tick(.6);
            Check(!station.Inventory.IsRefilling("batter"), $"缩放{scale} 拖料期间不会触发补货");
            station.CancelInput();

            var soy = (StockGesture)station.FindChild("StockGesture_soy_milk", true, false);
            var tray = station.SoyMilkTray!;
            tray.TryConsumeForDelivery();
            Press(soy); soy.Tick(.45); Release(soy);
            Check(!tray.IsRefilling && tray.IsTaking, "豆浆取杯冷却期间不能补货");
            tray.Tick(.3);
            Press(soy); station.Tick(.45); Release(soy);
            Check(tray.IsRefilling && tray.Quantity == 9, "豆浆长按触发后松手不取杯");
            station.Tick(.59);
            Check(tray.Quantity == 9, "豆浆保持0.6秒补货耗时");
            station.Tick(.01);
            Check(tray.Quantity == 10 && !tray.IsRefilling, "豆浆完成后恢复十杯");
            while (tray.Quantity > 0) { tray.TryConsumeForDelivery(); tray.Tick(.3); }
            Press(soy); station.Tick(.1); Release(soy);
            Check(!tray.IsRefilling, "豆浆空盘短按不补货");
            Press(soy); station.Tick(.45); Release(soy);
            Check(tray.IsRefilling, "豆浆空盘长按补货");
            var cups = (SoyMilkStockView)station.FindChild("SoyMilkStockArt", true, false);
            station.Tick(SoyMilkTrayRuntime.RefillSeconds * .5);
            Check(cups.VisibleCupCount == 5 && tray.Quantity == 0 && !tray.CanStartDrag,
                "豆浆长按补货半程托盘显示五杯，完成前不能取杯");
            station.Paused = true; station.Tick(1); station.Paused = false;
            Check(cups.VisibleCupCount == 5, "暂停冻结豆浆补货杯数");
            station.Tick(SoyMilkTrayRuntime.RefillSeconds);
            Check(cups.VisibleCupCount == tray.Capacity && tray.CanStartDrag,
                "豆浆长按补货结束显示完整十杯并恢复取用");
        }

        var coins = station.CoinTray!;
        foreach (float scale in new[] { 1f, 2f / 3f })
        {
            station.Scale = Vector2.One * scale;
            foreach ((int amount, int expected) in new[] { (0, 0), (1, 1), (10, 1), (11, 2), (120, 12), (500, 12) })
            {
                coins.RenderRevenue(amount);
                Check(coins.VisibleCoinCount == expected, $"金币托盘收入{amount}显示{expected}枚示意币");
                Check(coins.Coins.Where(coin => coin.Visible).All(coin => coins.SurfaceBounds.Encloses(coin.GetGlobalRect())),
                    $"金币{expected}枚/缩放{scale}全部完整位于盘内，不依赖裁切隐藏溢出");
                Check(coins.SurfaceBounds.HasPoint(coins.LandingPoint), "金币动画落点位于盘面内部");
            }
        }
        station.ResetForDay();
        Check(coins.VisibleCoinCount == 0, "重开清空金币托盘");
        station.Free();

        void Press(StockGesture gesture)
        {
            using var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = new Vector2(100, 60) };
            gesture._GuiInput(press);
        }
        void Release(StockGesture gesture)
        {
            using var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Position = gesture.GetGlobalTransform() * new Vector2(100, 60) };
            gesture._Input(release);
        }
    }
}
