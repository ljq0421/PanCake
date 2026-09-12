using ProjectCake.Core;
using ProjectCake.Gameplay;
using ProjectCake.Yangzhou;
namespace ProjectCake.UI;

public static class YangzhouBusinessBook
{
    public static BusinessBookModel Snapshot(YangzhouSession session, YangzhouCatalog catalog)
    {
        var r = session.Result();
        return new BusinessBookModel
        {
            CityId = "yangzhou", Result = new DayResult { Day = r.Day, PlannedCustomers = r.Planned, CompletedCustomers = r.Completed,
                LostCustomers = r.Lost, SaleRevenue = r.Sales, Tips = r.Tips, Satisfaction = r.Satisfaction, PerfectOrders = r.PerfectOrders },
            Orders = session.BusinessRecords.Select((o, i) => new BookOrder(i + 1, o.Id.ToString(), o.Customer,
                o.CustomerType switch { "regular" => "elder_regular", "office" => "male_office", _ => "young_woman" },
                catalog.Template(o.TemplateId).Items.Select(p => new BookProduct(p.Key, catalog.Product(p.Key).Name, p.Value, p.Key)).ToArray(),
                o.Unreceived ? BookOutcome.Unreceived : o.Lost ? BookOutcome.Lost : o.Mistakes > 0 ? BookOutcome.Incorrect : o.Perfect ? BookOutcome.Perfect : BookOutcome.Correct,
                o.Sales, o.Tips, o.Satisfaction, !o.Lost && o.Mistakes > 0 ? $"备餐失误 {o.Mistakes} 次" : "")).ToArray(),
            ExtraNotes = new[] { $"Perfect 干丝 {r.PerfectGansi} 份" },
        };
    }
    public static BusinessBookModel Commit(YangzhouSession session, YangzhouCatalog catalog, SaveService save, bool practice)
    {
        var model = Snapshot(session, catalog); model.Closing = true; model.Practice = practice;
        var before = save.Data.Yangzhou.UnlockedCollectibleIds.ToHashSet();
        int previousDay = save.Data.Yangzhou.HighestUnlockedDay;
        var previousEquipment = new Dictionary<string, int>(save.Data.Yangzhou.EquipmentLevels);
        try
        {
            var commit = practice ? new DayCommitResult(0, false, session.Result().Stars) : save.CommitYangzhou(session);
            model.SaveMessage = practice ? "练习营业 · 本次不保存收入、设备或章节进度" : $"已入账 ¥{commit.PermanentCoinGain} · 历史最佳收入差额" + (commit.NewBest ? " · 新纪录" : "");
            var stickers = new List<string>();
            if (commit.EarnedStars > 0) stickers.Add($"本次评级 {new string('★', commit.EarnedStars)}");
            if (!practice)
            {
                if (commit.NewChapterCompletion) stickers.Add("扬州章节已点亮");
                if (save.Data.Yangzhou.EquipmentLevels.Any(p => p.Value > 0 && previousEquipment.GetValueOrDefault(p.Key) == 0)) stickers.Add("新设备：蒸笼已开放");
                var products = catalog.Products.Where(p => p.UnlockDay > previousDay && p.UnlockDay <= save.Data.Yangzhou.HighestUnlockedDay).Select(p => p.Name).ToArray();
                if (products.Length > 0) stickers.Add("新菜品：" + string.Join("、", products));
                if (save.Data.Yangzhou.UnlockedCollectibleIds.Any(id => !before.Contains(id))) stickers.Add("获得新收藏 · 回店查看");
                var upgrades = save.AvailableYangzhouBookUpgrades(catalog);
                if (upgrades.Length > 0) stickers.Add("可升级：" + string.Join("、", upgrades));
            }
            model.Stickers = stickers.ToArray();
        }
        catch (Exception e) { model.SaveMessage = "未保存 · " + e.Message + "；收入与进度已回退。"; model.CanClose = false; model.CanRetry = true; }
        return model;
    }
}
