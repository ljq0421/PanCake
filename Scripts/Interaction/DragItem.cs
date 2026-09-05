using Godot;

namespace ProjectCake.Interaction;

public readonly record struct DragVisualSpec(Texture2D Texture, Vector2 DisplaySize);

public partial class DragItem : PanelContainer
{
    public event Action? StartRejected;
    public event Action? Invoked;

    private DragService? _dragService;
    private Func<bool>? _canStart;
    private string _payloadId = string.Empty;
    private string _displayName = string.Empty;
    private Color _color = Colors.White;
    private DragVisualSpec? _visual;
    private bool _clickEnabled;
    private bool _pressPending;
    private Vector2 _pressPosition;
    private float _dragThreshold = 10.0f;

    public void Configure(
        DragService dragService,
        string payloadId,
        string displayName,
        Color color,
        Func<bool>? canStart = null)
    {
        _dragService = dragService;
        _payloadId = payloadId;
        _displayName = displayName;
        _color = color;
        _visual = null;
        _canStart = canStart;
        MouseDefaultCursorShape = CursorShape.PointingHand;
    }

    public void Configure(
        DragService dragService,
        string payloadId,
        string displayName,
        Color color,
        DragVisualSpec visual,
        Func<bool>? canStart = null)
    {
        Configure(dragService, payloadId, displayName, color, canStart);
        _visual = visual;
    }

    public override void _GuiInput(InputEvent @event)
    {
        if (@event is not InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true })
        {
            return;
        }

        if (_dragService is null || !(_canStart?.Invoke() ?? true))
        {
            StartRejected?.Invoke();
            AcceptEvent();
            return;
        }

        if (_clickEnabled)
        {
            _pressPending = true;
            _pressPosition = GetGlobalMousePosition();
            SetProcessInput(true);
        }
        else
        {
            _dragService.BeginDrag(this, _payloadId, _displayName, _color, _visual);
        }

        AcceptEvent();
    }

    public void EnableClick(Action action, float dragThreshold = 10.0f)
    {
        Invoked += action;
        _clickEnabled = true;
        _dragThreshold = Math.Max(1.0f, dragThreshold);
    }

    public void CancelPendingInput()
    {
        _pressPending = false;
        SetProcessInput(false);
    }

    public override void _Input(InputEvent @event)
    {
        if (!_pressPending)
        {
            return;
        }

        if (@event is InputEventMouseMotion motion && motion.Position.DistanceTo(_pressPosition) >= _dragThreshold)
        {
            _pressPending = false;
            SetProcessInput(false);
            _dragService?.BeginDrag(this, _payloadId, _displayName, _color, _visual);
            GetViewport().SetInputAsHandled();
        }
        else if (@event is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: false })
        {
            _pressPending = false;
            SetProcessInput(false);
            Invoked?.Invoke();
            GetViewport().SetInputAsHandled();
        }
    }
}
