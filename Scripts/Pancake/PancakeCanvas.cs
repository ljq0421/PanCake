using Godot;
using ProjectCake.Fryer;

namespace ProjectCake.Pancake;

public partial class PancakeCanvas : Control
{
    private PancakeRuntime? _runtime;

    public void Bind(PancakeRuntime runtime)
    {
        _runtime = runtime;
        QueueRedraw();
    }

    public override void _Draw()
    {
        Vector2 center = Size * 0.5f;
        float radius = Mathf.Min(Size.X, Size.Y) * 0.42f;

        DrawCircle(center + new Vector2(0, 18), radius + 26, new Color("#33251E"));
        DrawCircle(center, radius + 20, new Color("#655047"));
        DrawCircle(center, radius, new Color("#1E2427"));
        DrawArc(center, radius - 8, 0, Mathf.Tau, 96, new Color("#4C5559"), 5);

        if (_runtime is null || _runtime.State == PancakeState.Empty)
        {
            DrawCircle(center, 8, new Color("#E36C4B"));
            return;
        }

        DrawPancake(center, radius * 0.80f, _runtime);
    }

    private void DrawPancake(Vector2 center, float radius, PancakeRuntime runtime)
    {
        float visibleRadius = runtime.State switch
        {
            PancakeState.BatterPlaced => radius * 0.34f,
            PancakeState.Spreading => Mathf.Lerp(radius * 0.38f, radius, (float)runtime.SpreadCoverage),
            PancakeState.Folded or PancakeState.Bagged or PancakeState.Delivered => radius * 0.62f,
            _ => radius,
        };

        Color pancake = runtime.Quality switch
        {
            PancakeQuality.Burnt => new Color("#30211B"),
            PancakeQuality.Overdone => new Color("#B86530"),
            _ => new Color("#E6A449"),
        };

        if (runtime.State is PancakeState.Folded or PancakeState.Bagged or PancakeState.Delivered)
        {
            var points = new Vector2[]
            {
                center + new Vector2(-visibleRadius, -visibleRadius * 0.36f),
                center + new Vector2(visibleRadius, -visibleRadius * 0.36f),
                center + new Vector2(visibleRadius * 0.72f, visibleRadius * 0.55f),
                center + new Vector2(-visibleRadius * 0.72f, visibleRadius * 0.55f),
            };
            DrawColoredPolygon(points, runtime.State == PancakeState.Bagged ? new Color("#F3D39A") : pancake);
            DrawPolyline(points.Append(points[0]).ToArray(), pancake.Darkened(0.3f), 5);
            return;
        }

        DrawCircle(center, visibleRadius, pancake);
        DrawArc(center, visibleRadius, 0, Mathf.Tau, 96, pancake.Darkened(0.24f), 5);

        if (runtime.HasEgg)
        {
            DrawCircle(center + new Vector2(-35, -25), visibleRadius * 0.26f, new Color("#FFF4CD"));
            DrawCircle(center + new Vector2(-35, -25), visibleRadius * 0.12f, new Color("#F7BB35"));
        }

        if (runtime.HasSauce || runtime.State == PancakeState.Saucing)
        {
            float coverage = runtime.HasSauce ? 1f : (float)runtime.SauceCoverage;
            for (int index = 0; index < Mathf.CeilToInt(coverage * 6); index++)
            {
                float y = -65 + index * 25;
                DrawLine(center + new Vector2(-visibleRadius * 0.62f, y), center + new Vector2(visibleRadius * 0.62f, y + 10), new Color("#9D3F25"), 10, true);
            }
        }

        if (runtime.ExtraIngredients.Contains(Data.StableIds.Ingredients.Crispy))
        {
            DrawRect(new Rect2(center + new Vector2(-75, -28), new Vector2(150, 56)), new Color("#D98A37"), true);
            DrawRect(new Rect2(center + new Vector2(-75, -28), new Vector2(150, 56)), new Color("#7E4A24"), false, 4);
        }

        if (runtime.ExtraIngredients.Contains(Data.StableIds.Ingredients.Scallion))
        {
            for (int index = 0; index < 13; index++)
            {
                float angle = index * 2.39996f;
                float distance = 35 + (index % 4) * 22;
                Vector2 point = center + Vector2.FromAngle(angle) * distance;
                DrawCircle(point, 6, new Color("#5F9D47"));
            }
        }

        if (runtime.ExtraIngredients.Contains(Data.StableIds.Ingredients.Ham))
        {
            DrawRect(new Rect2(center + new Vector2(-82, -18), new Vector2(164, 36)), new Color("#CC6252"), true);
            DrawLine(center + new Vector2(-72, 0), center + new Vector2(72, 0), new Color("#F0A08D"), 4);
        }

        if (runtime.ExtraIngredients.Contains(Data.StableIds.Ingredients.Youtiao))
        {
            Color color = runtime.InternalYoutiaoQuality switch
            {
                YoutiaoQuality.Light => new Color("#E8C987"),
                YoutiaoQuality.Deep => new Color("#9A5529"),
                _ => new Color("#D98A37"),
            };
            DrawRect(new Rect2(center + new Vector2(-105, -17), new Vector2(210, 34)), color, true);
            DrawLine(center + new Vector2(-95, -4), center + new Vector2(95, 5), color.Lightened(0.24f), 5);
        }
    }
}
