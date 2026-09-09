using Godot;

namespace ProjectCake.UI;

/// <summary>Independent liquid layer sampled from the original full bowl art.</summary>
public partial class LiquidStockView : TextureRect
{
    private ShaderMaterial _surface = null!;
    public int Tier { get; private set; } = 3;

    public override void _Ready() => _surface = (ShaderMaterial)Material;

    public void Configure(Texture2D fullBowl, bool sauce)
    {
        Texture = fullBowl;
        _surface.SetShaderParameter("source_center", sauce ? new Vector2(0.495f, 0.410f) : new Vector2(0.498f, 0.403f));
        _surface.SetShaderParameter("source_radius", sauce ? new Vector2(0.385f, 0.235f) : new Vector2(0.365f, 0.224f));
    }

    public void SetTier(int tier)
    {
        Tier = Math.Clamp(tier, 0, 3);
        Visible = Tier > 0;
        _surface.SetShaderParameter("amount", Tier switch { 1 => 0.58f, 2 => 0.8f, _ => 1f });
    }
}
