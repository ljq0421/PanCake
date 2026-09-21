using System.Text.Json;
using System.Text.RegularExpressions;
using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class EngagementSelfTest : Node
{
    private int _checks;
    private string _dir = "";
    private bool _capture;
    private void Check(bool ok, string message) { if (!ok) throw new InvalidOperationException(message); _checks++; }
    private async Task Frames(int n = 4) { for (int i = 0; i < n; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private static DayResult Win(DayConfig c) => new() { Day = c.Day, PlannedCustomers = c.CustomerCount,
        CompletedCustomers = c.CustomerCount, PerfectOrders = c.CustomerCount, HighestCorrectStreak = c.CustomerCount,
        Satisfaction = 100, SaleRevenue = 100 };
    private DayPlan Generate(DataCatalog c, DayConfig day) => new OrderGenerator().Generate(day, c.RecipesById, c.ProductsById, c.CustomersById);
    public override async void _Ready()
    {
        try
        {
            var args = OS.GetCmdlineUserArgs(); _capture = args.Contains("--capture");
            string locale = args.Contains("--english") ? "en" : "zh_CN";
            GetWindow().Size = args.Contains("--small") ? new(1280,720) : new(1920,1080);
            _dir = ProjectSettings.GlobalizePath("res://.tmp/engagement/" + locale);
            Directory.CreateDirectory(_dir);
            var settings = GetNode<JourneySettings>("/root/JourneySettings");
            settings.UsePathForTests(Path.Combine(_dir, "settings.cfg")); settings.SetLanguage(locale); InterfaceLessons.MarkAllSeen(settings);
            var c = GetNode<DataCatalog>("/root/DataCatalog"); Check(c.IsValid, "catalog valid");
            CheckPlans(c); CheckChallenges(c); CheckMigration(c); CheckEconomy(c);
            await CheckUi(c);
            GD.Print($"ENGAGEMENT_SELF_TEST_OK checks={_checks} locale={locale} demo={ExperienceProfile.IsDemo}");
            GetTree().Quit();
        }
        catch (Exception ex) { GD.PushError(ex.ToString()); GetTree().Quit(1); }
    }
    private void CheckPlans(DataCatalog c)
    {
        c.TryGetDay(StableIds.Cities.Tianjin, 6, out var tianjinDay6);
        c.TryGetDay(StableIds.Cities.Tianjin, 7, out var tianjinDay7);
        Check(tianjinDay6.StartUnlocks.Contains("ingredient:ham")
            && tianjinDay6.AvailableRecipeIds.Contains(StableIds.Recipes.Ham)
            && tianjinDay6.AvailableRecipeIds.Contains(StableIds.Recipes.HamCrispy)
            && tianjinDay7.StartUnlocks.Count == 0, "天津 Day 6 开场开放火腿配方，Day 7 不重复开放");
        foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
        {
            foreach (int day in Enumerable.Range(1, SaveService.ChapterDays(city)).Concat(new[] { 31, 100 }))
            {
                Check(c.TryGetDay(city, day, out var config), "configuration " + city + day);
                var plan = Generate(c, config);
                Check(plan.Customers.Count == config.CustomerCount && config.MaxWaitingCustomers == 5, "customer limits");
                Check(plan.Customers.All(p => p.ArrivalTime <= config.DurationSeconds - config.ArrivalEndBufferSeconds), "arrival cutoff");
                Check(JsonSerializer.Serialize(plan.Customers) == JsonSerializer.Serialize(Generate(c, config).Customers), "deterministic generation");
                Check(plan.Customers.SelectMany(p => p.Order.Lines).All(l => config.AvailableProductKinds.Contains(l.ProductKind)
                    && (l.ProductKind is not (ProductKind.Pancake or ProductKind.HotDryNoodles) || config.AvailableRecipeIds.Contains(l.DefinitionId))), "only available dishes");
                Check(day == 1 ? plan.Challenge is null : plan.Challenge?.Day == day, "challenge uses actual day");
                if (day == 1) continue;
                var challenge = plan.Challenge!;
                int target = challenge.Target;
                DayResult WithProgress(int n) => new() { Day = day, CorrectOrders = challenge.Kind == DailyChallengeKind.Service ? n : 0,
                    PerfectOrders = challenge.Kind == DailyChallengeKind.Perfect ? n : 0, HighestCorrectStreak = challenge.Kind == DailyChallengeKind.Streak ? n : 0 };
                Check(!challenge.Achieved(WithProgress(target-1)) && challenge.Achieved(WithProgress(target)), "threshold boundary");
                Check(challenge.Target <= config.CustomerCount, "attainable challenge count");
                Check(!challenge.Achieved(new() { Day=day, CompletedCustomers=config.CustomerCount, IncorrectOrders=config.CustomerCount }), "incorrect orders do not satisfy challenges");
                if (config.ArrivalSegments[2].CustomerRatio == 0)
                {
                    double horizon = config.DurationSeconds - 25;
                    Check(plan.Customers.All(p => p.ArrivalTime < horizon*.4 || p.ArrivalTime >= horizon*.55), "recovery has no planned arrivals");
                }
            }
        }
        using var controller = new DayController();
        Check(controller.TryPrepareTutorial(StableIds.Cities.Tianjin, 3, c, out _) && controller.CurrentPlan!.Challenge is null, "tutorial cannot earn challenge");
        foreach (int day in new[] {3,4,5})
        {
            c.TryGetDay(day, out var config); var plan = Generate(c, config);
            var first = plan.Customers.Take((int)Math.Ceiling(config.CustomerCount*.5)).SelectMany(p=>p.Order.Lines).ToArray();
            Check(day switch {3=>first.Count(l=>l.ProductKind==ProductKind.Youtiao)>=2,
                4=>first.Count(l=>l.DefinitionId.Contains("youtiao"))>=2,
                _=>first.Count(l=>l.ProductKind==ProductKind.SoyMilk)>=2}, "moved tutorial orders " + day);
        }
    }
    private void CheckChallenges(DataCatalog c)
    {
        string path = Path.Combine(_dir, "challenge-save.json");
        using var save = new SaveService(); save.UsePathForTests(path); Check(save.ResetProgress(out _), "isolated save");
        c.TryGetDay(2, out var config); var plan = Generate(c, config); var result = Win(config);
        var reward = save.CommitDay(result, plan, config);
        Check(reward.PermanentCoinGain==100 && reward.ChallengeCoinGain==20 && save.Data.Coins==120, "bonus separate from sales");
        Check(save.Data.Tianjin.DayBestRecords[2].TotalRevenue==100 && save.Data.Tianjin.BestStars==0, "bonus excluded from records and stars");
        Check(save.CommitDay(result,plan,config).ChallengeCoinGain==0 && save.Data.Coins==120, "same run idempotent");
        save.Load();
        Check(save.CommitDay(result,Generate(c,config),config).ChallengeCoinGain==0 && save.Data.Coins==220, "reload and replay cannot claim twice");
        c.TryGetDay(3, out var third); var retryPlan=Generate(c,third); int coins=save.Data.Coins;
        using (var locked = new FileStream(path+".tmp", FileMode.OpenOrCreate, System.IO.FileAccess.ReadWrite, FileShare.None))
        {
            bool failed=false; try { save.CommitDay(Win(third),retryPlan,third); } catch(IOException) { failed=true; }
            Check(failed && save.Data.Coins==coins && !save.Data.Tianjin.ClaimedChallenges.ContainsKey(3)
                && !save.Data.Tianjin.DayBestRecords.ContainsKey(3), "failed write rolls back reward, claim and day");
        }
        Check(save.CommitDay(Win(third),retryPlan,third).ChallengeCoinGain==20, "retry pays once");
        c.TryGetDay(4,out var fourth);
        save.CommitDay(new(){Day=4},Generate(c,fourth),fourth);
        Check(!save.Data.Tianjin.ClaimedChallenges.ContainsKey(4), "failed challenge does not block progression or claim");
        Check(save.CommitDay(Win(fourth),Generate(c,fourth),fourth).ChallengeCoinGain==20, "replay completes missed challenge");
        foreach(int day in new[]{15,16,17,31,100})
        {
            c.TryGetDay(day,out var endless);
            Check(save.CommitDay(Win(endless),Generate(c,endless),endless).ChallengeCoinGain==40, "endless reward keyed by real day");
        }
        save.Load(); Check(!save.HasLoadError && save.Data.Tianjin.ClaimedChallenges.ContainsKey(100), "endless persistence");
    }
    private void CheckMigration(DataCatalog c)
    {
        string path=Path.Combine(_dir,"legacy-save.json");
        using var save=new SaveService(); save.UsePathForTests(path); save.ResetProgress(out _);
        save.Data.Tianjin.HighestUnlockedDay=8; save.Data.Coins=123;
        save.Data.Tianjin.EquipmentLevels["pancake_stove"]=3;
        save.Data.Tianjin.LearnedWorkbenchActions.Add("test-learned-action");
        save.Data.Tianjin.DayBestRecords[2]=new(){TotalRevenue=57}; save.Data.Tianjin.DayBestRecords[SaveService.WuhanUnlockDay]=new(){TotalRevenue=126}; save.TrySave(out _);
        save.Load(); Check(save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan), "existing Day 7 completion opens Wuhan on load");
        using(var locked=new FileStream(path+".tmp",FileMode.OpenOrCreate,System.IO.FileAccess.ReadWrite,FileShare.None))
            Check(!save.ReconcileEngagementUnlocks(c,out _) && !save.Data.Tianjin.UnlockedContentIds.Contains("product:soy_milk"), "migration rolls back on failure");
        Check(save.ReconcileEngagementUnlocks(c,out _),"migration retry");
        Check(save.Data.PurchasedFryerLevel==1 && save.Data.PurchasedStoveLevel==3 && save.Data.Coins==123, "free equipment restored, paid level and money preserved");
        Check(save.Data.Tianjin.UnlockedContentIds.Contains("product:soy_milk") && save.Data.Tianjin.UnlockedContentIds.Contains("equipment:fryer_lv2"), "moved unlocks restored");
        Check(save.Data.Tianjin.ClaimedChallenges.Count==0 && save.Data.Tianjin.DayBestRecords[2].TotalRevenue==57
            && save.Data.Tianjin.LearnedWorkbenchActions.Contains("test-learned-action"), "no retroactive bonus or lost history");
        string before=JsonSerializer.Serialize(save.Data); Check(save.ReconcileEngagementUnlocks(c,out _) && before==JsonSerializer.Serialize(save.Data),"migration idempotent");
        var obj=System.Text.Json.Nodes.JsonNode.Parse(File.ReadAllText(path))!;
        obj["Cities"]![StableIds.Cities.Tianjin]!.AsObject().Remove("ClaimedChallenges"); File.WriteAllText(path,obj.ToJsonString());
        save.Load(); Check(!save.HasLoadError && save.Data.Tianjin.ClaimedChallenges.Count==0,"old save without field accepted");
    }
    private void CheckEconomy(DataCatalog c)
    {
        var lines=new List<string>{"scenario,city,day,baseSales,challengeBonus,balance,purchases"};
        foreach(bool bonuses in new[]{false,true}) foreach(bool capacityFirst in new[]{false,true})
        {
            using var save=new SaveService(); save.UsePathForTests(Path.Combine(_dir,$"economy-{bonuses}-{capacityFirst}.json")); save.ResetProgress(out _);
            foreach(string city in new[]{StableIds.Cities.Tianjin,StableIds.Cities.Wuhan})
                for(int day=1;day<=SaveService.ChapterDays(city);day++)
                {
                    c.TryGetDay(city,day,out var config); var generated=Generate(c,config); save.ApplyStartUnlocks(config,out _);
                    int revenue=generated.Customers.Sum(p=>p.Order.BasePrice);
                    var plan=bonuses?generated:new DayPlan{Day=day,Customers=generated.Customers};
                    var commit=save.CommitDay(new(){Day=day,SaleRevenue=revenue,CompletedCustomers=config.CustomerCount,
                        PerfectOrders=config.CustomerCount,HighestCorrectStreak=config.CustomerCount,Satisfaction=100},plan,config);
                    var purchases=new List<string>();
                    foreach(var offer in save.BookOffers(city,c)
                        .Where(o=>capacityFirst || city!=StableIds.Cities.Tianjin || save.Data.PurchasedStoveLevel>=2 || o.EquipmentId!="ingredient_station")
                        .OrderBy(o=>o.EquipmentId=="ingredient_station"?capacityFirst?0:2:1).ThenBy(o=>o.Price))
                        if(save.TryPurchase(city,offer.PurchaseId,c,out _)) purchases.Add(offer.PurchaseId);
                    Check(save.Data.Coins>=0,"economy remains nonnegative");
                    lines.Add($"bonus={bonuses}-capacity={capacityFirst},{city},{day},{revenue},{commit.ChallengeCoinGain},{save.Data.Coins},{string.Join(';',purchases)}");
                }
        }
        File.WriteAllLines(Path.Combine(_dir,"economy.csv"),lines);
    }
    private async Task Shot(string name, Node root)
    {
        await Frames(10);
        for(int i=0;i<180 && JourneyTransition.For(this).Active;i++) await Frames(1);
        Check(!JourneyTransition.For(this).Active,"transition finished before screenshot");
        var captions=root.Descendants<Control>().Where(n=>n.IsVisibleInTree()).Select(n=> n switch{Label l=>l.Tr(l.Text).ToString(),Button b=>b.Tr(b.Text).ToString(),_=>""}).Where(s=>s.Length>0).ToArray();
        File.WriteAllLines(Path.Combine(_dir,name+".txt"),captions);
        if(TranslationServer.GetLocale().StartsWith("en"))
            Check(!captions.Any(s=>Regex.IsMatch(s,"[\\u4e00-\\u9fff]")),"translated UI: "+name+" "+string.Join(" | ",captions.Where(s=>Regex.IsMatch(s,"[\\u4e00-\\u9fff]"))));
        if(!_capture)return;
        await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
        using var image=GetViewport().GetTexture().GetImage(); image.SavePng(Path.Combine(_dir,name+".png"));
    }
    private async Task CheckUi(DataCatalog c)
    {
        var save=GetNode<SaveService>("/root/SaveService"); save.UsePathForTests(Path.Combine(_dir,"ui.json")); save.ResetProgress(out _);
        save.Data.UpgradeTeachingCompleted=true; save.Data.Tianjin.HighestUnlockedDay=3;
        save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);save.Data.Wuhan.HighestUnlockedDay=4;save.Data.Coins=1000;save.TrySave(out _);
        var main=GD.Load<PackedScene>("res://Scenes/Main/Main.tscn").Instantiate<GameController>();AddChild(main);await Frames();
        var start=main.GetNode<StartScreen>("UI/StartScreen");
        foreach(string city in new[]{StableIds.Cities.Tianjin,StableIds.Cities.Wuhan})
        {
            int day=city==StableIds.Cities.Tianjin?3:4;
            start.PresentCity(city);await Shot(city[5..]+"-prepare",start);
            Check(main.StartCityBusiness(city,day),"start actual city");
            var controller=main.GetNode<DayController>("DayController");controller.SetProcess(false);
            controller.Tick(3);await Frames();
            var screen=main.GetNode<Control>(city==StableIds.Cities.Tianjin?"UI/TianjinDayScreen":"UI/WuhanDayScreen");screen.SetProcess(false);
            controller.CustomerQueue!.Tick(controller.CurrentConfig!.DurationSeconds-25,.5,true);
            screen.Call("_Process",0d); await Shot(city[5..]+"-business",screen);
            var book=screen is TianjinDayScreen t?t.BusinessDetails:((WuhanDayScreen)screen).BusinessDetails;
            var model=BusinessBookModel.From(city,Win(controller.CurrentConfig!),Array.Empty<BusinessOrderRecord>(),c);
            using(var locked=new FileStream(Path.Combine(_dir,"ui.json.tmp"),FileMode.OpenOrCreate,System.IO.FileAccess.ReadWrite,FileShare.None))
            {
                BusinessBookSettlement.Commit(model,save,controller.CurrentPlan!,controller.CurrentConfig!,c);
                book.Open(model);book.FinishAnimation();
                Check(model.CanRetry && model.Upgrades is null && book.CloseButton.Disabled,"failed save blocks buying and next day");
            }
            BusinessBookSettlement.Commit(model,save,controller.CurrentPlan!,controller.CurrentConfig!,c);controller.AbandonDay();
            book.Open(model);book.FinishAnimation();await Shot(city[5..]+"-settlement",book);
            Check(book.Model.ChallengeReward==20,"real settlement exposes bonus");
            var upgradeEntry=book.Descendants<Button>().Single(b=>b.Name=="OpenBookUpgrades");
            Check(!book.Descendants<Button>().Any(b=>b.Name=="ReturnFromSettlement") && !upgradeEntry.GetGlobalRect().Intersects(book.CloseButton.GetGlobalRect()), "settlement keeps only the upgrade and next-day actions");
            var source=book.Model.Upgrades!;
            string equipment=city==StableIds.Cities.Tianjin?"pancake_stove":"noodle_cooker";
            int before=save.Data.Coins;
            book.Descendants<Button>().Single(b=>b.Name=="OpenBookUpgrades").EmitSignal(Button.SignalName.Pressed);await Frames();
            book.Descendants<Button>().Single(b=>b.Name=="Select_"+equipment).EmitSignal(Button.SignalName.Pressed);await Frames();
            var buy=book.Descendants<Button>().Single(b=>b.Name=="UpgradeEquipment");
            Check(!buy.Disabled,"upgrade can be purchased in actual book");
            buy.EmitSignal(Button.SignalName.Pressed);await Frames();
            Check(source.LastPurchased?.EquipmentId==equipment && save.Data.Coins==before-source.LastPurchased.Price,"actual purchase deducts only its price");
            Check(source.NextGoal.StartsWith("下次营业体验"),"purchased upgrade becomes next goal");
            Check(book.Descendants<EquipmentUpgradeView>().Single().SelectedId==equipment,"selection survives purchase");
            await Shot(city[5..]+"-upgrade",book);
            var compactBuy=book.Descendants<Button>().Single(b=>b.Name=="UpgradeEquipment");
            var next=book.Descendants<Button>().Single(b=>b.Name=="ContinueAfterUpgrade");
            var continueArt=next.GetNode<NinePatchRect>("ContinueButtonArt");
            Check(compactBuy.Size.X==235 && next.Size==compactBuy.Size && Mathf.IsEqualApprox(next.Position.X,compactBuy.Position.X+compactBuy.Size.X)
                && continueArt.Texture is AtlasTexture { Atlas: { ResourcePath: var texturePath } } && texturePath.EndsWith("TianJin/DialogUI/button-secondary-v1.png"),"book upgrade actions share the compact secondary-button row");
            next.EmitSignal(Button.SignalName.Pressed);next.EmitSignal(Button.SignalName.Pressed);await Frames();
            Check(controller.CurrentConfig!.Day==day+1 && controller.CurrentConfig.CityId==city && !book.Visible,"direct next day uses current city and next date");
            controller.AbandonDay();screen.Hide();start.Show();
        }
        foreach(string city in new[]{StableIds.Cities.Tianjin,StableIds.Cities.Wuhan})
        {
            int day=SaveService.ChapterDays(city);save.Data.GetCity(city).HighestUnlockedDay=day;save.TrySave(out _);
            Check(main.StartCityBusiness(city,day),"start chapter milestone");
            var controller=main.GetNode<DayController>("DayController");controller.SetProcess(false);
            var screen=main.GetNode<Control>(city==StableIds.Cities.Tianjin?"UI/TianjinDayScreen":"UI/WuhanDayScreen");screen.SetProcess(false);
            var book=screen is TianjinDayScreen t?t.BusinessDetails:((WuhanDayScreen)screen).BusinessDetails;
            var model=BusinessBookModel.From(city,Win(controller.CurrentConfig!),Array.Empty<BusinessOrderRecord>(),c);
            BusinessBookSettlement.Commit(model,save,controller.CurrentPlan!,controller.CurrentConfig!,c);controller.AbandonDay();
            book.Open(model);book.FinishAnimation();book.CloseButton.EmitSignal(Button.SignalName.Pressed);
            await ToSignal(GetTree().CreateTimer(2.3),SceneTreeTimer.SignalName.Timeout);await Frames();
            Check(start.Page==JourneyPage.Completion && start.Visible,"chapter completion is shown before next day");
            Check(!screen.Visible,"business foreground cannot occlude chapter completion");
            await Shot(city[5..]+"-completion",start);
            start.Descendants<Button>().Single(b=>b.Name=="ContinueCompletedCity").EmitSignal(Button.SignalName.Pressed);await Frames();
            Check(controller.CurrentConfig!.Day==day+1 && !start.Visible,"chapter milestone continues without day cap");
            controller.AbandonDay();screen.Hide();start.Show();
        }
        main.QueueFree();await Frames();
    }
}
