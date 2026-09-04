using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Pancake;

namespace ProjectCake.Gameplay;

public partial class PancakeLab : Control
{
    public event Action? DataDebugRequested;
    public event Action? HubRequested;

    private DataCatalog? _catalog;
    private PracticeSession? _session;
    private PancakeWorkstation _workstation = null!;
    private Label _stats = null!;
    private Label _feedback = null!;
    private OptionButton _stove = null!;
    private OptionButton _station = null!;
    private PanelContainer _summary = null!;
    private bool _paused;

    public override void _Ready() => Build();

    public void Initialize(DataCatalog catalog)
    {
        _catalog = catalog;
        RecipeData[] recipes =
        {
            catalog.RecipesById[StableIds.Recipes.Basic],
            catalog.RecipesById[StableIds.Recipes.Crispy],
            catalog.RecipesById[StableIds.Recipes.Scallion],
            catalog.RecipesById[StableIds.Recipes.ScallionCrispy],
        };
        _session = new PracticeSession(recipes, 30);
        _workstation.Initialize(catalog, 1, 1);
        _workstation.SubmitPrepared = Submit;
        Render();
    }

    public override void _Process(double delta)
    {
        if (_session is null || _paused || !IsVisibleInTree() || _session.IsFinished) return;
        _workstation.Tick(delta);
        _session.Tick(delta);
        Render();
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut)
        {
            _paused = true;
            _workstation?.CancelInput();
            if (_workstation is not null) _workstation.Paused = true;
        }
        else if (what == NotificationApplicationFocusIn)
        {
            _paused = false;
            if (_workstation is not null) _workstation.Paused = false;
        }
    }

    private void Build()
    {
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        var bg = new ColorRect { Color = new Color("#211713"), MouseFilter = MouseFilterEnum.Ignore };
        bg.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        AddChild(bg);
        var root = new VBoxContainer();
        root.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        root.OffsetLeft = 28; root.OffsetTop = 20; root.OffsetRight = -28; root.OffsetBottom = -20;
        root.AddThemeConstantOverride("separation", 12);
        AddChild(root);
        var header = new HBoxContainer { CustomMinimumSize = new Vector2(0, 74) };
        var title = new Label { Text = "煎饼实验台 · P0→P1→P2→P3", SizeFlagsHorizontal = SizeFlags.ExpandFill };
        title.AddThemeFontSizeOverride("font_size", 30); title.AddThemeColorOverride("font_color", new Color("#FFD596")); header.AddChild(title);
        _stats = new Label(); _stats.AddThemeFontSizeOverride("font_size", 18); header.AddChild(_stats);
        _stove = Selector("炉Lv", header, index => SwitchEquipment((int)index + 1, _station.Selected + 1));
        _station = Selector("台Lv", header, index => SwitchEquipment(_stove.Selected + 1, (int)index + 1));
        var hub = new Button { Text = "营业大厅", CustomMinimumSize = new Vector2(120, 48) }; hub.Pressed += () => HubRequested?.Invoke(); header.AddChild(hub);
        var debug = new Button { Text = "Day 数据", CustomMinimumSize = new Vector2(120, 48) }; debug.Pressed += () => DataDebugRequested?.Invoke(); header.AddChild(debug);
        root.AddChild(header);
        _feedback = new Label { Text = "把面糊拖到炉面开始练习。", HorizontalAlignment = HorizontalAlignment.Center };
        _feedback.AddThemeFontSizeOverride("font_size", 18); _feedback.AddThemeColorOverride("font_color", new Color("#78D892")); root.AddChild(_feedback);
        _workstation = new PancakeWorkstation { SizeFlagsVertical = SizeFlags.ExpandFill };
        _workstation.Feedback += ShowFeedback; root.AddChild(_workstation);
        _summary = new PanelContainer { Visible = false, CustomMinimumSize = new Vector2(0, 80) };
        var again = new Button { Text = "30 张完成 · 点击重新练习" }; again.Pressed += Restart; _summary.AddChild(again); root.AddChild(_summary);
    }

    private bool Submit(PancakeStateMachine machine)
    {
        PancakeDeliveryResult result = _session!.TryDeliver(machine);
        ShowFeedback(result.Message, !result.Success);
        if (result.Success && _session.IsFinished) _summary.Visible = true;
        Render();
        return result.Success;
    }

    private void Restart() { _session!.Reset(); _workstation.ResetForDay(); _summary.Visible = false; Render(); }
    private void SwitchEquipment(int stove, int station)
    {
        if (!_workstation.TrySwitchEquipment(_catalog!, stove, station)) ShowFeedback("炉面非空或正在补料，不能切换设备。", true);
    }
    private void Render()
    {
        if (_session is not null) _stats.Text = $"目标 {_session.CurrentTarget.DisplayName} · {_session.CompletedCount}/30 · 完美 {_session.PerfectCount} 偏焦 {_session.OverdoneCount}";
    }
    private void ShowFeedback(string message, bool error) { _feedback.Text = message; _feedback.Modulate = error ? new Color("#FF756A") : new Color("#78D892"); }
    private static OptionButton Selector(string prefix, Container parent, Action<long> changed)
    {
        var option = new OptionButton { CustomMinimumSize = new Vector2(100, 48) };
        for (int level = 1; level <= 3; level++) option.AddItem($"{prefix}{level}");
        option.ItemSelected += index => changed(index); parent.AddChild(option); return option;
    }
}
