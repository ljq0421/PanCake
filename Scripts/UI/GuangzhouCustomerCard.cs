using Godot;

namespace ProjectCake.UI;

public partial class GuangzhouCustomerCard : Button
{
    public Action? DeliveryRejected { get; set; }
    private bool _rejectedDrop, _cancelledDrop, _dropReleasedHere;
    public override void _Notification(int what)
    {
        if (what == NotificationDragBegin) { _rejectedDrop = false; _cancelledDrop = false; _dropReleasedHere = false; }
        if (what != NotificationDragEnd) return;
        bool rejected = _rejectedDrop && !_cancelledDrop && !GetViewport().GuiIsDragSuccessful()
            && IsVisibleInTree() && _dropReleasedHere;
        _rejectedDrop = false;
        if (rejected) DeliveryRejected?.Invoke();
    }

    public override void _Input(InputEvent input)
    {
        if (input is InputEventKey { Pressed: true, Keycode: Key.Escape }) _cancelledDrop = true;
        if (input is InputEventMouseButton { Pressed: false, ButtonIndex: MouseButton.Left } release)
            _dropReleasedHere = new Rect2(Vector2.Zero, Size).HasPoint(GetGlobalTransformWithCanvas().AffineInverse() * release.Position);
    }
    public Func<string, bool>? Accepts { get; set; }
    public Action<string>? Delivered { get; set; }
    public override bool _CanDropData(Vector2 atPosition, Variant data)
    {
        bool accepts = data.VariantType == Variant.Type.String && Accepts?.Invoke(data.AsString()) == true;
        _rejectedDrop = data.VariantType == Variant.Type.String && !accepts;
        return accepts;
    }
    public override void _DropData(Vector2 atPosition, Variant data) => Delivered?.Invoke(data.AsString());
}
