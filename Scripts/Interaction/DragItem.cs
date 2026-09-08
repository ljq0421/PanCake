using Godot;

namespace ProjectCake.Interaction;

public readonly record struct DragVisualSpec(Texture2D Texture, Vector2 DisplaySize, Func<Control>? PreviewFactory = null);

public partial class DragItem : PanelContainer
{
    public event Action? StartRejected;

    public Func<Vector2, bool>? HitTest { get; set; }

    public override bool _HasPoint(Vector2 point) =>
        new Rect2(Vector2.Zero, Size).HasPoint(point) && (HitTest?.Invoke(point) ?? true);

    private DragService? _dragService;
    private Func<bool>? _canStart;
    private string _payloadId = string.Empty;
    private string _displayName = string.Empty;
    private Color _color = Colors.White;
    private DragVisualSpec? _visual;

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

        TryBeginDrag();
        AcceptEvent();
    }

    internal void TryBeginDrag()
    {
        if (_dragService is null || !(_canStart?.Invoke() ?? true))
        {
            StartRejected?.Invoke();
            return;
        }

        _dragService.BeginDrag(this, _payloadId, _displayName, _color, _visual);

    }
}
