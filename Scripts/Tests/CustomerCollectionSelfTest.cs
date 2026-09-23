using Godot;
using System.Text.Json.Nodes;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;
using ProjectCake.Xian;
using ProjectCake.Guangzhou;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class CustomerCollectionSelfTest : Node
{
    private int _checks;
    private string _dir = "";
    private DataCatalog _catalog = null!;
    private static readonly DeliveryEvaluation Correct = new(DeliveryGrade.Correct, 10, 0, 80, "", true);
    private void Check(bool ok, string message) { if (!ok) throw new Exception(message); _checks++; GD.Print("PASS " + message); }
    private async Task Frames() { for (int i = 0; i < 8; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame); }
    private void Observe(DayPlan plan, string id, string order = "one", string city = StableIds.Cities.Tianjin, DeliveryEvaluation? result = null)
        => CustomerCollection.Observe(plan, plan.RunId, city, order, id, result ?? Correct, false);
    public override async void _Ready()
    {
        try
        {
            bool small = OS.GetCmdlineUserArgs().Contains("--small");
            GetWindow().Size = small ? new(1280, 720) : new(1920, 1080);
            _dir = ProjectSettings.GlobalizePath("res://.tmp/customer-collection/" + (ExperienceProfile.IsDemo ? "demo-" : "full-") + (small ? "1280" : "1920") + "/" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_dir); _catalog = GetNode<DataCatalog>("/root/DataCatalog");
            var settings = GetNode<JourneySettings>("/root/JourneySettings"); settings.UsePathForTests(Path.Combine(_dir, "settings.cfg")); settings.SetLanguage("zh_CN");
            if (!OS.GetCmdlineUserArgs().Contains("--visual-only"))
            {
                TestRules(); TestController(); TestStorage();
                if (!ExperienceProfile.IsDemo) TestYangzhou();
            }
            await TestScreen();
            GD.Print($"CUSTOMER_COLLECTION PASS {_checks}; artifacts: {_dir}"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GetTree().Quit(1); }
    }

    private void TestRules()
    {
        var cards = CustomerCollection.Cards;
        Check(cards.Length == 34 && cards.Select(c => c.Id).Distinct().Count() == 34, "34 unique stable identities");
        Check(cards.Count(c => c.Category == CustomerCollection.Generic) == 6 && cards.Count(c => c.Category == StableIds.Cities.Tianjin) == 18
            && cards.Count(c => c.Category == StableIds.Cities.Wuhan) == 10, "6 / 18 / 10 categories");
        var art = new WuhanArtCatalog();
        foreach (var card in cards)
        {
            var visual = art.CustomerPortrait(card.Id, CustomerExpression.Normal);
            Check(CustomerAppearanceCatalog.IsKnown(card.Id) && visual.Head is not null && visual.Body is not null
                && art.CustomerLayout(card.Id).NormalVisibleBounds.Size.X > 0
                && card.Description.Length > 0 && card.Saying.Length > 0 && card.Anecdote.Length > 0, card.Id + " resources and copy");
        }
        var plan = new DayPlan();
        foreach (var grade in new[] { DeliveryGrade.Incomplete, DeliveryGrade.Incorrect, DeliveryGrade.Rejected })
            Observe(plan, "young_woman", grade.ToString(), result: Correct with { Grade = grade });
        CustomerCollection.Observe(plan, plan.RunId, StableIds.Cities.Tianjin, "lost", "young_woman", null, false);
        CustomerCollection.Observe(plan, plan.RunId, StableIds.Cities.Tianjin, "tutorial", "young_woman", Correct, true);
        CustomerCollection.Observe(plan, "stale", StableIds.Cities.Tianjin, "stale", "young_woman", Correct, false);
        Observe(plan, "unknown"); Observe(plan, "wuhan_grandma");
        Observe(plan, "tianjin_aunt", city: StableIds.Cities.Wuhan);
        Check(plan.PendingCustomerVisits.Count == 0, "partial, wrong, rejected, lost, tutorial, stale, unknown and other-city excluded");
        Observe(plan, "young_woman"); Observe(plan, "young_woman");
        Check(plan.PendingCustomerVisits["young_woman"] == 1, "order callback deduplication");
        var stats = new Dictionary<string, CustomerStatistics>();
        CustomerCollection.Merge(stats, plan, StableIds.Cities.Tianjin, 24);
        Check(stats["young_woman"].Known && !stats["young_woman"].StoryUnlocked && stats["young_woman"].FirstDay == 24, "first visit and actual unlimited business day");
        foreach (string city in new[] { StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou, StableIds.Cities.Yangzhou })
        {
            var next = new DayPlan(); Observe(next, "young_woman", city: city);
            CustomerCollection.Merge(stats, next, city, 2);
            if (stats["young_woman"].Served == 3) Check(stats["young_woman"].StoryUnlocked && !stats["young_woman"].Regular, "three visits reveal anecdote");
        }
        Check(stats["young_woman"].Regular && stats["young_woman"].FirstCity == StableIds.Cities.Tianjin, "five cross-city visits preserve first encounter");
        Check(CustomerCollection.MilestoneMessages(new(), stats).Count() == 3
            && !CustomerCollection.MilestoneMessages(new() { ["young_woman"] = 5 }, stats).Any(), "milestone feedback only on threshold crossings");
        var newlyKnown = CustomerCollection.NewlyKnownIds(new Dictionary<string, int> { ["young_woman"] = 5 },
            new Dictionary<string, CustomerStatistics> { ["young_woman"] = stats["young_woman"], ["male_office"] = new() { Served = 1 } });
        Check(newlyKnown.SequenceEqual(new[] { "male_office" }), "newly known IDs retain only this settlement's first encounters");
    }

    private void TestController()
    {
        var cities = ExperienceProfile.IsDemo ? new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan }
            : new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou };
        foreach (var city in cities)
        {
            var controller = new DayController(); AddChild(controller);
            Check(controller.TryPrepareDay(city, 9, _catalog, out _), city + " prepare");
            _catalog.TryGetDay(city, 9, out var config);
            ProductKind kind = city == StableIds.Cities.Tianjin ? ProductKind.Pancake : city == StableIds.Cities.Wuhan ? ProductKind.HotDryNoodles
                : city == StableIds.Cities.Xian ? ProductKind.Roujiamo : ProductKind.RiceRoll;
            string recipe = config.AvailableRecipeIds.First();
            controller.CustomerQueue!.ResolveBeforeArrival = null;
            foreach (var planned in controller.CurrentPlan!.Customers)
                planned.Order = new() { OrderId = planned.Order.OrderId, CityId = city, CustomerTypeId = planned.CustomerTypeId,
                    BasePrice = 20, PatienceSeconds = 100, Lines = new[] { new OrderLineData(kind, recipe, 2) } };
            controller.TryStartDay(out _); controller.Tick(3.1); controller.CustomerQueue.Tick(1000, .4, true);
            var first = controller.CustomerQueue.Slots[0]; first.AppearanceId = "young_woman";
            DeliveryEvaluation Deliver(string id, bool wrong = false) => kind switch
            {
                ProductKind.Pancake => controller.TryDeliverPreparedPancakeTo(id, new(PancakeQuality.Overdone,
                    new HashSet<string>(_catalog.RecipesById[recipe].ExtraIngredients), SauceAmount: wrong ? .1 : 1), _catalog, () => true),
                ProductKind.HotDryNoodles => controller.TryDeliverWuhanTo(id, new(kind, wrong ? "invalid" : recipe), () => true),
                ProductKind.Roujiamo => controller.TryDeliverXianTo(id, new(kind, wrong ? XianRules.RecipeId(XianRules.Meat(recipe), !XianRules.Juice(recipe)) : recipe,
                    BunQuality: BunQuality.Golden, MeatPortions: XianRules.Meat(recipe), HasJuice: wrong ? !XianRules.Juice(recipe) : XianRules.Juice(recipe)), () => true),
                _ => controller.TryDeliverGuangzhouTo(id, new(kind, wrong ? "invalid" : recipe, GuangzhouQuality: new(true, RiceRollQuality.Perfect)), () => true),
            };
            Deliver(first.Id);
            Check(controller.CurrentPlan.PendingCustomerVisits.Count == 0, city + " partial delivery not collected");
            var result = Deliver(first.Id);
            Check(result.Grade is DeliveryGrade.Correct or DeliveryGrade.Perfect && controller.CurrentPlan.PendingCustomerVisits.GetValueOrDefault("young_woman") == 1,
                city + " real complete-order path collects once regardless of quality");
            var second = controller.CustomerQueue.Slots[1]; second.AppearanceId = "male_office";
            Deliver(second.Id, true); Deliver(second.Id);
            Check(!controller.CurrentPlan.PendingCustomerVisits.ContainsKey("male_office"), city + " earlier mismatch blocks collection");
            controller.CustomerQueue.ForceLoseAll();
            Check(controller.CurrentPlan.PendingCustomerVisits.Count == 1, city + " timeout does not collect");
            controller.AbandonDay(); Check(controller.CurrentPlan is null, city + " abandon discards pending visits"); controller.Free();
        }
    }

    private void TestStorage()
    {
        _catalog.TryGetDay(StableIds.Cities.Tianjin, 1, out var config);
        foreach (bool demo in new[] { false, true })
        {
            string path = Path.Combine(_dir, demo ? "demo.json" : "full.json");
            var save = new SaveService(); if (demo) save.UseDemoPathForTests(path); else save.UsePathForTests(path);
            Check(save.ResetProgress(out _), "isolated save " + demo);
            var plan = new DayPlan(); for (int i = 0; i < 5; i++) Observe(plan, "student", i.ToString());
            var result = new DayResult { Day = 1, CompletedCustomers = 5 };
            var book = new BusinessBookModel { Result = result };
            Directory.CreateDirectory(path + ".tmp"); bool failed = false;
            try { save.CommitDay(result, plan, config); } catch (IOException) { failed = true; }
            Check(failed && save.Data.CustomerRecords.Count == 0, "save failure rolls back customers " + demo);
            BusinessBookSettlement.Commit(book, save, plan, config, _catalog);
            Check(book.CanRetry && book.CustomerMilestones.Length == 0, "failed settlement never announces unsaved unlocks " + demo);
            Directory.Delete(path + ".tmp");
            BusinessBookSettlement.Commit(book, save, plan, config, _catalog);
            Check(book.CustomerMilestones.Length == 3 && book.DailyNote.Contains("熟客印章")
                && book.NewCustomerIds.SequenceEqual(new[] { "student" }), "successful settlement exposes milestones and new customer portraits " + demo);
            save.CommitDay(result, plan, config); save.Load();
            Check(save.Data.CustomerRecords["student"].Served == 5, "retry persists once and duplicate settlement ignored " + demo);
            var replay = new DayPlan(); Observe(replay, "student"); save.CommitDay(result, replay, config);
            Check(save.Data.CustomerRecords["student"].Served == 6, "replay counts a new run " + demo);
            var old = JsonNode.Parse(File.ReadAllText(path))!; old.AsObject().Remove("CustomerRecords");
            File.WriteAllText(path, old.ToJsonString()); save.Load();
            Check(!save.HasLoadError && save.Data.CustomerRecords.Count == 0, "legacy save starts empty " + demo); save.Free();
        }
        var slots = new SaveService(); slots.UseSlotsForTests(Path.Combine(_dir, "slots"));
        Check(slots.TryCreateSlot(1, out _), "create slot one"); var owned = new DayPlan(); slots.BindRun(owned); Observe(owned, "student");
        slots.CommitDay(new DayResult { Day = 1 }, owned, config);
        Check(slots.TryCreateSlot(2, out _) && slots.Data.CustomerRecords.Count == 0, "new slot has empty collection");
        bool blocked = false; try { slots.CommitDay(new DayResult { Day = 1 }, owned, config); } catch (IOException) { blocked = true; }
        Check(blocked && slots.TryLoadSlot(1, out _) && slots.Data.CustomerRecords["student"].Served == 1, "stale run cannot leak across slots"); slots.Free();
    }

    private void TestYangzhou()
    {
        var session = YangzhouSelfTest.Play(YangzhouCatalog.Load(), 2, 3, 3, false);
        var save = new SaveService(); string path = Path.Combine(_dir, "yangzhou.json"); save.UsePathForTests(path);
        int expected = session.BusinessRecords.Count(o => !o.Lost && !o.Unreceived && o.Mistakes == 0
            && CustomerCollection.Find(CustomerCollection.YangzhouAppearance(o.CustomerType))?.Category == CustomerCollection.Generic);
        Check(expected > 0 && session.Phase == YangzhouPhase.Results, "Yangzhou real production session");
        Directory.CreateDirectory(path + ".tmp"); bool failed = false;
        try { save.CommitYangzhou(session); } catch (IOException) { failed = true; }
        Check(failed && save.Data.CustomerRecords.Count == 0, "Yangzhou rollback"); Directory.Delete(path + ".tmp");
        save.CommitYangzhou(session); save.CommitYangzhou(session); save.Load();
        Check(save.Data.CustomerRecords.Values.Sum(s => s.Served) == expected, "Yangzhou whole trays count once after retry"); save.Free();
    }

    private async Task TestScreen()
    {
        var save = GetNode<SaveService>("/root/SaveService");
        string path = Path.Combine(_dir, "ui.json"); if (ExperienceProfile.IsDemo) save.UseDemoPathForTests(path); else save.UsePathForTests(path);
        var screen = GD.Load<PackedScene>("res://Scenes/UI/StartScreen.tscn").Instantiate<StartScreen>(); AddChild(screen); screen.Initialize(save);
        screen.PresentCustomerCollection(); await Frames();
        Check(screen.Page == JourneyPage.Collection && screen.Descendants<Button>().Any(b => b.Name.ToString().StartsWith("CustomerCard_")),
            "direct customer collection entry opens the catalog");
        screen.PresentBreakfastCollection(); await Frames();
        async Task Click(string name) { screen.Descendants<Button>().Single(b => b.Name == name).EmitSignal(Button.SignalName.Pressed); await Frames(); }
        async Task Capture(string name)
        {
            if (!OS.GetCmdlineUserArgs().Contains("--capture")) return;
            if (OS.GetCmdlineUserArgs().Contains("--detail-icons-only")
                && name is not ("empty-locked" or "wuhan-long-copy" or "first-visit")) return;
            if (OS.GetCmdlineUserArgs().Contains("--settlement-only") && !name.EndsWith("-settlement")) return;
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            using var image = GetViewport().GetTexture().GetImage(); image.SavePng(Path.Combine(_dir, name + ".png"));
        }
        await Click("CustomerSection");
        Check(screen.Descendants<Button>().Count(b => b.Name.ToString().StartsWith("CustomerCard_")) == 8, "eight cards per page");
        Check(CustomerCollection.Cards.All(c => ResourceLoader.Exists(CustomerCollection.FullBodyArtPath(c))), "every collection customer has a full-body portrait");
        Check(screen.Descendants<TextureRect>().Single(t => t.Name == "CustomerSilhouette").Texture?.ResourcePath
            == CustomerCollection.FullBodyArtPath(CustomerCollection.Cards[0]), "locked detail uses one full-body silhouette");
        Check(screen.Descendants<Button>().Single(b => b.Name == "CustomerCategory3").Disabled
            && !screen.Descendants<Label>().Any(l => l.Name.ToString() is "CollectedCaption" or "CollectedCount"),
            "locked Wuhan and collection counter hidden");
        await Capture("empty-locked"); await Click("CustomerCategory1");
        Check(screen.Descendants<Button>().Count(b => b.Name.ToString().StartsWith("CustomerCard_")) == 6, "generic section has six people");
        await Capture("generic-empty");
        Check(!File.Exists(path), "browsing without a save creates nothing");
        save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
        foreach (var c in CustomerCollection.Cards) save.Data.CustomerRecords[c.Id] = new() { Served = 5, FirstDay = 24,
            FirstCity = c.Category == CustomerCollection.Generic ? StableIds.Cities.Xian : c.Category };
        Check(save.TrySave(out _), "save fully collected fixture"); string saved = File.ReadAllText(path);
        screen.PresentBreakfastCollection(); await Frames(); await Capture("generic-earned");
        await Click("CustomerCategory0");
        for (int i = 1; i <= 5; i++)
        {
            Check(screen.Descendants<Label>().Single(l => l.Name == "CustomerPage").Text == $"{i} / 5", "all page " + i);
            await Capture("all-page-" + i); if (i < 5) await Click("CustomerNext");
        }
        await Click("CustomerCategory3");
        Check(screen.Descendants<Label>().Single(l => l.Name == "CustomerPage").Text == "1 / 2", "category resets pagination");
        await Click("CustomerCard_wuhan_opera_actress"); await Capture("wuhan-long-copy");
        await Click("CustomerCategory2"); await Click("CustomerCard_xiangsheng_performer"); await Capture("tianjin-earned");
        save.Data.CustomerRecords["xiangsheng_performer"].Served = 1; screen.PresentBreakfastCollection(); await Frames(); await Capture("first-visit");
        Check(screen.Descendants<Label>().Single(l => l.Name == "CustomerStory").Text.Contains("再正确接待 2 次"), "anecdote locked below threshold");
        save.Data.CustomerRecords["xiangsheng_performer"].Served = 3; screen.PresentBreakfastCollection(); await Frames(); await Capture("story-unlocked");
        await Click("BreakfastSection"); Check(screen.Descendants<Control>().Any(c => c.Name == "CollectionDetail"), "breakfast section preserved");
        await Click("CustomerSection"); await Click("Back");
        Check(screen.Page == JourneyPage.Home, "back returns home"); screen.PresentBreakfastCollection(); await Frames();
        Check(!screen.Descendants<Control>().Any(c => c.Name == "CustomerDetail") && File.ReadAllText(path) == saved, "reopen defaults to breakfast and browsing never saves");
        await Click("CustomerSection");
        screen._Input(new InputEventKey { Keycode = Key.Escape, Pressed = true }); await Frames();
        Check(screen.Page == JourneyPage.Home && GetViewport().GuiGetFocusOwner()?.Name == "BreakfastRecords", "Escape returns home and restores collection focus");
        bool restoredWorkbench = false;
        screen.PresentCustomerCollectionOverWorkbench(() => restoredWorkbench = true); await Frames();
        Check(screen.Page == JourneyPage.Collection && !screen.GetNode<Control>("Canvas/Background").Visible,
            "workbench customer collection hides only start screen background");
        screen.Descendants<Button>().First(b => b.Name == "Back" && b.IsVisibleInTree()).EmitSignal(Button.SignalName.Pressed); await Frames();
        Check(restoredWorkbench && !screen.Visible, "workbench customer collection returns to its source");
        screen.QueueFree(); await Frames();
        if (OS.GetCmdlineUserArgs().Contains("--visual-only")) return;
        InterfaceLessons.MarkAllSeen(GetNode<JourneySettings>("/root/JourneySettings"));
        foreach (var city in new[] { "tianjin", "wuhan", "xian", "guangzhou", "yangzhou" })
        {
            var book = new BusinessDetailsView(); AddChild(book);
            var model = new BusinessBookModel { CityId = city, Closing = true,
                Result = new DayResult { Day = 9, PlannedCustomers = 20, CompletedCustomers = 20, SaleRevenue = 230, Tips = 20, Satisfaction = 94 },
                SaveMessage = "已入账 ¥250", CustomerMilestones = new[] { "认识了新朋友 · 12 位", "解锁人物趣闻 · 10 位", "获得熟客印章 · 10 位" },
                NewCustomerIds = CustomerCollection.Cards.Take(6).Select(c => c.Id).ToArray() };
            bool collectionRequested = false; book.CustomerCollectionRequested += () => collectionRequested = true;
            book.Open(model); book.FinishAnimation();
            // The paper-spread shader has its own entrance, independent of the count-up tween.
            await ToSignal(GetTree().CreateTimer(.8), SceneTreeTimer.SignalName.Timeout); await Frames();
            Check(book.Descendants<Label>().Any(l => l.IsVisibleInTree() && l.Text == model.DailyNote), city + " visible settlement milestones");
            int portraitCount = book.Descendants<TextureRect>().Count(p => p.Name.ToString().StartsWith("NewCustomerPortrait_"));
            bool hasOverflow = book.Descendants<Label>().Any(l => l.Text == "等 6 位");
            int resolvable = book.Model.NewCustomerIds.Count(id => CustomerCollection.Find(id) is not null);
            Check(portraitCount == 5 && hasOverflow, city + $" settlement shows five new-customer portraits and overflow (new={book.Model.NewCustomerIds.Length}, resolvable={resolvable}, portraits={portraitCount}, overflow={hasOverflow})");
            Vector2 portraitSize = (city is "tianjin" or "wuhan" or "xian" ? new Vector2(45, 48) : new Vector2(51, 54)) * 1.5f;
            var portraits = book.Descendants<TextureRect>().Where(p => p.Name.ToString().StartsWith("NewCustomerPortrait_")).ToArray();
            var collectionButton = book.Descendants<Button>().Single(b => b.Name == "OpenCustomerCollection");
            Check(portraits.All(p => Mathf.IsEqualApprox(p.Size.X, portraitSize.X) && Mathf.IsEqualApprox(p.Size.Y, portraitSize.Y))
                && portraits.All(p => !p.GetGlobalRect().Intersects(collectionButton.GetGlobalRect())),
                city + " settlement uses 1.5x new-customer portraits without covering the collection action");
            collectionButton.EmitSignal(Button.SignalName.Pressed); await Frames();
            Check(collectionRequested, city + " settlement customer collection button requests direct navigation");
            await Capture(city + "-settlement"); book.QueueFree(); await Frames();
        }
    }
}
