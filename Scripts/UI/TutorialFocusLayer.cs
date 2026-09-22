using Godot;

namespace ProjectCake.UI;

/// <summary>A description of real gameplay, never a command to advance it.</summary>
public sealed record TutorialFocusStep(string ActionId, string Text, TutorialFocusTarget[] Targets);

public sealed record TutorialFocusTarget(CanvasItem Owner, Vector2[] Points, bool Outline = true)
{
    public Texture2D? Texture { get; init; }
    public Rect2 Bounds { get; init; }
    public Rect2? Source { get; init; }
    public Rect2? ClipBounds { get; init; }
    public static TutorialFocusTarget Sprite(CanvasItem owner, Texture2D texture, Rect2 bounds, Rect2? source = null) =>
        new(owner, Rectangle(bounds)) { Texture = texture, Bounds = bounds, Source = source };
    public static TutorialFocusTarget Background(CanvasItem owner, Texture2D texture, Vector2[] guide, bool dark = false, int radius = 10)
    {
        var matte = BackgroundArtContour.Resolve(texture, guide, new Rect2(0, 0, 1920, 1080), dark, radius);
        return Sprite(owner, matte.Texture, matte.Bounds);
    }
    private static readonly Dictionary<(Texture2D, Rect2I), Vector2[][]> ArtPaths = new();
    public static Vector2[] Rectangle(Rect2 r) => new[] { r.Position, new Vector2(r.End.X, r.Position.Y), r.End, new Vector2(r.Position.X, r.End.Y) };
    public static TutorialFocusTarget Area(CanvasItem owner, Rect2 r, bool outline = true) => new(owner, Rectangle(r), outline);
    public static TutorialFocusTarget Control(Control control, bool outline = true) => control is Button button && button.GetThemeStylebox("normal") is StyleBoxFlat style
        ? new(control, ButtonContourHighlight.ContourPoints(style, new Rect2(Vector2.Zero, control.Size)), outline)
        : Area(control, new Rect2(Vector2.Zero, control.Size), outline);
    public static TutorialFocusTarget[] Artwork(Control control) => control.FindChildren("*", "", true, false)
        .OfType<ArtContourHighlight>().SelectMany(h => h.FocusTargets()).ToArray();
    public static TutorialFocusTarget Ellipse(CanvasItem owner, Rect2 r) => new(owner,
        Enumerable.Range(0, 64).Select(i => r.GetCenter() + new Vector2(Mathf.Cos(i * Mathf.Tau / 64), Mathf.Sin(i * Mathf.Tau / 64)) * r.Size * .5f).ToArray());
    public static IEnumerable<TutorialFocusTarget> Art(CanvasItem owner, Texture2D texture, Rect2 destination, Rect2? source = null, bool outline = true)
    {
        Rect2I region = (Rect2I)(source ?? new Rect2(Vector2.Zero, texture.GetSize()));
        if (!ArtPaths.TryGetValue((texture, region), out Vector2[][]? paths))
        {
            using Image image = texture.GetImage();
            using Image crop = image.GetRegion(region);
            using var alpha = new Bitmap(); alpha.CreateFromImageAlpha(crop, .2f);
            paths = alpha.OpaqueToPolygons(new Rect2I(Vector2I.Zero, crop.GetSize()), 1).Where(p => p.Length >= 3).ToArray();
            ArtPaths[(texture, region)] = paths;
        }
        foreach (var path in paths)
            yield return new(owner, path.Select(p => destination.Position + p * destination.Size / (Vector2)region.Size).ToArray(), outline);
    }
}

/// <summary>City-owned presentation only; focus targets and teaching progress remain shared.</summary>
public enum TutorialFocusCardSkin { Tianjin, Wuhan }

