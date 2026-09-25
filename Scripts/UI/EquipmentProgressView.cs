using Godot;

namespace ProjectCake.UI;

/// <summary>A read-only view of a production clock. Never advances or smooths simulation time.</summary>
public partial class EquipmentProgressView : Control
{
    internal static readonly Color WorkingColor = new("#E8B650");
    internal static readonly Color ReadyColor = new("#78A65A");
    internal static readonly Color WarningColor = new("#E58A3D");
    internal static readonly Color FailedColor = new("#C95343");
    private static readonly Color Ink = new("#654536");
    private static readonly Color Paper = new("#FFF3DB");
    private readonly StyleBoxFlat _track = new() { BgColor = Paper, BorderColor = Ink,
        BorderWidthLeft = 2, BorderWidthRight = 2, BorderWidthTop = 2, BorderWidthBottom = 2,
        CornerRadiusTopLeft = 6, CornerRadiusTopRight = 6, CornerRadiusBottomLeft = 6, CornerRadiusBottomRight = 6 };
    private readonly StyleBoxFlat _fill = new() { CornerRadiusTopLeft = 4, CornerRadiusTopRight = 4,
        CornerRadiusBottomLeft = 4, CornerRadiusBottomRight = 4 };
    private Func<EquipmentProgressState> _read = () => default;
    internal bool ShowCaption { get; private set; } = true;
    internal bool Ring { get; private set; }
    internal EquipmentProgressState Presentation { get; private set; }

    internal static EquipmentProgressView Attach(Control parent, string name, Rect2 rect, Func<EquipmentProgressState> read, bool showCaption = true, bool ring = false)
    {
        var view = new EquipmentProgressView { Name = name, Position = rect.Position, Size = rect.Size,
            MouseFilter = MouseFilterEnum.Ignore, Visible = false, _read = read, ShowCaption = showCaption, Ring = ring };
        parent.AddChild(view);
        return view;
    }

    public override void _Process(double delta) => Refresh();
    internal void Refresh()
    {
        var next = _read();
        Visible = next.Visible;
        if (next == Presentation) return;
        Presentation = next;
        QueueRedraw();
    }

    internal static Color FillColor(EquipmentProgressState state) => state.Failed ? FailedColor
        : state.Risk > 0 ? WarningColor.Lerp(FailedColor, (float)Math.Clamp(state.Risk, 0, 1))
        : state.Ready ? ReadyColor : WorkingColor;

    public override void _Draw()
    {
        if (!Presentation.Visible) return;
        if (Ring)
        {
            DrawRing();
            return;
        }
        if (ShowCaption)
        {
            // The light outline keeps short captions legible on the illustrated counter.
            var font = GetThemeDefaultFont();
            const int fontSize = 20;
            string caption = Tr(Presentation.Caption);
            float width = font.GetStringSize(caption, HorizontalAlignment.Left, -1, fontSize).X;
            Vector2 baseline = new((Size.X - width) / 2, 21);
            DrawStringOutline(font, baseline, caption, HorizontalAlignment.Left, -1, fontSize, 5, Paper);
            DrawString(font, baseline, caption, HorizontalAlignment.Left, -1, fontSize, Ink);
        }
        DrawStyleBox(_track, new Rect2(0, 28, Size.X, 12));
        if (Presentation.HeatPosition is double heatPosition)
        {
            // Yellow: heating; green: usable; the short final red segment means burnt.
            float width = Size.X - 4;
            DrawRect(new Rect2(2, 30, width * .3f, 8), WorkingColor);
            DrawRect(new Rect2(2 + width * .3f, 30, width * .6f, 8), ReadyColor);
            DrawRect(new Rect2(2 + width * .9f, 30, width * .1f, 8), FailedColor);
            float x = 2 + width * (float)Math.Clamp(heatPosition, 0, 1);
            DrawLine(new Vector2(x, 27), new Vector2(x, 41), Ink, 6, true);
            DrawLine(new Vector2(x, 27), new Vector2(x, 41), Paper, 2, true);
            return;
        }
        float filled = (Size.X - 4) * (float)Math.Clamp(Presentation.Progress, 0, 1);
        if (filled <= 0) return;
        _fill.BgColor = FillColor(Presentation);
        DrawStyleBox(_fill, new Rect2(2, 30, filled, 8));
    }

    private void DrawRing()
    {
        // An ellipse follows the bowl's perspective without covering its contents.
        Vector2 center = Size / 2;
        Vector2 radius = center - Vector2.One * 9;
        Vector2 Point(float turn) => center + new Vector2(
            Mathf.Sin(turn * Mathf.Tau) * radius.X, -Mathf.Cos(turn * Mathf.Tau) * radius.Y);
        Vector2[] Arc(float turns)
        {
            int segments = Math.Max(2, (int)Math.Ceiling(turns * 128));
            var points = new Vector2[segments + 1];
            for (int i = 0; i <= segments; i++) points[i] = Point(turns * i / segments);
            return points;
        }
        var track = Arc(1);
        DrawPolyline(track, Ink, 18, true);
        DrawPolyline(track, Paper, 12, true);
        float progress = (float)Math.Clamp(Presentation.Progress, 0, 1);
        if (progress > 0)
        {
            Color color = FillColor(Presentation);
            DrawPolyline(Arc(progress), color, 12, true);
            DrawCircle(Point(0), 6, color, true, -1, true);
            DrawCircle(Point(progress), 8, Ink, true, -1, true);
            DrawCircle(Point(progress), 5, color, true, -1, true);
        }
        if (!ShowCaption) return;
        var font = GetThemeDefaultFont();
        const int fontSize = 20;
        string caption = Tr(Presentation.Caption);
        float width = font.GetStringSize(caption, HorizontalAlignment.Left, -1, fontSize).X;
        Vector2 baseline = new((Size.X - width) / 2, Size.Y + 22);
        DrawStringOutline(font, baseline, caption, HorizontalAlignment.Left, -1, fontSize, 5, Paper);
        DrawString(font, baseline, caption, HorizontalAlignment.Left, -1, fontSize, Ink);
    }
}

internal readonly record struct EquipmentProgressState(bool Visible, double Progress, string Caption,
    bool Ready = false, double Risk = 0, bool Failed = false, double? HeatPosition = null)
{
    internal static EquipmentProgressState Working(double elapsed, double duration, string caption) =>
        new(true, Math.Clamp(elapsed / Math.Max(.0001, duration), 0, 1), caption);
    internal static EquipmentProgressState Done(string caption, double risk = 0, bool failed = false) =>
        new(true, 1, caption, true, Math.Clamp(risk, 0, 1), failed);
    internal static double Heat(double elapsed, double safeUntil, double burnAt) =>
        Math.Clamp((elapsed - safeUntil) / Math.Max(.0001, burnAt - safeUntil), 0, 1);
}
