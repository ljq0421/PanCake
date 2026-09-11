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

    private Control _pauseMenu = null!;
    private readonly XianArtCatalog _xianArt = new();
    private readonly OrderBubbleView[] _orders = new OrderBubbleView[5];
    private readonly TianjinArtCatalog _customerArt = new();
    private readonly CustomerPortraitView[] _portraits = new CustomerPortraitView[5];

    private void PrepareWorkbench()
    {
        Workbench = GetNode<Control>("Workbench");
        _workbenchArt = Workbench.GetNode<TextureRect>("WorkbenchArt");
        _initialArt = _workbenchArt.Texture;
        _soupArt = GD.Load<Texture2D>("res://resource/art/XiAn/西安早餐铺主界面-肉夹馍-肉丸锅.png");
        CoinTray = Workbench.GetNode<CoinTrayView>("CoinTray");
        CollectionFeedback = GetNode<CoinCollectionFeedback>("CoinCollectionFeedback");
        _pauseMenu = Workbench.GetNode<Control>("PauseMenu");
        for (int i = 0; i < _portraits.Length; i++)
        {
            _portraits[i] = _customers[i].GetNode<CustomerPortraitView>("Portrait");
            _orders[i] = _customers[i].GetNode<OrderBubbleView>("OrderBubble");
            _orders[i].ConfigureXian(_xianArt);
        }
        CollectionFeedback.Bind(CoinTray, Workbench, _clock, GD.Load<Texture2D>("res://resource/art/TianJin/金币图标.png"), () => CanInteract);
        Resized += FitWorkbench;
        FitWorkbench();
    }

    private void FitWorkbench()
    {
        float scale = Math.Min(Size.X / 1920f, Size.Y / 1080f);
        Workbench.Scale = Vector2.One * scale;
        Workbench.Position = (Size - new Vector2(1920, 1080) * scale) / 2;
    }

    private void RenderWorkbench()
    {
        _pauseMenu.Visible = _controller.IsPaused && !_results.Visible;
        bool soupOpen = Session.Soup is not null;
        Texture2D texture = soupOpen ? _soupArt : _initialArt;
        if (_workbenchArt.Texture != texture) _workbenchArt.Texture = texture;
        foreach (string id in new[] { "soup", "soup_bowl" }) _surfaces[id].Visible = soupOpen;
        _buttons["deliver_soup"].Visible = _buttons["refill_soup"].Visible = soupOpen;
        var bowl = _surfaces["soup_bowl"];
        bowl.Amount = Session.Soup?.HasBowl == true ? 1 : 0;
        bowl.Title = bowl.Amount > 0 ? "胡辣汤 · 拖给顾客" : "";
        bowl.Detail = ""; bowl.Refresh();
        CoinTray.RenderRevenue(_controller.Ledger?.Build().TotalRevenue ?? 0, _controller.Ledger?.CompletedCustomers ?? 0);
        _surfaces["oven"].Unavailable = Session.Oven is null;
    }
}