/// <summary>Pass-through spotlight. A small offscreen mask preserves arbitrary incumbent art contours.</summary>
public partial class TutorialFocusLayer : Control
{
    public Func<TutorialFocusStep?> Resolve { get; set; } = () => null;
    public Func<IEnumerable<TutorialFocusTarget>> KeepClear { get; set; } = () => Array.Empty<TutorialFocusTarget>();
    public TutorialFocusCardSkin CardSkin { get; init; } = TutorialFocusCardSkin.Tianjin;
    public bool PlaceNearTargets { get; init; }
    public bool AllowDismiss { get; init; } = true;
    internal bool DismissAtScreenEdge { get; init; }
    internal Func<bool> ShowDismiss { get; init; } = () => true;
    public Func<Control?> PresentationCard { get; set; } = () => null;
    public bool Dismissed { get; private set; }
    public string? CurrentAction { get; private set; }
    internal string CurrentText => _hint.Text;
    internal Rect2 CardBounds => (PresentationCard() ?? _card).GetGlobalRect();
    internal bool DefaultCardVisible => _card.IsVisibleInTree();
    internal IReadOnlyList<Vector2[]> FocusPolygons => _outlines;
    private readonly List<Vector2[]> _outlines = new();
    private readonly List<(TutorialFocusTarget Target, Transform2D Transform)> _shapes = new();
    private SubViewport _mask = null!;
    private TutorialFocusMask _ink = null!;
    private Panel _card = null!;
    private Label _hint = null!;
    private Button _close = null!;
    private string _layoutText = "";
    private TextureRect _shade = null!;

    public override void _Ready()
    {
        Callable.From(() => ButtonHoverFeedback.AttachTree(this)).CallDeferred();
        Name = "TutorialFocus"; MouseFilter = MouseFilterEnum.Ignore; ZIndex = 85;
        Size = new Vector2(1920, 1080);
        _mask = new SubViewport { Size = new Vector2I(1920, 1080), TransparentBg = true, Disable3D = true,
            RenderTargetUpdateMode = SubViewport.UpdateMode.Disabled, GuiDisableInput = true };
        AddChild(_mask); _ink = new TutorialFocusMask(); _mask.AddChild(_ink);
        var material = new ShaderMaterial { Shader = new Shader { Code = "shader_type canvas_item; render_mode unshaded; void fragment() { COLOR = vec4(0.0, 0.0, 0.0, 0.45 * (1.0 - texture(TEXTURE, UV).a)); }" } };
        _shade = new TextureRect { Size = Size, Texture = _mask.GetTexture(), ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            Material = material, MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_shade);
        _card = new Panel { Position = new Vector2(540, 32), Size = new Vector2(840, 124), MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_card);
        BuildCardChrome();
        AddChild(new TutorialFocusOutline { Layer = this });
        Hide();
    }

    private void BuildCardChrome()
    {
        bool wuhan = CardSkin == TutorialFocusCardSkin.Wuhan;
        if (wuhan) WuhanTeachingUi.ApplyPanel(_card); else TianjinTeachingUi.ApplyPanel(_card);
        _hint = new Label { Size = new(540, 76), AutowrapMode = TextServer.AutowrapMode.WordSmart,
            VerticalAlignment = VerticalAlignment.Center, MouseFilter = MouseFilterEnum.Ignore };
        _hint.AddThemeFontSizeOverride("font_size", 24);
        _hint.AddThemeColorOverride("font_color", wuhan ? WuhanUi.Text : TianjinUi.BrownText); _card.AddChild(_hint);
        TeachingEmphasis.Attach(_hint);
        _close = new Button { Name = "SkipGuidance", Text = DismissAtScreenEdge ? "跳过教学" : "本次关闭", FocusMode = FocusModeEnum.All };
        _close.Pressed += Dismiss;
        Vector2 position = DismissAtScreenEdge ? new(1620, 28) : Vector2.Zero;
        Vector2 size = DismissAtScreenEdge ? new(196, 56) : new(150, 54);
        (DismissAtScreenEdge ? (Control)this : _card).AddChild(wuhan ? WuhanTeachingUi.ActionFrame(_close, position, size)
            : TianjinTeachingUi.ActionFrame(_close, position, size));
    }

