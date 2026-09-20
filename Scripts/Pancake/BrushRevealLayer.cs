using Godot;

namespace ProjectCake.Pancake;

/// <summary>Adapted from the supplied BrushReveal2D example for the Control workbench.
/// Owns only pixels, never sauce quantity or completion rules.</summary>
public partial class BrushRevealLayer : TextureRect
{
    private const int Resolution = 256;
    private readonly Image _mask = Image.CreateEmpty(Resolution, Resolution, false, Image.Format.R8);
    private ImageTexture _maskTexture = null!;
    private Vector2? _last;
    private bool _dirty;
    internal float Sample(Vector2 uv) => _mask.GetPixel(Math.Clamp((int)(uv.X * 255), 0, 255), Math.Clamp((int)(uv.Y * 255), 0, 255)).R;

    public void Configure(Texture2D art)
    {
        Texture = art;
        ExpandMode = ExpandModeEnum.IgnoreSize;
        StretchMode = StretchModeEnum.Scale;
        MouseFilter = MouseFilterEnum.Ignore;
        _mask.Fill(Colors.Black);
        _maskTexture = ImageTexture.CreateFromImage(_mask);
        var material = new ShaderMaterial { Shader = new Shader { Code = "shader_type canvas_item;\nrender_mode unshaded;\nuniform sampler2D reveal_mask : filter_linear, repeat_disable;\nuniform vec4 uv_rect = vec4(0.0,0.0,1.0,1.0);\nvoid fragment(){ COLOR.a *= texture(reveal_mask, (UV-uv_rect.xy)/uv_rect.zw).r; }" } };
        if (art is AtlasTexture atlas)
        {
            Vector2 size = atlas.Atlas.GetSize();
            material.SetShaderParameter("uv_rect", new Vector4(atlas.Region.Position.X / size.X, atlas.Region.Position.Y / size.Y, atlas.Region.Size.X / size.X, atlas.Region.Size.Y / size.Y));
        }
        material.SetShaderParameter("reveal_mask", _maskTexture);
        Material = material;
    }

    public void PaintAtGlobal(Vector2 point)
    {
        if (!point.IsFinite() || Size.X <= 0 || Size.Y <= 0) { EndStroke(); return; }
        Vector2 uv = (GetGlobalTransform().AffineInverse() * point) / Size;
        if (((uv - Vector2.One * .5f) * 2).LengthSquared() > 1) { EndStroke(); return; }
        const float radius = .075f;
        Vector2 from = _last ?? uv;
        int steps = Math.Max(1, Mathf.CeilToInt(from.DistanceTo(uv) / (radius * .4f)));
        for (int i = 0; i <= steps; i++) Stamp(from.Lerp(uv, (float)i / steps), radius);
        _last = uv;
    }

    private void Stamp(Vector2 uv, float radiusUv)
    {
        Vector2 center = uv * (Resolution - 1);
        float radius = radiusUv * (Resolution - 1);
        for (int y = Math.Max(0, (int)(center.Y - radius)); y <= Math.Min(255, (int)(center.Y + radius)); y++)
        for (int x = Math.Max(0, (int)(center.X - radius)); x <= Math.Min(255, (int)(center.X + radius)); x++)
        {
            float edge = Mathf.Clamp((radius - new Vector2(x, y).DistanceTo(center)) / (radius * .2f), 0, 1);
            float value = edge * edge * (3 - 2 * edge);
            if (value <= _mask.GetPixel(x, y).R) continue;
            _mask.SetPixel(x, y, new Color(value, 0, 0));
            _dirty = true;
        }
    }

    public void EndStroke() => _last = null;
    public void CopyReveal(BrushRevealLayer source)
    {
        _mask.CopyFrom(source._mask); EndStroke(); _dirty = true;
    }
    public void ResetReveal()
    {
        EndStroke(); _mask.Fill(Colors.Black); _dirty = true;
    }
    public override void _Process(double delta)
    {
        if (!_dirty) return;
        _maskTexture.Update(_mask); _dirty = false;
    }
    public override void _ExitTree() { _mask.Dispose(); }
}
