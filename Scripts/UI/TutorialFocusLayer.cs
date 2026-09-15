using Godot;

namespace ProjectCake.UI;

/// <summary>A description of real gameplay, never a command to advance it.</summary>
public sealed record TutorialFocusStep(string ActionId, string Text, TutorialFocusTarget[] Targets);

public sealed record TutorialFocusTarget(CanvasItem Owner, Vector2[] Points, bool Outline = true)
{
    public Texture2D? Texture { get; init; }
    public Rect2 Bounds { get; init; }
    public Rect2? Source { get; init; }
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

/// <summary>Pass-through spotlight. A small offscreen mask preserves arbitrary incumbent art contours.</summary>
public partial class TutorialFocusLayer : Control
{
    public Func<TutorialFocusStep?> Resolve { get; set; } = () => null;
    public Func<IEnumerable<TutorialFocusTarget>> KeepClear { get; set; } = () => Array.Empty<TutorialFocusTarget>();
    public bool Dismissed { get; private set; }
    public string? CurrentAction { get; private set; }
    internal string CurrentText => _hint.Text;
    internal IReadOnlyList<Vector2[]> FocusPolygons => _outlines;
    private readonly List<Vector2[]> _outlines = new();
    private readonly List<(TutorialFocusTarget Target, Transform2D Transform)> _shapes = new();
    private SubViewport _mask = null!;
    private TutorialFocusMask _ink = null!;
    private Panel _card = null!;
    private Label _hint = null!;
    private TextureRect _shade = null!;

    public override void _Ready()
    {
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
        _card.AddThemeStyleboxOverride("panel", TianjinUi.Box(TianjinUi.Paper, 12, 2, false)); AddChild(_card);
        _hint = new Label { Position = new Vector2(24, 16), Size = new Vector2(620, 92), AutowrapMode = TextServer.AutowrapMode.WordSmart,
            VerticalAlignment = VerticalAlignment.Center, MouseFilter = MouseFilterEnum.Ignore };
        _hint.AddThemeFontSizeOverride("font_size", 24); _hint.AddThemeColorOverride("font_color", TianjinUi.BrownText); _card.AddChild(_hint);
        var close = TianjinUi.Button("本次关闭", minimumSize: new Vector2(148, 48));
        close.Position = new Vector2(668, 38); close.Size = new Vector2(148, 48); close.Pressed += Dismiss; _card.AddChild(close);
        AddChild(new TutorialFocusOutline { Layer = this });
        Hide();
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
        // The card lives above the workbench and does not follow the pointer across click targets.
        polygons.Add(TutorialFocusTarget.Rectangle(new Rect2(_card.Position, _card.Size)));
        if (_ink.SetImages(images) | _ink.SetPolygons(polygons)) _mask.RenderTargetUpdateMode = SubViewport.UpdateMode.Once;
        Show(); QueueRedraw();
    }

    internal void DrawOutlines(CanvasItem canvas)
    {
        foreach (var shape in _shapes)
        {
            canvas.DrawSetTransformMatrix(shape.Transform);
            var target = shape.Target;
            if (target.Texture is { } texture)
                DrawnArtContour.Draw(canvas, texture, target.Bounds, InteractionHighlightState.Hover, target.Source, drawingTransform: shape.Transform);
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
            && p.First.Target.Texture == p.Second.Target.Texture && p.First.Target.Bounds == p.Second.Target.Bounds && p.First.Target.Source == p.Second.Target.Source);
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
            DrawTextureRectRegion(shape.Target.Texture!, shape.Target.Bounds,
                shape.Target.Source ?? new Rect2(Vector2.Zero, shape.Target.Texture!.GetSize()));
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