    private void LayoutCard()
    {
        if (!AllowDismiss || DismissAtScreenEdge)
        {
            if (!AllowDismiss) _close.GetParent<Control>().Hide();
            float width = Mathf.Clamp(TeachingCardLayout.NaturalWidth(_hint), 300, 540);
            float height = TeachingCardLayout.Place(_hint, 64, 36, width);
            _card.Size = new(64 + width + 36, 36 + height + 22);
            _card.Position = new((1920 - _card.Size.X) / 2, 32);
            return;
        }
        if (PlaceNearTargets)
        {
            float width = Mathf.Clamp(TeachingCardLayout.NaturalWidth(_hint), 300, 440);
            float height = TeachingCardLayout.Place(_hint, 60, 38, width);
            float buttonWidth = TeachingCardLayout.ButtonWidth(_close, 150);
            TeachingCardLayout.PlaceButton(_close, new(60 + width - buttonWidth, 38 + height + 16), new(buttonWidth, 54));
            _card.Size = new(60 + width + 36, 38 + height + 16 + 54 + 22);
            return;
        }
        float textWidth = Mathf.Clamp(TeachingCardLayout.NaturalWidth(_hint), 260, 540);
        float actionWidth = TeachingCardLayout.ButtonWidth(_close, 150);
        float rowHeight = Mathf.Max(54, TeachingCardLayout.Height(_hint, textWidth));
        _card.Size = new(64 + textWidth + 24 + actionWidth + 36, 36 + rowHeight + 22);
        _card.Position = new((1920 - _card.Size.X) / 2, 32);
        TeachingCardLayout.Place(_hint, 64, 36 + (rowHeight - TeachingCardLayout.Height(_hint, textWidth)) / 2, textWidth);
        TeachingCardLayout.PlaceButton(_close, new(64 + textWidth + 24, 36 + (rowHeight - 54) / 2), new(actionWidth, 54));
    }

    public void ResetSession() { Dismissed = false; Clear(); }
    public void Dismiss() { Dismissed = true; Clear(); }
    private void Clear() { CurrentAction = null; Hide(); _mask.RenderTargetUpdateMode = SubViewport.UpdateMode.Disabled; }
    public override void _Process(double delta) => Refresh();
    public void Refresh()
    {
        TutorialFocusStep? step = Dismissed || !GetParent<CanvasItem>().IsVisibleInTree() ? null : Resolve();
        if (step is null || step.Targets.Length == 0) { Clear(); return; }
        var polygons = new List<Vector2[]>(); _outlines.Clear(); _shapes.Clear();
        var images = new List<(TutorialFocusTarget Target, Transform2D Transform)>();
        Transform2D inverse = GetGlobalTransform().AffineInverse();
        foreach (TutorialFocusTarget target in step.Targets.Concat(KeepClear()))
        {
            if (!IsInstanceValid(target.Owner) || !target.Owner.IsVisibleInTree() || target.Points.Length < 3) continue;
            Transform2D transform = inverse * target.Owner.GetGlobalTransform();
            Vector2[] points = target.Points.Select(p => transform * p).ToArray();
            if (target.Texture is null) polygons.Add(points); else images.Add((target, transform));
            if (target.Outline) { _outlines.Add(points); _shapes.Add((target, transform)); }
        }
        if (_outlines.Count == 0) { Clear(); return; }
        CurrentAction = step.ActionId; _hint.Text = step.Text;
        string translated = _hint.Tr(_hint.Text);
        if (_layoutText != translated) { _layoutText = translated; LayoutCard(); }
        Control? presentation = PresentationCard();
        _close.GetParent<Control>().Visible = AllowDismiss && ShowDismiss() && presentation is null;
        _card.Visible = presentation is null;
        if (PlaceNearTargets) PositionBesideTargets(presentation ?? _card);
        if (_ink.SetImages(images) | _ink.SetPolygons(polygons)) _mask.RenderTargetUpdateMode = SubViewport.UpdateMode.Once;
        Show(); QueueRedraw();
    }

