using Godot;
using ProjectCake.Core;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class WuhanDayScreen
{
    internal Button CashPendant { get; private set; } = null!;
    internal BusinessDetailsView BusinessDetails { get; private set; } = null!;
    private readonly CashPendantFeedback _paymentFeedback = new();
    internal IReadOnlyCollection<Control> PaymentCoins => _paymentFeedback.Coins;
    private bool _detailsPaused;
    private Control? _detailsReturnFocus;

    private void BuildCashPendant()
    {
        Rect2 bounds = WuhanWorkbenchLayout.CashPendant;
        CashPendant = new Button { Name = "CashPendant", Position = bounds.Position, Size = bounds.Size,
            TooltipText = "查看营业明细", MouseDefaultCursorShape = CursorShape.PointingHand, ZIndex = 80 };
        foreach (string state in new[] { "normal", "hover", "pressed", "disabled" })
            CashPendant.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        var focus = TianjinUi.Box(Colors.Transparent, 20, 2, false);
        focus.BorderColor = TianjinUi.Yellow;
        CashPendant.AddThemeStyleboxOverride("focus", focus);
        AddChild(CashPendant);
        CashPendant.Pressed += OpenBusinessDetails;
        BusinessDetails = new BusinessDetailsView { Name = "BusinessDetails" };
        AddChild(BusinessDetails);
        BusinessDetails.CloseRequested += CloseBusinessDetails;
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
        _paymentFeedback.SetPaused(!_focused || _detailsPaused || _controller?.IsPaused == true || _abandon?.Visible == true);
        if (CashPendant is not null)
            CashPendant.Disabled = !CanInteract || DeliveryDrag.IsDragging || Workstation.HasProductionGesture;
    }

    internal void OpenBusinessDetails()
    {
        if (!CanInteract || DeliveryDrag.IsDragging || Workstation.HasProductionGesture || _controller.Ledger is null) return;
        _detailsReturnFocus = GetViewport().GuiGetFocusOwner();
        Workstation.CancelInput();
        _detailsPaused = true;
        ApplyPendantPause();
        BusinessDetails.Open(_controller.Ledger.Build(), _controller.BusinessRecords, _catalog);
    }

    internal void CloseBusinessDetails()
    {
        if (BusinessDetails is null) return;
        BusinessDetails.Hide();
        bool wasOpen = _detailsPaused;
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
