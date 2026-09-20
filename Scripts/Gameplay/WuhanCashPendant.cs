using Godot;
using ProjectCake.Data;
using ProjectCake.Core;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class WuhanDayScreen
{
    internal Button CashPendant { get; private set; } = null!;
    internal TextureRect CashPendantArtwork { get; private set; } = null!;
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
        CashPendantArtwork = new TextureRect { Name = "CashPendantArtwork", Position = bounds.Position,
            Size = bounds.Size, Texture = _art.Texture("cash_pendant"), MouseFilter = MouseFilterEnum.Ignore,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, StretchMode = TextureRect.StretchModeEnum.Scale,
            ZIndex = 80 };
        AddChild(CashPendantArtwork);
        ArtContourHighlight.Attach(CashPendantArtwork,
            () => CashPendant.Disabled ? InteractionHighlightState.None
                : CashPendant.IsHovered() || CashPendant.HasFocus() ? InteractionHighlightState.Hover : InteractionHighlightState.None);
        ButtonHoverFeedback.Attach(CashPendant, CashPendantArtwork, () => CanInteract);
        CashPendant.Pressed += OpenBusinessDetails;
        BusinessDetails = new BusinessDetailsView { Name = "BusinessDetails" };
        AddChild(BusinessDetails);
        BusinessDetails.RetryRequested += RetryWuhanDemoSettlement;
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
