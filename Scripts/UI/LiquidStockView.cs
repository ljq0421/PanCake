using Godot;

namespace ProjectCake.UI;

/// <summary>Independent liquid layer sampled from the original full bowl art.</summary>
public partial class LiquidStockView : TextureRect
{
    private readonly ShaderMaterial _surface;
    public int Tier { get; private set; } = 3;

    public LiquidStockView(Texture2D fullBowl, bool sauce)
    {
        MouseFilter = MouseFilterEnum.Ignore;
        ExpandMode = ExpandModeEnum.IgnoreSize;
        StretchMode = StretchModeEnum.Scale;
        Texture = fullBowl;
        _surface = new ShaderMaterial
        {
            Shader = new Shader
            {
                Code = """
                    shader_type canvas_item;
                    uniform vec2 source_center;
                    uniform vec2 source_radius;
                    uniform float amount = 1.0;
                    void fragment() {
                        vec2 center = source_center + vec2(0.0, (1.0 - amount) * 0.16);
                        vec2 radius = source_radius * vec2(0.6 + 0.4 * amount, amount);
                        vec2 local = (UV - center) / radius;
                        float distance_to_edge = length(local);
                        float coverage = 1.0 - smoothstep(1.0 - fwidth(distance_to_edge), 1.0, distance_to_edge);
                        vec4 liquid = texture(TEXTURE, source_center + local * source_radius);
                        COLOR = vec4(liquid.rgb, liquid.a * coverage);
                    }
                    """,
            },
        };
        _surface.SetShaderParameter("source_center", sauce ? new Vector2(0.495f, 0.410f) : new Vector2(0.498f, 0.403f));
        _surface.SetShaderParameter("source_radius", sauce ? new Vector2(0.385f, 0.235f) : new Vector2(0.365f, 0.224f));
        Material = _surface;
    }

    public void SetTier(int tier)
    {
        Tier = Math.Clamp(tier, 0, 3);
        Visible = Tier > 0;
        _surface.SetShaderParameter("amount", Tier switch { 1 => 0.58f, 2 => 0.8f, _ => 1f });
    }
}
