using Godot;

namespace ProjectCake.Interaction;

public partial class ClickInteractable : Button
{
    public event Action? Invoked;

    public override void _Ready()
    {
        Pressed += () => Invoked?.Invoke();
        MouseDefaultCursorShape = CursorShape.PointingHand;
    }
}

