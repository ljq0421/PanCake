using Godot;

namespace ProjectCake.UI;

// An engine-rendered spatula stays attached to the active work area even outside
// the stroke control, scales with the viewport, and is included in viewport captures.
public partial class PancakeSpatulaCursor : TextureRect
{
    public Func<Vector2, bool>? ShouldShow { get; set; }
    public Func<Vector2, bool>? ShouldUsePinchHand { get; set; }
    private bool _ownsCursor;
    private Vector2 _pointer;
    private bool _usingPinchHand;

    private const string SpatulaPath = "res://resource/art/TianJin/煎饼铲子.png";
    private const string PinchHandPath = "res://resource/art/TianJin/捏住饼边光标.png";

    public override void _Ready()
    {
        Texture = GD.Load<Texture2D>(SpatulaPath);
        ExpandMode = ExpandModeEnum.IgnoreSize;
        Size = new Vector2(112, 112);
        MouseFilter = MouseFilterEnum.Ignore;
        ZIndex = 4095;
        Hide();
    }

    public override void _Input(InputEvent input)
    {
        // Use the same viewport-space event as the food gesture. Polling the OS
        // pointer separately can disagree during resize or replayed input.
        if (input is InputEventMouse mouse) _pointer = mouse.Position;
    }

    public override void _Process(double delta)
    {
        Vector2 point = _pointer;
        bool show = GetWindow().HasFocus() && GetParent<CanvasItem>().IsVisibleInTree()
            && ShouldShow?.Invoke(point) == true;
        if (!show) { ReleaseCursor(); return; }
        bool usePinchHand = ShouldUsePinchHand?.Invoke(point) == true;
        if (_usingPinchHand != usePinchHand)
        {
            _usingPinchHand = usePinchHand;
            Texture = GD.Load<Texture2D>(usePinchHand ? PinchHandPath : SpatulaPath);
        }
        if (!_ownsCursor)
        {
            if (Input.MouseMode != Input.MouseModeEnum.Visible) return;
            Input.MouseMode = Input.MouseModeEnum.Hidden;
            _ownsCursor = true;
        }
        // Both tools use the point that touches the food as their hotspot.
        Position = GetParent<CanvasItem>().GetGlobalTransformWithCanvas().AffineInverse() * point
            - (usePinchHand ? new Vector2(27, 33) : new Vector2(25, 91));
        Show();
    }

    public void ReleaseCursor()
    {
        Hide();
        if (!_ownsCursor) return;
        if (Input.MouseMode == Input.MouseModeEnum.Hidden) Input.MouseMode = Input.MouseModeEnum.Visible;
        _ownsCursor = false;
    }

    public override void _ExitTree() => ReleaseCursor();
}
