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
        TeachingFocus = new TutorialFocusLayer { CardSkin = TutorialFocusCardSkin.Tianjin, Resolve = ResolveTeachingFocus, KeepClear = TeachingClearAreas };
        AddChild(TeachingFocus);
    }
    private IEnumerable<TutorialFocusTarget> TeachingClearAreas()
    {
        foreach (var target in _workstation.FocusClearAreas()) yield return target;
        if (_demoGesture?.IsVisibleInTree() == true) yield return TutorialFocusTarget.Control(_demoGesture, false);
    }
    private TutorialFocusStep? ResolveTeachingFocus()
    {
        if (_controller?.CurrentConfig?.CityId != StableIds.Cities.Tianjin || !_focused || _manualPaused || _focusPaused || _detailsPaused
            || _abandonDialog.Visible || _controller.IsPaused || _committed || _demoLessonComplete
            || _controller.State is not (DayState.Running or DayState.Closing)) return null;
        var orders = TutorialOrders.Pending(_controller, _catalog);
        TutorialFocusTarget[] Recipients(ProductKind kind, string? recipe)
        {
            var ids = orders.Where(o => o.Kind == kind && (recipe is null || o.DefinitionId == recipe)).Select(o => o.CustomerId).ToHashSet();
            return _deliveryCustomerIds.Select((id, i) => (id, i)).Where(p => p.id is not null && ids.Contains(p.id))
                .SelectMany(p => TutorialFocusTarget.Artwork(_customerSlots[p.i])).ToArray();
        }
        var step = _workstation.ResolveFocus(orders, Recipients);
        // The guided example keeps its existing skip/completion controls and one source of step copy.
        if (step is not null && _demoLesson?.Visible == true && _controller.TutorialActive)
            _demoLessonHint!.Text = step.Text;
        return step;
    }
}
