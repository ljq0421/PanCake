using Godot;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.UI;

namespace ProjectCake.Pancake;

public partial class PancakeCanvas : Control
{
    internal float FlipPickup { get; set; }
    internal float FlipEdge { get; set; } = 1;
    private float VisualFlipProgress => IsFlipping ? FlipProgress : .08f + .12f * FlipPickup;
    private bool _directFoodHidden;
    internal bool DirectFoodHidden { get => _directFoodHidden; set { _directFoodHidden = value; QueueRedraw(); } }
    private bool _foldPreviewVisible;
    internal bool FoldPreviewVisible
    {
        get => _foldPreviewVisible;
        set
        {
            _foldPreviewVisible = value;
            _toppingLayer?.QueueRedraw();
            QueueRedraw();
        }
    }
    private readonly record struct StoveSurfaceSpec(float CenterY, float Width, float Height);

    private PancakeRuntime? _runtime;
    private TianjinArtCatalog? _art;
    private int _stoveLevel = 1;
    private float _batterDropProgress = 1.0f;
    private bool _foodOnly;
    private bool _compositeFoodPreview;
    private TextureRect? _sauceReveal;
    private PancakeToppingLayer? _toppingLayer;
    private long _visualGeneration = -1;
    internal TextureRect? SauceReveal => _sauceReveal;
    internal void EnableIngredientDetail(TianjinArtCatalog art)
    {
        if (_sauceReveal is not null) return;
        _art = art;
        _sauceReveal = new TextureRect { Name = "SauceAmount", ZIndex = 1,
            Texture = _art.PancakeSauce, ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.Scale, MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_sauceReveal);
        _toppingLayer = new PancakeToppingLayer { Name = "Toppings", ZIndex = 2, MouseFilter = MouseFilterEnum.Ignore, DrawFood = DrawToppings };
        AddChild(_toppingLayer);
    }
    private void SyncIngredientDetail()
    {
        if (_sauceReveal is null || _runtime is null) return;
        if (_visualGeneration != _runtime.Generation)
        {
            _visualGeneration = _runtime.Generation;
            _ingredientMotion.Clear();
        }
        Rect2 surface = GetSurfaceRect();
        _sauceReveal.Position = surface.Position;
        _sauceReveal.Size = surface.Size;
        _sauceReveal.Visible = !_compositeFoodPreview && !FoldPreviewVisible && !IsFlipping && (_runtime.HasSauce || _runtime.State == PancakeState.Saucing)
            && _runtime.State is not (PancakeState.Empty or PancakeState.Folded or PancakeState.Bagged or PancakeState.Delivered);
        _sauceReveal.Modulate = new Color(1, 1, 1, Mathf.Clamp((float)(_runtime.SauceCoverage / SauceRules.MaximumAmount), 0, 1));
    }
    private double _lastSpread;
    private float _edgeRelaxation;
    internal float EdgeRelaxation => _edgeRelaxation;
    internal const float FlipDuration = .35f;
    internal float FlipProgress { get; private set; } = 1;
    internal bool IsFlipping => FlipProgress < 1;
    private readonly Dictionary<string, (float Time, float Strength)> _ingredientMotion = new();
    internal void LandIngredient(string id, float delay, float strength)
    {
        SyncIngredientDetail();
        if (!ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool())
            _ingredientMotion[id] = (-delay, strength);
        QueueRedraw();
    }
    internal void ResetIngredientMotion() { _ingredientMotion.Clear(); _spreadMarks.Clear(); QueueRedraw(); }
    private void DrawIngredient(string id, Texture2D texture, Vector2 center, Vector2 size, Color? tint = null, CanvasItem? painter = null)
    {
        if (_ingredientMotion.TryGetValue(id, out var motion))
        {
            if (motion.Time < 0) return;
            float t = motion.Time;
            float width = t < .055f ? Mathf.Lerp(1, 1 + motion.Strength, t / .055f)
                : t < .14f ? Mathf.Lerp(1 + motion.Strength, 1 - motion.Strength * .6f, (t - .055f) / .085f)
                : Mathf.Lerp(1 - motion.Strength * .6f, 1, Mathf.Clamp((t - .14f) / .14f, 0, 1));
            size *= new Vector2(width, 1 / width);
            if (id == StableIds.Ingredients.Egg && _sauceReveal is not null)
                size *= Mathf.Lerp(.25f, 1, Mathf.SmoothStep(0, 1, Mathf.Clamp(t / .10f, 0, 1)));
            if (id == StableIds.Ingredients.Crispy)
                center.Y -= 2 * Mathf.Sin(Mathf.Clamp(t / .18f, 0, 1) * Mathf.Pi);
        }
        DrawCentered(texture, center, size, tint, painter);
    }

