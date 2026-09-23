using Godot;

namespace ProjectCake.UI;

// An engine-rendered cursor stays attached to the grabbed edge even outside the
// stroke control, scales with the viewport, and is included in viewport captures.
public partial class PancakePinchCursor : TextureRect
{
    public Func<Vector2, bool>? ShouldShow { get; set; }
    private bool _ownsCursor;
    private Vector2 _pointer;
    public override void _Ready()
    {
        Texture = GD.Load<Texture2D>("res://resource/art/TianJin/捏住饼边光标.png");
        ExpandMode = ExpandModeEnum.IgnoreSize;
        Size = new Vector2(76, 76);
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
        if (!_ownsCursor)
        {
            if (Input.MouseMode != Input.MouseModeEnum.Visible) return;
            Input.MouseMode = Input.MouseModeEnum.Hidden;
            _ownsCursor = true;
        }
        // Contact between the thumb and index finger in the 128px texture.
        Position = GetParent<CanvasItem>().GetGlobalTransformWithCanvas().AffineInverse() * point
            - new Vector2(8, 16);
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
