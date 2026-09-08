using Godot;
using ProjectCake.Core;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Ledger interaction regression tests using an isolated save and real viewport input.</summary>
public partial class TianjinLedgerSelfTest : Node
{
    private MorningHub _hub = null!;
    private TianjinLedger _ledger = null!;
    private SaveService _save = null!;
    private string _directory = "";
    private string _savePath = "";
    private int _passed;
    private bool _capture;
    private bool _small;

    public override async void _Ready()
    {
        try
        {
            _small = OS.GetCmdlineUserArgs().Contains("--capture-720");
            _capture = OS.GetCmdlineUserArgs().Contains("--capture");
            GetWindow().Size = _small ? new Vector2I(1280, 720) : new Vector2I(1920, 1080);
            _directory = ProjectSettings.GlobalizePath($"res://.tmp/ledger-tests/{Guid.NewGuid():N}");
            Directory.CreateDirectory(_directory);
            _savePath = Path.Combine(_directory, "save.json");
            TestAssets();
            _save = new SaveService();
            _save.UsePathForTests(_savePath);
            AddChild(_save);
            _hub = new MorningHub(); AddChild(_hub);
            _hub.Initialize(GetNode<DataCatalog>("/root/DataCatalog"), _save);
            _ledger = _hub.GetNode<TianjinLedger>("TianjinLedger");
            await Frames();

            var requests = new List<int>();
            _hub.DayRequested += requests.Add;
            _hub.ShowLedger(); await Frames();
            Check(_ledger.Visible && _ledger.SelectedDay == 1, "new save opens Day 1");
            Check(Find<Label>("EmptyRecord").Text.Contains("等待开店") && !Find<Control>("BestRecord").Visible, "new day has an honest empty state");
            Check(Find<Button>("StartLedgerDay").Text == "开始营业 · Day 1", "new day offers opening action");
            Check(Find<GridContainer>("DateGrid").Columns == 3 && Find<GridContainer>("DateGrid").GetChildCount() == 15, "all 15 dates in three columns");
            await Capture("new");

            await Click(Find<Button>("Date5"));
            Check(_ledger.SelectedDay == 5 && requests.Count == 0 && _ledger.Visible, "date selection never starts a shift");
            Check(Find<Button>("StartLedgerDay").Disabled && Find<Label>("EmptyRecord").Text.Contains("Day 4"), "locked date explains prerequisite and disables starting");
            Find<Button>("StartLedgerDay").EmitSignal(Button.SignalName.Pressed);
            Check(requests.Count == 0, "activation handler guards locked dates too");
            await Capture("locked");

            int backgroundClicks = 0;
            var probe = new Button { Text = "test", Position = new Vector2(16, 470), Size = new Vector2(140, 60) };
            probe.Pressed += () => backgroundClicks++;
            _hub.AddChild(probe);
            _hub.MoveChild(probe, _ledger.GetIndex());
            await Frames();
            await Click(probe);
            Check(backgroundClicks == 0, "modal blocks mouse clicks outside book");
            for (int index = 0; index < 21; index++)
            {
                KeyPress(Key.Tab);
                Check(_ledger.IsAncestorOf(GetViewport().GuiGetFocusOwner()), "Tab stays inside ledger");
            }
            Find<Button>("Date1").GrabFocus(); KeyPress(Key.Left); KeyPress(Key.Up);
            Check(Find<Button>("Date1").HasFocus(), "arrow focus cannot escape first date");
            await Click(Find<Button>("CloseLedger"));
            Check(!_ledger.Visible, "close hides entire modal");
            await Click(probe);
            Check(backgroundClicks == 1, "background receives input again after closing");
            probe.QueueFree(); await Frames();

            _save.Data.HighestUnlockedDay = 9;
            _save.Data.DayBestRecords[8] = new DayBestRecord { TotalRevenue = 386, Satisfaction = 96, PerfectOrders = 18 };
            _hub.ShowLedger();
            Check(_ledger.SelectedDay == 9, "open always selects highest unlocked day");
            await Click(Find<Button>("Date8"));
            Check(Find<Label>("BestRevenue").Text == "¥386" && Find<Label>("BestSatisfaction").Text == "满意度 96%" && Find<Label>("BestPerfect").Text == "Perfect 18 单", "detail displays exact saved best record");
            Check(Find<Control>("RecordStamp").Visible, "record stamp denotes existing record");
            await Capture("record");
            await Click(Find<Button>("StartLedgerDay"));
            Check(requests.SequenceEqual(new[] { 8 }) && !_ledger.Visible, "only action button dispatches selected day and closes ledger");
            _hub.ShowLedger(); await Frames();
            await Click(Find<Button>("StartLedgerDay"));
            Check(requests.SequenceEqual(new[] { 8, 9 }), "unplayed unlocked day dispatches correctly");

            _save.Data.HighestUnlockedDay = 15; _save.Data.TianjinBestStars = 3;
            for (int day = 1; day <= 15; day++)
                _save.Data.DayBestRecords[day] = new DayBestRecord { TotalRevenue = 120 + day * 19, Satisfaction = 90 + day % 10, PerfectOrders = day + 4 };
            _hub.ShowLedger(); await Frames();
            Check(_ledger.SelectedDay == 15 && !Find<Button>("StartLedgerDay").Disabled, "complete chapter remains replayable");
            await Capture("complete");
            _save.Data.DayBestRecords[15].TotalRevenue = int.MaxValue;
            _ledger.Refresh(_save);
            Check(Find<Label>("BestRevenue").GetCombinedMinimumSize().X <= 490, "largest saved revenue fits its allotted width");
            await Capture("large-record");

            await Click(Find<Button>("ResetLedgerProgress")); await Frames();
            var confirmation = _hub.GetChildren().OfType<ConfirmationDialog>().Single();
            Check(confirmation.Visible && _ledger.ConfirmationOpen && _save.Data.HighestUnlockedDay == 15, "reset requires confirmation before changing progress");
            confirmation.GetCancelButton().EmitSignal(Button.SignalName.Pressed); await Frames();
            Check(!_ledger.ConfirmationOpen && _save.Data.HighestUnlockedDay == 15, "cancel reset preserves progress and restores focus");
            await Click(Find<Button>("ResetLedgerProgress")); await Frames();
            confirmation.GetOkButton().EmitSignal(Button.SignalName.Pressed); await Frames();
            Check(_save.Data.HighestUnlockedDay == 1 && _save.Data.DayBestRecords.Count == 0 && _ledger.SelectedDay == 1, "confirmed reset refreshes selection and record state");
            Check(!Find<Control>("BestRecord").Visible && !Find<Button>("StartLedgerDay").Disabled, "reset exposes fresh Day 1");
            await Capture("reset");

            File.WriteAllText(_savePath, "{invalid-json"); _save.Load(); await Frames();
            Check(_save.HasLoadError && Find<Button>("StartLedgerDay").Disabled && Find<Label>("EmptyRecord").Text.Contains("存档无法读取"), "corrupt save blocks opening and explains recovery");
            _hub.ShowLedger();
            Find<Button>("StartLedgerDay").EmitSignal(Button.SignalName.Pressed);
            Check(requests.Count == 2, "corrupt-save activation cannot dispatch a day");
            await Capture("load-error");
            await Click(Find<Button>("ResetLedgerProgress")); await Frames();
            confirmation.GetOkButton().EmitSignal(Button.SignalName.Pressed); await Frames();
            Check(!_save.HasLoadError && !Find<Button>("StartLedgerDay").Disabled, "confirmed recovery re-enables opening");

            _ledger.SelectDay(15);
            // A save reload must update an already-open ledger without starting or closing it.
            _save.Load(); await Frames();
            Check(_ledger.Visible && _ledger.SelectedDay == 15 && Find<Button>("StartLedgerDay").Disabled, "live save refresh preserves inspected date and rechecks availability");
            KeyPress(Key.Escape);
            Check(!_ledger.Visible, "Escape closes ledger");
            _hub.Free(); _save.Free(); await Frames();
            GD.Print($"TIANJIN_LEDGER_TEST_RESULT passed={_passed} failed=0");
            GetTree().Quit();
        }
        catch (Exception exception)
        {
            GD.PushError(exception.ToString());
            GD.Print($"TIANJIN_LEDGER_TEST_RESULT passed={_passed} failed=1");
            GetTree().Quit(1);
        }
    }

