using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Pancake;
using ProjectCake.UI;

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

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _workstation.Feedback += ShowFeedback;
        _stove.ItemSelected += index => SwitchEquipment((int)index + 1, _station.Selected + 1);
        _station.ItemSelected += index => SwitchEquipment(_stove.Selected + 1, (int)index + 1);
        this.FindButton("营业大厅").Pressed += () => HubRequested?.Invoke();
        this.FindButton("Day 数据").Pressed += () => DataDebugRequested?.Invoke();
        this.FindButton("30 张完成 · 点击重新练习").Pressed += Restart;
    }

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
}
