using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class TianjinDayScreen
{
    internal TutorialFocusLayer TeachingFocus { get; private set; } = null!;
    private bool _deliveryTeaches;
    private void BuildTeachingFocus()
    {
        _workstation.BindFocusDrag();
        TeachingFocus = new TutorialFocusLayer { CardSkin = TutorialFocusCardSkin.Tianjin, Resolve = ResolveTeachingFocus,
            KeepClear = TeachingClearAreas, PlaceNearTargets = true,
            DismissAtScreenEdge = true, ShowDismiss = () => !_controller.TutorialActive,
            PresentationCard = () => _demoLesson?.IsVisibleInTree() == true ? _demoLesson : null };
        AddChild(TeachingFocus);
        _workstation.IsRefillTeachingActive = () => TeachingFocus.CurrentAction == PancakeWorkstation.SupplyIntroductionAction
            || TeachingFocus.CurrentAction?.StartsWith("refill:", StringComparison.Ordinal) == true;
    }
    private IEnumerable<TutorialFocusTarget> TeachingClearAreas()
    {
        foreach (var target in _workstation.FocusClearAreas()) yield return target;
        foreach (var card in _orderCards)
            if (card.IsVisibleInTree()) yield return TutorialFocusTarget.Control(card, false);
    }
    private TutorialFocusStep? ResolveTeachingFocus()
    {
        if (_controller?.CurrentConfig?.CityId != StableIds.Cities.Tianjin || !_focused || _manualPaused || _focusPaused || _detailsPaused
            || _abandonDialog.Visible || _controller.IsPaused || _committed || _demoLessonComplete || DemoLessonFailed
            || _controller.State is not (DayState.Running or DayState.Closing))
        {
            _controller?.SetBusinessClockFrozen("tianjin-refill-teaching", false);
            return null;
        }
        var orders = TutorialOrders.Pending(_controller, _catalog);
        TutorialFocusTarget[] Recipients(ProductKind kind, string? recipe)
        {
            var ids = orders.Where(o => o.Kind == kind && (recipe is null || o.DefinitionId == recipe)).Select(o => o.CustomerId).ToHashSet();
            return _deliveryCustomerIds.Select((id, i) => (id, i)).Where(p => p.id is not null && ids.Contains(p.id))
                .SelectMany(p => TutorialFocusTarget.Artwork(_customerSlots[p.i])).ToArray();
        }
        var step = _workstation.ResolveFocus(orders, Recipients);
        _controller.SetBusinessClockFrozen("tianjin-refill-teaching", step?.ActionId == PancakeWorkstation.SupplyIntroductionAction
            || step?.ActionId.StartsWith("refill:", StringComparison.Ordinal) == true);
        // One card owns the current instruction and the lesson action; the focus layer only spotlights it.
        if (_demoLesson?.Visible == true)
        {
            if (_demoLessonSaveError.Length == 0 && (step is not null || _controller.TutorialActive))
            {
                _demoLessonHint!.Text = step?.Text ?? "";
                _demoLessonHint.Visible = step is not null;
            }
            LayoutDemoLesson();
            if (step is null) RestDemoLesson();
        }
        return step;
    }
}
