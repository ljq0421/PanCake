using Godot;

namespace ProjectCake.UI;

/// <summary>Decorative income display; the day ledger remains the sole money owner.</summary>
public partial class CoinTrayView : Control
{
    private readonly TextureRect[] _coins = new TextureRect[12];
    private readonly Control _surface;
    public int VisibleCoinCount { get; private set; }
    public Vector2 LandingPoint => _surface.GetGlobalTransform() * (_surface.Size * .5f);
    internal Rect2 SurfaceBounds => _surface.GetGlobalRect();
    internal IReadOnlyList<TextureRect> Coins => _coins;

    public CoinTrayView(TianjinArtCatalog art)
    {
        Name = "CoinTray";
        ZIndex = 40;
        MouseFilter = MouseFilterEnum.Ignore;
        var tray = TianjinUi.Texture(art.ServingTray, TianjinWorkbenchLayout.FinishedTray.Size);
        tray.Name = "CoinTrayArt";
        tray.MouseFilter = MouseFilterEnum.Ignore;
        AddChild(tray);
        _surface = new Control
        {
            Name = "CoinTraySurface",
            Position = TianjinWorkbenchLayout.ServingTrayFloor.Position,
            Size = TianjinWorkbenchLayout.ServingTrayFloor.Size,
            ClipContents = true,
            MouseFilter = MouseFilterEnum.Ignore,
        };
        AddChild(_surface);
        for (int i = 0; i < _coins.Length; i++)
        {
            var coin = TianjinUi.Texture(art.Coin, new Vector2(24, 24));
            // All twelve complete coin rectangles fit inside the tray floor.
            coin.Position = new Vector2(17 + i % 4 * 32, 16 - i / 4 * 7);
            coin.MouseFilter = MouseFilterEnum.Ignore;
            coin.Visible = false;
            _surface.AddChild(coin);
            _coins[i] = coin;
        }
        var caption = TianjinUi.Panel(TianjinUi.Cream, 10, 2, false);
        var style = (StyleBoxFlat)caption.GetThemeStylebox("panel");
        style.BorderColor = TianjinUi.Brown;
        style.ContentMarginLeft = style.ContentMarginRight = 8;
        style.ContentMarginTop = style.ContentMarginBottom = 2;
        // Keep the caption centered and clear of the stove's curved upper edge.
        caption.Position = new Vector2(55, 80);
        caption.Size = new Vector2(140, 30);
        caption.MouseFilter = MouseFilterEnum.Ignore;
        var label = TianjinUi.Label("金币托盘", 18, TianjinUi.BrownText, HorizontalAlignment.Center);
        label.MouseFilter = MouseFilterEnum.Ignore;
        caption.AddChild(label);
        AddChild(caption);
    }

    public void RenderRevenue(int revenue)
    {
        VisibleCoinCount = (int)Math.Clamp(Math.Ceiling(Math.Max(0, revenue) / 10.0), 0, 12);
        for (int i = 0; i < _coins.Length; i++) _coins[i].Visible = i < VisibleCoinCount;
    }
}
