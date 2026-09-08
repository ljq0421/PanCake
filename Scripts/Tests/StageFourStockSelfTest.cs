using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Interaction;
using ProjectCake.Inventory;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class StageFourSelfTest
{
    private void TestStockPresentation(DataCatalog catalog)
    {
        var art = new TianjinArtCatalog();
        foreach (int level in Enumerable.Range(1, 3))
        foreach (string id in new[] { StableIds.Ingredients.Egg, StableIds.Ingredients.Crispy, StableIds.Ingredients.Ham })
        {
            int capacity = catalog.IngredientStationsByLevel[level].GetCapacity(id);
            var slot = new IngredientStockSlotView();
            AddChild(slot);
            slot.ConfigureStock(art.IngredientTray, art.Ingredient(id), id, TianjinWorkbenchLayout.IngredientSlot(id), IngredientVisualMode.HybridStock);
            var inventory = new IngredientInventory(catalog.IngredientStationsByLevel[level]);
            // Capacity chooses the fixed cell layout once; taking stock must not
            // change it. Configure alone has not received that capacity yet.
            slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id), 0, true);
            var identities = slot.IngredientVisuals.ToArray();
            var positions = identities.Select(item => (item.Position, item.Size)).ToArray();
            Check(identities.Length == 10, $"Lv{level} {id} 只创建十个独立库存位置");
            int previousVisible = 10;
            for (int quantity = capacity; quantity >= 0; quantity--)
            {
                slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id), inventory.GetRefillProgress(id), true);
                previousVisible = CheckFrame(quantity, previousVisible, increasing: false);
                if (quantity > 0)
                    Check(inventory.TryConsume(id) && inventory.GetQuantity(id) == quantity - 1,
                        $"Lv{level} {id} 实际取料从{quantity}份准确减为{quantity - 1}份");
            }

            Check(inventory.TryBeginRefill(id), $"Lv{level} {id} 空库存可开始真实补货");
            inventory.Tick(inventory.LevelData.RefillSeconds * .5);
            slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id), inventory.GetRefillProgress(id), true);
            Check(slot.VisibleIngredientVisualCount == 0 && slot.StockBar.Value == 50 && slot.RefillButton.Disabled,
                $"Lv{level} {id} 实际空盘补货一半仍无食材，进度独立且禁止重复补货");
            inventory.Tick(inventory.LevelData.RefillSeconds * .5);
            slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id), inventory.GetRefillProgress(id), true);
            Check(inventory.GetQuantity(id) == capacity && slot.VisibleIngredientVisualCount == Math.Min(capacity, 10)
                && !slot.RefillButton.Visible, $"Lv{level} {id} 实际补货完成恢复满库存与完整独立排列");
            CheckFrame(capacity, 0, increasing: true);

            previousVisible = 0;
            for (int quantity = 0; quantity <= capacity; quantity++)
            {
                slot.RenderStock(quantity, capacity, quantity == 0 ? IngredientStockStatus.Empty : IngredientStockStatus.Normal, 0, true);
                previousVisible = CheckFrame(quantity, previousVisible, increasing: true);
            }
            slot.RenderStock(1, capacity, IngredientStockStatus.Refilling, .5, true);
            Check(slot.VisibleIngredientVisualCount == 1 && slot.StockBar.Value == 50 && slot.RefillButton.Disabled,
                $"Lv{level} {id} 补货一半时仍显示实际一份，进度独立且禁止重复补货");
            slot.RenderStock(capacity, capacity, IngredientStockStatus.Normal, 1, true);
            Check(slot.VisibleIngredientVisualCount == Math.Min(capacity, 10) && !slot.RefillButton.Visible,
                $"Lv{level} {id} 有余量补货完成后恢复满库存");
            // Regression: a sprite on the front rim was inside the outer texture
            // rectangle and therefore passed the former containment check.
            TextureRect firstItem = slot.IngredientVisuals[0];
            Vector2 savedPosition = firstItem.Position;
            WorkstationSlotSpec spec = TianjinWorkbenchLayout.IngredientSlot(id);
            Rect2 safeInterior = spec.IngredientContainmentRect!.Value;
            float rimOverlap = Math.Min(1f, (slot.TrayVisualRect.End.Y - safeInterior.End.Y) * .5f);
            firstItem.Position = new Vector2(savedPosition.X,
                safeInterior.End.Y + rimOverlap - spec.IngredientAnchorRect.Position.Y - firstItem.Size.Y);
            Check(slot.TrayVisualRect.Encloses(slot.IngredientVisualRect) && !slot.IngredientIsInsideTray(),
                $"Lv{level} {id} 检查会拒绝仍在外框内、但压到前盘沿的食材");
            firstItem.Position = savedPosition;
            slot.Free();

            int CheckFrame(int quantity, int previousCount, bool increasing)
            {
                int visible = slot.VisibleIngredientVisualCount;
                string direction = increasing ? "增加" : "取走";
                Check(slot.VisibleStockUnits == visible
                    && visible <= Math.Min(quantity, 10) && (quantity <= 6 ? visible == quantity : visible > 6)
                    && (increasing ? visible >= previousCount : visible <= previousCount),
                    $"Lv{level} {id} {direction}至{quantity}份：可见量单调，六份内精确，最多十份且不多于实际余量",
                    $"previous={previousCount}; visible={visible}; actual={quantity}");
                Check(slot.CountLabel.Text == $"{quantity}/{capacity}" && slot.IngredientIsInsideTray(4),
                    $"Lv{level} {id} {direction}至{quantity}份：准确数字且食材与盘沿保持安全距离");
                Check(VisibleStockSpritesDoNotOverlap(slot),
                    $"Lv{level} {id} {direction}至{quantity}份：任意两份食材的显示矩形不重叠");
                Check(slot.IngredientVisuals.SequenceEqual(identities)
                    && identities.Select(item => (item.Position, item.Size)).SequenceEqual(positions),
                    $"Lv{level} {id} {direction}至{quantity}份：全部十个节点复用，位置和尺寸保持不变");
                return visible;
            }
        }

        // Explicit examples cover capacity-relative tier boundaries independently
        // of the renderer's arithmetic, including every small-capacity edge case.
        foreach (string id in new[] { StableIds.Ingredients.Egg, StableIds.Ingredients.Crispy, StableIds.Ingredients.Ham })
        {
            var slot = new IngredientStockSlotView();
            AddChild(slot);
            slot.ConfigureStock(art.IngredientTray, art.Ingredient(id), id,
                TianjinWorkbenchLayout.IngredientSlot(id), IngredientVisualMode.HybridStock);
            foreach ((int quantity, int expected) in new[] { (24, 10), (20, 10), (19, 9), (16, 9), (15, 8), (11, 8), (10, 7), (7, 7), (6, 6), (3, 3), (0, 0) })
            {
                slot.RenderStock(quantity, 24, quantity == 0 ? IngredientStockStatus.Empty : IngredientStockStatus.Normal, 0, true);
                Check(slot.VisibleIngredientVisualCount == expected && slot.VisibleStockUnits == expected,
                    $"{id} 容量24剩{quantity}份固定显示{expected}份", $"actual={slot.VisibleIngredientVisualCount}");
            }
            for (int capacity = 1; capacity <= 6; capacity++)
            for (int quantity = 0; quantity <= capacity; quantity++)
            {
                slot.RenderStock(quantity, capacity, quantity == 0 ? IngredientStockStatus.Empty : IngredientStockStatus.Normal, 0, true);
                Check(slot.VisibleIngredientVisualCount == quantity && slot.VisibleStockUnits == quantity
                    && VisibleStockSpritesDoNotOverlap(slot),
                    $"{id} 小容量{capacity}剩{quantity}份逐份精确显示且互不重叠");
            }
            slot.Free();

            var legacy = new IngredientStockSlotView();
            AddChild(legacy);
            legacy.ConfigureStock(art.IngredientTray, art.Ingredient(id), id,
                TianjinWorkbenchLayout.IngredientSlot(id) with { CaptionRect = null }, IngredientVisualMode.HybridStock);
            foreach ((int quantity, int expectedVisuals) in new[] { (24, 12), (7, 9), (6, 6), (3, 3), (0, 0) })
            {
                legacy.RenderStock(quantity, 24, quantity == 0 ? IngredientStockStatus.Empty : IngredientStockStatus.Normal, 0, true);
                Check(legacy.VisibleStockUnits == Math.Min(quantity, 6) && legacy.VisibleIngredientVisualCount == expectedVisuals,
                    $"{id} 无标牌旧槽位剩{quantity}份时保留原前景六份与后方堆叠规则");
            }
            legacy.Free();
        }

        foreach (string id in new[] { StableIds.Ingredients.Batter, StableIds.Ingredients.Sauce, StableIds.Ingredients.Scallion })
        {
            bool sauce = id == StableIds.Ingredients.Sauce;
            bool loose = id == StableIds.Ingredients.Scallion;
            var slot = new IngredientStockSlotView();
            AddChild(slot);
            Texture2D bowl = sauce ? art.SauceContainer : art.BatterContainer;
            slot.ConfigureStock(loose ? art.IngredientTray : bowl, art.Ingredient(id), id,
                TianjinWorkbenchLayout.IngredientSlot(id), loose ? IngredientVisualMode.LooseStock : IngredientVisualMode.Single);
            if (!loose) slot.ConfigureLiquid(sauce ? art.EmptySauceContainer : art.EmptyBatterContainer, bowl, sauce);
            Vector2 toolSize = slot.IngredientVisuals[0].Size;
            foreach ((int quantity, int tier) in new[] { (10, 3), (5, 2), (2, 1), (0, 0) })
            {
                slot.RenderStock(quantity, 10, quantity == 0 ? IngredientStockStatus.Empty : IngredientStockStatus.Normal, 0, true);
                Check(slot.StockTier == tier && (loose ? slot.VisibleIngredientVisualCount == tier : slot.LiquidTier == tier),
                    $"{id} 满、半、少、空正确切换：{quantity}/10");
                if (!loose) Check(slot.IngredientVisuals[0].Size == toolSize, $"{id} 液面变化不改变工具尺寸");
                else Check(slot.IngredientIsInsideTray(4) && VisibleStockSpritesDoNotOverlap(slot),
                    $"香葱{quantity}/10的整簇轮廓均避开盘沿，簇与簇之间互不重叠");
            }
            slot.RenderStock(0, 10, IngredientStockStatus.Refilling, .5, true);
            Check(loose ? slot.VisibleIngredientVisualCount == 0 : slot.LiquidTier == 0, $"{id} 补货未完成不会凭进度制造食材");
            slot.Free();
        }

        foreach ((Texture2D texture, Texture2D trayTexture, WorkstationSlotSpec spec) in new[] {
            (art.RawYoutiao, art.IngredientTray, TianjinWorkbenchLayout.RawYoutiaoSlot()),
            (art.Ingredient(StableIds.Ingredients.Youtiao), art.YoutiaoRack, TianjinWorkbenchLayout.FinishedYoutiaoSlot()) })
        {
            var slot = new WorkstationSlotView();
            AddChild(slot);
            slot.Configure(trayTexture, texture, "油条", spec, IngredientVisualMode.WideSingle);
            TextureRect visual = slot.IngredientVisuals[0];
            Check(Close(visual.Size.X / visual.Size.Y, (float)texture.GetWidth() / texture.GetHeight())
                && visual.RotationDegrees != 0 && slot.IngredientIsInsideTray(4), "生熟油条保持素材纵横比且旋转后的轮廓不出盘",
                $"source={texture.GetSize()}; drawn={visual.Size}; bounds={slot.IngredientVisualRect}; tray={slot.TrayVisualRect}");
            slot.Free();
        }

        var workstation = new PancakeWorkstation { UseServingTray = true };
        AddChild(workstation);
        workstation.Initialize(catalog, 1, 1, 1, catalog.DaysByNumber[11], art);
        var cups = (SoyMilkStockView)workstation.FindChild("SoyMilkStockArt", true, false);
        var cupNodes = cups.Cups.ToArray();
        var cupPositions = cupNodes.Select(cup => cup.Position).ToArray();
        SoyMilkTrayRuntime tray = workstation.SoyMilkTray!;
        var drag = workstation.GetChildren().OfType<DragService>().Single();
        var source = (Control)workstation.FindChild("SoyMilkCupDrag", true, false);
        var soyPanel = (Control)workstation.FindChild("SoyMilkSlot", true, false);
        var trayArt = (TextureRect)workstation.FindChild("SoyMilkTrayArt", true, false);
        float trayScale = Math.Min(trayArt.Size.X / trayArt.Texture.GetWidth(), trayArt.Size.Y / trayArt.Texture.GetHeight());
        Vector2 traySize = trayArt.Texture.GetSize() * trayScale;
        Rect2 trayBounds = new(trayArt.GlobalPosition + (trayArt.Size - traySize) * .5f, traySize);
        Rect2 cupBounds = cupNodes.Select(cup => cup.GetGlobalRect()).Aggregate((left, right) => left.Merge(right));
        Check(cupBounds.Size.X >= trayBounds.Size.X * .75f
            && Math.Abs((cupBounds.Position.X - trayBounds.Position.X) - (trayBounds.End.X - cupBounds.End.X)) <= 16,
            "六杯豆浆覆盖托盘至少四分之三宽度，左右留白均衡");
        for (int index = 0; index < cupNodes.Length; index++)
        {
            Rect2 cupBoundsNow = cupNodes[index].GetGlobalRect();
            Vector2 foot = new(cupBoundsNow.GetCenter().X, cupBoundsNow.End.Y);
            Rect2 floor = new(trayBounds.Position + trayBounds.Size * new Vector2(.12f, .24f), trayBounds.Size * new Vector2(.76f, .51f));
            Check(floor.HasPoint(foot) && source.GetGlobalRect().Encloses(cupBoundsNow),
                $"豆浆第{index + 1}杯落在盘内且整个杯子可拖取");
            if (index % 3 != 2)
                Check(cupBoundsNow.End.X + 4 <= cupNodes[index + 1].GetGlobalRect().Position.X,
                    $"豆浆第{index + 1}杯与同排下一杯有间隔");
        }
        var refill = (Button)soyPanel.FindChild("SoyMilkRefill", true, false);
        Check(!source.GetGlobalRect().Intersects(refill.GetGlobalRect()) && !trayBounds.Intersects(refill.GetGlobalRect()),
            "豆浆补货在盘外，既不占盘面也不遮挡取杯热区");
        // Starting and cancelling a real drag must not reserve or consume a cup.
        drag.BeginDrag(source, "soy_milk", "豆浆", TianjinUi.Cream, new DragVisualSpec(art.Product(ProductKind.SoyMilk), TianjinWorkbenchLayout.SoyVisual));
        drag.CancelDrag();
        workstation.RefreshForCapture();
        Check(tray.Quantity == 6 && cups.VisibleCupCount == 6, "取消豆浆拖拽后库存和六杯画面保持一致");
        for (int quantity = 6; quantity >= 0; quantity--)
        {
            workstation.RefreshForCapture();
            Check(cups.VisibleCupCount == quantity && cups.Cups.SequenceEqual(cupNodes)
                && cups.Cups.Select(cup => cup.Position).SequenceEqual(cupPositions), $"豆浆{quantity}杯：数量准确且固定位置复用节点");
            if (quantity == 0) break;
            tray.TryConsumeForDelivery();
            workstation.RefreshForCapture();
            Check(cups.VisibleCupCount == quantity - 1 && !tray.TryConsumeForDelivery(), "豆浆取杯阶段只减一杯，不能重复扣除");
            tray.Tick(SoyMilkTrayRuntime.TakeSeconds);
        }
        tray.TryBeginRefill();
        tray.Tick(SoyMilkTrayRuntime.RefillSeconds * .5);
        workstation.RefreshForCapture();
        Check(cups.VisibleCupCount == 0 && !tray.CanStartDrag, "豆浆补货一半仍为空盘且不可取杯");
        tray.Tick(SoyMilkTrayRuntime.RefillSeconds);
        workstation.RefreshForCapture();
        Check(cups.VisibleCupCount == 6 && tray.CanStartDrag, "豆浆补货完成恢复六杯和取杯交互");
        workstation.Free();
    }

    private static bool VisibleStockSpritesDoNotOverlap(WorkstationSlotView slot)
    {
        Rect2[] rectangles = slot.IngredientVisuals.Where(visual => visual.Visible)
            .Select(visual => visual.GetGlobalRect()).ToArray();
        for (int left = 0; left < rectangles.Length; left++)
        for (int right = left + 1; right < rectangles.Length; right++)
            if (rectangles[left].Intersects(rectangles[right])) return false;
        return true;
    }
}
