using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.UI;
using ProjectCake.Wuhan;

namespace ProjectCake.Gameplay;

public partial class WuhanDayScreen
{
    internal TutorialFocusLayer TeachingFocus { get; private set; } = null!;
    private bool _teachingDoupiLast;
    private void BuildTeachingFocus()
    {
        TeachingFocus = new TutorialFocusLayer { CardSkin = TutorialFocusCardSkin.Wuhan, Resolve = ResolveTeachingFocus,
            DismissAtScreenEdge = true, ShowDismiss = () => !_controller.TutorialActive,
            KeepClear = TeachingClearAreas, PlaceNearTargets = true,
            PresentationCard = () => _demoLesson?.IsVisibleInTree() == true ? _demoLesson : null };
        AddChild(TeachingFocus);
    }
    private IEnumerable<TutorialFocusTarget> TeachingClearAreas()
    {
        foreach (var target in Workstation.TeachingClearAreas()) yield return target;
        foreach (var card in _orders)
            if (card.IsVisibleInTree()) yield return TutorialFocusTarget.Control(card, false);
    }
    private void LearnTeachingAction(string action)
    {
        _teachingDoupiLast = action.StartsWith("doupi:");
        if (_controller.TutorialActive) { _demoLearned.Add(action); return; }
        if (_save is null || !_save.Data.Wuhan.LearnedWorkbenchActions.Add(action)) return;
        if (!_save.TrySave(out string error)) Callable.From(() => Feedback(error, true)).CallDeferred();
    }
    private TutorialFocusStep? ResolveTeachingFocus()
    {
        var step = ResolveTeachingStep();
        // Share one moving card between the lesson and its current operation, as in Tianjin.
        if (_demoLesson?.Visible == true) LayoutWuhanDemoLesson(step);
        return step;
    }
    private TutorialFocusStep? ResolveTeachingStep()
    {
        if (!CanInteract || _controller.CurrentConfig?.CityId != StableIds.Cities.Wuhan || _cooker is null) return null;
        var learned = _controller.TutorialActive ? new HashSet<string>() : _save.Data.Wuhan.LearnedWorkbenchActions;
        var orders = TutorialOrders.Pending(_controller, _catalog);
        TutorialFocusStep? Step(string action, string text, params string[] targets) => learned.Contains(action) ? null
            : new(action, text, targets.Select(Workstation.TeachingTarget).ToArray());
        TutorialFocusStep? Delivery(ProductKind kind, string source, string name, string? recipe = null)
        {
            if (!Workstation.CanDeliver(kind)) return null;
            string action = kind == ProductKind.HotDryNoodles ? "deliver:hot_dry_noodles" : "deliver:doupi";
            if (learned.Contains(action)) return null;
            var ids = orders.Where(o => o.Kind == kind && (recipe is null || o.DefinitionId == recipe)).Select(o => o.CustomerId).ToHashSet();
            var targets = _deliveryCustomerIds.Select((id, i) => (id, i)).Where(p => p.id is not null && ids.Contains(p.id))
                .SelectMany(p => TutorialFocusTarget.Artwork(_customers[p.i])).ToArray();
            if (targets.Length == 0) return null;
            return new(action, Workstation.DraggedProduct == kind ? "松手交给亮起的顾客。" : $"把{name}拖给需要它的顾客。",
                Workstation.DraggedProduct == kind ? targets : new[] { Workstation.TeachingTarget(source) });
        }
        string? noodlesRecipe = _bowl.TryPrepare(_catalog.RecipesById, out var prepared) ? prepared.RecipeId : null;
        if (Workstation.DraggedProduct is ProductKind held)
            return held == ProductKind.Doupi ? Delivery(held, "stock", "熟豆皮") : Delivery(held, "bowl", "拌好的热干面", noodlesRecipe);
        string gesture = Workstation.TeachingGesture;
        if (Workstation.TeachingTrashActive) return Step("discard", "拖入垃圾桶，松手丢弃。", "trash");
        if (gesture == "raw")
            return Step("take:noodles", "把生面拖进空漏勺，松手下锅。", Enumerable.Range(0, _cooker.Baskets.Count)
                .Where(i => _cooker.Baskets[i].State == NoodleBasketState.Empty && !Workstation.Busy($"basket{i}")).Select(i => $"basket{i}").ToArray());
        if (gesture == "basket")
        {
            bool raised = _cooker.Baskets[Workstation.TeachingBasket].State is NoodleBasketState.Raised or NoodleBasketState.Draining or NoodleBasketState.Drained;
            return raised ? (_bowl.State == NoodleBowlState.Empty ? Step("pour:noodles", "把漏勺拖到空碗，沥干后自动倒入。", "bowl") : null)
                : Step("raise:noodles", "按住漏勺向上提起。", $"basket{Workstation.TeachingBasket}");
        }
        if (gesture == "batter") return _doupi?.State == DoupiState.Empty ? Step("doupi:batter", "把面浆拖入空锅后松手。", "pan") : null;
        if (gesture == "filling") return _doupi?.State == DoupiState.Flipped ? Step("doupi:filling", "把三鲜馅拖入锅内，松手自动铺匀。", "pan") : null;
        if (gesture == "flip") return Step("doupi:flip", "按住锅面向上划动翻面。", "pan");
        if (Workstation.IsKnifeHeld) return Step("doupi:cut", "沿虚线横划一次、竖划一次，切好后自动入盘。", "pan");
        if (Workstation.IsMixing) return Step("mix:noodles", "按住左键在碗里划动，直到酱料拌匀。", "bowl");

        TutorialFocusStep? Noodles()
        {
            if (Workstation.Busy("bowl")) return null;
            var order = orders.FirstOrDefault(o => o.Kind == ProductKind.HotDryNoodles && _bowl.Toppings.All(o.Toppings.Contains));
            if (_bowl.State == NoodleBowlState.Noodles) return Step("take:" + StableIds.Ingredients.WuhanBaseSeasoning, "点击基础调味，加入碗中。", "ingredient0");
            if (_bowl.State is NoodleBowlState.Seasoned or NoodleBowlState.Ready)
            {
                foreach (string id in order?.Toppings ?? Array.Empty<string>())
                {
                    if (_bowl.Toppings.Contains(id)) continue;
                    bool beef = id == StableIds.Ingredients.WuhanBraisedBeef;
                    if (beef != (_bowl.State == NoodleBowlState.Ready)) continue;
                    int i = Array.IndexOf(WuhanWorkstationView.IngredientIds, id);
                    if (i < 0) continue;
                    string name = beef ? "牛肉" : id == StableIds.Ingredients.WuhanScallion ? "葱花" : "辣油";
                    return Step("take:" + id, $"按订单点击{name}，加入碗中。", $"ingredient{i}");
                }
            }
            if (_bowl.State is NoodleBowlState.Seasoned or NoodleBowlState.Mixing)
                return Step("mix:noodles", "按住左键在碗里划动，直到酱料拌匀。", "bowl");
            if (_bowl.State == NoodleBowlState.Ready) return Delivery(ProductKind.HotDryNoodles, "bowl", "拌好的热干面", noodlesRecipe);
            for (int i = 0; i < _cooker.Baskets.Count; i++)
            {
                if (Workstation.Busy($"basket{i}")) continue;
                var state = _cooker.Baskets[i].State;
                if (state is NoodleBasketState.Raised or NoodleBasketState.Draining or NoodleBasketState.Drained)
                    return _bowl.State == NoodleBowlState.Empty ? Step("pour:noodles", "把漏勺拖到空碗，沥干后自动倒入。", $"basket{i}") : null;
                if (state is NoodleBasketState.Ready or NoodleBasketState.Soft or NoodleBasketState.Overcooked or NoodleBasketState.Locked)
                    return Step("raise:noodles", "漏勺亮起了，按住并向上提篮。", $"basket{i}");
                if (state != NoodleBasketState.Empty) return Step("raise:noodles", "等待面条煮好，漏勺亮起后向上提篮。", $"basket{i}");
            }
            return order is not null ? Step("take:noodles", "把生面拖进空漏勺。", "raw") : null;
        }
        TutorialFocusStep? Doupi()
        {
            if (_doupi is null || Workstation.Busy("pan")) return null;
            return _doupi.State switch {
                DoupiState.Empty when _doupiStock.Count > 0 => Delivery(ProductKind.Doupi, "stock", "熟豆皮"),
                DoupiState.Empty when orders.Any(o => o.Kind == ProductKind.Doupi) => Step("doupi:batter", "把面浆拖入空锅后松手。", "batter"),
                DoupiState.Batter => Step("doupi:egg", "点击蛋液容器，给面皮加蛋。", "doupi_egg"),
                DoupiState.SkinCooking => Step("doupi:flip", "等待面皮定型，再向上划动翻面。", "pan"),
                DoupiState.ReadyToFlip => Step("doupi:flip", "按住锅面向上划动翻面。", "pan"),
                DoupiState.Flipped => Step("doupi:filling", "把三鲜馅拖入锅内，松手自动铺匀。", "filling"),
                DoupiState.SecondCooking => Step("doupi:cut", "等待豆皮成熟，再拿小刀切块。", "pan"),
                DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cutting => Step("doupi:cut", "点击右下方小刀，再沿锅内虚线切块。", "knife"),
                DoupiState.Cut => Delivery(ProductKind.Doupi, "stock", "熟豆皮"),
                DoupiState.Burnt => Step("discard", "在焦豆皮上长按右键 0.45 秒，再拖入垃圾桶。", "pan"),
                _ => null,
            };
        }
        // Continue production already under way before introducing another workstation.
        if (_teachingDoupiLast && _doupi is not null && _doupi.State != DoupiState.Empty) { var step = Doupi(); if (step is not null) return step; }
        return Noodles() ?? Doupi();
    }
}
