using Godot;
using ProjectCake.Interaction;

namespace ProjectCake.UI;

/// <summary>Development-only references; never participates in pointer input.</summary>
public partial class TianjinDeskGuide : Control
{
    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        ZIndex = 100;
        Visible = OS.GetCmdlineUserArgs().Contains("--dev-ui", StringComparer.Ordinal);
    }

    public override void _Draw()
    {
        if (!Visible) return;
        DrawLine(new(0, TianjinWorkbenchLayout.BackEdge), new(1920, TianjinWorkbenchLayout.BackEdge), Colors.Aqua, 2);
        DrawLine(new(0, TianjinWorkbenchLayout.FrontEdge), new(1920, TianjinWorkbenchLayout.FrontEdge), Colors.Aqua, 2);
        DrawLine(new(960, 160), new(960, 995), new Color(1, 1, 1, .6f), 1);
        foreach (float depth in new[] { .25f, .5f, .8f })
        {
            float y = Mathf.Lerp(TianjinWorkbenchLayout.BackEdge, TianjinWorkbenchLayout.FrontEdge, depth);
            DrawLine(new(0, y), new(1920, y), new Color(1, .85f, .2f, .65f), 1);
            DrawString(ThemeDB.FallbackFont, new(10, y - 6), $"Depth {depth:0.00}", fontSize: 18);
        }
        Transform2D toLocal = GetGlobalTransform().AffineInverse();
        foreach (WorkstationSlotView slot in GetParent().Descendants<WorkstationSlotView>())
        {
            if (!slot.IsVisibleInTree()) continue;
            Vector2 contact = toLocal * (slot.GetGlobalTransform() * slot.TableContactAnchor);
            DrawCircle(contact, 4, Colors.Yellow);
            Rect2 hit = slot.ClickBounds;
            Transform2D transform = toLocal * slot.GetGlobalTransform();
            Vector2[] points = { transform * hit.Position, transform * new Vector2(hit.End.X, hit.Position.Y),
                transform * hit.End, transform * new Vector2(hit.Position.X, hit.End.Y), transform * hit.Position };
            DrawPolyline(points, new Color(.2f, 1, .6f, .8f), 1);
        }
        foreach (DropZone zone in GetParent().Descendants<DropZone>())
        {
            if (!zone.IsVisibleInTree()) continue;
            Rect2 hit = zone.FixedHitRect ?? new Rect2(Vector2.Zero, zone.Size).Grow(zone.HitPadding);
            Transform2D transform = toLocal * (zone.FixedHitRect.HasValue
                ? zone.GetParent<Control>().GetGlobalTransform() : zone.GetGlobalTransform());
            Vector2[] points = { transform * hit.Position, transform * new Vector2(hit.End.X, hit.Position.Y),
                transform * hit.End, transform * new Vector2(hit.Position.X, hit.End.Y), transform * hit.Position };
            DrawPolyline(points, new Color(1, .4f, .35f, .8f), 2);
        }
        foreach (FryerVisualView fryer in GetParent().Descendants<FryerVisualView>())
            if (fryer.IsVisibleInTree()) DrawCircle(toLocal * (fryer.GetGlobalTransform() * fryer.TableContactAnchor), 5, Colors.Yellow);
    }

    public override void _Process(double delta) { if (Visible) QueueRedraw(); }
}
