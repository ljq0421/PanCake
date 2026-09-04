using Godot;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.UI;

namespace ProjectCake.Pancake;

public partial class PancakeCanvas : Control
{
    private PancakeRuntime? _runtime;
    private TianjinArtCatalog? _art;
    private int _stoveLevel = 1;

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
        Vector2 center = Size * 0.5f + new Vector2(0, 16);
        float stoveSize = Mathf.Min(Size.X * 0.72f, Size.Y * 1.04f);
        DrawCentered(_art.Stove(_stoveLevel), center, new Vector2(stoveSize, stoveSize));

        if (_runtime is null || _runtime.State == PancakeState.Empty) return;

        PancakeRuntime runtime = _runtime;
        Color qualityTint = runtime.Quality switch
        {
            PancakeQuality.Burnt => new Color(0.28f, 0.19f, 0.14f, 1),
            PancakeQuality.Overdone => new Color(0.82f, 0.56f, 0.33f, 1),
            _ => Colors.White,
        };

        if (runtime.State is PancakeState.Folded or PancakeState.Bagged or PancakeState.Delivered)
        {
            DrawCentered(_art.FinishedPancake, center + new Vector2(0, -12), new Vector2(260, 220), qualityTint);
            return;
        }

        float scale = runtime.State switch
        {
            PancakeState.BatterPlaced => 0.42f,
            PancakeState.Spreading => Mathf.Lerp(0.46f, 1f, (float)runtime.SpreadCoverage),
            _ => 1f,
        };
        Vector2 pancakeSize = Vector2.One * (stoveSize * 0.72f) * scale;
        DrawCentered(_art.PancakeBase, center - new Vector2(0, 20), pancakeSize, qualityTint);

        if (runtime.HasEgg)
            DrawCentered(_art.PancakeEgg, center - new Vector2(0, 20), pancakeSize, qualityTint);

        if (runtime.HasSauce || runtime.State == PancakeState.Saucing)
        {
            float alpha = runtime.HasSauce ? 1f : Mathf.Clamp((float)runtime.SauceCoverage + 0.22f, 0.22f, 1f);
            DrawCentered(_art.PancakeSauce, center - new Vector2(0, 20), pancakeSize, new Color(1, 1, 1, alpha));
        }

        if (runtime.ExtraIngredients.Contains(StableIds.Ingredients.Crispy))
            DrawCentered(_art.Ingredient(StableIds.Ingredients.Crispy), center + new Vector2(-48, -6), new Vector2(170, 150));
        if (runtime.ExtraIngredients.Contains(StableIds.Ingredients.Scallion))
            DrawCentered(_art.Ingredient(StableIds.Ingredients.Scallion), center + new Vector2(48, -68), new Vector2(135, 120));
        if (runtime.ExtraIngredients.Contains(StableIds.Ingredients.Ham))
            DrawCentered(_art.Ingredient(StableIds.Ingredients.Ham), center + new Vector2(52, 26), new Vector2(150, 128));
        if (runtime.ExtraIngredients.Contains(StableIds.Ingredients.Youtiao))
        {
            Color youtiaoTint = runtime.InternalYoutiaoQuality switch
            {
                YoutiaoQuality.Light => new Color(1f, 0.88f, 0.66f, 1),
                YoutiaoQuality.Deep => new Color(0.72f, 0.48f, 0.28f, 1),
                _ => Colors.White,
            };
            DrawCentered(_art.Ingredient(StableIds.Ingredients.Youtiao), center + new Vector2(-10, 20), new Vector2(205, 170), youtiaoTint);
        }
    }

    private void DrawCentered(Texture2D texture, Vector2 center, Vector2 size, Color? modulate = null)
    {
        Rect2 destination = new(center - size * 0.5f, size);
        DrawTextureRect(texture, destination, false, modulate ?? Colors.White);
    }
}
