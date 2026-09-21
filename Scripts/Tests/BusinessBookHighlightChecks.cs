using Godot;
using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class BusinessBookSelfTest
{
    private void CheckHighlightModel()
    {
        Check(new BusinessBookModel().Highlights.Count == 0, "empty shift has no achievements");
        Check(new BusinessBookModel { Result = new() { LostCustomers = 4 } }.Highlights.Count == 0, "all lost has no achievements");
        var full = new BusinessBookModel
        {
            Closing = true,
            Result = new() { CompletedCustomers = 4, PerfectOrders = 4, Tips = 4, HighestCorrectStreak = 4 }
        };
        Check(full.Highlights.Select(h => h.Kind).SequenceEqual(new[] { BookHighlightKind.Perfect, BookHighlightKind.NoLoss, BookHighlightKind.Tips }), "three highlights use approved priority");
        Check(full.Highlights.Select(h => h.Caption).SequenceEqual(new[] { "完美出餐 ×4", "零流失", "小费 ¥4" }), "highlight amounts are actual results");
        full.Closing = false;
        Check(full.Highlights.Single(h => h.Kind == BookHighlightKind.NoLoss).Caption == "暂未流失", "live no-loss is provisional");
        var streak = new BusinessBookModel { Result = new() { CompletedCustomers = 3, LostCustomers = 1, HighestCorrectStreak = 3 } };
        Check(streak.Highlights.Count == 1 && streak.Highlights[0].Caption == "连续正确 ×3", "streak fills missing perfect and tip achievements");
        Check(new BusinessBookModel { Result = new() { HighestCorrectStreak = 1 } }.Highlights.Count == 0, "one correct order is not a streak achievement");
        Check(new BusinessBookModel { Result = new() { CompletedCustomers = 1, LostCustomers = 1 } }.Highlights.Count == 0, "no invented achievements for an ordinary mixed shift");
    }

    private void CheckTravelHighlightLayout(BusinessDetailsView view)
    {
        var book = view.Descendants<Control>().Single(c => c.Name == "SettlementBook");
        var reception = view.Descendants<Label>().Single(l => l.Text == "今日接待");
        var evaluation = view.Descendants<Label>().Single(l => l.Name == "BookSatisfaction");
        var income = view.Descendants<Label>().Single(l => l.Text == "今日收入");
        var challenge = view.Descendants<Label>().Single(l => l.Name == "ChallengeSettlement");
        var note = view.Descendants<Control>().Single(c => c.Name == "DailyNote");
        var title = view.Descendants<Label>().Single(l => l.Text == "营业小结");
        var upgrade = view.Descendants<Button>().Single(b => b.Name == "OpenBookUpgrades");
        Check(new Control[] { reception, evaluation, note }.All(c => InLocalSpace(book, c).End.X < book.Size.X / 2),
            "reception, satisfaction and daily note read on the left page");
        Check(new Control[] { income, challenge, upgrade, view.CloseButton }.All(c => InLocalSpace(book, c).Position.X > book.Size.X / 2),
            "income, challenge and next-step actions read on the right page");
        Check(!title.GetGlobalRect().Intersects(reception.GetGlobalRect()), "left-page reception clears the book title");
        Check(!view.Descendants<Control>().Any(c => c.Name == "BookHighlights")
            && !view.Descendants<Label>().Any(l => l.Text is "收入详情" or "菜品销售" or "顾客小费" or "今日亮点" or "本次亮点"),
            "travel summary removes secondary income, highlights and rating content");
        Check(!note.GetGlobalRect().Intersects(upgrade.GetGlobalRect()) && !challenge.GetGlobalRect().Intersects(upgrade.GetGlobalRect())
            && !upgrade.GetGlobalRect().Intersects(view.CloseButton.GetGlobalRect()), "summary actions remain clear of results");
    }

    private async Task CheckTravelHighlightStates()
    {
        string locale = TranslationServer.GetLocale();
        var view = new BusinessDetailsView(); AddChild(view);
        var cases = new (string Name, DayResult Result)[]
        {
            ("empty", new()),
            ("challenge-failure", new() { Day = 2, LostCustomers = 4, SaleRevenue = 7, Satisfaction = 0 }),
            ("challenge-success", new() { Day = 2, CompletedCustomers = 3, CorrectOrders = 2, SaleRevenue = 21, Tips = 4, Satisfaction = 92 }),
            ("all-lost", new() { LostCustomers = 4 }),
            ("ordinary", new() { CompletedCustomers = 1, LostCustomers = 1, SaleRevenue = 7, Satisfaction = 65 }),
            ("streak", new() { CompletedCustomers = 3, LostCustomers = 1, HighestCorrectStreak = 3, SaleRevenue = 21, Satisfaction = 80 }),
            ("zero-tips", new() { CompletedCustomers = 3, PerfectOrders = 2, HighestCorrectStreak = 3, SaleRevenue = 21, Satisfaction = 95 }),
            ("long-amounts", new() { CompletedCustomers = 123456, PerfectOrders = 123456, SaleRevenue = 1000000000, Tips = 1000000000, Satisfaction = 100 })
        };
        try
        {
            TranslationServer.SetLocale("zh_CN");
            GetWindow().Size = new(1280, 720); await Frames(5);
            foreach (string city in new[] { "tianjin", "wuhan" })
            foreach (var scenario in cases)
            {
                var model = new BusinessBookModel
                {
                    CityId = city, Closing = true, Result = scenario.Result,
                    Challenge = scenario.Name == "empty" ? null : new DailyChallenge(city, scenario.Result.Day, DailyChallengeKind.Service, 2, 20)
                };
                if (scenario.Name == "long-amounts")
                    model = new BusinessBookModel
                    {
                        CityId = city, Closing = true, Result = scenario.Result,
                        Orders = new[] { new BookOrder(1, "long-summary", "演示顾客", "elder_regular",
                            new[] { new BookProduct("long-food", "双份加料香葱少酱特别早餐套餐请单独打包", 1, city == "tianjin" ? "Pancake" : "HotDryNoodles") },
                            BookOutcome.Perfect, 1000000000, 1000000000, 100) }
                    };
                view.Open(model); view.FinishAnimation(); JourneyTransition.For(view).Finish(); await Frames();
                CheckTravelHighlightLayout(view); CheckArtPage(view, city, scenario.Name);
                if (Capture) await Shot($"highlights-{city}-{scenario.Name}");
            }
            TranslationServer.SetLocale("en");
            foreach (string caption in new[] { "今日接待", "顾客满意度", "营业手记", "今日收入", "挑战结果", "今日暂无挑战", "店铺升级" })
                Check(!System.Text.RegularExpressions.Regex.IsMatch(TranslationServer.Translate(caption), "[\\u4e00-\\u9fff]"), "summary caption translated: " + caption);
            foreach (string city in new[] { "tianjin", "wuhan" })
            {
                view.Open(new BusinessBookModel { CityId = city, Result = new() { CompletedCustomers = 4, PerfectOrders = 4, Tips = 4, Satisfaction = 100 } });
                view.FinishAnimation(); await Frames(); CheckTravelHighlightLayout(view);
                if (Capture) await Shot($"highlights-{city}-english-live");
            }
        }
        finally { TranslationServer.SetLocale(locale); view.QueueFree(); await Frames(); }
    }

    private async Task CheckTravelChallengeCaptures(DataCatalog catalog)
    {
        string locale = TranslationServer.GetLocale();
        var save = new SaveService(); save.UsePathForTests("res://.tmp/book-tests/challenge-captures.json"); AddChild(save);
        var cases = new (string Name, DayResult Result, DailyChallenge? Challenge)[]
        {
            ("no-challenge", new() { Day = 1 }, null),
            ("challenge-success", new() { Day = 2, CompletedCustomers = 3, CorrectOrders = 2, SaleRevenue = 21, Tips = 4, Satisfaction = 92 }, null),
            ("challenge-failure", new() { Day = 2, LostCustomers = 4, SaleRevenue = 7 }, null)
        };
        try
        {
            TranslationServer.SetLocale("zh_CN");
            GetWindow().ContentScaleAspect = Window.ContentScaleAspectEnum.Expand;
            GetWindow().Size = new(1280, 720); await Frames(5);
            foreach (string city in new[] { "tianjin", "wuhan" })
            foreach (var scenario in cases)
            {
                var view = new BusinessDetailsView(); AddChild(view); view.ContinueRequested += () => { };
                string cityId = "city:" + city;
                save.Data.GetCity(cityId).HighestUnlockedDay = scenario.Result.Day + 1;
                var challenge = scenario.Challenge ?? (scenario.Name == "no-challenge" ? null
                    : new DailyChallenge(city, scenario.Result.Day, DailyChallengeKind.Service, 2, 20));
                view.Open(new BusinessBookModel
                {
                    CityId = city, Closing = true, Result = scenario.Result,
                    Challenge = challenge, Upgrades = new BookUpgradeSource(save, catalog, cityId)
                });
                view.FinishAnimation(); JourneyTransition.For(view).Finish();
                await ToSignal(GetTree().CreateTimer(1.5), SceneTreeTimer.SignalName.Timeout);
                CheckTravelHighlightLayout(view); CheckArtPage(view, city, scenario.Name);
                await Shot($"challenge-{city}-{scenario.Name}");
                view.QueueFree(); await Frames();
            }
        }
        finally
        {
            TranslationServer.SetLocale(locale); save.QueueFree(); await Frames();
        }
    }
}
