using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class WuhanUnlockSelfTest : Node
{
    private int _checks;
    private string _dir = "";
    private string _saveFile = "";
    private SaveService _save = null!;
    public override async void _Ready()
    {
        try
        {
            _dir = ProjectSettings.GlobalizePath("res://.tmp/wuhan-unlock/" + (ExperienceProfile.IsDemo ? "demo" : "formal") + (OS.GetCmdlineUserArgs().Contains("--small") ? "-small" : ""));
            _dir = OS.GetCmdlineUserArgs().FirstOrDefault(a => a.StartsWith("--capture-dir=", StringComparison.Ordinal))?[14..] ?? _dir;
            Directory.CreateDirectory(_dir);
            string fixture = Path.Combine(_dir, Guid.NewGuid().ToString("N")); Directory.CreateDirectory(fixture);
            _saveFile = Path.Combine(fixture, "save.json");
            _save = GetNode<SaveService>("/root/SaveService"); _save.UsePathForTests(_saveFile);
            var settings = GetNode<JourneySettings>("/root/JourneySettings"); settings.UsePathForTests(Path.Combine(fixture, "settings.cfg")); InterfaceLessons.MarkAllSeen(settings);
            Check(_save.ResetProgress(out _), "isolated progress");
            if (OS.GetCmdlineUserArgs().Contains("--unlock-audio-only"))
            {
                CheckUnlockAudio();
                await Frames(); GC.Collect(); GC.WaitForPendingFinalizers(); await Frames();
                GD.Print($"WUHAN_UNLOCK_AUDIO_TEST_PASS checks={_checks} demo={ExperienceProfile.IsDemo}");
                GetTree().Quit(); return;
            }
            await CheckPreparationFlow();
            GD.Print($"WUHAN_UNLOCK_TEST_PASS checks={_checks} demo={ExperienceProfile.IsDemo}");
            GetTree().Quit();
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
    private void Check(bool value, string message) { if (!value) throw new InvalidOperationException(message); _checks++; GD.Print("PASS " + message); }
    private async Task CheckPreparationFlow()
    {
        _save.Data.UpgradeTeachingCompleted = true;
        _save.Data.Tianjin.HighestUnlockedDay = 7;
        _save.Data.Coins = 600;
        Check(!_save.CanDepartForWuhan, "600 coins before completing Day 7 do not allow departure");
        _save.Data.Coins = 0;
        Check(_save.TrySave(out _), "prepare Day 7 fixture");
        GetWindow().Size = ExperienceProfile.IsDemo ? new(1280, 720) : new(1920, 1080);
        var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
        AddChild(main); await Frames();
        var day = main.GetNode<DayController>("DayController");
        var screen = main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen");
        var home = main.GetNode<StartScreen>("UI/StartScreen");
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 7), "Day 7 starts");
        day.SetProcess(false); screen.SetProcess(false);
        var model = BusinessBookModel.From(StableIds.Cities.Tianjin,
            new DayResult { Day = 7, SaleRevenue = 550, CompletedCustomers = 1 },
            Array.Empty<BusinessOrderRecord>(), catalog);
        BusinessBookSettlement.Commit(model, _save, day.CurrentPlan!, day.CurrentConfig!, catalog);
        Check(!model.NewWuhanUnlock && !_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan)
            && _save.Data.Coins == 550 && !_save.CanDepartForWuhan,
            "Day 7 credits wallet but does not unlock Wuhan");
        _save.CommitDay(model.Result, day.CurrentPlan!, day.CurrentConfig!);
        Check(_save.Data.Coins == 550, "same settlement cannot pay twice");
        day.AbandonDay();
        Check(main.StartCityBusiness(StableIds.Cities.Tianjin, 8), "Day 8 starts");
        day.SetProcess(false); screen.SetProcess(false);
        var next = BusinessBookModel.From(StableIds.Cities.Tianjin,
            new DayResult { Day = 8, SaleRevenue = 40, Tips = 10, CompletedCustomers = 1 },
            Array.Empty<BusinessOrderRecord>(), catalog);
        BusinessBookSettlement.Commit(next, _save, day.CurrentPlan!, day.CurrentConfig!, catalog);
        Check(_save.Data.Coins == 600 && _save.CanDepartForWuhan
            && !_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan), "600 wallet coins prepare Wuhan without automatic unlock");
        _save.Data.Coins = 599;
        Check(!_save.CanDepartForWuhan, "spending below 600 removes departure eligibility");
        _save.Data.Coins = 600;
        Check(_save.TrySave(out _), "restore 600 coin fixture");
        _save.Load();
        Check(_save.CanDepartForWuhan && !_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan),
            "loading an eligible save still waits for departure");
        day.AbandonDay(); screen.Hide(); home.PresentHome(); JourneyTransition.For(this).Finish(); await Frames();
        home.Descendants<Button>().Single(b => b.Name == "Continue").EmitSignal(BaseButton.SignalName.Pressed);
        JourneyTransition.For(this).Finish(); await Frames();
        Check(home.Page == JourneyPage.Map && home.Descendants<Button>().Any(b => b.Name == "DepartWuhan"),
            "normal continue journey route opens the current map with departure");
        await Capture("map-ready");
        using (var blocked = new FileStream(_saveFile + ".tmp", FileMode.OpenOrCreate, System.IO.FileAccess.ReadWrite, FileShare.None))
            Check(!_save.TryDepartForWuhan(out _) && !_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan),
                "failed save rolls back departure");
        home.Descendants<Button>().Single(b => b.Name == "DepartWuhan").EmitSignal(BaseButton.SignalName.Pressed);
        Check(_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan) && _save.Data.Coins == 600,
            "departure unlocks Wuhan without payment");
        var presentation = main.GetNode<WuhanUnlockPresentation>("WuhanUnlockPresentation");
        Check(presentation is not null, "map departure starts the existing Wuhan opening");
        presentation!.Skip();
        Check(_save.Data.WuhanUnlockPresentationSeen, "opening completion is saved");
        _save.Data.Coins = 0; Check(_save.TrySave(out _), "save spending after departure");
        _save.Load(); Check(_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan)
            && _save.Data.Coins == 0, "previously unlocked Wuhan remains open after spending");
    }
    private async Task Frames() { for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Capture(string name)
    {
        if (DisplayServer.GetName() == "headless") return;
        await Frames(); var drawn = ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw); RenderingServer.ForceDraw(); await drawn;
        using var image = GetViewport().GetTexture().GetImage(); image.SavePng(Path.Combine(_dir, name + ".png"));
    }
}
