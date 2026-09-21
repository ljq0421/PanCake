using Godot;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    private readonly Dictionary<string, float> _loopHover = new();
    private float _loopPress;

    private void ResetLoopFeedback()
    {
        _loopHover.Clear();
        _loopPress = 0;
    }

    private void TickLoopFeedback(double delta)
    {
        if (ReducedMotion || CanInteract?.Invoke() != true || _drag?.IsDragging == true || HasProductionGesture)
        { ResetLoopFeedback(); return; }
        string target = HitTarget(GetLocalMousePosition());
        float step = (float)delta / .10f;
        foreach (string id in new[] { "bowl", "stock", "batter", "doupi_egg" })
            _loopHover[id] = Mathf.MoveToward(_loopHover.GetValueOrDefault(id), target == id ? 1 : 0, step);
        _loopPress = Mathf.MoveToward(_loopPress, Input.IsMouseButtonPressed(MouseButton.Left) ? 1 : 0, (float)delta / .05f);
    }

    // Only food and the independent ladles respond. Baked-in bowls, trays,
    // perspective and input geometry remain exactly where the artwork puts them.
    private Rect2 LoopToolRect(Rect2 rect, string target)
        => new(rect.Position + new Vector2(0, -2 * _loopHover.GetValueOrDefault(target) * (1 - _loopPress)), rect.Size);

    private Rect2 LoopFoodRect(Rect2 rect)
    {
        float hover = _loopHover.GetValueOrDefault("bowl");
        float width = 1 + hover * (.012f + .013f * _loopPress);
        Vector2 size = rect.Size * new Vector2(width, 1 / width);
        return new Rect2(rect.GetCenter() - size * .5f, size);
    }

    private Vector2[] LoopStockQuad(Vector2[] quad, bool first, float landing = 0)
    {
        float hover = first ? _loopHover.GetValueOrDefault("stock") : 0;
        Vector2 center = quad.Aggregate(Vector2.Zero, (sum, p) => sum + p) / quad.Length;
        float width = 1 + hover * (.012f + .013f * _loopPress) + landing * .035f;
        return quad.Select(p => center + (p - center) * new Vector2(width, 1 / width)).ToArray();
    }
}
