using Godot;
using ProjectCake.Data;
using ProjectCake.Fryer;
using ProjectCake.Inventory;
using ProjectCake.Pancake;
using ProjectCake.UI;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    private readonly HashSet<string> _learnedActions = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Label> _firstUseHints = new(StringComparer.Ordinal);
    private bool _tutorialMemory;
    private Label? _trashHint;
    public event Action<string>? WorkbenchActionLearned;
    internal IReadOnlySet<string> LearnedWorkbenchActions => _learnedActions;
    internal static readonly string[] AllWorkbenchActions = {
        "take:batter", "take:egg", "take:sauce", "take:crispy", "take:ham", "take:scallion", "take:youtiao", "take:soy_milk",
        "spread", "flip", "sauce", "fold", "bag", "discard", "fryer:load", "fryer:lower", "fryer:raise",
        "refill:egg", "refill:crispy", "refill:ham", "refill:scallion", "refill:soy_milk",
        "deliver:finished_pancake", "deliver:stored_youtiao", "deliver:soy_milk_cup"
    };

    public void ConfigureTutorial(IEnumerable<string>? learned)
    {
        _tutorialMemory = true;
        _learnedActions.Clear();
        if (learned is not null) _learnedActions.UnionWith(learned);
        Render();
    }

    public void LearnWorkbenchAction(string action)
    {
        if (!_tutorialMemory || !_learnedActions.Add(action)) return;
        WorkbenchActionLearned?.Invoke(action);
        Render();
    }

    private bool NeedsTeaching(string action) => !_learnedActions.Contains(action);

    private void LearnPancakeAction(PancakeCommand command, string? ingredient)
    {
        string? action = command switch
        {
            PancakeCommand.PlaceBatter => "take:batter",
            PancakeCommand.CompleteSpread => "spread",
            PancakeCommand.AddEgg => "take:egg",
            PancakeCommand.Flip => "flip",
            PancakeCommand.BeginSauce => "take:sauce",
            PancakeCommand.CompleteSauce => "sauce",
            PancakeCommand.AddIngredient => $"take:{ingredient}",
            PancakeCommand.Fold => "fold",
            PancakeCommand.Bag => "bag",
            PancakeCommand.Discard => "discard",
            _ => null,
        };
        if (action is not null) LearnWorkbenchAction(action);
    }

    private void BuildFirstUseHints()
    {
        foreach ((string id, IngredientStockSlotView slot) in _ingredientSlots)
        {
            var hint = slot.GetNode<Label>("FirstUseHint");
            hint.Text = id is "egg" or "scallion" ? "点击添加" : id == "sauce" ? "点击拿刷" : "拖入炉面";
            hint.AddThemeColorOverride("font_color", TianjinUi.BrownText);
            _firstUseHints[id] = hint;
        }
        _trashHint = _trashZone.FindChild("TrashLabel", true, false) as Label;
        if (IsTianjinWorkbench && _trashHint is not null) _trashHint.Text = "长按右键拖入丢弃";
    }

    private void RenderTutorial()
    {
        if (!_tutorialMemory) return;
        PancakeRuntime runtime = Machine.Runtime;
        string? action = runtime.State switch
        {
            PancakeState.Empty => "take:batter",
            PancakeState.BatterPlaced or PancakeState.Spreading => "spread",
            PancakeState.Spread => "take:egg",
            PancakeState.SideACooking when !runtime.HasEgg => "take:egg",
            PancakeState.SideAReady => "flip",
            PancakeState.SideBCooking or PancakeState.SideBReady => "take:sauce",
            PancakeState.Saucing => "sauce",
            PancakeState.Sauced or PancakeState.Toppings => "fold",
            PancakeState.Folded => "bag",
            _ => null,
        };
        // Keep live heat/quality warnings. Only instructional idle copy disappears.
        bool live = _batterDropAnimating || IsTransferringBag || runtime.State is PancakeState.SideACooking
            or PancakeState.SideAReady or PancakeState.SideAOverdone or PancakeState.Burnt or PancakeState.Saucing;
        _pancakeStatusTag.Visible = live || action is not null && NeedsTeaching(action);
        if (action is not null && !NeedsTeaching(action))
            _state.Text = runtime.State switch
            {
                PancakeState.SideACooking => "第一面加热中",
                PancakeState.SideAReady => "火候正好",
                PancakeState.Saucing => SauceRules.Describe(runtime.SauceCoverage),
                _ => _state.Text,
            };
        foreach ((string id, Label hint) in _firstUseHints)
        {
            IngredientStockSlotView slot = _ingredientSlots[id];
            slot.ConfigureRefillTeaching(!IsTianjinWorkbench && NeedsTeaching($"refill:{id}"));
            hint.Visible = slot.Visible && NeedsTeaching($"take:{id}")
                && slot.AttentionState is WorkstationSlotAttentionState.Actionable or WorkstationSlotAttentionState.Required
                && Inventory.GetStatus(id) is IngredientStockStatus.Normal;
        }
        if (FryerMachine is not null)
        {
            bool idle = FryerMachine.Runtime.State is FryerState.Empty or FryerState.Stored;
            _fryerStatus.GetParent<Control>().Visible = !idle || NeedsTeaching("fryer:load");
            if (idle && NeedsTeaching("fryer:load")) _fryerStatus.Text = "长按炸锅 · 连续装料";
            if (FryerMachine.Runtime.State == FryerState.Loaded)
                _fryerStatus.Text = NeedsTeaching("fryer:lower") ? "装料完成 · 点击下锅" : "装料完成";
            if (FryerMachine.Runtime.State == FryerState.Frying && !FryerMachine.Level.AutoRaise
                && NeedsTeaching("fryer:raise")) _fryerStatus.Text += " · 金黄后升篮";
        }
        _directDeliveryHint.Visible = HasFinishedPancake && NeedsTeaching("deliver:finished_pancake");
        if (runtime.State is PancakeState.Sauced or PancakeState.Toppings && NeedsTeaching("fold"))
            _state.Text = "添加配料后点击折叠";
        if (SoyMilkTray is { IsRefilling: false, IsTaking: false, Quantity: > 2 } && NeedsTeaching("take:soy_milk"))
        {
            _soyStatus.Text = "拖给顾客";
            _soyStatus.Visible = true;
        }
        if (SoyMilkTray is { IsRefilling: false, IsTaking: false } soy && soy.Quantity < soy.Capacity)
        {
            if (!IsTianjinWorkbench && NeedsTeaching("refill:soy_milk")) _soyStatus.Text = "长按补货";
            else if (soy.Quantity <= 2) _soyStatus.Text = soy.Quantity == 0 ? "已用完" : "余量不足";
            _soyStatus.Visible = !string.IsNullOrEmpty(_soyStatus.Text);
        }
        if (_trashHint is not null) _trashHint.Visible = NeedsTeaching("discard");
        if (FryerMachine?.Inventory.Count > 0)
        {
            bool take = NeedsTeaching("take:youtiao"), deliver = NeedsTeaching("deliver:stored_youtiao");
            _finishedYoutiaoSlot.ShowEmptyCaption(take || deliver, take ? "拖入饼面或交付" : "拖给顾客");
        }
        else _finishedYoutiaoSlot.ShowEmptyCaption(NeedsTeaching("take:youtiao"), "熟油条");
    }
}
