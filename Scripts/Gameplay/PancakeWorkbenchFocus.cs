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
        foreach (var progress in _focusProgress)
            if (progress.IsVisibleInTree()) yield return TutorialFocusTarget.Area(progress, new Rect2(0, 28, progress.Size.X, 12), false);
    }

    internal TutorialFocusStep? ResolveFocus(IReadOnlyList<TutorialOrder> orders, Func<ProductKind, string?, TutorialFocusTarget[]> recipients)
    {
        if (!_initialized || !CanInteract || !IsTianjinWorkbench) return null;
        var r = Machine.Runtime;
        string? FinishedRecipe() => PancakeTray.Selected is { } food ? orders.FirstOrDefault(o => o.Kind == ProductKind.Pancake && food.ExtraIngredients.SetEquals(o.Toppings))?.DefinitionId ?? "unmatched" : null;
        TutorialFocusTarget Surface() => TutorialFocusTarget.Ellipse(this, TianjinWorkbenchLayout.EmbeddedSurface);
        Texture2D Background() => _art.WorkbenchBackground(SoyMilkTray is not null ? new[] { ProductKind.SoyMilk }
            : FryerMachine is not null ? new[] { ProductKind.Youtiao } : Array.Empty<ProductKind>());
        TutorialFocusTarget Ingredient(string id) => TutorialFocusTarget.Background(this, Background(), IngredientOutline(id), id is "crispy" or "ham");
        TutorialFocusTarget Painted(TianjinPaintedObject id) {
            var matte = TianjinPaintedObjectContour.Get(Background(), id);
            var scale = new Vector2(1920, 1080) / Background().GetSize();
            return TutorialFocusTarget.Sprite(this, matte.Texture, new Rect2(matte.Bounds.Position * scale, matte.Bounds.Size * scale));
        }
        TutorialFocusStep? Step(string action, string text, params TutorialFocusTarget[] targets) =>
            NeedsTeaching(action) ? new(action, text, targets) : null;
        TutorialFocusStep? Take(string id, string text)
        {
            if (!Inventory.HasAvailable(id))
                return Inventory.CanRefill(id) ? Step("refill:" + id, $"按住{IngredientName(id)}料盒补货。", Ingredient(id)) : null;
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
        if (FocusPayload == TrashPayload) return Step("discard", "拖入垃圾桶，松手丢弃。", Painted(TianjinPaintedObject.Trash));
        if (FocusPayload == StoredYoutiaoPayload && r.State is PancakeState.Sauced or PancakeState.Toppings
            && !r.ExtraIngredients.Contains("youtiao") && orders.Any(o => o.Kind == ProductKind.Pancake && o.Toppings.Contains("youtiao") && r.ExtraIngredients.All(o.Toppings.Contains)))
            return Step("take:youtiao", "把熟油条拖入饼面后松手。", Surface());
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
        if (_focusLastChannel == "fryer" && r.State is not (PancakeState.BatterPlaced or PancakeState.Spreading or PancakeState.Saucing))
        { var step = FryerFocus(); if (step is not null) return step; }
        TutorialOrder? order = orders.FirstOrDefault(o => o.Kind == ProductKind.Pancake && r.ExtraIngredients.All(o.Toppings.Contains));
        if (r.State is PancakeState.Sauced or PancakeState.Toppings)
        {
            foreach (string id in order?.Toppings ?? Array.Empty<string>())
            {
                if (r.ExtraIngredients.Contains(id)) continue;
                if (id == "youtiao")
                {
                    if (FryerMachine?.Inventory.Count > 0)
                        return Step("take:youtiao", FocusPayload == StoredYoutiaoPayload ? "把熟油条拖入饼面后松手。" : "把熟油条拖入饼面。",
                            FocusPayload == StoredYoutiaoPayload ? new[] { Surface() } : TutorialFocusTarget.Artwork(_finishedYoutiaoSlot));
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
            PancakeState.SideAReady or PancakeState.SideAOverdone => Step("flip", "点击翻面，或按 F。", TutorialFocusTarget.Control(_flip)),
            PancakeState.SideBCooking => Step("take:sauce", "等第二面成熟，再拿刷子刷酱。", Surface()),
            PancakeState.SideBReady => Take("sauce", "点击酱碗拿刷子。"),
            PancakeState.Saucing => Step("sauce", "在饼面刷酱；达到订单酱量后短按右键收刷，或按 F。", Surface()),
            PancakeState.Sauced or PancakeState.Toppings => Step("fold", "配料已齐，点击折叠，或按 F。", TutorialFocusTarget.Control(_fold)),
            PancakeState.Folded => Step("bag", "点击装袋，或按 F。", TutorialFocusTarget.Control(_bag)),
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
            if (SoyMilkTray.Quantity < SoyMilkTray.Capacity && !SoyMilkTray.IsRefilling && !SoyMilkTray.IsTaking && NeedsTeaching("refill:soy_milk"))
                return Step("refill:soy_milk", "按住豆浆托盘补货。", Painted(TianjinPaintedObject.SoyTray));
            return Deliver(SoyMilkPayload, ProductKind.SoyMilk, _soyPanel, "豆浆");
        }
        return null;

        TutorialFocusStep? FryerFocus()
        {
            if (FryerMachine is null) return null;
            var f = FryerMachine.Runtime;
            var basket = _fryerVisual.TeachingBasketTarget();
            return f.State switch {
                FryerState.Empty or FryerState.Stored when FryerMachine.Inventory.Count == 0 => Step("fryer:load", "在炸锅上按住左键，装入油条。", basket),
                FryerState.Loaded => Step("fryer:lower", "点击下锅，或按 G。", TutorialFocusTarget.Control(_lowerBasket)),
                FryerState.Frying when !FryerMachine.Level.AutoRaise => Step("fryer:raise", f.Quality == YoutiaoQuality.Light ? "等待油条金黄，再升篮。" : "点击升篮，或按 G。", f.Quality == YoutiaoQuality.Light ? basket : TutorialFocusTarget.Control(_raiseBasket)),
                FryerState.Burnt => Step("discard", "在焦油条上长按右键，再拖入垃圾桶。", basket),
                _ => null,
            };
        }
    }
}
