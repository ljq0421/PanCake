using Godot;
using ProjectCake.Fryer;
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
        var levelOneSizes = new Dictionary<string, Vector2>();
        foreach (int level in Enumerable.Range(1, 3))
        foreach (string id in new[] { StableIds.Ingredients.Egg, StableIds.Ingredients.Crispy, StableIds.Ingredients.Ham, StableIds.Ingredients.Scallion })
        {
            int capacity = catalog.IngredientStationsByLevel[level].GetCapacity(id);
            var slot = new IngredientStockSlotView();
            AddChild(slot);
            slot.ConfigureStock(art.IngredientTray, art.Ingredient(id), id, TianjinWorkbenchLayout.IngredientSlot(id),
                id == StableIds.Ingredients.Scallion ? IngredientVisualMode.LooseStock : IngredientVisualMode.HybridStock);
            var inventory = new IngredientInventory(catalog.IngredientStationsByLevel[level]);
            // Capacity chooses the fixed cell layout once; taking stock must not
            // change it. Configure alone has not received that capacity yet.
            slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id), 0, true);
            var identities = slot.IngredientVisuals.ToArray();
            var positions = identities.Select(item => (item.Position, item.Size, item.Rotation)).ToArray();
            Check(identities.All(item => Mathf.IsEqualApprox(item.Size.X / item.Size.Y,
                    item.Texture.GetWidth() / (float)item.Texture.GetHeight())),
                $"Lv{level} {id} 拉高托盘后食材仍保持原始宽高比");
            Check(identities.Length == capacity, $"Lv{level} {id} 按完整容量创建{capacity}个独立库存位置");
            if (level == 1) levelOneSizes[id] = identities[0].Size;
            Check(capacity == 4 + level * 2 && identities[0].Size.IsEqualApprox(levelOneSizes[id]),
                $"Lv{level} {id} 使用6/8/10份容量，升级不缩小实物");
            int columns = capacity / 2;
            Check(identities.Take(columns).Average(back => back.Position.Y) < identities.Skip(columns).Average(front => front.Position.Y)
                && identities.Take(columns).All(back => back.GetIndex() < identities[columns].GetIndex()),
                $"Lv{level} {id} 后排先绘制，前排后绘制，取料从前排最后一份开始");
            if (id == StableIds.Ingredients.Egg)
            {
                Rect2 anchor = TianjinWorkbenchLayout.IngredientSlot(id).IngredientAnchorRect;
                Check(identities.Select((visual, index) =>
                {
                    int row = index / columns, column = index % columns;
                    Vector2 foot = anchor.Position + visual.GetTransform() * new Vector2(visual.Size.X * .5f, visual.Size.Y);
                    return foot.IsEqualApprox(new Vector2(124 + (column - (columns - 1) * .5f) * 34 + (row == 0 ? 4 : -4), row == 0 ? 51 : 82));
                }).All(matches => matches) && Mathf.IsEqualApprox(identities[0].Size.X, 46),
                    $"Lv{level} 鸡蛋保持已确认的大小和全部落点");
            }
            else
            {
                Check(slot.IngredientBounds(identities[0]).Intersects(slot.IngredientBounds(identities[columns])),
                    $"Lv{level} {id} 前后排实物相互覆盖");
                Vector2 previousFrame = id switch
                {
                    StableIds.Ingredients.Crispy => new(58, 62),
                    StableIds.Ingredients.Ham => new(46, 62),
                    _ => new(46, 34),
                };
                Vector2 sourceSize = identities[0].Texture.GetSize();
                Vector2 previousSize = sourceSize * Math.Min(previousFrame.X / sourceSize.X, previousFrame.Y / sourceSize.Y);
                Check(identities.All(item => item.Size.IsEqualApprox(previousSize * 1.2f)),
                    $"Lv{level} {id} 比上一版等比放大1.2倍");
                if (id == StableIds.Ingredients.Scallion)
                {
                    Check(identities.All(item => new Rect2(32, 40, 184, 46).Encloses(slot.IngredientBounds(item))),
                        $"Lv{level} 每团香葱旋转后的完整轮廓收在盘底，覆盖也不越沿",
                        string.Join("; ", identities.Select(item => slot.IngredientBounds(item).ToString())));
                    Check(slot.IngredientVisualRect.Size.X >= (level == 3 ? 180 : level == 2 ? 160 : 128)
                        && slot.IngredientVisualRect.Size.Y >= 44,
                        $"Lv{level} 香葱铺开盘底宽度和纵深，不再挤成窄条");
                }
            }
            Check(identities.Any(item => item.Rotation > .02f) && identities.Any(item => item.Rotation < -.02f)
                && identities.All(item => item.Size.Length() > 40),
                $"Lv{level} {id} 保持大尺寸，前后两排错位叠放");
            int previousVisible = capacity;
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
            int halfVisible = capacity / 2;
            Check(slot.VisibleIngredientVisualCount == halfVisible && slot.StockBar.Value == 50 && slot.RefillButton.Disabled
                && inventory.GetQuantity(id) == 0 && !inventory.TryConsume(id),
                $"Lv{level} {id} 空盘补货一半显示逐份补入预览，真实库存仍为空且禁止取用和重复补货");
            inventory.Tick(inventory.LevelData.RefillSeconds * .5);
            slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id), inventory.GetRefillProgress(id), true);
            Check(inventory.GetQuantity(id) == capacity && slot.VisibleIngredientVisualCount == capacity
                && !slot.RefillButton.Visible, $"Lv{level} {id} 实际补货完成恢复满库存与完整独立排列");
            CheckFrame(capacity, 0, increasing: true);

            previousVisible = 0;
            for (int quantity = 0; quantity <= capacity; quantity++)
            {
                slot.RenderStock(quantity, capacity, quantity == 0 ? IngredientStockStatus.Empty : IngredientStockStatus.Normal, 0, true);
                previousVisible = CheckFrame(quantity, previousVisible, increasing: true);
            }
            slot.RenderStock(1, capacity, IngredientStockStatus.Refilling, .5, true);
            Check(slot.VisibleIngredientVisualCount == halfVisible && slot.StockBar.Value == 50 && slot.RefillButton.Disabled,
                $"Lv{level} {id} 从余下一份开始补货，半程逐步补入缺少部分且禁止重复补货");
            slot.RenderStock(capacity, capacity, IngredientStockStatus.Normal, 1, true);
            Check(slot.VisibleIngredientVisualCount == capacity && !slot.RefillButton.Visible,
                $"Lv{level} {id} 有余量补货完成后恢复满库存");
            // Regression: a sprite on the front rim was inside the outer texture
            // rectangle and therefore passed the former containment check.
            TextureRect firstItem = slot.IngredientVisuals[0];
            Vector2 savedPosition = firstItem.Position;
            WorkstationSlotSpec spec = TianjinWorkbenchLayout.IngredientSlot(id);
            Rect2 safeInterior = spec.StockFootprintRect!.Value;
            float rimOverlap = Math.Min(1f, (slot.TrayVisualRect.End.Y - safeInterior.End.Y) * .5f);
            firstItem.Position = new Vector2(savedPosition.X,
                safeInterior.End.Y + rimOverlap - spec.IngredientAnchorRect.Position.Y - firstItem.Size.Y);
            Check(!slot.IngredientIsInsideTray(),
                $"Lv{level} {id} 检查会拒绝仍在外框内、但压到前盘沿的食材");
            firstItem.Position = savedPosition;
            slot.Free();

            int CheckFrame(int quantity, int previousCount, bool increasing)
            {
                int visible = slot.VisibleIngredientVisualCount;
                string direction = increasing ? "增加" : "取走";
                Check(slot.VisibleStockUnits == visible
                    && visible == quantity
                    && (increasing ? visible >= previousCount : visible <= previousCount),
                    $"Lv{level} {id} {direction}至{quantity}份：可见实物数量与实际余量完全一致",
                    $"previous={previousCount}; visible={visible}; actual={quantity}");
                Check(slot.CountLabel.Text == $"{quantity}/{capacity}" && slot.IngredientIsInsideTray(4),
                    $"Lv{level} {id} {direction}至{quantity}份：准确数字且食材与盘沿保持安全距离");
                Check(StockSpritesRemainDistinct(slot),
                    $"Lv{level} {id} {direction}至{quantity}份：允许轻微遮挡但每份实物仍清晰可辨");
                Check(slot.IngredientVisuals.SequenceEqual(identities)
                    && identities.Select(item => (item.Position, item.Size, item.Rotation)).SequenceEqual(positions),
                    $"Lv{level} {id} {direction}至{quantity}份：全部库存节点复用，位置和尺寸保持不变",
                    string.Join("; ", identities.Select((item, index) => $"{index}: {positions[index]} -> {(item.Position, item.Size, item.Rotation)}")));
                return visible;
            }
        }

        // Include capacities above today's upgrades and shrinking pooled layouts.
        foreach (string id in new[] { StableIds.Ingredients.Egg, StableIds.Ingredients.Crispy, StableIds.Ingredients.Ham })
        {
            var slot = new IngredientStockSlotView();
            AddChild(slot);
            slot.ConfigureStock(art.IngredientTray, art.Ingredient(id), id,
                TianjinWorkbenchLayout.IngredientSlot(id), IngredientVisualMode.HybridStock);
            foreach (int quantity in new[] { 10, 9, 8, 7, 6, 3, 0 })
            {
                slot.RenderStock(quantity, 10, quantity == 0 ? IngredientStockStatus.Empty : IngredientStockStatus.Normal, 0, true);
                Check(slot.VisibleIngredientVisualCount == quantity && slot.VisibleStockUnits == quantity
                    && slot.IngredientIsInsideTray(4) && StockSpritesRemainDistinct(slot),
                    $"{id} 容量10剩{quantity}份完整显示且落点在盘内且实物可辨", $"actual={slot.VisibleIngredientVisualCount}");
            }
            for (int capacity = 1; capacity <= 6; capacity++)
            for (int quantity = 0; quantity <= capacity; quantity++)
            {
                slot.RenderStock(quantity, capacity, quantity == 0 ? IngredientStockStatus.Empty : IngredientStockStatus.Normal, 0, true);
                Check(slot.VisibleIngredientVisualCount == quantity && slot.VisibleStockUnits == quantity
                    && StockSpritesRemainDistinct(slot),
                    $"{id} 小容量{capacity}剩{quantity}份逐份精确显示且每份可辨");
            }
            slot.Free();

            var legacy = new IngredientStockSlotView();
            AddChild(legacy);
            legacy.ConfigureStock(art.IngredientTray, art.Ingredient(id), id,
                TianjinWorkbenchLayout.IngredientSlot(id) with { CaptionRect = null, StockFootprintRect = null }, IngredientVisualMode.HybridStock);
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
                Check(slot.StockTier == tier && (loose ? slot.VisibleIngredientVisualCount == quantity : slot.LiquidTier == tier),
                    $"{id} 满、半、少、空正确切换：{quantity}/10");
                if (!loose)
                {
                    Check(slot.IngredientVisuals[0].Size == toolSize, $"{id} 液面变化不改变工具尺寸");
                    Check(slot.IngredientIsInsideTray(4), $"{id} 工具在各液面状态下都不压到容器前沿");
                    TextureRect tool = slot.IngredientVisuals[0];
                    Vector2 position = tool.Position;
                    tool.Position += new Vector2(0, 24);
                    Check(!slot.IngredientIsInsideTray(4), $"{id} 内沿检查能发现工具向下越界");
                    tool.Position = position;
                }
                else Check(slot.IngredientIsInsideTray(4) && StockSpritesRemainDistinct(slot),
                    $"香葱{quantity}/10的整簇轮廓均避开盘沿，各簇允许轻微遮挡");
            }
            slot.RenderStock(0, 10, IngredientStockStatus.Refilling, .5, true);
            Check(loose ? slot.VisibleIngredientVisualCount == 5 : slot.LiquidTier == 2,
                $"{id} 半程显示五簇香葱或半碗液面的补货预览");
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
        var rack = (WorkstationSlotView)workstation.FindChild("FinishedYoutiaoArea", true, false);
        YoutiaoInventory friedStock = workstation.FryerMachine!.Inventory;
        friedStock.TryStore(friedStock.Capacity, YoutiaoQuality.Golden);
        var rackPositions = rack.IngredientVisuals.Select(item => (item.Position, item.Size)).ToArray();
        int previousRackCount = rack.VisibleIngredientVisualCount;
        while (friedStock.TryTake(out _))
        {
            Check(rack.VisibleIngredientVisualCount <= previousRackCount
                && (friedStock.Count == 0 ? rack.VisibleIngredientVisualCount == 0 : rack.VisibleIngredientVisualCount > 0)
                && rack.IngredientIsInsideTray(4)
                && rack.IngredientVisuals.Select(item => (item.Position, item.Size)).SequenceEqual(rackPositions),
                "熟油条取用后按余量减少堆叠，空库存露出空架，剩余素材位置与尺寸不变");
            previousRackCount = rack.VisibleIngredientVisualCount;
        }
        Check(!rack.CountLabel.IsVisibleInTree()
            && workstation.FindChildren("IngredientSlot_*", "Control", true, false).OfType<IngredientStockSlotView>()
                .All(slot => !slot.StockLabel.IsVisibleInTree())
            && workstation.FindChild("SoyMilkStatus", true, false) is Label soyLabel && !soyLabel.Text.Any(char.IsDigit),
            "天津小料、熟油条与豆浆通过素材余量表达库存，不显示库存数字");
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
        Check(cupBounds.Size.X >= trayBounds.Size.X * .7f
            && Math.Abs((cupBounds.Position.X - trayBounds.Position.X) - (trayBounds.End.X - cupBounds.End.X)) <= 16,
            "十杯豆浆覆盖托盘至少七成宽度，左右留白均衡");
        for (int index = 0; index < cupNodes.Length; index++)
        {
            Rect2 cupBoundsNow = cupNodes[index].GetGlobalRect();
            Vector2 foot = new(cupBoundsNow.GetCenter().X, cupBoundsNow.End.Y);
            Rect2 floor = new(trayArt.GlobalPosition + TianjinWorkbenchLayout.ServingTrayFloor.Position,
                TianjinWorkbenchLayout.ServingTrayFloor.Size);
            Check(floor.HasPoint(foot) && source.GetGlobalRect().Encloses(cupBoundsNow),
                $"豆浆第{index + 1}杯落在盘内且整个杯子可拖取");
            if (index % 5 != 4)
                Check(cupNodes[index + 1].GetGlobalRect().Position.X - cupBoundsNow.Position.X >= cupBoundsNow.Size.X * .8f,
                    $"豆浆第{index + 1}杯与同排下一杯仅轻微遮挡，杯身仍清晰");
        }
        var refill = (Button)soyPanel.FindChild("SoyMilkRefill", true, false);
        Check(!refill.IsVisibleInTree() && soyPanel.FindChild("StockGesture_soy_milk", true, false) is StockGesture gesture
            && gesture.GetGlobalRect().Encloses(cupBounds)
            && gesture.GetGlobalRect().HasPoint(trayBounds.GetCenter()), "豆浆长按区域覆盖全部杯子和盘心且隐藏加号");
        // Starting and cancelling a real drag must not reserve or consume a cup.
        drag.BeginDrag(source, "soy_milk", "豆浆", TianjinUi.Cream, new DragVisualSpec(art.Product(ProductKind.SoyMilk), TianjinWorkbenchLayout.SoyVisual));
        drag.CancelDrag();
        workstation.RefreshForCapture();
        Check(tray.Quantity == 10 && cups.VisibleCupCount == 10, "取消豆浆拖拽后库存和十杯画面保持一致");
        for (int quantity = 10; quantity >= 0; quantity--)
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
        Check(cups.VisibleCupCount == 5 && tray.Quantity == 0 && !tray.CanStartDrag, "豆浆补货一半显示五杯预览且不可提前取杯");
        tray.Tick(SoyMilkTrayRuntime.RefillSeconds);
        workstation.RefreshForCapture();
        Check(cups.VisibleCupCount == 10 && tray.CanStartDrag, "豆浆补货完成恢复十杯和取杯交互");
        workstation.Free();
    }

    private void TestRefillPreview(DataCatalog catalog)
    {
        var art = new TianjinArtCatalog();
        Variant previousMotion = ProjectSettings.GetSetting("accessibility/reduce_motion", false);
        try
        {
            foreach (bool reducedMotion in new[] { false, true })
            foreach (int level in Enumerable.Range(1, 3))
            foreach (string id in new[] { StableIds.Ingredients.Crispy, StableIds.Ingredients.Egg,
                StableIds.Ingredients.Scallion, StableIds.Ingredients.Ham })
            foreach (int remainder in new[] { 0, 2 })
            {
                ProjectSettings.SetSetting("accessibility/reduce_motion", reducedMotion);
                var inventory = new IngredientInventory(catalog.IngredientStationsByLevel[level]);
                int capacity = inventory.GetCapacity(id);
                inventory.TryConsume(id, capacity - remainder);
                var slot = new IngredientStockSlotView();
                AddChild(slot);
                bool loose = id == StableIds.Ingredients.Scallion;
                slot.ConfigureStock(art.IngredientTray, art.Ingredient(id), id,
                    TianjinWorkbenchLayout.IngredientSlot(id), loose ? IngredientVisualMode.LooseStock : IngredientVisualMode.HybridStock);
                slot.RenderStock(remainder, capacity, inventory.GetStatus(id), 0, true);
                var identities = slot.IngredientVisuals.ToArray();
                var positions = identities.Select(item => (item.Position, item.Size, item.Rotation)).ToArray();
                int previousVisible = slot.VisibleIngredientVisualCount;
                string context = $"Lv{level} {id} 余量{remainder} reducedMotion={reducedMotion}";
                Check(inventory.TryBeginRefill(id), $"{context} 开始补货");
                // Sample every portion boundary halfway through its interval,
                // including repeated frames with no gameplay time advancing.
                int missing = capacity - remainder;
                for (int portion = 0; portion < missing; portion++)
                {
                    double progress = (portion + .5) / missing;
                    slot.RenderStock(remainder, capacity, IngredientStockStatus.Refilling, progress, false);
                    int visible = slot.VisibleIngredientVisualCount;
                    Check(visible == remainder + portion && visible >= previousVisible && visible <= previousVisible + 1,
                        $"{context} 第{portion}份按顺序出现，不提前全盘填满");
                    Check(slot.RefillButton.Disabled && inventory.GetQuantity(id) == remainder
                        && !inventory.TryConsume(id) && !inventory.TryBeginRefill(id),
                        $"{context} 预览不提前入库、不能取料或重复补货");
                    inventory.Tick(0);
                    slot.RenderStock(remainder, capacity, IngredientStockStatus.Refilling, progress, false);
                    Check(slot.VisibleIngredientVisualCount == visible && slot.IngredientVisuals.SequenceEqual(identities)
                        && identities.Select(item => (item.Position, item.Size, item.Rotation)).SequenceEqual(positions)
                        && slot.IngredientIsInsideTray(4) && StockSpritesRemainDistinct(slot),
                        $"{context} 暂停时数量和布局不变，食材保持可辨且落点不出盘");
                    previousVisible = visible;
                }
                inventory.Tick(inventory.LevelData.RefillSeconds);
                slot.RenderStock(inventory.GetQuantity(id), capacity, inventory.GetStatus(id), 0, true);
                Check(slot.VisibleIngredientVisualCount == capacity
                    && slot.VisibleIngredientVisualCount >= previousVisible && !slot.RefillButton.Visible
                    && slot.CountLabel.Text == $"{capacity}/{capacity}" && inventory.TryConsume(id),
                    $"{context} 补满后预览衔接真实库存，恢复取料");
                slot.RenderStock(0, capacity, IngredientStockStatus.Refilling, .75, true);
                slot.RenderStock(0, capacity, IngredientStockStatus.Empty, 0, true);
                Check(slot.VisibleIngredientVisualCount == 0, $"{context} 退出补货时清除预览");
                slot.RenderStock(0, capacity, IngredientStockStatus.Refilling, 0, true);
                Check(slot.VisibleIngredientVisualCount == 0, $"{context} 再次补货从空盘开始");
                slot.Free();
            }
        }
        finally { ProjectSettings.SetSetting("accessibility/reduce_motion", previousMotion); }
    }

    private async System.Threading.Tasks.Task TestYoutiaoPicking()
    {
        DataCatalog catalog = GetNode<DataCatalog>("/root/DataCatalog");
        string savePath = $"user://youtiao-picking-{Guid.NewGuid():N}.json";
        var save = new SaveService(); AddChild(save); save.UsePathForTests(savePath);
        var controller = new DayController(); AddChild(controller);
        var screen = new TianjinDayScreen(); AddChild(screen);
        screen.ConnectController(controller);
        screen.Initialize(catalog, save, controller, 11);
        screen.SetProcess(false);
        screen.BeginDay(); controller.Tick(3);
        screen.RefreshForCapture(true);
        var workstation = screen.GetChildren().OfType<PancakeWorkstation>().Single();
        workstation.FryerMachine!.Inventory.TryStore(2, YoutiaoQuality.Golden);
        workstation.RefreshForCapture();
        var service = workstation.GetChildren().OfType<DragService>().Single();
        bool rawPicking = false;
        foreach ((string slotName, string inputName, WorkstationSlotSpec spec) in new[] {
            ("RawYoutiaoSlot", "RawYoutiaoInput", TianjinWorkbenchLayout.RawYoutiaoSlot()),
            ("FinishedYoutiaoArea", "FinishedYoutiaoDrag", TianjinWorkbenchLayout.FinishedYoutiaoSlot()) })
        {
            var slot = (WorkstationSlotView)workstation.FindChild(slotName, true, false);
            rawPicking = inputName == "RawYoutiaoInput";
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            TextureRect visual = slot.IngredientVisuals[0];
            Texture2D texture = visual.Texture;
            using Image image = texture.GetImage();
            var opaqueSamples = new List<Vector2>();
            Vector2 opaque = Vector2.Zero, transparent = Vector2.Zero;
            bool foundOpaque = false, foundTransparent = false;
            for (int y = 0; y < image.GetHeight(); y += 8)
            for (int x = 0; x < image.GetWidth(); x += 8)
            {
                Vector2 point = (new Vector2(x, y) + Vector2.One * .5f) / texture.GetSize() * visual.Size;
                Vector2 inSlot = slot.GetGlobalTransform().AffineInverse() * (visual.GetGlobalTransform() * point);
                if (!spec.IngredientAnchorRect.HasPoint(inSlot) || !spec.ClickRect.HasPoint(inSlot)) continue;
                if (!foundOpaque && image.GetPixel(x, y).A > .9f) { opaque = point; foundOpaque = true; }
                if (!foundTransparent && image.GetPixel(x, y).A == 0) { transparent = point; foundTransparent = true; }
                if (x % 64 == 0 && y % 64 == 0 && image.GetPixel(x, y).A > .9f) opaqueSamples.Add(point);
            }
            Check(foundOpaque && foundTransparent, "生熟油条素材具有可验证的实体点与透明点");
            foreach (float scale in new[] { 1f, 2f / 3f })
            {
                screen.Scale = Vector2.One * scale;
                Click(visual.GetGlobalTransform() * transparent, false, "透明像素不能取用");
                Click(slot.GetGlobalTransform() * spec.CaptionRect!.Value.GetCenter(), false, "标牌不能取用");
                Click(slot.GetGlobalTransform() * (spec.ClickRect.Position + new Vector2(5, 5)), false, "托盘空白不能取用");
                Click(visual.GetGlobalTransform() * opaque, true, "旋转缩放后的实体像素可以取用");
                int picked = 0;
                foreach (Vector2 sample in opaqueSamples)
                {
                    Vector2 global = visual.GetGlobalTransform() * sample;
                    using var motion = new InputEventMouseMotion { Position = global };
                    GetViewport().PushInput(motion, true);
                    if (Click(global, true, "实体采样点")) picked++;
                }
                Check(opaqueSamples.Count > 0 && picked == opaqueSamples.Count,
                    $"完整营业页面 {slotName} 缩放{scale:F2}的全部实体采样点可取用", $"{picked}/{opaqueSamples.Count}");
                // Hover animations transform the visible ingredient anchor too.
                using (var motion = new InputEventMouseMotion { Position = visual.GetGlobalTransform() * opaque })
                    GetViewport().PushInput(motion, true);
                await WaitForAnimation(.16);
                Click(visual.GetGlobalTransform() * opaque, true, "悬停动画完成后实体像素仍可取用");
                slot.SetIngredientAvailable(false);
                Click(visual.GetGlobalTransform() * opaque, false, "油条隐藏后不能取用");
                slot.SetIngredientAvailable(true);
            }
        }
        screen.Free(); controller.Free(); save.Free();
        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(savePath));

        bool Click(Vector2 point, bool expected, string label)
        {
            if (rawPicking) workstation.FryerMachine!.TryExecute(FryerCommand.Discard);
            using var press = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point };
            GetViewport().PushInput(press, true);
            bool dragging = service.IsDragging;
            service.CancelDrag();
            using var release = new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = point };
            GetViewport().PushInput(release, true);
            bool picked = rawPicking ? workstation.FryerMachine!.Runtime.Quantity == 1 && !dragging : dragging;
            Check(picked == expected, $"{(rawPicking ? "生油条点击" : "熟油条拖拽")}鼠标事件：{label}");
            return picked;
        }
    }

    private static bool StockSpritesRemainDistinct(WorkstationSlotView slot)
    {
        Rect2[] rectangles = slot.IngredientVisuals.Where(visual => visual.Visible)
            .Select(slot.IngredientBounds).ToArray();
        for (int left = 0; left < rectangles.Length; left++)
        for (int right = left + 1; right < rectangles.Length; right++)
            if (rectangles[left].Intersection(rectangles[right]).Area > Math.Min(rectangles[left].Area, rectangles[right].Area) * .85f) return false;
        return true;
    }
}