    private T Find<T>(string name) where T : Node => (T)(_ledger.FindChild(name, true, false)
        ?? throw new InvalidOperationException($"Missing {name}"));

    private void TestAssets()
    {
        foreach (string name in new[] { "ledger_book", "ledger_bookmark", "ledger_record_stamp" })
        {
            using Image image = Image.LoadFromFile($"res://resource/art/TianJin/Ledger/{name}.png");
            Check(image.GetFormat() == Image.Format.Rgba8 && image.GetPixel(0, 0).A == 0, $"{name} has actual transparent alpha");
            bool green = false;
            for (int y = 0; y < image.GetHeight() && !green; y += 3)
                for (int x = 0; x < image.GetWidth() && !green; x += 3)
                {
                    Color pixel = image.GetPixel(x, y);
                    green = pixel.A > .1f && pixel.G > pixel.R + .12f && pixel.G > pixel.B + .12f;
                }
            Check(!green, $"{name} has no visible green-screen residue");
        }
    }

    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        _passed++;
        GD.Print($"PASS {message}");
    }

    private async Task Frames(int count = 2)
    {
        for (int index = 0; index < count; index++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task Click(Control control)
    {
        Vector2 point = control.GetGlobalRect().GetCenter();
        GetViewport().PushInput(new InputEventMouseMotion { Position = point, GlobalPosition = point }, true);
        GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true, Position = point, GlobalPosition = point }, true);
        await Frames(1);
        GetViewport().PushInput(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = false, Position = point, GlobalPosition = point }, true);
        await Frames();
    }

    private void KeyPress(Key key)
    {
        GetViewport().PushInput(new InputEventKey { Keycode = key, Pressed = true }, true);
        GetViewport().PushInput(new InputEventKey { Keycode = key, Pressed = false }, true);
    }

    private async Task Capture(string state)
    {
        if (!_capture) return;
        await Frames(3);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string root = ProjectSettings.GlobalizePath($"res://.tmp/ledger-review/{(_small ? 720 : 1080)}");
        Directory.CreateDirectory(root);
        Error result = GetViewport().GetTexture().GetImage().SavePng(Path.Combine(root, state + ".png"));
        Check(result == Error.Ok, $"capture {state}");
    }
}
