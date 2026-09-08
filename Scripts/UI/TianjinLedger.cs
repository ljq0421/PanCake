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
    private Button _start = null!;
    private int _illustrationDay;
    private bool _illustrationLocked;

    public override void _Ready()
    {
        TianjinUi.FullRect(this);
        MouseFilter = MouseFilterEnum.Stop;
        _art = new TianjinArtCatalog();
        var blocker = new ColorRect { Name = "LedgerBlocker", Color = new Color(0.18f, 0.08f, 0.035f, 0.64f), MouseFilter = MouseFilterEnum.Stop };
        AddChild(blocker);
        TianjinUi.FullRect(blocker);

        var book = Place(new Control { Name = "Book", MouseFilter = MouseFilterEnum.Stop }, this, 225, 50, 1470, 960);
        var background = TianjinUi.Texture(_art.LedgerBook, Vector2.Zero);
        Place(background, book, 0, 0, 1470, 960);
        var bookmark = TianjinUi.Texture(_art.LedgerBookmark, Vector2.Zero);
        Place(bookmark, book, 604, 22, 54, 122);

        var left = Place(new Control { Name = "LeftPage", MouseFilter = MouseFilterEnum.Ignore }, book, 85, 116, 570, 742);
        Place(TianjinUi.Label("经营手账", 42), left, 0, 0, 600, 58);
        _chapter = Place(TianjinUi.Label("天津 · 15 个营业日", 22, TianjinUi.Brown), left, 0, 65, 570, 34);
        Place(TianjinUi.Label("选一个日子，翻看店里的故事", 20, TianjinUi.Brown), left, 0, 110, 610, 30);

        var grid = Place(new GridContainer { Name = "DateGrid", Columns = 3 }, left, 0, 162, 570, 508);
        grid.AddThemeConstantOverride("h_separation", 14);
        grid.AddThemeConstantOverride("v_separation", 12);
        for (int day = 1; day <= 15; day++)
        {
            int selected = day;
            var button = TianjinUi.Button("", false, new Vector2(180, 92));
            button.Name = $"Date{day}";
            button.ToggleMode = true;
            button.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            button.Pressed += () => SelectDay(selected);
            grid.AddChild(button);
            Place(TianjinUi.Label($"Day {day}", 27), button, 16, 8, 146, 38).MouseFilter = MouseFilterEnum.Ignore;
            var state = Place(TianjinUi.Label("", 19, TianjinUi.BrownText), button, 16, 49, 145, 29);
            state.MouseFilter = MouseFilterEnum.Ignore;
            var stamp = Place(TianjinUi.Texture(_art.LedgerRecordStamp, Vector2.Zero), button, 140, 14, 28, 28);
            _dates.Add(button); _dateStates.Add(state); _dateStamps.Add(stamp); _focusOrder.Add(button);
        }
        _notice = Place(TianjinUi.Label("点选日期后，在右页开始营业。", 19, TianjinUi.Brown), left, 0, 695, 570, 56);
        _notice.AutowrapMode = TextServer.AutowrapMode.WordSmart;

        var right = Place(new Control { Name = "RightPage", MouseFilter = MouseFilterEnum.Ignore }, book, 810, 116, 570, 742);
        _day = Place(TianjinUi.Label("Day 1", 46), right, 0, 0, 470, 60);
        _title = Place(TianjinUi.Label("", 30, TianjinUi.Brown), right, 0, 65, 570, 48);
        _stamp = Place(TianjinUi.Texture(_art.LedgerRecordStamp, Vector2.Zero), right, 490, 0, 76, 76);
        _stamp.Name = "RecordStamp";
        _illustrations = Place(new HBoxContainer { Name = "DayIllustrations", Alignment = BoxContainer.AlignmentMode.Center }, right, 0, 128, 570, 212);
        _illustrations.AddThemeConstantOverride("separation", 18);

        _record = Place(new Control { Name = "BestRecord", MouseFilter = MouseFilterEnum.Ignore }, right, 0, 364, 570, 170);
        Place(TianjinUi.Texture(_art.Coin, Vector2.Zero), _record, 0, 11, 60, 60);
        Place(TianjinUi.Label("历史最佳收入", 20, TianjinUi.Brown), _record, 78, 0, 490, 30);
        _revenue = Place(TianjinUi.Label("", 40), _record, 78, 33, 490, 56);
        _revenue.Name = "BestRevenue";
        Place(TianjinUi.Texture(_art.HeartEffect, Vector2.Zero), _record, 0, 119, 44, 44);
        _satisfaction = Place(TianjinUi.Label("", 23), _record, 58, 117, 275, 48);
        _satisfaction.Name = "BestSatisfaction";
        Place(new LedgerCheckIcon { MouseFilter = MouseFilterEnum.Ignore }, _record, 306, 126, 28, 28);
        _perfect = Place(TianjinUi.Label("", 23), _record, 347, 117, 223, 48);
        _perfect.Name = "BestPerfect";
        _empty = Place(TianjinUi.Label("", 26, TianjinUi.Brown), right, 0, 364, 570, 170);
        _empty.Name = "EmptyRecord";
        _empty.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        _note = Place(TianjinUi.Label("", 20, TianjinUi.Brown), right, 0, 560, 570, 62);
        _note.Name = "DayNote";
        _note.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        _start = Place(TianjinUi.Button("开始营业", true, new Vector2(570, 70)), right, 0, 652, 570, 70);
        _start.Name = "StartLedgerDay";
        _start.Pressed += StartSelectedDay;
        _focusOrder.Add(_start);

        var close = Place(TianjinUi.Button("合上手账", false, new Vector2(176, 52)), this, 1590, 16, 176, 52);
        close.Name = "CloseLedger";
        close.Pressed += Close;
        var reset = Place(TianjinUi.Button("重置进度", false, new Vector2(152, 50)), this, 270, 1010, 152, 50);
        reset.Name = "ResetLedgerProgress";
        reset.Pressed += () => ResetRequested?.Invoke();
        _focusOrder.Add(close); _focusOrder.Add(reset);
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
            bool recorded = save.Data.DayBestRecords.ContainsKey(day);
            bool selected = day == SelectedDay;
            Button button = _dates[index];
            button.SetPressedNoSignal(selected);
            _dateStates[index].Text = !unlocked ? "未解锁" : recorded ? "已记录" : "等待开店";
            _dateStamps[index].Visible = unlocked && recorded;
            Color paper = selected ? TianjinUi.Yellow : unlocked ? TianjinUi.Paper : TianjinUi.CreamMuted;
            button.AddThemeStyleboxOverride("normal", TianjinUi.Box(paper, 14, selected ? 4 : 2, false));
            button.AddThemeStyleboxOverride("pressed", TianjinUi.Box(TianjinUi.Yellow, 14, 4, false));
            button.AddThemeStyleboxOverride("hover", TianjinUi.Box(paper.Lightened(.06f), 14, 3, false));
            button.AddThemeStyleboxOverride("hover_pressed", TianjinUi.Box(TianjinUi.Yellow.Lightened(.06f), 14, 4, false));
            var focus = TianjinUi.Box(Colors.Transparent, 14, 4, false);
            focus.BorderColor = TianjinUi.Orange;
            button.AddThemeStyleboxOverride("focus", focus);
            button.TooltipText = $"Day {day} · {MorningHub.DaySubtitle(day)} · {_dateStates[index].Text}";
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
        foreach (Node child in _illustrations.GetChildren()) { _illustrations.RemoveChild(child); child.QueueFree(); }
        if (locked)
        {
            var lockView = new LedgerLockIcon { CustomMinimumSize = new Vector2(130, 170), MouseFilter = MouseFilterEnum.Ignore };
            _illustrations.AddChild(lockView);
            return;
        }
        Texture2D[] images = SelectedDay switch
        {
            2 => new[] { _art.FinishedPancake, _art.Ingredient(StableIds.Ingredients.Crispy) },
            3 => new[] { _art.FinishedPancake, _art.Ingredient(StableIds.Ingredients.Scallion) },
            5 => new[] { _art.Product(ProductKind.Youtiao) },
            6 or 7 => new[] { _art.FinishedPancake, _art.Product(ProductKind.Youtiao) },
            8 => new[] { _art.FinishedPancake, _art.Ingredient(StableIds.Ingredients.Ham) },
            9 => new[] { _art.FinishedPancake, _art.Product(ProductKind.SoyMilk) },
            11 => new[] { _art.CustomerHead("male_office", CustomerExpression.Normal), _art.FinishedPancake },
            >= 10 => new[] { _art.FinishedPancake, _art.Product(ProductKind.Youtiao), _art.Product(ProductKind.SoyMilk) },
            _ => new[] { _art.FinishedPancake },
        };
        foreach (Texture2D texture in images)
            _illustrations.AddChild(TianjinUi.Texture(texture, new Vector2(images.Length == 3 ? 174 : 210, 212)));
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

    private static T Place<T>(T control, Control parent, float x, float y, float width, float height) where T : Control
    {
        parent.AddChild(control);
        control.Position = new Vector2(x, y);
        control.Size = new Vector2(width, height);
        return control;
    }
}

internal partial class LedgerCheckIcon : Control
{
    public override void _Draw() => DrawPolyline(new[] { new Vector2(2, 14), new Vector2(11, 23), new Vector2(27, 3) }, TianjinUi.Brown, 5, true);
}

internal partial class LedgerLockIcon : Control
{
    public override void _Draw()
    {
        DrawArc(new Vector2(65, 75), 34, Mathf.Pi, Mathf.Tau, 32, TianjinUi.Brown, 8, true);
        DrawStyleBox(TianjinUi.Box(TianjinUi.CreamMuted, 14, 4, false), new Rect2(15, 74, 100, 78));
        DrawCircle(new Vector2(65, 108), 8, TianjinUi.BrownDark);
        DrawLine(new Vector2(65, 112), new Vector2(65, 128), TianjinUi.BrownDark, 7, true);
    }
}
