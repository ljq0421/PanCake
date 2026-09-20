using Godot;
using ProjectCake.Core;
using ProjectCake.Customers;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Guangzhou;
using ProjectCake.Orders;
using ProjectCake.Pancake;
using ProjectCake.UI;
using ProjectCake.Wuhan;
using ProjectCake.Xian;
using ProjectCake.Yangzhou;

namespace ProjectCake.Tests;

public partial class BusinessFeedbackSelfTest : Node
{
    private int _passed;
    private DataCatalog _catalog = null!;
    private void Check(bool value, string message)
    {
        if (!value) throw new InvalidOperationException(message);
        _passed++; GD.Print("PASS " + message);
    }
    public override async void _Ready()
    {
        try
        {
            _catalog = GetNode<DataCatalog>("/root/DataCatalog");
            foreach (string city in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou }) TestCity(city);
            TestBatch(); TestYangzhou(); TestAudio(); TestCoins(); await TestScreens();
            GD.Print($"BUSINESS_FEEDBACK_TEST_RESULT passed={_passed} failed=0"); GetTree().Quit();
        }
        catch (Exception e) { GD.PushError(e.ToString()); GD.Print($"BUSINESS_FEEDBACK_TEST_RESULT passed={_passed} failed=1"); GetTree().Quit(1); }
    }
    private DayController Prepare(string city, params OrderLineData[] lines)
    {
        var c = new DayController(); AddChild(c);
        Check(c.TryPrepareDay(city, 9, _catalog, out _), city + " prepare");
        c.CustomerQueue!.ResolveBeforeArrival = null;
        foreach (var planned in c.CurrentPlan!.Customers)
            planned.Order = new() { OrderId = planned.Order.OrderId, CityId = city, CustomerTypeId = planned.CustomerTypeId,
                BasePrice = 20, PatienceSeconds = 100, Lines = lines };
        c.TryStartDay(out _); c.Tick(3.1);
        c.CustomerQueue.Tick(1000, .4, true);
        return c;
    }
    private void TestCity(string city)
    {
        ProductKind kind = city == StableIds.Cities.Tianjin ? ProductKind.Pancake : city == StableIds.Cities.Wuhan ? ProductKind.HotDryNoodles
            : city == StableIds.Cities.Xian ? ProductKind.Roujiamo : ProductKind.RiceRoll;
        _catalog.TryGetDay(city, 9, out var config);
        string recipe = config.AvailableRecipeIds[0];
        var c = Prepare(city, new OrderLineData(kind, recipe, 2));
        var events = new List<BusinessFeedbackEvent>(); c.Feedback.Requested += events.Add;
        var customer = c.CustomerQueue!.Slots[0];
        DeliveryEvaluation Deliver(string? id, bool wrong = false) => kind switch
        {
            ProductKind.Pancake => c.TryDeliverPreparedPancakeTo(id,
                new(PancakeQuality.Perfect, new HashSet<string>(_catalog.RecipesById[recipe].ExtraIngredients), SauceAmount: wrong ? .1 : 1), _catalog, () => true),
            ProductKind.HotDryNoodles => c.TryDeliverWuhanTo(id, new(kind, wrong ? "invalid" : recipe), () => true),
            ProductKind.Roujiamo => c.TryDeliverXianTo(id, new(kind, wrong ? XianRules.RecipeId(XianRules.Meat(recipe), !XianRules.Juice(recipe)) : recipe,
                BunQuality: BunQuality.Golden, MeatPortions: XianRules.Meat(recipe), HasJuice: wrong ? !XianRules.Juice(recipe) : XianRules.Juice(recipe)), () => true),
            _ => c.TryDeliverGuangzhouTo(id, new(kind, wrong ? "invalid" : recipe, GuangzhouQuality: new(true, RiceRollQuality.Perfect)), () => true),
        };
        Deliver(customer.Id);
        Check(events.Select(e => e.Cue).SequenceEqual(new[] { BusinessCue.ItemAccepted }), city + " partial delivery only one positive cue");
        events.Clear(); Deliver(customer.Id);
        Check(events.Count(e => e.Cue == BusinessCue.OrderCompleted) == 1 && events.All(e => e.Cue != BusinessCue.ItemAccepted), city + " final item only completion");
        bool automatic = city is StableIds.Cities.Tianjin or StableIds.Cities.Wuhan or StableIds.Cities.Guangzhou;
        Check(events.Count(e => e.Cue == BusinessCue.CoinCredited) == (automatic ? 1 : 0), city + " correct cash policy");
        Check(!automatic || events.Single(e => e.Cue == BusinessCue.CoinCredited).Amount == c.Ledger!.Build().TotalRevenue, city + " amount matches committed ledger");
        events.Clear(); Deliver(customer.Id);
        Check(events.Count == 1 && events[0].Cue == BusinessCue.DeliveryError, city + " duplicate delivery fails once");
        events.Clear(); Deliver(null);
        Check(events.Count == 1 && events[0].Cue == BusinessCue.DeliveryError, city + " missing customer fails once");
        events.Clear(); c.IsPaused = true; Deliver(c.CustomerQueue.Slots[1].Id); c.IsPaused = false;
        Check(events.Count == 0, city + " paused action is silent");
        var wrongCustomer = c.CustomerQueue.Slots[1];
        Deliver(wrongCustomer.Id, true);
        Check(events.Count == 1 && events[0].Cue == BusinessCue.DeliveryError, city + " accepted mismatch is not a positive partial cue");
        events.Clear(); Deliver(wrongCustomer.Id);
        Check(events.Count(e => e.Cue == BusinessCue.DeliveryError) == 1 && events.All(e => e.Cue != BusinessCue.OrderCompleted), city + " incorrect final grade stays negative");
        events.Clear(); var waiting = c.CustomerQueue.Slots[2];
        waiting.WaitSeconds = waiting.Type.ImpatientUntilSeconds * waiting.PatienceMultiplier;
        c.CustomerQueue.Tick(1000, .001, false);
        Check(events.Count(e => e.Cue == BusinessCue.LowPatience && e.CustomerId == waiting.Id) == 1, city + " first angry transition warns");
        waiting.RestorePatience(.15);
        waiting.WaitSeconds = waiting.Type.ImpatientUntilSeconds * waiting.PatienceMultiplier;
        c.CustomerQueue.Tick(1000, .001, false);
        Check(events.Count(e => e.Cue == BusinessCue.LowPatience && e.CustomerId == waiting.Id) == 1, city + " recovery cannot repeat warning");
        events.Clear(); waiting.WaitSeconds = waiting.LeaveAtSeconds; c.CustomerQueue.Tick(1000, .001, false);
        c.CustomerQueue.Tick(1000, .001, false);
        Check(events.Count(e => e.Cue == BusinessCue.CustomerLeft && e.CustomerId == waiting.Id) == 1, city + " natural timeout once");
        events.Clear(); c.CustomerQueue.ForceLoseAll();
        Check(events.Count == 0, city + " closing cleanup silent");
        var oldQueue = c.CustomerQueue;
        c.TryPrepareDay(city, 9, _catalog, out _);
        events.Clear(); oldQueue.Tick(1000, 1000, true);
        Check(events.Count == 0, city + " previous queue detached on restart");
        c.Feedback.Warn("repeat"); c.AbandonDay();
        c.Free();
    }
    private void TestBatch()
    {
        var c = Prepare(StableIds.Cities.Wuhan, new OrderLineData(ProductKind.Doupi, StableIds.Products.Doupi, 2));
        var events = new List<BusinessFeedbackEvent>(); c.Feedback.Requested += events.Add;
        var stock = new DoupiInventory(); stock.TryAddBatch(8);
        var result = c.TryDeliverWuhanDoupiTo(c.CustomerQueue!.Slots[0].Id, stock);
        Check(result.CompletesOrder && stock.Count == 6, "batch consumes exactly two pieces");
        Check(events.Count == 2 && events.Count(e => e.Cue == BusinessCue.OrderCompleted) == 1 && events.Count(e => e.Cue == BusinessCue.CoinCredited) == 1, "batch emits one completion and one credit");
        events.Clear(); c.TryDeliverWuhanDoupiTo(c.CustomerQueue.Slots[1].Id, new());
        Check(events.Count == 1 && events[0].Cue == BusinessCue.DeliveryError, "empty doupi inventory has failure feedback"); c.Free();
    }
    private void TestYangzhou()
    {
        var catalog = YangzhouCatalog.Load();
        var s = new YangzhouSession(catalog, 1, 1, 1);
        var events = new List<BusinessFeedbackEvent>(); s.Feedback.Requested += events.Add;
        s.Tick(5); while (s.Selected is null) s.Tick(.25);
        Check(events.Count == 0, "Yangzhou arrival silent");
        s.Serve(); Check(events.Count == 1 && events[0].Cue == BusinessCue.DeliveryError, "Yangzhou incomplete tray errors without success"); events.Clear();
        s.Tick(150); Check(events.Count == 0, "Yangzhou tutorial never warns or times out");
        s.Cut(); for (int i = 0; i < 40 && s.Kitchen.Board.Cutting; i++) s.Stroke(i % 2 == 0 ? 70 : -70, .1);
        s.LoadGansi(); for (int i = 0; i < 3; i++) { s.Dip(); s.Tick(.31); s.Lift(); }
        s.Season(); s.Tick(.31);
        Check(s.Stage("G01") && events.Count == 0, "Yangzhou staging does not produce customer feedback");
        Check(s.Serve() && events.Count == 2 && events[0].Cue == BusinessCue.OrderCompleted
            && events[1].Cue == BusinessCue.CoinCredited && events[1].Amount == s.Revenue, "Yangzhou whole tray completion and actual revenue credit once");
        var normal = new YangzhouSession(catalog, 12, 3, 3); events.Clear(); normal.Feedback.Requested += events.Add;
        normal.Tick(5); while (normal.Selected is null) normal.Tick(.25);
        var first = normal.Selected; normal.Tick(first.Patience * .85);
        Check(events.Count(e => e.Cue == BusinessCue.LowPatience && e.CustomerId == first.Plan.Id.ToString()) == 1, "Yangzhou angry threshold once");
        normal.Tick(first.Patience * .2);
        Check(events.Count(e => e.Cue == BusinessCue.CustomerLeft && e.CustomerId == first.Plan.Id.ToString()) == 1, "Yangzhou timeout once");
    }
    private void TestAudio()
    {
        bool active = true; ulong clock = 1000;
        var owner = new Node(); AddChild(owner); var source = new BusinessFeedback();
        var audio = BusinessFeedbackAudio.Attach(owner, source, () => active); audio.Clock = () => clock;
        var played = new List<BusinessFeedbackEvent>(); audio.Played += played.Add;
        source.Reject(); source.Reject(); clock += 399; source.Reject();
        Check(played.Count == 1, "error throttled for 400ms"); clock++; source.Reject(); Check(played.Count == 2, "error allowed at 400ms");
        played.Clear(); source.Warn("a"); source.Warn("b"); clock += 500; source.Warn("c"); source.Warn("a");
        Check(played.Count == 2, "warnings throttled globally and deduplicated by customer");
        played.Clear(); source.TimedOut("a"); source.TimedOut("b"); clock += 500; source.TimedOut("c");
        Check(played.Count == 2, "timeout chorus throttled for 500ms");
        played.Clear(); source.Delivery("final", new(DeliveryGrade.Perfect, 20, 2, 100, "")); source.Credit(22);
        Check(played.Count == 2 && audio.GetChildren().OfType<AudioStreamPlayer>().Select(p => p.Stream).Distinct().Count() >= 2, "completion and cash use independent streams");
        Check(audio.GetChildren().OfType<AudioStreamPlayer>().All(p => p.Bus == JourneySettings.EffectsBus)
            && AudioServer.GetBusSend(AudioServer.GetBusIndex(JourneySettings.EffectsBus)) == "Master", "all business voices follow effects and master volumes");
        active = false; audio._Process(0); source.Credit(22); active = true; audio._Process(0);
        Check(played.Count == 2 && audio.GetChildren().OfType<AudioStreamPlayer>().All(p => !p.Playing), "pause stops voices without replay on resume");
        source.Reset(); played.Clear(); source.Warn("a"); Check(played.Count == 1, "new business resets warning identities");
        var replacement = new BusinessFeedback(); BusinessFeedbackAudio.Attach(owner, replacement, () => active);
        played.Clear(); source.Credit(1); replacement.Credit(1); Check(played.Count == 1, "rebinding detaches old source");
        audio.Free(); replacement.Credit(1); Check(played.Count == 1, "exit detaches source"); owner.Free();
        foreach (BusinessCue cue in Enum.GetValues<BusinessCue>())
        {
            var wave = BusinessFeedbackAudio.Make(cue);
            Check(wave.Data.Any(b => b != 0) && wave.GetLength() is > .15 and < .5, cue + " nonempty short PCM"); wave.Dispose();
        }
    }
    private void TestCoins()
    {
        foreach (bool reduced in new[] { false, true })
        {
            ProjectSettings.SetSetting("accessibility/reduce_motion", reduced);
            var root = new Control(); AddChild(root);
            var tray = SceneFactory.Instantiate<CoinTrayView>("res://Scenes/UI/CoinTrayView.tscn"); root.AddChild(tray);
            var target = new Control { Size = new(50, 50) }; root.AddChild(target);
            var feedback = SceneFactory.Instantiate<CoinCollectionFeedback>("res://Scenes/UI/CoinCollectionFeedback.tscn"); root.AddChild(feedback);
            bool active = true; var art = new TianjinArtCatalog();
            feedback.Bind(tray, root, target, art.Coin, () => active);
            var events = new List<BusinessFeedbackEvent>(); feedback.AudioFeedback.Requested += events.Add;
            tray.RenderRevenue(25); feedback.PaymentFrom(Vector2.Zero); feedback.PaymentFrom(Vector2.Zero);
            Check(events.Count == 0, "payment flights silent reduced=" + reduced);
            Check(tray.TryCollect() && events.Count == 1 && events[0].Amount == 25, "merged collection one cue reduced=" + reduced);
            Check(!tray.TryCollect() && events.Count == 1, "empty collection silent");
            tray.RenderRevenue(40); active = false; Check(!tray.TryCollect() && events.Count == 1, "paused collection silent");
            active = true; feedback.Bind(tray, root, target, art.Coin, () => active); tray.TryCollect();
            Check(events.Count == 2 && events[1].Amount == 15, "rebind does not double subscribe"); root.Free();
        }
        ProjectSettings.SetSetting("accessibility/reduce_motion", false);
    }

    private async Task Frames()
    {
        for (int i = 0; i < 3; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
    private async Task TestScreens()
    {
        // This test owns pause/resume; first-run HUD teaching must not add another pause reason.
        var settings = GetNode<JourneySettings>("/root/JourneySettings");
        settings.UsePathForTests($"res://.tmp/business-audio-tests/settings-{Guid.NewGuid():N}.cfg");
        InterfaceLessons.MarkAllSeen(settings);
        var save = new SaveService(); save.UsePathForTests($"res://.tmp/business-audio-tests/screen-{Guid.NewGuid():N}.json"); AddChild(save);
        foreach (var id in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan, StableIds.Cities.Xian, StableIds.Cities.Guangzhou, YangzhouCatalog.CityId })
            save.Data.GetCity(id).HighestUnlockedDay = 15;
        foreach (string city in new[] { "Tianjin", "Wuhan", "Xian", "Guangzhou", "Yangzhou" })
        {
            var controller = new DayController(); AddChild(controller);
            var screen = SceneFactory.Instantiate<Control>($"res://Scenes/Gameplay/{city}DayScreen.tscn"); AddChild(screen); screen.SetProcess(false);
            BusinessDetailsView book; Button entry;
            switch (screen)
            {
                case TianjinDayScreen s:
                    s.ConnectController(controller); s.Initialize(_catalog, save, controller, 2); s.BeginDay(); controller.Tick(3.1); s.RefreshForCapture(true);
                    book = s.BusinessDetails; entry = s.CashPendant; break;
                case WuhanDayScreen s:
                    s.ConnectController(controller); s.Initialize(_catalog, save, controller, 2); s.BeginDay(); controller.Tick(3.1); s.RefreshForCapture();
                    book = s.BusinessDetails; entry = s.CashPendant; break;
                case XianDayScreen s:
                    Check(s.Initialize(_catalog, save, controller, 2), "Xian screen initializes"); s.BeginDay(); controller.Tick(3.1); s.Render();
                    book = s.BusinessDetails; entry = (Button)s.FindChild("OpenBusinessBook", true, false); break;
                case GuangzhouDayScreen s:
                    Check(s.Initialize(_catalog, save, controller, 2), "Guangzhou screen initializes"); s.BeginDay(); controller.Tick(3.1); s._Process(0);
                    book = s.BusinessDetails; entry = (Button)s.FindChild("OpenBusinessBook", true, false); break;
                case YangzhouDayScreen s:
                    Check(s.Initialize(YangzhouCatalog.Load(), save, 2), "Yangzhou screen initializes"); s.Session.Tick(5.1); s._Process(0);
                    book = s.BusinessDetails; entry = (Button)s.FindChild("OpenBusinessBook", true, false); break;
                default: throw new InvalidOperationException();
            }
            screen._Notification((int)NotificationApplicationFocusIn);
            var source = screen is YangzhouDayScreen yz ? yz.Session.Feedback : controller.Feedback;
            var audio = screen.GetNode<BusinessFeedbackAudio>("BusinessFeedbackAudio");
            var played = new List<BusinessFeedbackEvent>(); audio.Played += played.Add;
            if (screen is XianDayScreen or GuangzhouDayScreen)
            {
                controller.CustomerQueue!.Tick(1000, .4, true);
                if (screen is XianDayScreen xs) xs.Render(); else ((GuangzhouDayScreen)screen)._Process(0);
                await Frames();
                Control target = screen is XianDayScreen
                    ? screen.Descendants<XianSurface>().First(s => s.Kind == "customer")
                    : screen.Descendants<GuangzhouCustomerCard>().First();
                Vector2 point = target.GetGlobalRect().GetCenter();
                screen.ForceDrag("wrong-product", new Label { Text = "test food" });
                GetViewport().PushInput(new InputEventMouseMotion { Position = point, GlobalPosition = point }, true); await Frames();
                Check(played.Count == 0, city + " hovering rejected target is silent");
                GetViewport().PushInput(new InputEventMouseButton { Position = point, GlobalPosition = point, ButtonIndex = MouseButton.Left, Pressed = false }, true); await Frames();
                Check(played.Count == 1 && played[0].Cue == BusinessCue.DeliveryError, city + " real native rejected drop plays once");
                played.Clear();
            }
            source.Delivery("fixture", new(DeliveryGrade.Perfect, 20, 2, 100, "")); source.Credit(22);
            Check(played.Count == 2, city + " actual screen binding allows concurrent customer and cash audio");
            played.Clear(); source.Credit(0); source.Credit(-1); Check(played.Count == 0, city + " zero or negative credit silent");
            entry.EmitSignal(Button.SignalName.Pressed); await Frames();
            Check(book.Visible, city + " live book opens");
            source.Reject(); source.Credit(22); source.Warn("paused");
            Check(played.Count == 0 && audio.GetChildren().OfType<AudioStreamPlayer>().All(p => !p.Playing), city + " book pauses business voices without extra credit");
            book.CloseButton.EmitSignal(Button.SignalName.Pressed); await Frames();
            Check(!book.Visible && played.Count == 0, city + " closing book does not replay missed events");
            source.Credit(22); Check(played.Count == 1, city + " resumed business plays new events");
            screen._Notification((int)NotificationApplicationFocusOut); audio._Notification((int)NotificationApplicationFocusOut); await Frames();
            source.Credit(22); Check(played.Count == 1 && audio.GetChildren().OfType<AudioStreamPlayer>().All(p => !p.Playing), city + " focus loss stops and suppresses audio");
            screen.Hide(); source.Credit(22); Check(played.Count == 1, city + " hidden city silent");
            screen.QueueFree(); await Frames(); source.Credit(22); Check(played.Count == 1, city + " destroyed city unsubscribed");
            controller.QueueFree(); await Frames();
        }
        save.QueueFree(); await Frames();
    }
}
