using Godot;

namespace ProjectCake.Interaction;

public readonly record struct DragVisualSpec(Texture2D Texture, Vector2 DisplaySize);

public partial class DragItem : PanelContainer
{
    public event Action? StartRejected;

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
        if (@event is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true })
        {
            if (_dragService is not null && (_canStart?.Invoke() ?? true))
            {
                _dragService.BeginDrag(this, _payloadId, _displayName, _color, _visual);
            }
            else
            {
                StartRejected?.Invoke();
            }

            AcceptEvent();
        }
    }
}
