using Godot;
using System.Runtime.CompilerServices;

namespace ProjectCake.UI;

/// <summary>Draws only the outside alpha contour; source art, materials and hit areas stay independent.</summary>
public partial class ArtContourHighlight : Control
{
    private static Shader? _shader;
    private static readonly ConditionalWeakTable<Texture2D, Texture2D> AtlasImages = new();
    private TextureRect _source = null!;
    private TextureRect? _unionSource;
    private Func<InteractionHighlightState> _resolve = null!;
    private ShaderMaterial _material = null!;
    private Texture2D? _texture;
    private Texture2D? _unionTexture;
    private Rect2 _artRect;
    private Rect2 _drawRect;
    private InteractionHighlightState _state;
    private float _opacity;

    public static ArtContourHighlight Attach(TextureRect source, Func<InteractionHighlightState> state,
        TextureRect? unionSource = null)
    {
        var outline = new ArtContourHighlight
        {
            Name = source.Name + "Contour", MouseFilter = MouseFilterEnum.Ignore,
            _source = source, _unionSource = unionSource, _resolve = state,
        };
        source.GetParent().AddChild(outline);
        // A combined portrait contour belongs above both opaque art layers.
        int index = Math.Max(source.GetIndex(), unionSource?.GetIndex() ?? source.GetIndex());
        source.GetParent().MoveChild(outline, index + 1);
        return outline;
    }

    public override void _Ready()
    {
        _material = new ShaderMaterial
        {
            Shader = _shader ??= GD.Load<Shader>("res://resource/shaders/interaction_contour.gdshader"),
        };
        Material = _material;
        Visible = false;
    }

    public override void _Process(double delta)
    {
        if (!IsInstanceValid(_source) || _source.IsQueuedForDeletion()) { QueueFree(); return; }
        bool available = _source.IsVisibleInTree() && _source.Texture is not null;
        InteractionHighlightState next = available ? _resolve() : InteractionHighlightState.None;
        bool reduced = ProjectSettings.HasSetting("accessibility/reduce_motion")
            && ProjectSettings.GetSetting("accessibility/reduce_motion").AsBool();
        _opacity = reduced ? (next == InteractionHighlightState.None ? 0 : 1)
            : Mathf.MoveToward(_opacity, next == InteractionHighlightState.None ? 0 : 1, (float)delta * 10);
        if (next != InteractionHighlightState.None) _state = next;
        Visible = available && _opacity > 0;
        if (!Visible) return;
        Position = _source.Position; Size = _source.Size; Scale = _source.Scale;
        Rotation = _source.Rotation; PivotOffset = _source.PivotOffset;
        ZIndex = _source.ZIndex; ZAsRelative = _source.ZAsRelative;
        Modulate = _source.Modulate * _source.SelfModulate;
        _texture = ResolveTexture(_source.Texture!);
        bool hasUnion = IsInstanceValid(_unionSource) && _unionSource!.IsVisibleInTree() && _unionSource.Texture is not null;
        _unionTexture = hasUnion ? ResolveTexture(_unionSource!.Texture!) : _texture;
        _artRect = FittedRect(_source.Texture!.GetSize(), Size, _source.StretchMode);
        if (_artRect.Size.X <= 0 || _artRect.Size.Y <= 0) { Visible = false; return; }
        ConfigureLayer("first", _source, _artRect);
        _drawRect = _artRect;
        if (hasUnion)
        {
            Rect2 secondRect = FittedRect(_unionSource!.Texture!.GetSize(), _unionSource.Size, _unionSource.StretchMode);
            ConfigureLayer("second", _unionSource, secondRect);
            Transform2D relative = GetGlobalTransform().AffineInverse() * _unionSource.GetGlobalTransform();
            _drawRect = _drawRect.Merge(relative * secondRect);
        }
        _material.SetShaderParameter("has_second", hasUnion);
        // Include one antialias pixel beyond the screen-space stroke, even at 720p.
        _drawRect = _drawRect.Grow(InteractionHighlightPresentation.LocalWidthFor(this, _state) +
            InteractionHighlightPresentation.LocalWidthFor(this, InteractionHighlightState.Hover) / 4f);
        Color color = InteractionHighlightPresentation.ColorFor(_state);
        color.A *= _opacity;
        _material.SetShaderParameter("contour_color", color);
        _material.SetShaderParameter("outline_pixels", InteractionHighlightPresentation.WidthFor(_state));
        _material.SetShaderParameter("second_layer", _unionTexture);
        _material.SetShaderParameter("first_layer", _texture);
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (_texture is null || _artRect.Size.X <= 0 || _artRect.Size.Y <= 0) return;
        DrawTextureRect(_texture, _drawRect, false);
    }

    private void ConfigureLayer(string prefix, TextureRect layer, Rect2 fitted)
    {
        Transform2D local = layer.GetGlobalTransform().AffineInverse() * GetGlobalTransform();
        Transform2D uv = new Transform2D(new Vector2(1 / fitted.Size.X, 0),
            new Vector2(0, 1 / fitted.Size.Y), -fitted.Position / fitted.Size) * local;
        _material.SetShaderParameter(prefix + "_uv_x", new Vector3(uv.X.X, uv.Y.X, uv.Origin.X));
        _material.SetShaderParameter(prefix + "_uv_y", new Vector3(uv.X.Y, uv.Y.Y, uv.Origin.Y));
        _material.SetShaderParameter(prefix + "_flip", new Vector2(layer.FlipH ? 1 : 0, layer.FlipV ? 1 : 0));
        Rect2 clip = layer.StretchMode == TextureRect.StretchModeEnum.KeepAspectCovered
            ? new Rect2(-fitted.Position / fitted.Size, layer.Size / fitted.Size) : new Rect2(0, 0, 1, 1);
        _material.SetShaderParameter(prefix + "_clip", new Vector4(clip.Position.X, clip.Position.Y, clip.End.X, clip.End.Y));
    }

    private static Texture2D ResolveTexture(Texture2D texture) => texture is AtlasTexture
        ? AtlasImages.GetValue(texture, source => ImageTexture.CreateFromImage(source.GetImage())) : texture;

    private static Rect2 FittedRect(Vector2 texture, Vector2 size, TextureRect.StretchModeEnum mode)
    {
        if (mode is TextureRect.StretchModeEnum.Scale or TextureRect.StretchModeEnum.Tile)
            return new Rect2(Vector2.Zero, size);
        if (mode == TextureRect.StretchModeEnum.Keep) return new Rect2(Vector2.Zero, texture);
        if (mode == TextureRect.StretchModeEnum.KeepCentered) return new Rect2((size - texture) * .5f, texture);
        float ratio = mode == TextureRect.StretchModeEnum.KeepAspectCovered
            ? Math.Max(size.X / texture.X, size.Y / texture.Y) : Math.Min(size.X / texture.X, size.Y / texture.Y);
        Vector2 fitted = texture * ratio;
        return new Rect2(mode == TextureRect.StretchModeEnum.KeepAspect ? Vector2.Zero : (size - fitted) * .5f, fitted);
    }
}
