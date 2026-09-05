using Godot;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.UI;

namespace ProjectCake.Pancake;

public partial class PancakeCanvas : Control
{
    private readonly record struct StoveSurfaceSpec(float CenterY, float Width, float Height);

    private PancakeRuntime? _runtime;
    private TianjinArtCatalog? _art;
    private int _stoveLevel = 1;
    private float _batterDropProgress = 1.0f;

    public float BatterDropProgress
    {
        get => _batterDropProgress;
        set
        {
            _batterDropProgress = Mathf.Clamp(value, 0, 1);
            QueueRedraw();
        }
    }

    public void Bind(PancakeRuntime runtime, TianjinArtCatalog art, int stoveLevel)
    {
        _runtime = runtime;
        _art = art;
        _stoveLevel = stoveLevel;
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (_art is null) return;
        (Vector2 stoveCenter, float stoveSize) = GetStoveGeometry();
        DrawCentered(_art.Stove(_stoveLevel), stoveCenter, new Vector2(stoveSize, stoveSize));

        if (_runtime is null || _runtime.State == PancakeState.Empty) return;

        PancakeRuntime runtime = _runtime;
        Color qualityTint = runtime.Quality switch
        {
            PancakeQuality.Burnt => new Color(0.28f, 0.19f, 0.14f, 1),
            PancakeQuality.Overdone => new Color(0.82f, 0.56f, 0.33f, 1),
            _ => Colors.White,
        };

        if (runtime.State == PancakeState.Folded)
        {
            DrawCentered(_art.FoldedPancake, stoveCenter + new Vector2(0, -12), new Vector2(260, 220), qualityTint);
            return;
        }
        if (runtime.State is PancakeState.Bagged or PancakeState.Delivered)
        {
            DrawCentered(_art.FinishedPancake, stoveCenter + new Vector2(0, -12), new Vector2(250, 210), qualityTint);
            return;
        }

        Rect2 surface = GetSurfaceRect();
        float scale = runtime.State switch
        {
            PancakeState.BatterPlaced => Mathf.Lerp(0.22f, 0.32f, BatterDropProgress),
            PancakeState.Spreading => Mathf.Lerp(0.32f, 1f, Mathf.SmoothStep(0, 1, (float)runtime.SpreadCoverage)),
            _ => 1f,
        };
        Rect2 pancakeRect = ScaleFromCenter(surface, scale);
        Color reveal = qualityTint;
        if (runtime.State == PancakeState.BatterPlaced)
        {
            reveal.A *= BatterDropProgress;
        }
        DrawPancakeSurface(pancakeRect, reveal);

        if (runtime.HasEgg)
            DrawCentered(_art.PancakeEgg, surface.GetCenter(), surface.Size, qualityTint);

        if (runtime.HasSauce || runtime.State == PancakeState.Saucing)
        {
            float alpha = runtime.HasSauce ? 1f : Mathf.Clamp((float)runtime.SauceCoverage + 0.22f, 0.22f, 1f);
            DrawCentered(_art.PancakeSauce, surface.GetCenter(), surface.Size, new Color(1, 1, 1, alpha));
        }

        if (runtime.ExtraIngredients.Contains(StableIds.Ingredients.Crispy))
            DrawCentered(_art.Ingredient(StableIds.Ingredients.Crispy), surface.GetCenter() + new Vector2(-surface.Size.X * 0.13f, 0), surface.Size * new Vector2(0.42f, 0.58f));
        if (runtime.ExtraIngredients.Contains(StableIds.Ingredients.Scallion))
            DrawCentered(_art.Ingredient(StableIds.Ingredients.Scallion), surface.GetCenter() + new Vector2(surface.Size.X * 0.13f, -surface.Size.Y * 0.22f), surface.Size * new Vector2(0.34f, 0.46f));
        if (runtime.ExtraIngredients.Contains(StableIds.Ingredients.Ham))
            DrawCentered(_art.Ingredient(StableIds.Ingredients.Ham), surface.GetCenter() + new Vector2(surface.Size.X * 0.14f, surface.Size.Y * 0.14f), surface.Size * new Vector2(0.38f, 0.5f));
        if (runtime.ExtraIngredients.Contains(StableIds.Ingredients.Youtiao))
        {
            Color youtiaoTint = runtime.InternalYoutiaoQuality switch
            {
                YoutiaoQuality.Light => new Color(1f, 0.88f, 0.66f, 1),
                YoutiaoQuality.Deep => new Color(0.72f, 0.48f, 0.28f, 1),
                _ => Colors.White,
            };
            DrawCentered(_art.Ingredient(StableIds.Ingredients.Youtiao), surface.GetCenter() + new Vector2(-surface.Size.X * 0.03f, surface.Size.Y * 0.1f), surface.Size * new Vector2(0.51f, 0.66f), youtiaoTint);
        }

        if (runtime.Quality == PancakeQuality.Burnt || runtime.State == PancakeState.Burnt)
            DrawCentered(_art.PancakeBurntOverlay, surface.GetCenter(), surface.Size * 1.03f);
    }

    public Rect2 GetSurfaceRect()
    {
        (Vector2 stoveCenter, float stoveSize) = GetStoveGeometry();
        StoveSurfaceSpec spec = _stoveLevel switch
        {
            2 => new StoveSurfaceSpec(-0.086f, 0.796f, 0.444f),
            3 => new StoveSurfaceSpec(-0.108f, 0.784f, 0.456f),
            _ => new StoveSurfaceSpec(-0.084f, 0.798f, 0.446f),
        };
        Vector2 size = new(stoveSize * spec.Width, stoveSize * spec.Height);
        Vector2 center = stoveCenter + new Vector2(0, stoveSize * spec.CenterY);
        return new Rect2(center - size * 0.5f, size);
    }

    private (Vector2 Center, float Size) GetStoveGeometry()
    {
        Vector2 center = Size * 0.5f + new Vector2(0, 16);
        float stoveSize = Mathf.Min(Size.X * 0.72f, Size.Y * 1.04f);
        return (center, stoveSize);
    }

    private void DrawPancakeSurface(Rect2 rect, Color tint)
    {
        DrawEllipse(rect, new Color(0.29f, 0.16f, 0.11f, tint.A));
        DrawEllipse(new Rect2(rect.Position + new Vector2(4, 4), rect.Size - new Vector2(8, 8)), new Color(1.0f, 0.78f, 0.28f, tint.A));
        DrawCentered(_art!.PancakeBase, rect.GetCenter(), rect.Size - new Vector2(5, 5), tint);
    }

    private void DrawEllipse(Rect2 rect, Color color, float inset = 0)
    {
        Vector2 radii = rect.Size * 0.5f - Vector2.One * inset;
        if (radii.X <= 0 || radii.Y <= 0) return;
        DrawSetTransform(rect.GetCenter(), 0, new Vector2(radii.X / radii.Y, 1));
        DrawCircle(Vector2.Zero, radii.Y, color);
        DrawSetTransform(Vector2.Zero, 0, Vector2.One);
    }

    private static Rect2 ScaleFromCenter(Rect2 rect, float scale)
    {
        Vector2 size = rect.Size * scale;
        return new Rect2(rect.GetCenter() - size * 0.5f, size);
    }

    private void DrawCentered(Texture2D texture, Vector2 center, Vector2 size, Color? modulate = null)
    {
        Rect2 destination = new(center - size * 0.5f, size);
        DrawTextureRect(texture, destination, false, modulate ?? Colors.White);
    }
}
