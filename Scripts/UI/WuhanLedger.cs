using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

/// <summary>A modal, two-page ledger. Selecting a date never starts a shift.</summary>
public partial class WuhanLedger : Control
{
    public event Action<int>? DayRequested;
    public int SelectedDay { get; private set; } = 1;

    private readonly List<Button> _dates = new();
    private readonly List<Label> _dateStates = new();
    private readonly List<TextureRect> _dateStamps = new();
    private readonly List<Button> _focusOrder = new();
    private WuhanArtCatalog _art = null!;
    private SaveService? _save;
    private Control? _previousFocus;
    private Label _chapter = null!, _day = null!, _title = null!, _revenue = null!;
    private Label _satisfaction = null!, _perfect = null!, _empty = null!, _note = null!, _notice = null!;
    private Control _record = null!;
    private TextureRect _stamp = null!;
    private HBoxContainer _illustrations = null!;
    private Control[] _illustrationSlots = Array.Empty<Control>();
    private WuhanLedgerLockIcon _lockIllustration = null!;
    private Button _start = null!;
    private WuhanActionAudio _audio = null!;
    private int _illustrationDay;
    private bool _illustrationLocked;

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        _audio = new WuhanActionAudio(this);
        _art = new WuhanArtCatalog();
        _illustrationSlots = new[] { GetNode<Control>("%Illustration1"), GetNode<Control>("%Illustration2"), GetNode<Control>("%Illustration3") };
        _lockIllustration = GetNode<WuhanLedgerLockIcon>("%WuhanLedgerLockIllustration");
        for (int index = 0; index < _dates.Count; index++)
        {
            int day = index + 1;
            _dates[index].Pressed += () => SelectDay(day);
        }
        _start.Pressed += StartSelectedDay;
        ((Button)FindChild("CloseLedger", true, false)).Pressed += Close;
    }

    public void Open(SaveService save)
    {
        if (!Visible) _previousFocus = GetViewport().GuiGetFocusOwner();
        SelectedDay = Math.Clamp(save.Data.Wuhan.HighestUnlockedDay, 1, 12);
        _notice.Text = "点选日期后，在右页开始营业。";
        _notice.Modulate = Colors.White;
        Refresh(save);
        Show();
        _audio.Play(WuhanSound.BookOpen);
        FocusSelectedDay();
    }

    public void Close()
    {
        if (Visible) _audio.Play(WuhanSound.BookClose);
        Hide();
        if (IsInstanceValid(_previousFocus) && _previousFocus!.IsVisibleInTree()) _previousFocus.GrabFocus();
        else GetViewport().GuiGetFocusOwner()?.ReleaseFocus();
    }

    public void FocusSelectedDay()
    {
        if (IsVisibleInTree()) _dates[SelectedDay - 1].GrabFocus();
    }

    public void SelectDay(int day)
    {
        if (_save is null || day is < 1 or > 12) return;
        if (SelectedDay != day) _audio.Play(WuhanSound.Page);
        SelectedDay = day;
        Refresh(_save);
    }

    public void Refresh(SaveService save)
    {
        _save = save;
        _chapter.Text = $"武汉 · 已到 Day {Math.Clamp(save.Data.Wuhan.HighestUnlockedDay, 1, 12)} · 章节 {save.Data.Wuhan.BestStars} 星";
        for (int index = 0; index < _dates.Count; index++)
        {
            int day = index + 1;
            bool unlocked = day <= save.Data.Wuhan.HighestUnlockedDay;
            bool recorded = save.Data.Wuhan.DayBestRecords.ContainsKey(day);
            bool selected = day == SelectedDay;
            Button button = _dates[index];
            button.SetPressedNoSignal(selected);
            _dateStates[index].Text = !unlocked ? "未解锁" : recorded ? "已记录" : "等待开店";
            _dateStamps[index].Visible = unlocked && recorded;
            Color selection = WuhanUi.Paper.Lerp(WuhanUi.Accent, .22f);
            Color paper = selected ? selection : unlocked ? WuhanUi.Paper : WuhanUi.Disabled;
            UpdateButtonStyle(button, "normal", paper, selected ? 4 : 2);
            UpdateButtonStyle(button, "pressed", selection, 4);
            UpdateButtonStyle(button, "hover", paper.Lightened(.06f), 3);
            UpdateButtonStyle(button, "hover_pressed", selection.Lightened(.06f), 4);
            button.TooltipText = $"Day {day} · {WuhanHub.DaySubtitle(day)} · {_dateStates[index].Text}";
        }

        bool locked = SelectedDay > save.Data.Wuhan.HighestUnlockedDay;
        bool hasRecord = save.Data.Wuhan.DayBestRecords.TryGetValue(SelectedDay, out DayBestRecord? best);
        _day.Text = $"Day {SelectedDay}";
        _title.Text = locked ? "未解锁的营业日" : WuhanHub.DaySubtitle(SelectedDay);
        _record.Visible = hasRecord && !locked && !save.HasLoadError;
        _stamp.Visible = _record.Visible;
        _empty.Visible = !_record.Visible;
        _revenue.Text = hasRecord ? $"¥{best!.TotalRevenue}" : "";
        _satisfaction.Text = hasRecord ? $"满意度 {best!.Satisfaction:0}%" : "";
        _perfect.Text = hasRecord ? $"Perfect {best!.PerfectOrders} 单" : "";
        _empty.Text = save.HasLoadError ? "存档无法读取\n请返回天津经营手账重置进度。"
            : locked ? $"尚未解锁\n完成 Day {SelectedDay - 1} 后再来翻看。"
            : "等待开店\n今天的故事，还等你写下。";
        _note.Text = save.HasLoadError ? "重置会清除所有城市进度，并需要确认。"
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
        if (_save is null || _save.HasLoadError || SelectedDay > _save.Data.Wuhan.HighestUnlockedDay) return;
        int day = SelectedDay;
        Close();
        DayRequested?.Invoke(day);
    }

    private void RenderIllustrations(bool locked)
    {
        if (_illustrationDay == SelectedDay && _illustrationLocked == locked) return;
        _illustrationDay = SelectedDay;
        _illustrationLocked = locked;
        foreach (Control slot in _illustrationSlots) slot.Visible = false;
        _lockIllustration.Visible = locked;
        if (locked)
            return;
        string[] images = SelectedDay switch
        {
            2 => new[] { "noodles", "scallion" },
            3 => new[] { "noodles", "chili" },
            4 or 5 => new[] { "noodles", "doupi_single" },
            6 => new[] { "noodles", "egg_finished" },
            7 => new[] { "noodles", "beef" },
            10 => new[] { "doupi_single", "griddle_3" },
            >= 8 => new[] { "noodles", "doupi_single", "egg_finished" },
            _ => new[] { "noodles" },
        };
        for (int index = 0; index < images.Length; index++)
        {
            string id = images[index];
            float width = images.Length == 3 ? 174 : 210;
            Control slot = _illustrationSlots[index];
            TextureRect baseLayer = slot.GetNode<TextureRect>("Base");
            TextureRect overlay = slot.GetNode<TextureRect>("Overlay");
            slot.CustomMinimumSize = new Vector2(width, 212);
            baseLayer.Visible = false;
            baseLayer.Texture = null;
            overlay.Texture = _art.Texture(id == "noodles" ? "noodles_finished" : id);
            overlay.Position = Vector2.Zero;
            overlay.Size = new Vector2(width, 212);
            slot.Visible = true;
        }
    }
    public override void _Input(InputEvent @event)
    {
        if (!IsVisibleInTree() || @event is not InputEventKey key || !key.Pressed) return;
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
                _dates[Math.Clamp(index + step, 0, 11)].GrabFocus();
            }
            GetViewport().SetInputAsHandled();
        }
    }

}