    private void PositionBesideTargets(Control card)
    {
        Rect2 Bounds(Vector2[] points)
        {
            var rect = new Rect2(points[0], Vector2.Zero);
            foreach (var point in points) rect = rect.Expand(point);
            return rect;
        }
        var targets = _outlines.Select(Bounds).ToArray();
        Rect2 anchor = targets.Aggregate((a, b) => a.Merge(b));
        var clear = KeepClear().Where(t => IsInstanceValid(t.Owner) && t.Owner.IsVisibleInTree() && t.Points.Length > 0)
            .Select(t => Bounds(t.Points.Select(p => GetGlobalTransform().AffineInverse() * t.Owner.GetGlobalTransform() * p).ToArray()));
        Rect2[] obstacles = targets.Concat(clear).ToArray();
        const float margin = 24, gap = 24;
        Vector2 size = card.Size;
        Vector2 center = anchor.GetCenter();
        Vector2[] candidates = {
            new(center.X - size.X / 2, anchor.Position.Y - gap - size.Y),
            new(anchor.Position.X - gap - size.X, center.Y - size.Y / 2),
            new(anchor.End.X + gap, center.Y - size.Y / 2),
            new(center.X - size.X / 2, anchor.End.Y + gap),
        };
        Vector2 Clamp(Vector2 p) => new(Mathf.Clamp(p.X, margin, Mathf.Max(margin, Size.X - size.X - margin)),
            Mathf.Clamp(p.Y, margin, Mathf.Max(margin, Size.Y - size.Y - margin)));
        float Score(Vector2 p)
        {
            var rect = new Rect2(p, size);
            float overlap = obstacles.Sum(o => { var intersection = rect.Intersection(o.Grow(12)); return intersection.HasArea() ? intersection.Size.X * intersection.Size.Y : 0; });
            return overlap * 1000 + rect.GetCenter().DistanceSquaredTo(center);
        }
        Vector2 position = candidates.Select(Clamp).OrderBy(Score).First();
        // Anchor to the actual control/art contour, never to the moving mouse or dragged sprite.
        card.GlobalPosition = GetGlobalTransform() * position;
    }

    internal void DrawOutlines(CanvasItem canvas)
    {
        foreach (var shape in _shapes)
        {
            canvas.DrawSetTransformMatrix(shape.Transform);
            var target = shape.Target;
            if (target.Texture is { } texture)
                DrawnArtContour.Draw(canvas, texture, target.Bounds, InteractionHighlightState.Hover, target.Source, drawingTransform: shape.Transform, clipBounds: target.ClipBounds);
            else {
                canvas.DrawSetTransformMatrix(Transform2D.Identity);
                InteractionHighlightPresentation.DrawPath(canvas, target.Points.Select(p => shape.Transform * p).ToArray(), InteractionHighlightState.Hover);
            }
        }
        canvas.DrawSetTransformMatrix(Transform2D.Identity);
    }
}

internal partial class TutorialFocusMask : Control
{
    private List<(TutorialFocusTarget Target, Transform2D Transform)> _images = new();
    public bool SetImages(List<(TutorialFocusTarget Target, Transform2D Transform)> images)
    {
        bool same = _images.Count == images.Count && _images.Zip(images).All(p => p.First.Transform == p.Second.Transform
            && p.First.Target.Texture == p.Second.Target.Texture && p.First.Target.Bounds == p.Second.Target.Bounds && p.First.Target.Source == p.Second.Target.Source
            && p.First.Target.ClipBounds == p.Second.Target.ClipBounds);
        if (same) return false;
        _images = images; QueueRedraw(); return true;
    }
    private List<Vector2[]> _polygons = new();
    public bool SetPolygons(List<Vector2[]> polygons)
    {
        if (_polygons.Count == polygons.Count && _polygons.Zip(polygons).All(p => p.First.SequenceEqual(p.Second))) return false;
        _polygons = polygons; QueueRedraw(); return true;
    }
    public override void _Draw()
    {
        foreach (Vector2[] polygon in _polygons) DrawColoredPolygon(polygon, Colors.White);
        foreach (var shape in _images)
        {
            DrawSetTransformMatrix(shape.Transform);
            Rect2 bounds = shape.Target.Bounds;
            Rect2 visible = shape.Target.ClipBounds is { } clip ? bounds.Intersection(clip) : bounds;
            if (!visible.HasArea()) continue;
            Rect2 source = shape.Target.Source ?? new Rect2(Vector2.Zero, shape.Target.Texture!.GetSize());
            DrawTextureRectRegion(shape.Target.Texture!, visible,
                new Rect2(source.Position + (visible.Position - bounds.Position) / bounds.Size * source.Size,
                    visible.Size / bounds.Size * source.Size));
        }
        DrawSetTransformMatrix(Transform2D.Identity);
    }
}

internal partial class TutorialFocusOutline : Control
{
    public TutorialFocusLayer Layer { get; set; } = null!;
    public TutorialFocusOutline() { MouseFilter = MouseFilterEnum.Ignore; }
    public override void _Process(double delta) => QueueRedraw();
    public override void _Draw() => Layer.DrawOutlines(this);
}
