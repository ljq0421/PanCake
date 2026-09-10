using System.Text.Json.Nodes;
using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Tests;

/// <summary>Exercises real menu input and disk failures using only an isolated workspace save.</summary>
public partial class StartScreenSelfTest : Node
{
    private SaveService _save = null!;
    private GameController _main = null!;
    private StartScreen _screen = null!;
    private string _path = string.Empty;
    private int _passed;
    private bool _capture;
    private int _width;

    public override async void _Ready()
    {
        try
        {
            string[] args = OS.GetCmdlineUserArgs();
            _capture = args.Contains("--capture");
            _width = args.Contains("--small") ? 1280 : args.Contains("--wide") ? 1600 : args.Contains("--square") ? 1080 : 1920;
            GetWindow().Size = new(_width, _width is 1280 or 1600 ? 720 : 1080);
            string directory = ProjectSettings.GlobalizePath($"res://.tmp/start-tests/{Guid.NewGuid():N}");
            Directory.CreateDirectory(directory);
            _path = Path.Combine(directory, "save.json");
            _save = GetNode<SaveService>("/root/SaveService");
            _save.UsePathForTests(_path);
            await Launch();
            Check(!_save.CanContinue && !_save.RequiresNewGameConfirmation, "missing save is distinct from an empty valid save");
            Check(Find<Button>("Continue").Disabled && Find<Button>("Continue").Text.Contains("暂无存档"), "continue stays visible and disabled without a save");
            Check(_main.GetNode("UI").GetChildren().OfType<Control>().Count(c => c.Visible) == 1 && _screen.Visible, "only the title page is visible at startup");
            Check(Find<Button>("NewGame").HasFocus(), "first run focuses new game");
            KeyPress(Key.Down);
            Check(Find<Button>("Quit").HasFocus(), "keyboard skips unavailable continue");
            KeyPress(Key.Tab);
            Check(Find<Button>("NewGame").HasFocus(), "keyboard wraps within title controls");
            await Capture("first-run");
            await Click(Find<Button>("NewGame"));
            Check(_save.CanContinue && _save.Data.Coins == 0 && _save.Data.LastVisitedCityId == StableIds.Cities.Tianjin, "new game creates an empty valid save");
            Check(_main.GetNode<Control>("UI/MorningHub").Visible && !_screen.Visible, "new game enters Tianjin hub");

            string[] cities = { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou, StableIds.Cities.Yangzhou };
            string[] hubs = { "MorningHub", "WuhanHub", "XianHub", "GuangzhouHub", "YangzhouHub" };
            _save.Data.UnlockedCityIds = cities.ToList();
            foreach (string city in cities) _save.Data.GetCity(city);
            _save.Data.Coins = 321;
            Check(_save.TrySave(out _), "save fixture persists");
            for (int i = 0; i < cities.Length; i++)
            {
                Check(_main.OpenCity(cities[i]), $"enter {cities[i]}");
                _save.Load();
                await Launch();
                Check(_save.ContinueCityId == cities[i] && Find<Button>("Continue").HasFocus(), $"restart retains {cities[i]} and focuses continue");
                await Click(Find<Button>("Continue"));
                Check(_main.GetNode<Control>("UI/" + hubs[i]).Visible && _save.Data.Coins == 321, $"continue enters {hubs[i]} without starting a shift");
            }

            await Launch();
            await Capture("continue");
            string before = File.ReadAllText(_path);
            await Click(Find<Button>("NewGame"));
            Check(_screen.ConfirmationOpen && Find<Button>("Cancel").HasFocus(), "existing save requires confirmation with cancel focused");
            await Capture("confirmation");
            await Click(Find<Button>("NewGame"));
            Check(File.ReadAllText(_path) == before && _screen.ConfirmationOpen, "confirmation blocks clicks on background controls");
            KeyPress(Key.Tab);
            Check(Find<Button>("Confirm").HasFocus(), "Tab remains within confirmation");
            KeyPress(Key.Tab);
            Check(Find<Button>("Cancel").HasFocus(), "confirmation focus wraps");
            KeyPress(Key.Escape);
            Check(!_screen.ConfirmationOpen && Find<Button>("NewGame").HasFocus() && File.ReadAllText(_path) == before, "Escape cancels without touching progress and restores focus");

            // An empty directory at the atomic-save temporary path makes writes fail deterministically.
            Directory.CreateDirectory(_path + ".tmp");
            await Click(Find<Button>("NewGame"));
            await Click(Find<Button>("Confirm"));
            Check(_screen.Visible && _save.CanContinue && _save.Data.Coins == 321 && File.ReadAllText(_path) == before, "failed overwrite retains disk and memory progress on title page");
            Check(Find<Label>("Status").Text.Contains("保存失败"), "failed overwrite gives a visible error");
            await Capture("save-error");
            string previousCity = _save.Data.LastVisitedCityId;
            Check(!_save.TryRecordCityVisit(StableIds.Cities.Wuhan, out _) && _save.Data.LastVisitedCityId == previousCity, "failed location save restores prior city");
            Directory.Delete(_path + ".tmp");

            await Click(Find<Button>("NewGame"));
            await Click(Find<Button>("Confirm"));
            Check(_save.Data.Coins == 0 && _save.Data.UnlockedCityIds.SequenceEqual(new[] { StableIds.Cities.Tianjin })
                && _save.Data.Cities.Values.All(city => city.HighestUnlockedDay == 1 && city.BestStars == 0 && !city.Completed
                    && city.DayBestRecords.Count == 0 && city.EquipmentLevels.Values.All(level => level <= 1)), "confirmed new game clears every city and returns to Tianjin");
            Check(_main.OpenCity(StableIds.Cities.Wuhan, true) && _save.ContinueCityId == StableIds.Cities.Tianjin, "developer preview of locked city does not alter resume city");
            Check(!_main.OpenCity(StableIds.Cities.Wuhan), "normal navigation rejects locked city");

            JsonObject old = JsonNode.Parse(File.ReadAllText(_path))!.AsObject();
            old.Remove("LastVisitedCityId"); File.WriteAllText(_path, old.ToJsonString());
            _save.Load();
            Check(_save.CanContinue && _save.ContinueCityId == StableIds.Cities.Tianjin, "old v3 save without city field loads without data loss");
            foreach (string invalid in new[] { "city:future", StableIds.Cities.Wuhan })
            {
                old["LastVisitedCityId"] = invalid; File.WriteAllText(_path, old.ToJsonString()); _save.Load();
                Check(_save.CanContinue && _save.ContinueCityId == StableIds.Cities.Tianjin, "invalid or locked city falls back to Tianjin");
            }

            File.WriteAllText(_path, "broken save"); _save.Load();
            await Launch();
            Check(!_save.CanContinue && Find<Button>("Continue").Disabled && Find<Label>("Status").Text.Contains("无法读取"), "corrupt save cannot be continued");
            Check(File.Exists(_save.CorruptBackupPath), "corrupt save backup is preserved");
            await Capture("corrupt");
            Directory.CreateDirectory(_path + ".tmp");
            await Click(Find<Button>("NewGame")); await Click(Find<Button>("Confirm"));
            Check(_save.HasLoadError && !_save.CanContinue && File.ReadAllText(_path) == "broken save", "failed corrupt reset preserves error state and original file");
            Directory.Delete(_path + ".tmp");
            await Click(Find<Button>("NewGame"));
            KeyPress(Key.Escape);
            Check(_save.HasLoadError, "cancelled corrupt reset keeps the protection");
            await Click(Find<Button>("NewGame")); await Click(Find<Button>("Confirm"));
            Check(_save.CanContinue && !_save.HasLoadError, "confirmed corrupt reset creates a valid new game");

            await Launch();
            int requests = 0;
            _screen.ContinueRequested += () => requests++;
            Find<Button>("Continue").EmitSignal(BaseButton.SignalName.Pressed);
            Find<Button>("Continue").EmitSignal(BaseButton.SignalName.Pressed);
            Check(requests == 1, "repeated activation dispatches only one transition");
            GD.Print($"START_SCREEN_TEST_RESULT passed={_passed} failed=0");
            GetTree().Quit();
        }
        catch (Exception exception)
        {
            GD.PushError(exception.ToString());
            GD.Print($"START_SCREEN_TEST_RESULT passed={_passed} failed=1");
            GetTree().Quit(1);
        }
    }

    private async Task Launch()
    {
        if (_main is not null) { RemoveChild(_main); _main.Free(); }
        _main = ResourceLoader.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
        AddChild(_main);
        _screen = _main.GetNode<StartScreen>("UI/StartScreen");
        await Frames(3);
        if (_capture) await ToSignal(GetTree().CreateTimer(0.3), SceneTreeTimer.SignalName.Timeout);
    }

    private T Find<T>(string name) where T : Node => _screen.GetNode<T>("%" + name);
    private void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
        _passed++; GD.Print("PASS " + message);
    }
    private async Task Frames(int count = 2) { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Click(Control control)
    {
        // Include the canvas scale when dispatching actual viewport input.
        Vector2 point = control.GetGlobalTransformWithCanvas() * (control.Size / 2);
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
        string directory = ProjectSettings.GlobalizePath($"res://.tmp/start-review/{_width}");
        Directory.CreateDirectory(directory);
        Check(GetViewport().GetTexture().GetImage().SavePng(Path.Combine(directory, state + ".png")) == Error.Ok, "capture " + state);
    }
}
