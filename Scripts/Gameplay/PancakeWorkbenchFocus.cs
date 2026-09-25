using Godot;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Inventory;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    internal string FocusPayload => _drag.IsDragging ? _focusPayload : "";
    private string _focusPayload = "";
    private string _focusLastChannel = "pancake";
    private EquipmentProgressView[] _focusProgress = Array.Empty<EquipmentProgressView>();
    internal void BindFocusDrag()
    {
        _drag.DragStarted += payload => _focusPayload = payload;
        _focusProgress = FindChildren("*", "", true, false).OfType<EquipmentProgressView>().ToArray();
        // Only the held brush/scraper is drawn by this node, above the pass-through shade.
        _stroke.ZAsRelative = false; _stroke.ZIndex = 86;
    }

    internal IEnumerable<TutorialFocusTarget> FocusClearAreas()
    {
        if (_stroke.SauceMeterVisible)
            yield return TutorialFocusTarget.Area(_stroke, _stroke.SauceMeterBounds(), false);
        foreach (var progress in _focusProgress)
            if (progress.IsVisibleInTree()) yield return TutorialFocusTarget.Area(progress, new Rect2(0, 28, progress.Size.X, 12), false);
    }

    internal TutorialFocusStep? ResolveFocus(IReadOnlyList<TutorialOrder> orders, Func<ProductKind, string?, TutorialFocusTarget[]> recipients)
    {
        if (!_initialized || !CanInteract || !IsTianjinWorkbench) return null;
        if (NeedsSupplyIntroduction && FocusPayload.Length == 0)
        {
            if (SupplyNpcCalled && SupplyNpcFocusTarget is Control helper)
                return new(SupplyIntroductionAction, "点击左侧送货员，每次补充一份食材；满库存时送货员会离开。", new[] { TutorialFocusTarget.Control(helper) });
            if (SupplyBellFocusTarget is Control bell)
                return new(SupplyIntroductionAction, "点击煎饼炉左上方的铃叫来送货员，再点击送货员补充食材。", new[] { TutorialFocusTarget.Control(bell) });
        }
        var r = Machine.Runtime;
        string? FinishedRecipe() => PancakeTray.Selected is { } food ? orders.FirstOrDefault(o => o.Kind == ProductKind.Pancake && food.ExtraIngredients.SetEquals(o.Toppings))?.DefinitionId ?? "unmatched" : null;
        TutorialFocusTarget Surface() => TutorialFocusTarget.Ellipse(this, TianjinWorkbenchLayout.EmbeddedSurface);
        Texture2D Background() => _art.WorkbenchBackground(SoyMilkTray is not null ? new[] { ProductKind.SoyMilk }
            : FryerMachine is not null ? new[] { ProductKind.Youtiao } : Array.Empty<ProductKind>());
        TutorialFocusTarget Ingredient(string id) => id == StableIds.Ingredients.Sauce
            ? Painted(TianjinPaintedObject.Sauce)
            : TutorialFocusTarget.Background(this, Background(), IngredientOutline(id), id is "crispy" or "ham");
        TutorialFocusTarget Painted(TianjinPaintedObject id) {
            var matte = TianjinPaintedObjectContour.Get(Background(), id);
            var scale = new Vector2(1920, 1080) / Background().GetSize();
            return TutorialFocusTarget.Sprite(this, matte.Texture, new Rect2(matte.Bounds.Position * scale, matte.Bounds.Size * scale));
        }
        TutorialFocusStep? Step(string action, string text, params TutorialFocusTarget[] targets) =>
            NeedsTeaching(action) ? new(action, text, targets) : null;
        TutorialFocusStep? RefillFocus(string id) => Step("refill:" + id,
            Inventory.IsRefilling(id) ? $"{IngredientName(id)}补货中，等待补满。"
                : SupplyNpcCalled ? $"继续点击左侧送货员，每次补一份{IngredientName(id)}。"
                : "点击煎饼炉左上方的叫货铃，叫来送货员。",
            SupplyNpcCalled && SupplyNpcFocusTarget is Control npc ? TutorialFocusTarget.Control(npc)
                : SupplyBellFocusTarget is Control bell ? TutorialFocusTarget.Control(bell) : Ingredient(id));
        TutorialFocusStep? Take(string id, string text)
        {
            if (!Inventory.HasAvailable(id))
                return Inventory.CanRefill(id) || Inventory.IsRefilling(id) ? RefillFocus(id) : null;
            return Step("take:" + id, text, Ingredient(id));
        }
        TutorialFocusStep? Deliver(string payload, ProductKind kind, Control source, string name, string? recipe = null)
        {
            if (!CanDeliverProduct(payload)) return null;
            var customers = recipients(kind, recipe);
            if (customers.Length == 0) return null;
            return Step("deliver:" + payload, FocusPayload == payload ? $"松手交给亮起的顾客。" : $"把{name}拖给需要它的顾客。",
                FocusPayload == payload ? customers : TutorialFocusTarget.Artwork(source == _storedYoutiao ? _finishedYoutiaoSlot : source));
        }
        TutorialFocusStep? AddYoutiaoToPancake(bool dragging) => Step("take:youtiao",
            dragging ? "把熟油条拖入饼面后松手。" : "把熟油条拖入饼面。",
            dragging ? new[] { Surface() } : TutorialFocusTarget.Artwork(_finishedYoutiaoSlot));
        if (FocusPayload == TrashPayload) return Step("discard", "拖入垃圾桶，松手丢弃。", Painted(TianjinPaintedObject.Trash));
        if (FocusPayload == StoredYoutiaoPayload && r.State is PancakeState.Sauced or PancakeState.Toppings
            && !r.ExtraIngredients.Contains("youtiao") && orders.Any(o => o.Kind == ProductKind.Pancake && o.Toppings.Contains("youtiao") && r.ExtraIngredients.All(o.Toppings.Contains)))
            return AddYoutiaoToPancake(dragging: true);
        if (FocusPayload is "finished_pancake" or SoyMilkPayload or StoredYoutiaoPayload)
            return FocusPayload switch {
                "finished_pancake" => Deliver("finished_pancake", ProductKind.Pancake, _finished, "装袋的煎饼", FinishedRecipe()),
                SoyMilkPayload => Deliver(SoyMilkPayload, ProductKind.SoyMilk, _soyPanel, "豆浆"),
                _ => Deliver(StoredYoutiaoPayload, ProductKind.Youtiao, _storedYoutiao, "熟油条"),
            };
        if (FocusPayload.Length > 0 && FocusPayload != StoredYoutiaoPayload)
        {
            string id = FocusPayload;
            if (CanDrop(id) && (id == "batter" || _ingredientSlots.ContainsKey(id))) return Step("take:" + id, $"把{IngredientName(id)}拖到饼面后松手。", Surface());
            return null;
        }
        // Urgent cleanup precedes idle production hints, even when the fryer was used last.
        if (r.State == PancakeState.Burnt && NeedsTeaching("discard"))
            return Step("discard", "在焦饼上长按右键 0.45 秒，再拖入垃圾桶。", Surface());
        bool busyStroke = r.State is PancakeState.BatterPlaced or PancakeState.Spreading or PancakeState.Saucing;
        if (!busyStroke && FryerMachine?.Runtime.State == FryerState.Burnt && NeedsTeaching("discard"))
            return FryerFocus();
        // Offer low-stock help in a safe gap, before the next pancake, without stealing a delivery.
        // Missing ingredients in an active recipe are handled immediately by Take above.
        if (!IsTransferringBag && r.State == PancakeState.Empty && !HasFinishedPancake)
        {
            foreach (string id in _ingredientSlots.Keys.Where(_enabledIngredients.Contains).OrderBy(id => id, StringComparer.Ordinal))
                if (!(id == StableIds.Ingredients.Egg && _deferEggRefillToRecipe)
                    && NeedsTeaching("refill:" + id)
                    && (Inventory.GetStatus(id) is IngredientStockStatus.Low or IngredientStockStatus.Empty or IngredientStockStatus.Refilling
                        || SupplyNpcCalled && NextMissingSupply() == id))
                    return RefillFocus(id);
            if (SoyMilkTray is { IsTaking: false } soy && NeedsTeaching("refill:soy_milk")
                && (soy.Quantity <= 2 || soy.IsRefilling || SupplyNpcCalled && NextMissingSupply() == "soy_milk"))
                return SoyRefillFocus();
        }
        TutorialOrder? order = orders.FirstOrDefault(o => o.Kind == ProductKind.Pancake && r.ExtraIngredients.All(o.Toppings.Contains));
        string? blockedIngredient = r.State is PancakeState.Spread or PancakeState.SideACooking && !r.HasEgg && !Inventory.HasAvailable("egg")
            ? "egg" : r.State is PancakeState.Sauced or PancakeState.Toppings
                ? order?.Toppings.FirstOrDefault(id => _ingredientSlots.ContainsKey(id) && _enabledIngredients.Contains(id) && !r.ExtraIngredients.Contains(id) && !Inventory.HasAvailable(id)) : null;
        if (blockedIngredient is not null && NeedsTeaching("refill:" + blockedIngredient)) return RefillFocus(blockedIngredient);
        if (_focusLastChannel == "fryer" && !busyStroke)
        { var step = FryerFocus(); if (step is not null) return step; }
        if (r.State is PancakeState.Sauced or PancakeState.Toppings)
        {
            foreach (string id in order?.Toppings ?? Array.Empty<string>())
            {
                if (r.ExtraIngredients.Contains(id)) continue;
                if (id == "youtiao")
                {
                    if (FryerMachine?.Inventory.Count > 0)
                        return AddYoutiaoToPancake(FocusPayload == StoredYoutiaoPayload);
                    return FryerFocus();
                }
                if (!_enabledIngredients.Contains(id)) continue;
                return Take(id, id == "scallion" ? "点击香葱，加入这份煎饼。" : $"把{IngredientName(id)}拖入饼面。");
            }
        }
        TutorialFocusStep? pancake = r.State switch {
            PancakeState.Empty when HasFinishedPancake => Deliver("finished_pancake", ProductKind.Pancake, _finished, "装袋的煎饼", FinishedRecipe()),
            PancakeState.Empty when order is not null => Take("batter", "把面糊拖到中间饼炉。"),
            PancakeState.BatterPlaced or PancakeState.Spreading => Step("spread", "按住左键在面糊上划动，摊成一张饼。", Surface()),
            PancakeState.Spread or PancakeState.SideACooking when !r.HasEgg => Take("egg", "点击鸡蛋，把蛋打到饼上。"),
            PancakeState.SideACooking => Step("flip", "等第一面成熟，再翻面。", Surface()),
            PancakeState.SideAReady or PancakeState.SideAOverdone => Step("flip", "点击饼皮翻面；也可按 F。", Surface()),
            PancakeState.SideBCooking => Step("take:sauce", "等第二面成熟，再拿刷子刷酱。", Surface()),
            PancakeState.SideBReady => Take("sauce", "点击酱碗拿刷子。"),
            PancakeState.Saucing => Step("sauce", "在饼面刷酱；达到订单酱量后短按右键收刷，或按 F。", Surface()),
            PancakeState.Sauced or PancakeState.Toppings => Step("fold", "配料已齐，用小铲子从左侧或右侧推向对侧后松手；也可按 F。", Surface()),
            PancakeState.Folded => Step("bag", _directGesture == DirectGesture.Bag ? "用小铲子把纸袋推到煎饼上，松手套袋。" : "用小铲子取左侧纸袋，推到煎饼上套袋；也可按 F。", _directGesture == DirectGesture.Bag ? new[] { Surface() } : new[] { Painted(TianjinPaintedObject.BagStack) }),
            PancakeState.Bagged => Deliver("finished_pancake", ProductKind.Pancake, _finished, "装袋的煎饼", FinishedRecipe()),
            PancakeState.Burnt => Step("discard", "在焦饼上长按右键 0.45 秒，再拖入垃圾桶。", Surface()),
            _ => null,
        };
        if (pancake is not null) return pancake;
        if (FryerMachine is not null && (orders.Any(o => o.Kind == ProductKind.Youtiao || o.Toppings.Contains("youtiao"))
            || FryerMachine.Runtime.State is not (FryerState.Empty or FryerState.Stored)))
        {
            var fryer = FryerFocus(); if (fryer is not null) return fryer;
            var delivery = Deliver(StoredYoutiaoPayload, ProductKind.Youtiao, _storedYoutiao, "熟油条"); if (delivery is not null) return delivery;
        }
        if (SoyMilkTray is not null && orders.Any(o => o.Kind == ProductKind.SoyMilk))
        {
            if (!busyStroke && !SoyMilkTray.IsTaking && NeedsTeaching("refill:soy_milk") && (SoyMilkTray.Quantity == 0 || SoyMilkTray.IsRefilling))
                return SoyRefillFocus();
            return Deliver(SoyMilkPayload, ProductKind.SoyMilk, _soyPanel, "豆浆");
        }
        return null;

        TutorialFocusStep? SoyRefillFocus() => Step("refill:soy_milk", SoyMilkTray!.IsRefilling
            ? "豆浆补货中，等待补满。"
            : SupplyNpcCalled ? "继续点击左侧送货员，每次补一杯豆浆。"
            : "点击煎饼炉左上方的叫货铃，叫来送货员。",
            SupplyNpcCalled && SupplyNpcFocusTarget is Control npc ? TutorialFocusTarget.Control(npc)
                : SupplyBellFocusTarget is Control bell ? TutorialFocusTarget.Control(bell) : Painted(TianjinPaintedObject.SoyTray));

        TutorialFocusStep? FryerFocus()
        {
            if (FryerMachine is null) return null;
            var f = FryerMachine.Runtime;
            var basket = _fryerVisual.TeachingBasketTarget();
            return f.State switch {
                FryerState.Empty or FryerState.Stored when FryerMachine.Inventory.Count == 0 => Step("fryer:load", "在炸锅上按住左键，装入油条。", basket),
                FryerState.Loaded => Step("fryer:lower", "点击炸锅锅体下锅，或按 G。", TutorialFocusTarget.Control(_fryerVisual)),
                FryerState.Frying when !FryerMachine.Level.AutoRaise => Step("fryer:raise", f.Quality == YoutiaoQuality.Light ? "等待油条金黄，再点击炸锅锅体提篮。" : "点击炸锅锅体提篮，或按 G。", TutorialFocusTarget.Control(_fryerVisual)),
                FryerState.Burnt => Step("discard", "在焦油条上长按右键 0.45 秒，再拖入垃圾桶。", basket),
                _ => null,
            };
        }
    }
}
