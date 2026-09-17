using Godot;
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
        var section = view.Descendants<Control>().Single(c => c.Name == "BookHighlights");
        var progress = view.Descendants<ProgressBar>().Single(c => c.Name == "BookCompletionProgress");
        Check(Math.Abs(progress.Value - (view.Model.CompletionRate ?? 0)) < .001, "completion bar agrees with underlying ratio");
        var chips = section.GetChildren().OfType<Panel>().Where(c => c.Name.ToString().StartsWith("Highlight")).ToArray();
        Check(chips.Length == view.Model.Highlights.Count, "only earned highlights are rendered");
        foreach (var chip in chips)
        {
            Check(new Rect2(Vector2.Zero, section.Size).Encloses(chip.GetRect()), "highlight fits section");
            foreach (var label in chip.GetChildren().OfType<Label>())
                Check(new Rect2(Vector2.Zero, chip.Size).Encloses(label.GetRect()) && label.GetVisibleLineCount() == label.GetLineCount(), "highlight caption fully visible");
        }
        for (int i = 1; i < chips.Length; i++) Check(!chips[i - 1].GetRect().Intersects(chips[i].GetRect()), "highlight chips do not overlap");
        foreach (var action in view.Descendants<Control>().Where(c => c.IsVisibleInTree() && c.Name.ToString() is "UpgradeSticker" or "UnlockSticker" or "CloseBusinessDetails"))
            Check(!section.GetGlobalRect().Intersects(action.GetGlobalRect()), "highlights leave navigation and unlocks clear");
        Check(section.Descendants<Label>().Any(l => l.Text == (view.Model.Closing ? "今日亮点" : "本次亮点")), "highlight heading reflects current stage");
        if (chips.Length == 0) Check(section.Descendants<Label>().Any(l => l.Text == "慢慢来，把下一份早餐做好。"), "empty highlights have encouragement");
    }

    private async Task CheckTravelHighlightStates()
    {
        string locale = TranslationServer.GetLocale();
        var view = new BusinessDetailsView(); AddChild(view);
        var cases = new (string Name, DayResult Result)[]
        {
            ("empty", new()),
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
                var model = new BusinessBookModel { CityId = city, Closing = true, Result = scenario.Result };
                if (scenario.Name == "long-amounts")
                    model = new BusinessBookModel
                    {
                        CityId = city, Closing = true, Result = scenario.Result,
                        Orders = new[] { new BookOrder(1, "long-summary", "演示顾客", "elder_regular",
                            new[] { new BookProduct("long-food", "双份加料香葱少酱特别早餐套餐请单独打包", 1, city == "tianjin" ? "Pancake" : "HotDryNoodles") },
                            BookOutcome.Perfect, 1000000000, 1000000000, 100) }
                    };
                view.Open(model); view.FinishAnimation(); await Frames();
                CheckTravelHighlightLayout(view); CheckArtPage(view, city, scenario.Name);
                if (scenario.Name == "long-amounts")
                {
                    var best = view.Descendants<Label>().Single(l => l.Name == "BookBestSeller");
                    Check(best.GetLineCount() == 2 && best.GetVisibleLineCount() == 2 && best.TooltipText == best.Text,
                        $"long summary food uses two lines and retains its full name: lines={best.GetLineCount()} visible={best.GetVisibleLineCount()} tooltip={best.TooltipText}");
                    Check(!best.GetGlobalRect().Intersects(view.Descendants<Label>().Single(l => l.Text == "最受欢迎").GetGlobalRect()), "long product name clears its heading");
                }
                if (Capture) await Shot($"highlights-{city}-{scenario.Name}");
            }
            TranslationServer.SetLocale("en");
            Check(TranslationServer.Translate("完美出餐 ×4") == "Perfect ×4" && TranslationServer.Translate("小费 ¥4") == "Tips ¥4", "parameterized highlight translations");
            foreach (string caption in new[] { "收入详情", "今日接待", "顾客满意度", "今日亮点", "本次亮点", "零流失", "暂未流失", "错误", "流失", "连续正确 ×3", "好味道，", "让每一天都值得", "感谢每一位顾客", "慢慢来，把下一份早餐做好。", "完成率  —" })
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
}
