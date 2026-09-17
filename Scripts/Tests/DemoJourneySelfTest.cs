using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.Fryer;
using ProjectCake.Inventory;
using ProjectCake.Customers;
using ProjectCake.UI;
namespace ProjectCake.Tests;

public partial class DemoJourneySelfTest : Node
{
    private int _checks;
    private string _dir = "";
    private bool _capture;
    private void Check(bool ok, string message) { if (!ok) throw new Exception(message); GD.Print("PASS " + message); _checks++; }
    private async Task Frames(int count = 5) { for (int i = 0; i < count; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private async Task Capture(string name, Node root)
    {
        await Frames(12);
        var labels = root.Descendants<Control>().Where(c => c.IsVisibleInTree()).Select(c =>
        {
            string raw = c switch { Label l => l.Text, Button b => b.Text, _ => "" };
            return new { path = c.GetPath().ToString(), raw, translated = c.Tr(raw).ToString(), bounds = c.GetGlobalRect().ToString() };
        }).Where(r => r.raw.Length > 0).ToArray();
        File.WriteAllText(Path.Combine(_dir, name + ".json"), System.Text.Json.JsonSerializer.Serialize(labels));
        if (TranslationServer.GetLocale().StartsWith("en") && labels.FirstOrDefault(r => System.Text.RegularExpressions.Regex.IsMatch(r.translated, "[\\u4e00-\\u9fff]")) is { } missing)
            throw new Exception("Untranslated visible text in " + name + ": " + missing.raw);
        if (!_capture) return;
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage(); image.SavePng(Path.Combine(_dir, name + ".png"));
    }
    public override async void _Ready()
    {
        try
        {
            var args = OS.GetCmdlineUserArgs(); _capture = args.Contains("--capture");
            string locale = args.Contains("--english") ? "en" : "zh_CN";
            var size = args.Contains("--small") ? new Vector2I(1280,720) : args.Contains("--1440") ? new Vector2I(2560,1440) : args.Contains("--16-10") ? new Vector2I(1600,1000) : new Vector2I(1920,1080);
            GetWindow().Size = size;
            _dir = ProjectSettings.GlobalizePath("user://demo-qa-artifacts/journey-" + locale + "-" + size.X);
            Directory.CreateDirectory(_dir);
            var c = GetNode<DataCatalog>("/root/DataCatalog"); var save = GetNode<SaveService>("/root/SaveService");
            string path = Path.Combine(_dir, "journey.json"); save.UseDemoPathForTests(path, c.Demo!); Check(save.ResetProgress(out _), "new isolated two-city journey");
            var settings = GetNode<JourneySettings>("/root/JourneySettings"); settings.UsePathForTests(Path.Combine(_dir, "settings.cfg")); settings.SetLanguage(locale);
            var controller = new DayController(); AddChild(controller); controller.SetProcess(false);
            int receiptCount = 0; controller.ItemDelivered += _ => receiptCount++;
            foreach (var stage in c.Demo!.Stages)
            {
                Check(controller.TryPrepareDay(stage.CityId, stage.Day, c, out _), stage.Id + " prepare");
                save.ApplyStartUnlocks(controller.CurrentConfig!, out _); controller.TryStartDay(out _); controller.Tick(3);
                for (int tick = 0; tick < 10000 && controller.State != DayState.Results; tick++)
                {
                    controller.Tick(.2);
                    foreach (var customer in controller.CustomerQueue!.Slots.Where(x => x.State is CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry).ToArray())
                        for (int lineIndex = 0; lineIndex < customer.Order.Lines.Count; lineIndex++)
                        {
                            var line = customer.Order.Lines[lineIndex]; int remaining = customer.Progress.GetRemainingQuantity(lineIndex);
                            for (int i = 0; i < remaining; i++)
                            {
                                DeliveryEvaluation result;
                                if (line.ProductKind == ProductKind.Pancake)
                                    result = controller.TryDeliverPreparedPancakeTo(customer.Id, new PreparedPancake(PancakeQuality.Perfect, c.RecipesById[line.DefinitionId].ExtraIngredients.ToHashSet(), YoutiaoQuality.Golden), c, () => true);
                                else if (line.ProductKind == ProductKind.Youtiao)
                                { var inventory = new YoutiaoInventory(1); inventory.TryStore(1, YoutiaoQuality.Golden); result = controller.TryDeliverYoutiaoTo(customer.Id, inventory); }
                                else if (line.ProductKind == ProductKind.SoyMilk) result = controller.TryDeliverSoyMilkTo(customer.Id, new SoyMilkTrayRuntime(1));
                                else result = controller.TryDeliverWuhanTo(customer.Id, new DeliveredItem(line.ProductKind, line.DefinitionId, WuhanQuality: line.ProductKind == ProductKind.HotDryNoodles ? WuhanFoodQuality.MixedComplete : WuhanFoodQuality.None), () => true);
                                if (!result.ItemAccepted && !result.CompletesOrder) throw new Exception(stage.Id + " real delivery rejected: " + result.Message);
                            }
                        }
                }
                var dayResult = controller.Ledger!.Build(); var plan = controller.CurrentPlan!;
                Check(controller.State == DayState.Results && dayResult.CompletedCustomers == stage.ExplicitOrders.Length && dayResult.LostCustomers == 0, stage.Id + " all real orders resolve");
                int owned = save.DemoProgress.BreakfastRecords.Count;
                if (stage.Day == 1)
                {
                    Directory.CreateDirectory(path + ".tmp");
                    bool failed = false; try { save.CommitDay(dayResult, plan, controller.CurrentConfig!); } catch (IOException) { failed = true; }
                    Check(failed && save.DemoProgress.BreakfastRecords.Count == owned && !save.DemoProgress.AcceptedRuns.Contains(plan.RunId), stage.Id + " failed save rolls back collection and run");
                    Directory.Delete(path + ".tmp");
                }
                save.CommitDay(dayResult, plan, controller.CurrentConfig!);
                int coins = save.Data.Coins; save.CommitDay(dayResult, plan, controller.CurrentConfig!);
                Check(coins == save.Data.Coins, stage.Id + " duplicate settlement pays nothing");
                save.Load(); Check(save.CanContinue && !save.HasLoadError, stage.Id + " exit and reload");
            }
            Check(save.DemoProgress.BreakfastRecords.Count == 5 && receiptCount > 100, "five cards earned by real item receipts");
            var first = c.Demo.Stages[0]; int before = save.Data.Coins;
            save.CommitDay(new() { Day = 1, CompletedCustomers = 1 }, first.Plan(c), first.Config(c.RecipesById, c.ProductsById));
            Check(save.Data.Tianjin.Completed && save.Data.Wuhan.Completed && save.Data.Coins == before, "earlier replay preserves both chapter completions");
            Check(DemoBreakfastCollection.Qualifies(new(ProductKind.Pancake, "pancake_youtiao", PancakeQuality.Perfect, InternalYoutiaoQuality:YoutiaoQuality.Light)) is null, "light internal youtiao excluded");
            Check(DemoBreakfastCollection.Qualifies(new(ProductKind.Pancake, "pancake_basic", PancakeQuality.Overdone)) is null, "overdone pancake excluded");
            Check(DemoBreakfastCollection.Qualifies(new(ProductKind.Youtiao, "youtiao", YoutiaoQuality:YoutiaoQuality.Deep)) is null, "deep youtiao excluded");
            Check(DemoBreakfastCollection.Qualifies(new(ProductKind.HotDryNoodles, "hot_dry_noodles_classic", WuhanQuality: WuhanFoodQuality.MixedComplete | WuhanFoodQuality.NoodlesSoft)) is null, "soft noodles excluded");
            Check(DemoBreakfastCollection.Qualifies(new(ProductKind.HotDryNoodles, "hot_dry_noodles_classic", WuhanQuality: WuhanFoodQuality.None)) is null, "unmixed noodles excluded");
            Check(DemoBreakfastCollection.Qualifies(new(ProductKind.Doupi, "doupi", WuhanQuality: WuhanFoodQuality.DoupiOverbrowned)) is null, "overbrowned doupi excluded");
            var pending = first.Plan(c); var receipt = new DeliveryReceipt(pending.RunId,pending.StageId,new(ProductKind.SoyMilk,"soy_milk"),true,true,false);
            foreach (var invalid in new[] { receipt with { Matched=false }, receipt with { Accepted=false }, receipt with { Tutorial=true }, receipt with { RunId="old-run" }, receipt with { StageId="other" } }) DemoBreakfastCollection.Observe(invalid,pending);
            Check(pending.PendingBreakfastRecords.Count == 0, "mismatch, rejected, tutorial and stale events ignored");
            DemoBreakfastCollection.Observe(receipt,pending); Check(pending.PendingBreakfastRecords.Count == 1,"eligible partial receipt staged only");
            // No commit models an abandoned run; collection remains unchanged.
            var replay = c.Demo.Stage(StableIds.Cities.Tianjin,6)!;
            save.DemoProgress.BreakfastRecords.Remove("soy_milk"); save.TrySave(out _);
            var replayPlan = replay.Plan(c); DemoBreakfastCollection.Observe(receipt with { RunId=replayPlan.RunId, StageId=replayPlan.StageId }, replayPlan);
            save.CommitDay(new() {Day=6}, replayPlan, replay.Config(c.RecipesById,c.ProductsById));
            Check(save.Data.Coins == before && save.DemoProgress.BreakfastRecords.ContainsKey("soy_milk"), "new partial collection saves without new income or completed order");
            controller.QueueFree();
            var main = GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>(); AddChild(main); await Frames();
            var screen = main.GetNode<StartScreen>("UI/StartScreen");
            screen.PresentHome(); await Capture("home", screen);
            Check(screen.Descendants<Label>().Single(l => l.Name == "DemoScope").Text.Contains("武汉 6"), "home describes both cities");
            screen.Descendants<Button>().Single(b => b.Name == "Help").EmitSignal(Button.SignalName.Pressed); await Capture("help", screen);
            screen.Descendants<Button>().Single(b => b.Name == "MusicCredits").EmitSignal(Button.SignalName.Pressed); await Capture("music-credits", screen);
            screen.Descendants<Button>().Single(b => b.Name == "Close" && b.IsVisibleInTree()).EmitSignal(Button.SignalName.Pressed);
            var originalSize = GetWindow().Size;
            settings.PreviewDisplay(true, originalSize); await Frames();
            Check(GetWindow().Mode == Window.ModeEnum.Fullscreen, "native fullscreen preview");
            settings.RevertDisplay(); await Frames();
            Check(GetWindow().Mode == Window.ModeEnum.Windowed && GetWindow().Size == originalSize, "display rollback restores exact window");
            screen.PresentCity(StableIds.Cities.Wuhan); await Capture("wuhan-ready", screen);
            screen.PresentLedger(); await Capture("wuhan-calendar", screen);
            screen.PresentUpgrades(); await Capture("wuhan-upgrades", screen);
            screen.PresentBreakfastCollection(); await Capture("collection",screen);
            foreach (var card in DemoBreakfastCollection.Cards)
            { screen.Descendants<Button>().Single(b=>b.Name=="Breakfast_"+card.Id).EmitSignal(Button.SignalName.Pressed); await Capture("card-"+card.Id,screen); }
            screen.PresentCompletion(StableIds.Cities.Wuhan, screen.PresentHome); await Capture("ending",screen);
            Check(screen.Descendants<Label>().Any(l=>l.Name=="EndingCollection" && l.Text.Contains("5 / 5")),"ending shows true collection");
            screen.PresentCompletion(StableIds.Cities.Wuhan, screen.PresentHome);
            Check(save.Data.Coins==before,"repeated ending grants no reward");
            screen.PresentCompletion(StableIds.Cities.Tianjin, screen.PresentHome);
            screen.Descendants<Button>().Single(b=>b.Name=="Skip").EmitSignal(Button.SignalName.Pressed); await Capture("wuhan-opening",screen);
            foreach (var (city, day) in new[] { (StableIds.Cities.Tianjin, 1), (StableIds.Cities.Tianjin, 4), (StableIds.Cities.Tianjin, 6), (StableIds.Cities.Wuhan, 1), (StableIds.Cities.Wuhan, 4) })
            {
                Check(main.StartCityBusiness(city, day), city + " lesson entry " + day);
                var active = city == StableIds.Cities.Tianjin ? (Control)main.GetNode<TianjinDayScreen>("UI/TianjinDayScreen") : main.GetNode<WuhanDayScreen>("UI/WuhanDayScreen");
                active._Notification((int)NotificationApplicationFocusIn);
                main.GetNode<DayController>("DayController").Tick(.6); active._Process(0);
                await Capture(city.Replace("city:", "") + "-lesson-" + day, active);
                active._Notification((int)NotificationApplicationFocusIn);
                if (active is TianjinDayScreen tj) tj.FinishDemoLesson(); else ((WuhanDayScreen)active).FinishWuhanDemoLesson();
                Check(!main.GetNode<DayController>("DayController").TutorialActive, city + " skips to actual business " + day);
                main.GetNode<DayController>("DayController").Tick(3.6);
                await Capture(city.Replace("city:", "") + "-business-" + day, active);
                if (active is WuhanDayScreen wuhan && day == 4)
                {
                    Directory.CreateDirectory(path + ".tmp");
                    var wc = main.GetNode<DayController>("DayController"); wc.Tick(1000); wc.Tick(1000);
                    Check(wuhan.BusinessDetails.Model.CanRetry && !wuhan.BusinessDetails.Model.CanClose, "Wuhan failed settlement retains retry and blocks premature return");
                    Directory.Delete(path + ".tmp");
                    wuhan.BusinessDetails.Descendants<Button>().First(b => b.Text == "重试保存").EmitSignal(Button.SignalName.Pressed);
                    Check(!wuhan.BusinessDetails.Model.CanRetry && wuhan.BusinessDetails.Model.CanClose, "Wuhan actual retry button saves same result");
                }
                main.GetNode<DayController>("DayController").AbandonDay();
            }
            main.OpenCity(StableIds.Cities.Wuhan);
            var music = main.GetNode<DemoMusicPlayer>("DemoMusic"); music.SetProcess(false); music._Notification((int)NotificationApplicationFocusIn);
            music.SetContext(StableIds.Cities.Tianjin,false,2); music.SetContext(StableIds.Cities.Wuhan,true,2);
            Check(music.CurrentKey==StableIds.Cities.Wuhan && music.DuckGain==.25f,"music switches cities and ducks");
            music._Notification((int)NotificationApplicationFocusOut); Check(music.FocusPaused && music.GetChildren().OfType<AudioStreamPlayer>().All(p=>!p.Playing || p.StreamPaused),"focus loss pauses both voices");
            music._Notification((int)NotificationApplicationFocusIn); music.SetContext("home",false,2); Check(!music.FocusPaused && music.DuckGain==1,"music resumes without catchup");
            settings.SetVolume("music",0); Check(AudioServer.IsBusMute(AudioServer.GetBusIndex(JourneySettings.MusicBus)),"music volume mutes actual bus");
            GD.Print("DEMO_JOURNEY_SELF_TEST_OK "+_checks+" artifacts="+_dir); GetTree().Quit();
        }
        catch(Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }
}
