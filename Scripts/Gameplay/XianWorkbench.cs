using Godot;
using ProjectCake.Core;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class XianDayScreen
{
    public Control Workbench { get; private set; } = null!;
    public CoinTrayView CoinTray { get; private set; } = null!;
    public CoinCollectionFeedback CollectionFeedback { get; private set; } = null!;
    private TextureRect _workbenchArt = null!;
    private Texture2D _initialArt = null!, _soupArt = null!;
    public bool SoupWorkbenchVisible => _workbenchArt.Texture == _soupArt;

    private static void Place(Control node, float x, float y, float width, float height)
    {
        node.SetAnchorsAndOffsetsPreset(LayoutPreset.TopLeft);
        node.CustomMinimumSize = Vector2.Zero;
        node.Position = new(x, y); node.Size = new(width, height);
    }

    private void PrepareWorkbench()
    {
        var original = GetChildren().OfType<Control>().ToArray();
        var letterbox = new ColorRect { Name = "Letterbox", Color = new Color("#281b15"), MouseFilter = MouseFilterEnum.Ignore };
        AddChild(letterbox); letterbox.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        Workbench = new Control { Name = "Workbench", Size = new(1920, 1080), MouseFilter = MouseFilterEnum.Ignore };
        AddChild(Workbench);
        foreach (Control child in original) child.Reparent(Workbench, false);
        foreach (ColorRect panel in original.OfType<ColorRect>()) if (panel != _blocker) panel.Hide();
        _initialArt = GD.Load<Texture2D>("res://resource/art/XiAn/西安早餐铺主界面-肉夹馍.png");
        _soupArt = GD.Load<Texture2D>("res://resource/art/XiAn/西安早餐铺主界面-肉夹馍-肉丸锅.png");
        _workbenchArt = new TextureRect { Name = "WorkbenchArt", Texture = _initialArt,
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize, MouseFilter = MouseFilterEnum.Ignore };
        Workbench.AddChild(_workbenchArt); Workbench.MoveChild(_workbenchArt, 0);
        Place(_workbenchArt, 0, 0, 1920, 1080);
        var fifth = (XianSurface)_customers[0].Duplicate(); fifth.Name = "customer4";
        Workbench.AddChild(fifth); _customers.Add(fifth);
        var bowl = (XianSurface)Workbench.GetNode<XianSurface>("soup").Duplicate(); bowl.Name = "soup_bowl";
        Workbench.AddChild(bowl);
        foreach (XianSurface surface in Workbench.GetChildren().OfType<XianSurface>())
        {
            surface.Kind = surface.Name.ToString().StartsWith("customer") ? "customer" : surface.Name;
            surface.ArtworkMode = true;
        }
        for (int i = 0; i < 5; i++) Place(_customers[i], 35 + i * 372, 235, 362, 270);
        Place(Workbench.GetNode<Control>("oven"), 70, 548, 560, 240);
        Place(Workbench.GetNode<Control>("board"), 700, 575, 530, 210);
        Place(Workbench.GetNode<Control>("bun"), 990, 820, 315, 180);
        Place(Workbench.GetNode<Control>("meat"), 700, 786, 280, 66);
        Place(Workbench.GetNode<Control>("juice"), 774, 854, 178, 135);
        Place(Workbench.GetNode<Control>("soup"), 1430, 540, 420, 245);
        Place(bowl, 1430, 825, 425, 175);
        foreach (Button button in original.OfType<Button>())
        {
            button.AddThemeFontSizeOverride("font_size", 22);
        }
        Place(Workbench.GetNode<Control>("OvenAction"), 70, 790, 205, 48);
        Place(_batch, 285, 790, 145, 48);
        Place(Workbench.GetNode<Control>("chop"), 700, 530, 150, 44);
        Place(Workbench.GetNode<Control>("refill_meat"), 860, 530, 170, 44);
        Place(Workbench.GetNode<Control>("wrap"), 1000, 1000, 140, 44);
        Place(Workbench.GetNode<Control>("deliver"), 1150, 1000, 140, 44);
        Place(Workbench.GetNode<Control>("refill_juice"), 780, 1000, 175, 44);
        Place(Workbench.GetNode<Control>("deliver_soup"), 1645, 1000, 205, 44);
        Place(Workbench.GetNode<Control>("refill_soup"), 1430, 1000, 205, 44);
        Place(_heading, 40, 18, 720, 52); Caption(_heading, 30);
        Place(_clock, 1100, 20, 430, 50); Caption(_clock, 24);
        Place(_inventory, 40, 82, 1460, 42); Caption(_inventory, 23);
        Place(_tutorial, 40, 132, 1840, 60); Caption(_tutorial, 23);
        Place(_feedback, 40, 198, 1840, 33); Caption(_feedback, 22);
        CoinTray = SceneFactory.Instantiate<CoinTrayView>("res://Scenes/UI/CoinTrayView.tscn");
        Workbench.AddChild(CoinTray); CoinTray.ConfigureButtonPresentation(); Place(CoinTray, 1600, 82, 240, 44);
        CollectionFeedback = SceneFactory.Instantiate<CoinCollectionFeedback>("res://Scenes/UI/CoinCollectionFeedback.tscn");
        AddChild(CollectionFeedback);
        CollectionFeedback.Bind(CoinTray, Workbench, _clock, GD.Load<Texture2D>("res://resource/art/TianJin/金币图标.png"), () => CanInteract);
        Resized += FitWorkbench; FitWorkbench();
    }

    private static void Caption(Label label, int fontSize)
    {
        label.MouseFilter = MouseFilterEnum.Ignore;
        label.AddThemeFontSizeOverride("font_size", fontSize);
        label.AddThemeStyleboxOverride("normal", new StyleBoxFlat { BgColor = new Color("#fff2dfe8"),
            CornerRadiusTopLeft = 8, CornerRadiusTopRight = 8, CornerRadiusBottomLeft = 8, CornerRadiusBottomRight = 8,
            ContentMarginLeft = 10, ContentMarginRight = 10 });
    }

    private void FitWorkbench()
    {
        float scale = Math.Min(Size.X / 1920f, Size.Y / 1080f);
        Workbench.Scale = Vector2.One * scale;
        Workbench.Position = (Size - new Vector2(1920, 1080) * scale) / 2;
    }

    private void RenderWorkbench()
    {
        bool soupOpen = Session.Soup is not null;
        Texture2D texture = soupOpen ? _soupArt : _initialArt;
        if (_workbenchArt.Texture != texture) _workbenchArt.Texture = texture;
        foreach (string id in new[] { "soup", "soup_bowl" }) _surfaces[id].Visible = soupOpen;
        _buttons["deliver_soup"].Visible = _buttons["refill_soup"].Visible = soupOpen;
        var bowl = _surfaces["soup_bowl"];
        bowl.Amount = Session.Soup?.HasBowl == true ? 1 : 0;
        bowl.Title = bowl.Amount > 0 ? "胡辣汤 · 拖给顾客" : "盛汤后放在这里";
        bowl.Detail = ""; bowl.Refresh();
        CoinTray.RenderRevenue(_controller.Ledger?.Build().TotalRevenue ?? 0, _controller.Ledger?.CompletedCustomers ?? 0);
        _surfaces["oven"].Unavailable = Session.Oven is null;
    }
}
