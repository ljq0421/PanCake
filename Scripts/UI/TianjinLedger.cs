using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>A modal, two-page ledger. Selecting a date never starts a shift.</summary>
public partial class TianjinLedger : Control
{
    public event Action<int>? DayRequested;
    public event Action? ResetRequested;
    public int SelectedDay { get; private set; } = 1;
    public bool ConfirmationOpen { get; set; }

    private readonly List<Button> _dates = new();
    private readonly List<Label> _dateStates = new();
    private readonly List<TextureRect> _dateStamps = new();
    private readonly List<Button> _focusOrder = new();
    private TianjinArtCatalog _art = null!;
    private SaveService? _save;
    private Control? _previousFocus;
    private Label _chapter = null!, _day = null!, _title = null!, _revenue = null!;
    private Label _satisfaction = null!, _perfect = null!, _empty = null!, _note = null!, _notice = null!;
    private Control _record = null!;
    private TextureRect _stamp = null!;
    private HBoxContainer _illustrations = null!;
    private TextureRect[] _illustrationSlots = Array.Empty<TextureRect>();
    private LedgerLockIcon _lockIllustration = null!;
    private Button _start = null!;
    private int _illustrationDay;
    private bool _illustrationLocked;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _art = new TianjinArtCatalog();
        _illustrationSlots = new[] { GetNode<TextureRect>("%Illustration1"), GetNode<TextureRect>("%Illustration2"), GetNode<TextureRect>("%Illustration3") };
        _lockIllustration = GetNode<LedgerLockIcon>("%LedgerLockIllustration");
        for (int index = 0; index < _dates.Count; index++)
        {
            int day = index + 1;
            _dates[index].Pressed += () => SelectDay(day);
        }
        _start.Pressed += StartSelectedDay;
        ((Button)FindChild("CloseLedger", true, false)).Pressed += Close;
        ((Button)FindChild("ResetLedgerProgress", true, false)).Pressed += () => ResetRequested?.Invoke();
    }

    public void Open(SaveService save)
    {
        if (!Visible) _previousFocus = GetViewport().GuiGetFocusOwner();
        SelectedDay = Math.Clamp(save.Data.HighestUnlockedDay, 1, 15);
        _notice.Text = "点选日期后，在右页开始营业。";
        _notice.Modulate = Colors.White;
        Refresh(save);
        Show();
        FocusSelectedDay();
    }

    public void Close()
    {
        if (ConfirmationOpen) return;
        Hide();
        if (IsInstanceValid(_previousFocus) && _previousFocus!.IsVisibleInTree()) _previousFocus.GrabFocus();
        else GetViewport().GuiGetFocusOwner()?.ReleaseFocus();
    }

    public void FocusSelectedDay()
    {
        if (IsVisibleInTree()) _dates[SelectedDay - 1].GrabFocus();
    }

    public void ShowNotice(string message, bool error)
    {
        _notice.Text = message;
        _notice.Modulate = error ? TianjinUi.Red : Colors.White;
    }

    public void SelectDay(int day)
    {
        if (_save is null || day is < 1 or > 15) return;
        SelectedDay = day;
        Refresh(_save);
    }

    public void Refresh(SaveService save)
    {
        _save = save;
        _chapter.Text = $"天津 · 已到 Day {Math.Clamp(save.Data.HighestUnlockedDay, 1, 15)} · 章节 {save.Data.TianjinBestStars} 星";
        for (int index = 0; index < _dates.Count; index++)
        {
            int day = index + 1;
            bool unlocked = day <= save.Data.HighestUnlockedDay;
            bool recorded = save.Data.DayBestRecords.TryGetValue(day, out DayBestRecord? dayBest) && !save.HasLoadError;
            bool selected = day == SelectedDay;
            Button button = _dates[index];
            button.SetPressedNoSignal(selected);
            Label state = _dateStates[index];
            bool showMetrics = unlocked && recorded;
            state.Text = !unlocked ? "未解锁" : recorded
                ? $"{dayBest!.TotalRevenue}\n{dayBest.Satisfaction:0}%" : "等待开店";
            button.GetNode<TextureRect>("RevenueIcon").Visible = showMetrics;
            button.GetNode<TextureRect>("SatisfactionIcon").Visible = showMetrics;
            state.Position = new Vector2(showMetrics ? 42 : 14, 39);
            state.Size = new Vector2(button.Size.X - state.Position.X - 14, 46);
            // Keep even the largest saved integer inside the date card without truncation.
            Font font = state.GetThemeFont("font");
            int fontSize = 18;
            float availableWidth = state.Size.X;
            while (fontSize > 12 && state.Text.Split('\n').Any(line =>
                font.GetStringSize(line, HorizontalAlignment.Left, -1, fontSize).X > availableWidth)) fontSize--;
            state.AddThemeFontSizeOverride("font_size", fontSize);
            _dateStamps[index].Visible = unlocked && recorded;
            Color paper = selected ? TianjinUi.Yellow : unlocked ? TianjinUi.Paper : TianjinUi.CreamMuted;
            UpdateButtonStyle(button, "normal", paper, selected ? 4 : 2);
            UpdateButtonStyle(button, "pressed", TianjinUi.Yellow, 4);
            UpdateButtonStyle(button, "hover", paper.Lightened(.06f), 3);
            UpdateButtonStyle(button, "hover_pressed", TianjinUi.Yellow.Lightened(.06f), 4);
            string description = showMetrics
                ? $"最佳收入 ¥{dayBest!.TotalRevenue} · 满意度 {dayBest.Satisfaction:0}%" : state.Text;
            button.TooltipText = $"Day {day} · {MorningHub.DaySubtitle(day)} · {description}";
        }

        bool locked = SelectedDay > save.Data.HighestUnlockedDay;
        bool hasRecord = save.Data.DayBestRecords.TryGetValue(SelectedDay, out DayBestRecord? best);
        _day.Text = $"Day {SelectedDay}";
        _title.Text = locked ? "未解锁的营业日" : MorningHub.DaySubtitle(SelectedDay);
        _record.Visible = hasRecord && !locked && !save.HasLoadError;
        _stamp.Visible = _record.Visible;
        _empty.Visible = !_record.Visible;
        _revenue.Text = hasRecord ? $"¥{best!.TotalRevenue}" : "";
        _satisfaction.Text = hasRecord ? $"满意度 {best!.Satisfaction:0}%" : "";
        _perfect.Text = hasRecord ? $"Perfect {best!.PerfectOrders} 单" : "";
        _empty.Text = save.HasLoadError ? "存档无法读取\n请通过左下角“重置进度”恢复。"
            : locked ? $"尚未解锁\n完成 Day {SelectedDay - 1} 后再来翻看。"
            : "等待开店\n今天的故事，还等你写下。";
        _note.Text = save.HasLoadError ? "重置会清除进度，操作前会再次确认。"
            : locked ? "当前只能开始已经解锁的营业日。"
            : hasRecord ? "重玩只补发超过历史最佳的收入差额。"
            : "先看清订单，再安排今天的工作台。";
        _start.Text = save.HasLoadError ? "暂时无法营业" : locked ? "尚未解锁"
            : $"{(hasRecord ? "再次营业" : "开始营业")} · Day {SelectedDay}";
        _start.Disabled = locked || save.HasLoadError;
        RenderIllustrations(locked || save.HasLoadError);
    }

    private static void UpdateButtonStyle(Button button, string state, Color color, int borderWidth)
    {
        if (button.GetThemeStylebox(state) is not StyleBoxFlat style) return;
        style.BgColor = color;
        style.BorderWidthLeft = style.BorderWidthTop = style.BorderWidthRight = style.BorderWidthBottom = borderWidth;
    }

    private void StartSelectedDay()
    {
        // Recheck at activation: progress may have changed while the ledger was open.
        if (_save is null || _save.HasLoadError || SelectedDay > _save.Data.HighestUnlockedDay || ConfirmationOpen) return;
        int day = SelectedDay;
        Close();
        DayRequested?.Invoke(day);
    }

    private void RenderIllustrations(bool locked)
    {
        if (_illustrationDay == SelectedDay && _illustrationLocked == locked) return;
        _illustrationDay = SelectedDay;
        _illustrationLocked = locked;
        foreach (TextureRect slot in _illustrationSlots) slot.Visible = false;
        _lockIllustration.Visible = locked;
        if (locked)
            return;
        Texture2D[] images = SelectedDay switch
        {
            2 => new[] { _art.FinishedPancake, _art.Ingredient(StableIds.Ingredients.Crispy) },
            3 => new[] { _art.FinishedPancake, _art.Ingredient(StableIds.Ingredients.Scallion) },
            5 => new[] { _art.Product(ProductKind.Youtiao) },
            6 or 7 => new[] { _art.FinishedPancake, _art.Product(ProductKind.Youtiao) },
            8 => new[] { _art.FinishedPancake, _art.Ingredient(StableIds.Ingredients.Ham) },
            9 => new[] { _art.FinishedPancake, _art.Product(ProductKind.SoyMilk) },
            11 => new[] { _art.LedgerOfficeCustomer, _art.FinishedPancake },
            >= 10 => new[] { _art.FinishedPancake, _art.Product(ProductKind.Youtiao), _art.Product(ProductKind.SoyMilk) },
            _ => new[] { _art.FinishedPancake },
        };
        for (int index = 0; index < images.Length; index++)
        {
            TextureRect slot = _illustrationSlots[index];
            slot.Texture = images[index];
            slot.CustomMinimumSize = new Vector2(images.Length == 3 ? 174 : 210, 212);
            slot.Visible = true;
        }
    }

    public override void _Input(InputEvent @event)
    {
        if (!IsVisibleInTree() || ConfirmationOpen || @event is not InputEventKey key || !key.Pressed) return;
        if (key.Keycode == Key.Escape)
        {
            GetViewport().SetInputAsHandled();
            Close();
        }
        else if (key.Keycode == Key.Tab)
        {
            var buttons = _focusOrder.Where(button => !button.Disabled).ToList();
            int current = buttons.FindIndex(button => button.HasFocus());
            int next = (current + (key.ShiftPressed ? -1 : 1) + buttons.Count) % buttons.Count;
            buttons[next].GrabFocus();
            GetViewport().SetInputAsHandled();
        }
        else if (key.Keycode is Key.Left or Key.Right or Key.Up or Key.Down)
        {
            int index = _dates.FindIndex(button => button.HasFocus());
            if (index >= 0)
            {
                int step = key.Keycode switch { Key.Left => -1, Key.Right => 1, Key.Up => -3, _ => 3 };
                _dates[Math.Clamp(index + step, 0, 14)].GrabFocus();
            }
            GetViewport().SetInputAsHandled();
        }
    }

}
