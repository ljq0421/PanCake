using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class TianjinMapScreen : Control
{
    public event Action? HubRequested;
    public event Action<string>? CityRequested;

    private SaveService _save = null!;
    private TianjinArtCatalog _art = null!;
    private PanelContainer _tianjinCard = null!;
    private Label _tianjinState = null!;
    private PanelContainer _wuhanCard = null!;
    private Label _wuhanState = null!;
    private TextureRect _wuhanLockedIcon = null!;
    private Label _wuhanUnlockedEmblem = null!;
    private bool _lightUpPlayed;
    private PanelContainer _xianCard = null!;
    private Label _xianState = null!;

    // Production keeps progression gating intact. QA can reach any map card with
    // the existing --dev-ui launch flag, without marking that city as unlocked.
    public bool DeveloperToolsVisible => OS.GetCmdlineUserArgs().Contains("--dev-ui", StringComparer.Ordinal);

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _art = new TianjinArtCatalog();
        this.FindButton("测试直达武汉").Pressed += () => CityRequested?.Invoke(StableIds.Cities.Wuhan);
        this.FindButton("返回经营首页").Pressed += () => HubRequested?.Invoke();
        Button xianTest = this.FindButton("测试直达西安");
        xianTest.Visible = DeveloperToolsVisible;
        xianTest.Pressed += () => CityRequested?.Invoke(StableIds.Cities.Xian);
        this.FindButton("测试直达广州").Pressed += () => CityRequested?.Invoke(StableIds.Cities.Guangzhou);
        Button? yangzhouTest = this.FindOptionalButton("测试直达扬州");
        if (yangzhouTest is not null)
        {
            yangzhouTest.Visible = DeveloperToolsVisible;
            yangzhouTest.Pressed += () => CityRequested?.Invoke(ProjectCake.Yangzhou.YangzhouCatalog.CityId);
        }
        _guangzhouEnter.Pressed += () => CityRequested?.Invoke(StableIds.Cities.Guangzhou);
        _yangzhouEnter.Pressed += () => CityRequested?.Invoke(ProjectCake.Yangzhou.YangzhouCatalog.CityId);
        _tianjinCard.GuiInput += input => { if (IsClick(input)) CityRequested?.Invoke(StableIds.Cities.Tianjin); };
        _wuhanCard.GuiInput += input =>
        {
            bool unlocked = _save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan, StringComparer.Ordinal);
            if (IsClick(input) && CanEnterCity(unlocked, DeveloperToolsVisible)) CityRequested?.Invoke(StableIds.Cities.Wuhan);
        };
        _xianCard.GuiInput += input =>
        {
            bool unlocked = _save.Data.UnlockedCityIds.Contains(StableIds.Cities.Xian, StringComparer.Ordinal);
            if (IsClick(input) && CanEnterCity(unlocked, DeveloperToolsVisible)) CityRequested?.Invoke(StableIds.Cities.Xian);
        };
    }

    public void Initialize(SaveService save)
    {
        if (_save is not null) _save.Changed -= Render;
        _save = save;
        _save.Changed += Render;
        Render();
    }

    public override void _ExitTree()
    {
        if (_save is not null) _save.Changed -= Render;
    }

    public override void _Process(double delta)
    {
        if (_lightUpPlayed || _save is null || !_save.Data.TianjinCompleted || !IsVisibleInTree()) return;
        _lightUpPlayed = true;
        _tianjinCard.PivotOffset = _tianjinCard.Size * .5f;
        _tianjinCard.Scale = new Vector2(.92f, .92f);
        _tianjinCard.Modulate = new Color(1.35f, 1.15f, .75f, .25f);
        Tween tween = CreateTween().SetParallel(true).SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(_tianjinCard, "scale", Vector2.One, .65);
        tween.TweenProperty(_tianjinCard, "modulate", Colors.White, .8);
    }
    private void Render()
    {
        if (_save is null) return;
        RenderGuangzhouEntry();
        RenderYangzhouEntry();
        var xian = _save.Data.Xian; bool xianOpen = _save.Data.UnlockedCityIds.Contains(StableIds.Cities.Xian);
        _xianState.Text = xian.Completed ? $"已点亮 {new string('★', xian.BestStars)}{new string('☆', 3 - xian.BestStars)}" : xianOpen ? $"已开放 · Day {xian.HighestUnlockedDay}" : "完成武汉 Day 12 一星后开放";
        SetCardColor(_xianCard, xian.Completed ? TianjinUi.Yellow : xianOpen ? TianjinUi.CreamMuted : TianjinUi.Paper);
        int stars = _save.Data.TianjinBestStars;
        bool complete = _save.Data.TianjinCompleted;
        _tianjinState.Text = complete ? $"已点亮  {new string('★', stars)}{new string('☆', 3 - stars)}\n最高星级：{stars}" : "尚未点亮\n完成 Day 15 并至少获得一星";
        SetCardColor(_tianjinCard, complete ? TianjinUi.Yellow : TianjinUi.CreamMuted);

        bool wuhan = _save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan, StringComparer.Ordinal);
        _wuhanLockedIcon.Texture = wuhan ? new WuhanArtCatalog().CityNode : _art.LockedMapNode;
        _wuhanLockedIcon.Visible = true;
        _wuhanUnlockedEmblem.Visible = false;
        CityProgressData wuhanProgress = _save.Data.GetCity(StableIds.Cities.Wuhan);
        _wuhanState.Text = !wuhan && DeveloperToolsVisible ? "测试直达\n不写入城市解锁" : !wuhan ? "未开放\n可使用上方测试入口" : wuhanProgress.Completed
            ? $"已点亮  {new string('★', wuhanProgress.BestStars)}{new string('☆', 3 - wuhanProgress.BestStars)}\n下一站：西安"
            : $"路线已开放\n武汉 Day {wuhanProgress.HighestUnlockedDay}";
        SetCardColor(_wuhanCard, wuhanProgress.Completed ? TianjinUi.Yellow : wuhan ? new Color("#D9E8C3") : TianjinUi.Paper);
    }
    private static void SetCardColor(PanelContainer card, Color background)
    {
        if (card.GetThemeStylebox("panel") is StyleBoxFlat style) style.BgColor = background;
    }

    private static bool IsClick(InputEvent input) => input is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: false };

    public static bool CanEnterCity(bool isUnlocked, bool developerToolsVisible) => isUnlocked || developerToolsVisible;
}