    internal void SetFlipProgress(float progress)
    {
        FlipProgress = Mathf.Clamp(progress, 0, 1);
        QueueRedraw();
    }

    // The first 20% lets the spatula reach the edge; the last 10% settles the food.
    internal static float FlipFlight(float progress) => Mathf.Clamp((progress - .2f) / .7f, 0, 1);

    public void TickLivingMotion(double delta, bool active, bool spreading)
    {
        SyncIngredientDetail();
        TickMakingMotion(delta, active);
        if (!active) _ingredientMotion.Clear();
        else foreach (string id in _ingredientMotion.Keys.ToArray())
        {
            var motion = _ingredientMotion[id];
            motion.Time += (float)Math.Max(0, delta);
            if (motion.Time >= .28f) _ingredientMotion.Remove(id);
            else _ingredientMotion[id] = motion;
        }
        double coverage = _runtime?.SpreadCoverage ?? 0;
        if (!active) _edgeRelaxation = 0;
        else if (spreading && coverage > _lastSpread) _edgeRelaxation = .008f;
        else _edgeRelaxation = Mathf.MoveToward(_edgeRelaxation, 0, (float)delta * .04f);
        _lastSpread = coverage;
        QueueRedraw();
        _toppingLayer?.QueueRedraw();
    }

    [Export] public float DisplayScale { get; set; } = 1.0f;
    [Export] public Vector2 DisplayOffset { get; set; } = Vector2.Zero;
    [Export] public bool ShowBaggedPancake { get; set; } = true;
    public bool UseTableContact { get; set; }
    public Rect2? EmbeddedSurface { get; set; }

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
        if (!ReferenceEquals(_runtime, runtime)) _visualGeneration = -1;
        _runtime = runtime;
        _art = art;
        _stoveLevel = stoveLevel;
        QueueRedraw();
    }

    public override void _Draw()
    {
        SyncIngredientDetail();
        if (_art is null) return;
        (Vector2 stoveCenter, float stoveSize) = GetStoveGeometry();
        if (EmbeddedSurface is null && !_foodOnly)
            DrawCentered(_art.Stove(_stoveLevel), stoveCenter, new Vector2(stoveSize, stoveSize));
        else if (EmbeddedSurface is Rect2 embedded) stoveCenter = embedded.GetCenter();

        if (_runtime is null || _runtime.State == PancakeState.Empty || FoldPreviewVisible || DirectFoodHidden) return;

        PancakeRuntime runtime = _runtime;
        Color qualityTint = runtime.Quality switch
        {
            PancakeQuality.Burnt => new Color(0.28f, 0.19f, 0.14f, 1),
            PancakeQuality.Overdone => new Color(0.82f, 0.56f, 0.33f, 1),
            _ => Colors.White,
        };

        if (runtime.State == PancakeState.Folded)
        {
            DrawIngredient("fold", _art.FoldedPancake, stoveCenter + new Vector2(0, -12), new Vector2(260, 220), qualityTint);
            return;
        }
        if (runtime.State is PancakeState.Bagged or PancakeState.Delivered)
        {
            if (ShowBaggedPancake)
                DrawCentered(_art.FinishedPancake, stoveCenter + new Vector2(0, -12), new Vector2(250, 210), qualityTint);
            return;
        }

        Rect2 surface = GetSurfaceRect();
        if (IsFlipping || FlipPickup > 0)
        {
            DrawFlippingPancake(surface, qualityTint);
            return;
        }
        float scale = runtime.State switch
        {
            PancakeState.BatterPlaced => Mathf.Lerp(0.22f, 0.32f, BatterDropProgress),
            PancakeState.Spreading => Mathf.Lerp(0.32f, 1f, Mathf.SmoothStep(0, 1, (float)runtime.SpreadCoverage)),
            _ => 1f,
        };
        Rect2 pancakeRect = ScaleFromCenter(surface, scale);
        if (EmbeddedSurface.HasValue && runtime.State == PancakeState.Spreading)
            pancakeRect = new Rect2(pancakeRect.Position - new Vector2(pancakeRect.Size.X * _edgeRelaxation * .5f, 0),
                pancakeRect.Size * new Vector2(1 + _edgeRelaxation, 1));
        Color reveal = qualityTint;
        if (runtime.State == PancakeState.BatterPlaced)
        {
            reveal.A *= BatterDropProgress;
        }
        DrawPancakeSurface(pancakeRect, reveal);
        if (runtime.State == PancakeState.Spreading) DrawSpreadContact(pancakeRect);

        if (runtime.HasEgg)
            DrawIngredient(StableIds.Ingredients.Egg, _art.PancakeEgg, surface.GetCenter(), surface.Size, qualityTint);

        if ((_sauceReveal is null || _compositeFoodPreview) && (runtime.HasSauce || runtime.State == PancakeState.Saucing))
        {
            float alpha = Mathf.Clamp((float)(runtime.SauceCoverage / SauceRules.MaximumAmount), 0, 1f);
            DrawCentered(_art.PancakeSauce, surface.GetCenter(), surface.Size, new Color(1, 1, 1, alpha));
        }

        if (_toppingLayer is null || _compositeFoodPreview) DrawToppings(this);
        else _toppingLayer.QueueRedraw();
        if (!_foodOnly) DrawStateIndicator(surface, runtime.State);
    }

    private void DrawToppings(CanvasItem painter)
    {
        if (_runtime is not { } runtime || _art is null || IsFlipping || FoldPreviewVisible || runtime.State is PancakeState.Empty or PancakeState.Folded or PancakeState.Bagged or PancakeState.Delivered) return;
        Rect2 surface = GetSurfaceRect();
        // Canvas drawing is painter's-order: rendering in join order makes the
        // most recently added topping visually sit on top of prior toppings.
        foreach (string ingredient in runtime.ExtraIngredientOrder)
        {
            switch (ingredient)
            {
                case StableIds.Ingredients.Crispy:
                    DrawIngredient(ingredient, _art.Ingredient(ingredient), surface.GetCenter() + new Vector2(-surface.Size.X * .13f, 0), surface.Size * new Vector2(.42f, .58f), painter: painter);
                    break;
                case StableIds.Ingredients.Scallion:
                    DrawScallions(painter, surface);
                    break;
                case StableIds.Ingredients.Ham:
                    DrawIngredient(ingredient, _art.Ingredient(ingredient), surface.GetCenter() + new Vector2(surface.Size.X * .14f, surface.Size.Y * .14f), surface.Size * new Vector2(.38f, .5f), painter: painter);
                    break;
                case StableIds.Ingredients.Youtiao:
                    Color youtiaoTint = YoutiaoPresentation.Tint(runtime.InternalYoutiaoQuality ?? YoutiaoQuality.Golden);
                    DrawIngredient(ingredient, _art.Ingredient(ingredient), surface.GetCenter() + new Vector2(-surface.Size.X * .03f, surface.Size.Y * .1f), surface.Size * new Vector2(.51f, .66f), youtiaoTint, painter);
                    break;
            }
        }

        if (runtime.Quality == PancakeQuality.Burnt || runtime.State == PancakeState.Burnt)
            DrawCentered(_art.PancakeBurntOverlay, surface.GetCenter(), surface.Size * 1.03f, painter: painter);
    }

    private void DrawScallions(CanvasItem painter, Rect2 surface)
    {
        if (_sauceReveal is null)
        {
            DrawIngredient(StableIds.Ingredients.Scallion, _art!.Ingredient(StableIds.Ingredients.Scallion), surface.GetCenter() + surface.Size * new Vector2(.13f, -.22f), surface.Size * new Vector2(.34f, .46f), painter: painter);
            return;
        }
        // Stable anchors: the pieces that land are the pieces that remain on this pancake.
        for (int i = 0; i < 10; i++)
        {
            float angle = i * 2.399963f;
            float radius = .12f + .20f * (i % 4) / 3;
            Vector2 end = surface.GetCenter() + surface.Size * new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius;
            float progress = 1;
            if (_ingredientMotion.TryGetValue(StableIds.Ingredients.Scallion, out var motion))
            {
                if (motion.Time < 0) continue;
                progress = Mathf.Clamp((motion.Time - (i % 3) * .02f) / .18f, 0, 1);
            }
            Vector2 start = surface.GetCenter() + surface.Size * new Vector2(.13f, -.22f) - new Vector2(0, 26);
            Vector2 position = start.Lerp(end, 1 - Mathf.Pow(1 - progress, 2));
            Vector2 size = new Vector2(16 + i % 3 * 2, 13 + i % 3 * 2) * 1.6f;
            painter.DrawSetTransform(position, angle * .14f * progress, Vector2.One);
            painter.DrawTextureRect(_art!.ScallionPieces[i % 3], new Rect2(-size / 2, size), false);
            painter.DrawSetTransform(Vector2.Zero, 0, Vector2.One);
        }
    }

    // Draw the same food layers and perspective as the stove, frozen at pickup.
    public Control CreateFoodPreview(Vector2 displaySize, bool bare = false, bool composite = false)
    {
        var preview = new Control { CustomMinimumSize = displaySize, MouseFilter = MouseFilterEnum.Ignore };
        if (_runtime is null || _art is null) return preview;
        var snapshot = new PancakeRuntime
        {
            State = _runtime.State, Quality = _runtime.Quality,
            SpreadCoverage = _runtime.SpreadCoverage, SauceCoverage = _runtime.SauceCoverage,
            HasEgg = !bare && _runtime.HasEgg, HasSauce = !bare && _runtime.HasSauce,
            InternalYoutiaoQuality = _runtime.InternalYoutiaoQuality,
        };
        if (!bare)
            foreach (string ingredient in _runtime.ExtraIngredientOrder) snapshot.AddIngredient(ingredient);
        Rect2 bounds = GetSurfaceRect();
        if (snapshot.State is PancakeState.Folded or PancakeState.Bagged)
        {
            Vector2 center = EmbeddedSurface?.GetCenter() ?? GetStoveGeometry().Center;
            Vector2 size = snapshot.State == PancakeState.Folded ? new(260, 220) : new(250, 210);
            bounds = new Rect2(center + new Vector2(0, -12) - size / 2, size);
        }
        bounds = bounds.Grow(8);
        float scale = Mathf.Min(displaySize.X / bounds.Size.X, displaySize.Y / bounds.Size.Y);
        var food = new PancakeCanvas
        {
            Name = "DraggedPancakeFood", Size = Size, DisplayScale = DisplayScale, DisplayOffset = DisplayOffset,
            UseTableContact = UseTableContact, EmbeddedSurface = EmbeddedSurface,
            BatterDropProgress = BatterDropProgress, _foodOnly = true, _compositeFoodPreview = composite,
            MouseFilter = MouseFilterEnum.Ignore, Scale = Vector2.One * scale,
            Position = displaySize / 2 - bounds.GetCenter() * scale,
        };
        food.Bind(snapshot, _art, _stoveLevel);
        preview.AddChild(food);
        if (_sauceReveal is not null)
        {
            food.EnableIngredientDetail(_art);
            if (composite) food._toppingLayer!.Visible = false;
            food._visualGeneration = snapshot.Generation;
            food.SyncIngredientDetail();
        }
        return preview;
    }

    public Rect2 GetSurfaceRect()
    {
        if (EmbeddedSurface is Rect2 embedded) return embedded;
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
        Vector2 center = Size * 0.5f + new Vector2(0, 16) + DisplayOffset;
        float stoveSize = Mathf.Min(Size.X * 0.72f, Size.Y * 1.04f) * Mathf.Max(0.1f, DisplayScale);
        if (UseTableContact)
        {
            const float targetContact = 1038f / 1254 - .5f;
            float sourceContact = (_stoveLevel switch { 1 => 1061f, 2 => 1043f, _ => 1038f }) / 1254 - .5f;
            float sourceCenter = _stoveLevel switch { 1 => -.084f, 2 => -.086f, _ => -.108f };
            float fit = (targetContact + .108f) / (sourceContact - sourceCenter);
            center.Y += stoveSize * (targetContact - fit * sourceContact);
            stoveSize *= fit;
        }
        return (center, stoveSize);
    }

    private void DrawFlippingPancake(Rect2 surface, Color tint)
    {
        float flight = FlipFlight(VisualFlipProgress);
        float lift = Mathf.Sin(flight * Mathf.Pi);
        // A soft contact shadow stays on the stove while the pancake leaves it.
        for (int i = 3; i >= 0; i--)
        {
            Rect2 shadow = ScaleFromCenter(surface, .94f - .09f * lift).Grow(i * 3);
            DrawEllipse(shadow, new Color(.18f, .10f, .06f, .035f * lift));
        }
        float settle = VisualFlipProgress > .9f ? Mathf.Sin((VisualFlipProgress - .9f) * 10 * Mathf.Pi) : 0;
        Vector2 size = surface.Size * new Vector2(1 + .018f * lift + .008f * settle,
            Math.Max(.055f, Mathf.Abs(Mathf.Cos(flight * Mathf.Pi))) * (1 - .025f * settle));
        Vector2 center = surface.GetCenter() + new Vector2(0, -44 * lift);
        Rect2 food = new(center - size * .5f, size);
        float light = 1 - .16f * lift;
        Color face = new(tint.R * light, tint.G * light, tint.B * light, tint.A);
        // Warp the silhouette and every texture through the same curve so the egg
        // remains attached to the skin, including when the pancake is edge-on.
        DrawBentEllipse(food, surface, new Color(.29f, .16f, .11f, tint.A));
        DrawBentEllipse(new Rect2(food.Position + new Vector2(4, 4), food.Size - new Vector2(8, 8)),
            surface, new Color(1, .78f, .28f, tint.A));
        DrawBentTexture(_art!.PancakeBase, new Rect2(food.Position + new Vector2(2.5f, 2.5f),
            food.Size - new Vector2(5, 5)), surface, face);
        if (_runtime!.HasEgg) DrawBentTexture(_art.PancakeEgg, food, surface, face);
    }

    private Vector2 BendFlipPoint(Vector2 point, Rect2 surface)
    {
        float x = Mathf.Clamp((point.X - surface.GetCenter().X) / (surface.Size.X * .5f), -1, 1);
        float flight = FlipFlight(VisualFlipProgress);
        float pickup = Mathf.Sin(Mathf.Pi * Mathf.Clamp((VisualFlipProgress - .08f) / .34f, 0, 1));
        float airborne = Mathf.Sin(flight * Mathf.Pi);
        float sag = 42 * airborne;
        float landingCurl = 18 * Mathf.Sin(Mathf.Pi * Mathf.Clamp((VisualFlipProgress - .72f) / .28f, 0, 1));
        // The spatula lifts its edge first; the unsupported center hangs in a deep
        // curve. A travelling bend makes the opposite edge lag rather than move as
        // one rigid disc. The center lands first, then the still-curled edges relax.
        float edge = x * FlipEdge;
        float travellingBend = 10 * airborne * Mathf.Sin(edge * Mathf.Pi + flight * Mathf.Tau);
        point.Y += -38 * pickup * Mathf.Pow((edge + 1) * .5f, 2)
            + sag * (1 - x * x) + travellingBend - landingCurl * x * x;
        return point;
    }

    private void DrawBentEllipse(Rect2 rect, Rect2 surface, Color color)
    {
        if (rect.Size.X <= 0 || rect.Size.Y <= 0) return;
        const int segments = 96;
        var points = new Vector2[segments];
        for (int i = 0; i < segments; i++)
        {
            float angle = Mathf.Tau * i / segments;
            points[i] = BendFlipPoint(rect.GetCenter() + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * rect.Size * .5f, surface);
        }
        DrawColoredPolygon(points, color);
        var outline = new Vector2[segments + 1];
        points.CopyTo(outline, 0); outline[segments] = points[0];
        DrawPolyline(outline, color, 1, true);
    }

    private void DrawBentTexture(Texture2D texture, Rect2 rect, Rect2 surface, Color tint)
    {
        // Narrow textured strips follow the curve without allocating scene nodes
        // or changing the stove's input region. Adjacent strips share exact edges.
        const int strips = 40;
        var vertices = new Vector2[4];
        var uv = new Vector2[4];
        var colors = new[] { tint };
        for (int i = 0; i < strips; i++)
        {
            float left = (float)i / strips, right = (float)(i + 1) / strips;
            uv[0] = new(left, 0); uv[1] = new(right, 0);
            uv[2] = new(right, 1); uv[3] = new(left, 1);
            for (int corner = 0; corner < 4; corner++)
                vertices[corner] = BendFlipPoint(rect.Position + rect.Size * uv[corner], surface);
            DrawPolygon(vertices, colors, uv, texture);
        }
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
        DrawCircle(Vector2.Zero, radii.Y, color, antialiased: true);
        DrawSetTransform(Vector2.Zero, 0, Vector2.One);
    }

    private void DrawStateIndicator(Rect2 surface, PancakeState state)
    {
        Color? color = state switch
        {
            PancakeState.SideAReady => TianjinUi.Green,
            PancakeState.SideAOverdone => TianjinUi.Orange,
            PancakeState.Burnt => TianjinUi.Red,
            _ => null,
        };
        if (color is not Color indicator) return;
        Vector2 radii = surface.Size * 0.5f + new Vector2(8, 6);
        DrawSetTransform(surface.GetCenter(), 0, new Vector2(radii.X / radii.Y, 1));
        DrawArc(Vector2.Zero, radii.Y, 0, Mathf.Tau, 64, indicator, 6, true);
        DrawSetTransform(Vector2.Zero, 0, Vector2.One);
    }

    private static Rect2 ScaleFromCenter(Rect2 rect, float scale)
    {
        Vector2 size = rect.Size * scale;
        return new Rect2(rect.GetCenter() - size * 0.5f, size);
    }

    private void DrawCentered(Texture2D texture, Vector2 center, Vector2 size, Color? modulate = null, CanvasItem? painter = null)
    {
        Rect2 destination = new(center - size * 0.5f, size);
        (painter ?? this).DrawTextureRect(texture, destination, false, modulate ?? Colors.White);
    }
}
