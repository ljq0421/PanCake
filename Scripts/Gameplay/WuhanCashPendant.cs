using Godot;
using ProjectCake.Data;
using ProjectCake.Core;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class WuhanDayScreen
{
    internal Button CashPendant { get; private set; } = null!;
    internal BusinessDetailsView BusinessDetails { get; private set; } = null!;
    private readonly CashPendantFeedback _paymentFeedback = new();
    internal IReadOnlyCollection<Control> PaymentCoins => _paymentFeedback.Coins;
    private WuhanActionAudio _bookAudio = null!;
    private bool _detailsPaused;
    private Control? _detailsReturnFocus;

    private void BuildCashPendant()
    {
        _bookAudio = new WuhanActionAudio(this);
        Rect2 bounds = WuhanWorkbenchLayout.CashPendant;
        CashPendant = new Button { Name = "CashPendant", Position = bounds.Position, Size = bounds.Size,
            MouseDefaultCursorShape = CursorShape.PointingHand, ZIndex = 80 };
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled", "focus" })
            CashPendant.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        AddChild(CashPendant);
        // Trace the pouch, bow and tassel on the 1920 x 1080 scene canvas.
        Vector2[] pendantEdge = { new(1841, 195), new(1859, 196), new(1866, 202), new(1878, 205),
            new(1887, 216), new(1885, 228), new(1877, 240), new(1884, 250), new(1891, 262),
            new(1895, 274), new(1900, 286), new(1900, 364), new(1873, 379), new(1830, 375),
            new(1830, 387), new(1826, 392), new(1828, 399), new(1837, 429), new(1837, 436),
            new(1828, 442), new(1809, 439), new(1801, 433), new(1807, 404), new(1810, 398),
            new(1806, 391), new(1811, 382), new(1811, 371), new(1773, 364), new(1766, 357),
            new(1764, 290), new(1772, 275), new(1777, 263), new(1791, 244), new(1812, 218),
            new(1812, 207), new(1823, 201), new(1833, 205) };
        PathContourHighlight.Attach(CashPendant,
            pendantEdge.Select(point => point - bounds.Position).ToArray(),
            () => CashPendant.Disabled ? InteractionHighlightState.None
                : CashPendant.IsHovered() || CashPendant.HasFocus() ? InteractionHighlightState.Hover : InteractionHighlightState.None);
        CashPendant.Pressed += OpenBusinessDetails;
        BusinessDetails = new BusinessDetailsView { Name = "BusinessDetails" };
        AddChild(BusinessDetails);
        BusinessDetails.PageChanged += () => _bookAudio.Play(WuhanSound.Page);
        BusinessDetails.CloseRequested += () => { if (BusinessDetails.Model.Closing) { _bookAudio.Play(WuhanSound.BookClose); BusinessDetails.Hide(); HubRequested?.Invoke(); } else CloseBusinessDetails(); };
    }

    private void ApplyPendantPause()
    {
        if (_controller is not null)
        {
            _controller.SetPauseReason("wuhan-details", _detailsPaused);
            _controller.SetPauseReason("wuhan-focus", !_focused && IsVisibleInTree());
        }
        UpdatePendantState();
    }

    private void UpdatePendantState()
    {
        _bookAudio?.SetPaused(!_focused || !IsVisibleInTree());
        _paymentFeedback.SetPaused(!_focused || _detailsPaused || _controller?.IsPaused == true || _abandon?.Visible == true);
        if (CashPendant is not null)
            CashPendant.Disabled = !CanInteract || DeliveryDrag.IsDragging || Workstation.HasProductionGesture;
    }

    internal void OpenBusinessDetails()
    {
        if (!CanInteract || DeliveryDrag.IsDragging || Workstation.HasProductionGesture || _controller.Ledger is null) return;
        _bookAudio.Play(WuhanSound.BookOpen);
        _detailsReturnFocus = GetViewport().GuiGetFocusOwner();
        Workstation.CancelInput();
        _detailsPaused = true;
        ApplyPendantPause();
        BusinessDetails.Open(BusinessBookModel.From(StableIds.Cities.Wuhan, _controller.Ledger.Build(), _controller.BusinessRecords, _catalog));
    }

    internal void CloseBusinessDetails()
    {
        if (BusinessDetails is null) return;
        BusinessDetails.Hide();
        bool wasOpen = _detailsPaused;
        if (wasOpen && IsVisibleInTree() && !_committed) _bookAudio.Play(WuhanSound.BookClose);
        _detailsPaused = false;
        ApplyPendantPause();
        if (wasOpen && CanInteract)
        {
            if (IsInstanceValid(_detailsReturnFocus) && _detailsReturnFocus!.IsVisibleInTree()) _detailsReturnFocus.GrabFocus();
            else CashPendant.GrabFocus();
        }
        _detailsReturnFocus = null;
    }

    private void ClearPendantOnExit()
    {
        _paymentFeedback.Clear();
        if (IsInstanceValid(_controller))
        {
            _controller.SetPauseReason("wuhan-details", false);
            _controller.SetPauseReason("wuhan-focus", false);
        }
    }
}
