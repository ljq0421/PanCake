using Godot;

namespace ProjectCake.Pancake;

// Drawn after the independent sauce material and before the workbench tools.
public partial class PancakeToppingLayer : Control
{
    public Action<CanvasItem>? DrawFood { get; set; }
    public override void _Draw() => DrawFood?.Invoke(this);
}
