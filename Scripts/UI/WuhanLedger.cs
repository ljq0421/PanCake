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
    private Button _start = null!;
    private int _illustrationDay;
    private bool _illustrationLocked;

    public override void _Ready()
    {
        TianjinUi.FullRect(this);
        Theme = WuhanUi.CreateTheme();
        MouseFilter = MouseFilterEnum.Stop;
        _art = new WuhanArtCatalog();
        var blocker = new ColorRect { Name = "LedgerBlocker", Color = new Color(0.06f, 0.14f, 0.11f, 0.64f), MouseFilter = MouseFilterEnum.Stop };
        AddChild(blocker);
        TianjinUi.FullRect(blocker);

        var book = Place(new Control { Name = "Book", MouseFilter = MouseFilterEnum.Stop }, this, 225, 50, 1470, 960);
        var background = TianjinUi.Texture(_art.Shared.LedgerBook, Vector2.Zero);
        // Reuse the shared book silhouette with Wuhan's paper and cover palette.
        var bookMaterial = new ShaderMaterial { Shader = new Shader { Code = """
            shader_type canvas_item;
            uniform vec4 paper : source_color;
            uniform vec4 ink : source_color;
            uniform vec4 accent : source_color;
            void fragment() {
                vec4 source = texture(TEXTURE, UV);
                float light = dot(source.rgb, vec3(0.299, 0.587, 0.114));
                float chroma = max(source.r, max(source.g, source.b)) - min(source.r, min(source.g, source.b));
                vec3 page = paper.rgb * clamp(light / 0.96, 0.0, 1.04);
                vec3 cover = mix(ink.rgb, accent.rgb, smoothstep(0.15, 0.78, light));
                COLOR = vec4(mix(page, cover, smoothstep(0.16, 0.42, chroma)), source.a);
            }
            """ } };
        bookMaterial.SetShaderParameter("paper", WuhanUi.Paper);
        bookMaterial.SetShaderParameter("ink", WuhanUi.Ink);
        bookMaterial.SetShaderParameter("accent", WuhanUi.Accent);
        background.Material = bookMaterial;
        Place(background, book, 0, 0, 1470, 960);
        var bookmark = TianjinUi.Texture(_art.Shared.LedgerBookmark, Vector2.Zero);
        bookmark.Material = bookMaterial;
        Place(bookmark, book, 604, 22, 54, 122);

        var left = Place(new Control { Name = "LeftPage", MouseFilter = MouseFilterEnum.Ignore }, book, 85, 116, 570, 742);
        Place(WuhanUi.Label("经营手账", 42), left, 0, 0, 600, 58);
        _chapter = Place(WuhanUi.Label("武汉 · 12 个营业日", 22, WuhanUi.Muted), left, 0, 65, 570, 34);
        Place(WuhanUi.Label("选一个日子，翻看店里的故事", 20, WuhanUi.Muted), left, 0, 110, 610, 30);

        var grid = Place(new GridContainer { Name = "DateGrid", Columns = 3 }, left, 0, 162, 570, 508);
        grid.AddThemeConstantOverride("h_separation", 14);
        grid.AddThemeConstantOverride("v_separation", 12);
        for (int day = 1; day <= 12; day++)
        {
            int selected = day;
            var button = WuhanUi.Button("", false, new Vector2(180, 116));
            button.Name = $"Date{day}";
            button.ToggleMode = true;
            button.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            button.Pressed += () => SelectDay(selected);
            grid.AddChild(button);
            Place(WuhanUi.Label($"Day {day}", 27), button, 16, 16, 146, 38).MouseFilter = MouseFilterEnum.Ignore;
            var state = Place(WuhanUi.Label("", 19, WuhanUi.Text), button, 16, 64, 145, 29);
            state.MouseFilter = MouseFilterEnum.Ignore;
            var stamp = Place(TianjinUi.Texture(_art.Shared.LedgerRecordStamp, Vector2.Zero), button, 140, 14, 28, 28);
            _dates.Add(button); _dateStates.Add(state); _dateStamps.Add(stamp); _focusOrder.Add(button);
        }
        _notice = Place(WuhanUi.Label("点选日期后，在右页开始营业。", 19, WuhanUi.Muted), left, 0, 695, 570, 56);
        _notice.AutowrapMode = TextServer.AutowrapMode.WordSmart;

        var right = Place(new Control { Name = "RightPage", MouseFilter = MouseFilterEnum.Ignore }, book, 810, 116, 570, 742);
        _day = Place(WuhanUi.Label("Day 1", 46), right, 0, 0, 470, 60);
        _title = Place(WuhanUi.Label("", 30, WuhanUi.Muted), right, 0, 65, 570, 48);
        _stamp = Place(TianjinUi.Texture(_art.Shared.LedgerRecordStamp, Vector2.Zero), right, 490, 0, 76, 76);
        _stamp.Name = "RecordStamp";
        _illustrations = Place(new HBoxContainer { Name = "DayIllustrations", Alignment = BoxContainer.AlignmentMode.Center }, right, 0, 128, 570, 212);
        _illustrations.AddThemeConstantOverride("separation", 18);

        _record = Place(new Control { Name = "BestRecord", MouseFilter = MouseFilterEnum.Ignore }, right, 0, 364, 570, 170);
        Place(TianjinUi.Texture(_art.Shared.Coin, Vector2.Zero), _record, 0, 11, 60, 60);
        Place(WuhanUi.Label("历史最佳收入", 20, WuhanUi.Muted), _record, 78, 0, 490, 30);
        _revenue = Place(WuhanUi.Label("", 40), _record, 78, 33, 490, 56);
        _revenue.Name = "BestRevenue";
        Place(TianjinUi.Texture(_art.Shared.HeartEffect, Vector2.Zero), _record, 0, 119, 44, 44);
        _satisfaction = Place(WuhanUi.Label("", 23), _record, 58, 117, 275, 48);
        _satisfaction.Name = "BestSatisfaction";
        Place(new WuhanLedgerCheckIcon { MouseFilter = MouseFilterEnum.Ignore }, _record, 306, 126, 28, 28);
        _perfect = Place(WuhanUi.Label("", 23), _record, 347, 117, 223, 48);
        _perfect.Name = "BestPerfect";
        _empty = Place(WuhanUi.Label("", 26, WuhanUi.Muted), right, 0, 364, 570, 170);
        _empty.Name = "EmptyRecord";
        _empty.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        _note = Place(WuhanUi.Label("", 20, WuhanUi.Muted), right, 0, 560, 570, 62);
        _note.Name = "DayNote";
        _note.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        _start = Place(WuhanUi.Button("开始营业", true, new Vector2(570, 70)), right, 0, 652, 570, 70);
        _start.Name = "StartLedgerDay";
        _start.Pressed += StartSelectedDay;
        _focusOrder.Add(_start);

        var close = Place(WuhanUi.Button("合上手账", false, new Vector2(176, 52)), this, 1590, 16, 176, 52);
        close.Name = "CloseLedger";
        close.Pressed += Close;
        _focusOrder.Add(close);
    }

    public void Open(SaveService save)
    {
        if (!Visible) _previousFocus = GetViewport().GuiGetFocusOwner();
        SelectedDay = Math.Clamp(save.Data.Wuhan.HighestUnlockedDay, 1, 12);
        _notice.Text = "点选日期后，在右页开始营业。";
        _notice.Modulate = Colors.White;
        Refresh(save);
        Show();
        FocusSelectedDay();
    }

    public void Close()
    {
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
            button.AddThemeStyleboxOverride("normal", WuhanUi.Box(paper, 14, selected ? 4 : 2, false));
            button.AddThemeStyleboxOverride("pressed", WuhanUi.Box(selection, 14, 4, false));
            button.AddThemeStyleboxOverride("hover", WuhanUi.Box(paper.Lightened(.06f), 14, 3, false));
            button.AddThemeStyleboxOverride("hover_pressed", WuhanUi.Box(selection.Lightened(.06f), 14, 4, false));
            var focus = WuhanUi.Box(Colors.Transparent, 14, 4, false);
            focus.BorderColor = WuhanUi.Accent;
            button.AddThemeStyleboxOverride("focus", focus);
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
        foreach (Node child in _illustrations.GetChildren()) { _illustrations.RemoveChild(child); child.QueueFree(); }
        if (locked)
        {
            var lockView = new WuhanLedgerLockIcon { CustomMinimumSize = new Vector2(130, 170), MouseFilter = MouseFilterEnum.Ignore };
            _illustrations.AddChild(lockView);
            return;
        }
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
        foreach (string id in images)
        {
            float width = images.Length == 3 ? 174 : 210;
            if (id != "noodles")
            {
                _illustrations.AddChild(TianjinUi.Texture(_art.Texture(id), new Vector2(width, 212)));
                continue;
            }
            var bowl = new Control { Name = "NoodleBowl", CustomMinimumSize = new Vector2(width, 212), MouseFilter = MouseFilterEnum.Ignore };
            _illustrations.AddChild(bowl);
            Place(TianjinUi.Texture(_art.Texture("empty_bowl"), Vector2.Zero), bowl, 0, 0, width, 212);
            Place(TianjinUi.Texture(_art.Texture("mixed"), Vector2.Zero), bowl, width * .15f, 12, width * .7f, 140);
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

    private static T Place<T>(T control, Control parent, float x, float y, float width, float height) where T : Control
    {
        parent.AddChild(control);
        control.Position = new Vector2(x, y);
        control.Size = new Vector2(width, height);
        return control;
    }
}

internal partial class WuhanLedgerCheckIcon : Control
{
    public override void _Draw() => DrawPolyline(new[] { new Vector2(2, 14), new Vector2(11, 23), new Vector2(27, 3) }, WuhanUi.Muted, 5, true);
}

internal partial class WuhanLedgerLockIcon : Control
{
    public override void _Draw()
    {
        DrawArc(new Vector2(65, 75), 34, Mathf.Pi, Mathf.Tau, 32, WuhanUi.Muted, 8, true);
        DrawStyleBox(WuhanUi.Box(WuhanUi.Disabled, 14, 4, false), new Rect2(15, 74, 100, 78));
        DrawCircle(new Vector2(65, 108), 8, WuhanUi.Ink);
        DrawLine(new Vector2(65, 112), new Vector2(65, 128), WuhanUi.Ink, 7, true);
    }
}

