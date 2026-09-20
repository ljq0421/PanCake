using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class EndlessBusinessSelfTest : Node
{
    private static void Check(bool ok, string message)
    { if (!ok) throw new InvalidOperationException(message); }

    public override async void _Ready()
    {
        try
        {
            bool demo = ExperienceProfile.IsDemo;
            bool capture = OS.GetCmdlineUserArgs().Contains("--capture");
            GetWindow().Size = new(1280, 720);
            string dir = ProjectSettings.GlobalizePath("res://.tmp/endless-business/" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(dir);
            var save = GetNode<SaveService>("/root/SaveService");
            string path = Path.Combine(dir, "save.json");
            if (demo) save.UseDemoPathForTests(path); else save.UsePathForTests(path);
            Check(save.ResetProgress(out _), "create isolated save");
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Path.Combine(dir, "settings.cfg"));
            InterfaceLessons.MarkAllSeen(settings);
            var catalog = GetNode<DataCatalog>("/root/DataCatalog");
            Check(catalog.IsValid, "valid catalog");
            var cities = JourneyModel.Cities.Where(c => save.IsCityAvailable(c.Id)).ToArray();
            foreach (var city in cities)
            {
                if (!save.Data.UnlockedCityIds.Contains(city.Id)) save.Data.UnlockedCityIds.Add(city.Id);
                var progress = save.Data.GetCity(city.Id);
                progress.HighestUnlockedDay = city.Days;
                progress.DayBestRecords[city.Days] = new() { TotalRevenue = 17 };
            }
            Check(save.TrySave(out _), "save old capped progress");
            save.Load();
            Check(!save.HasLoadError, "old saves load");
            foreach (var city in cities)
                Check(save.Data.GetCity(city.Id).HighestUnlockedDay == city.Days + 1, "old final day unlocks next " + city.Id);

            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();
            AddChild(main);
            await Frames();
            foreach (var city in cities)
            {
                var progress = save.Data.GetCity(city.Id);
                int day = city.Days + 1;
                Check(save.CanEnter(city.Id, day) && !save.CanEnter(city.Id, day + 1), "only unlocked days enter " + city.Id);
                Check(main.StartCityBusiness(city.Id, day), "actual game starts extended day " + city.Id);
                await Frames(); // Also exercises headings and all live workbench updates.
                main.OpenCity(city.Id);
                if (city.Id == StableIds.Cities.Yangzhou)
                {
                    var yz = YangzhouCatalog.Load();
                    Check(yz.Day(day).Day == day && yz.Day(day).Customers == yz.Day(city.Days).Customers, "Yangzhou repeats final configuration");
                    var session = YangzhouSelfTest.Play(yz, day, 3, 3, productionAdvancesBusiness: false);
                    var result = session.Result();
                    Check(result.Day == day && result.Completed == result.Planned && result.Stars > 0, "Yangzhou extended day completes and rates");
                    save.CommitYangzhou(session);
                    Check(save.CommitYangzhou(session).PermanentCoinGain == 0, "Yangzhou duplicate settlement ignored");
                }
                else
                {
                    Check(catalog.TryGetDay(city.Id, city.Days, out var last) && catalog.TryGetDay(city.Id, day, out _), "extended config exists");
                    catalog.TryGetDay(city.Id, day, out var extended);
                    Check(last.Day == city.Days && extended.Day == day && extended.CustomerCount == last.CustomerCount
                        && extended.DurationSeconds == last.DurationSeconds && extended.AvailableRecipeIds.SequenceEqual(last.AvailableRecipeIds)
                        && extended.StarGoals.Count == last.StarGoals.Count, "repeat config preserves template " + city.Id);
                    var controller = new DayController(); AddChild(controller);
                    Check(controller.TryPrepareDay(city.Id, day, catalog, out _) && controller.TryStartDay(out _), "prepare extended simulation");
                    for (int tick = 0; tick < 2000 && controller.State != DayState.Results; tick++) controller.Tick(1);
                    Check(controller.State == DayState.Results && controller.Ledger!.Build().Day == day, "extended loss day settles " + city.Id);
                    save.CommitDay(controller.Ledger!.Build(), controller.CurrentPlan!, extended);
                    Check(save.CommitDay(controller.Ledger.Build(), controller.CurrentPlan!, extended).PermanentCoinGain == 0, "duplicate settlement ignored");
                    controller.Free();
                    // Missing the chapter star at its original endpoint must not permanently block the next city.
                    progress.HighestUnlockedDay = day + 1;
                    catalog.TryGetDay(city.Id, day + 1, out var retry);
                    var goal = retry.StarGoals.Single(g => g.Stars == 1);
                    save.CommitDay(new() { Day = day + 1, CompletedCustomers = goal.MinimumCompletedCustomers,
                        Satisfaction = goal.MinimumSatisfaction, PerfectOrders = goal.MinimumPerfectOrders },
                        new() { Day = day + 1 }, retry);
                    Check(progress.Completed, "later day can earn chapter completion " + city.Id);
                }
                Check(progress.HighestUnlockedDay > day && progress.DayBestRecords.ContainsKey(day), "extended day persists separately " + city.Id);
                int highest = progress.HighestUnlockedDay;
                save.Load();
                Check(!save.HasLoadError && save.Data.GetCity(city.Id).HighestUnlockedDay == highest, "extended save roundtrip " + city.Id);
                GD.Print("PASS endless business " + city.Id);
            }
            if (demo) Check(!save.CanEnter(StableIds.Cities.Xian, 1), "Demo city availability unchanged");

            var screen = main.GetNode<StartScreen>("UI/StartScreen");
            var p = save.Data.Tianjin;
            p.HighestUnlockedDay = 101;
            p.DayBestRecords[100] = new() { TotalRevenue = 54321, Satisfaction = 98 };
            save.Data.BreakfastRecords["doupi"] = 100;
            Check(save.TrySave(out _), "late breakfast collection can save"); save.Load();
            Check(!save.HasLoadError && save.Data.BreakfastRecords["doupi"] == 100, "late collection roundtrip");
            main.OpenCity(StableIds.Cities.Tianjin);
            var model = new CityPageModel(catalog, save, demo ? null : YangzhouCatalog.Load());
            var overview = model.Overview(StableIds.Cities.Tianjin, 1);
            Check(overview.Day == 101 && overview.BestDay == 100 && overview.BestRevenue == 54321, "overview includes later records");
            screen.PresentLedger(); await Frames();
            Button Find(string name) => screen.FindChildren(name, "Button", true, false).OfType<Button>().First(b => b.IsVisibleInTree());
            Check(!Find("Date101").Disabled && Find("NextDays").Disabled, "calendar opens latest page");
            Find("PreviousDays").EmitSignal(BaseButton.SignalName.Pressed); await Frames();
            Check(Find("Date76").IsVisibleInTree(), "calendar previous page");
            Find("NextDays").EmitSignal(BaseButton.SignalName.Pressed); await Frames();
            Find("Date100").EmitSignal(BaseButton.SignalName.Pressed); await Frames();
            Check(screen.SelectedDay == 100 && !Find("StartSelectedDay").Disabled, "later day can replay");
            if (capture)
            {
                await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
                using var image = GetViewport().GetTexture().GetImage();
                string screenshot = ProjectSettings.GlobalizePath("res://.tmp/endless-business-ledger.png");
                image.SavePng(screenshot); GD.Print("CAPTURE " + screenshot);
            }
            screen.PresentMap(); await Frames();
            Find("Node0").EmitSignal(BaseButton.SignalName.Pressed); await Frames();
            Check(main.GetNode<DayController>("DayController").CurrentConfig?.Day == 101, "map opens latest business day");
            GD.Print($"ENDLESS_BUSINESS_SELF_TEST_OK demo={demo} cities={cities.Length}");
            GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
    private async Task Frames() { for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
}
