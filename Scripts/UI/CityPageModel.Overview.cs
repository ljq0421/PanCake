using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public sealed record CityUnlockView(string Id, string Name, string Visual, string? Art = null);
public sealed record CityOverviewView(int Day, string Title, int Coins, int CompletedDays, int TotalDays,
    int? BestRevenue, int? BestDay, string Goal, IReadOnlyList<CityUnlockView> LatestUnlocks);

public sealed partial class CityPageModel
{
    public CityOverviewView Overview(string city, int selectedDay)
    {
        var progress = JourneyModel.Progress(save, city);
        int total = save.ChapterLength(city);
        int highest = Math.Clamp(progress.HighestUnlockedDay, 1, Math.Max(1, total));
        int day = Math.Clamp(save.IsDemo ? selectedDay : highest, 1, Math.Max(1, total));
        var records = progress.DayBestRecords.Where(r => r.Key >= 1 && r.Key <= highest && r.Key <= total).ToArray();
        var best = records.OrderByDescending(r => r.Value.TotalRevenue).ThenBy(r => r.Key).FirstOrDefault();
        return new(day, total > 0 ? DayTitle(city, day) : "", save.Data.Coins,
            records.Length, total, records.Length == 0 ? null : best.Value.TotalRevenue,
            records.Length == 0 ? null : best.Key, JourneyModel.Goal(save, JourneyModel.City(city)), LatestUnlocks(city, highest));
    }

    private IReadOnlyList<CityUnlockView> LatestUnlocks(string city, int highest)
    {
        if (city == StableIds.Cities.Yangzhou && !save.IsDemo)
        {
            var available = Yangzhou.Products.Where(p => p.UnlockDay <= highest).ToArray();
            int latest = available.Select(p => p.UnlockDay).DefaultIfEmpty(0).Max();
            return available.Where(p => p.UnlockDay == latest).Select(p => new CityUnlockView(p.Id, p.Name, p.Id)).ToArray();
        }
        var seen = new HashSet<string>(StringComparer.Ordinal);
        CityUnlockView[] latestBatch = Array.Empty<CityUnlockView>();
        for (int day = 1; day <= highest; day++)
        {
            IEnumerable<string> ids;
            if (save.IsDemo)
            {
                var stage = save.DemoContent?.Stage(city, day);
                if (stage is null) continue;
                ids = stage.StartUnlocks.Concat(stage.AvailableRecipes.Select(id => "recipe:" + id))
                    .Concat(stage.AvailableProducts.Select(kind => "kind:" + kind));
            }
            else
            {
                if (catalog is null || !catalog.TryGetDay(city, day, out var config)) continue;
                ids = config.StartUnlocks.Concat(config.AvailableRecipeIds.Select(id => "recipe:" + id))
                    .Concat(config.AvailableProductKinds.Select(kind => "kind:" + kind));
            }
            var batch = new List<CityUnlockView>();
            foreach (string id in ids)
            {
                var entry = DescribeUnlock(city, id);
                if (entry is not null && seen.Add(entry.Id)) batch.Add(entry);
            }
            if (batch.Count > 0) latestBatch = batch.ToArray();
        }
        return latestBatch;
    }

    private CityUnlockView? DescribeUnlock(string city, string id)
    {
        const string root = "res://resource/art/";
        if (id.StartsWith("ingredient:")) return id[11..] switch
        {
            "crispy" => new(id, "薄脆", "Pancake", root + "TianJin/薄脆.png"),
            "scallion" => new(id, "香葱", "Pancake", root + "TianJin/香葱碎.png"),
            "ham" => new(id, "火腿", "Pancake", root + "TianJin/火腿片.png"),
            _ => null,
        };
        if (id.StartsWith("recipe:") && catalog?.RecipesById.TryGetValue(id[7..], out var recipe) == true)
        {
            string visual = city switch { StableIds.Cities.Wuhan => "HotDryNoodles", StableIds.Cities.Xian => "Roujiamo", StableIds.Cities.Guangzhou => "RiceRoll", _ => "Pancake" };
            return new(id, recipe.DisplayName, visual, recipe.Icon?.ResourcePath ?? OverviewFoodArt(visual));
        }
        ProductData? product = null;
        if (id.StartsWith("product:")) catalog?.ProductsById.TryGetValue(id[8..], out product);
        else if (id.StartsWith("kind:") && Enum.TryParse<ProductKind>(id[5..], out var kind))
            product = catalog?.ProductsById.Values.FirstOrDefault(p => p.Kind == kind);
        if (product is null) return null; // Recipe-based foods already have their named recipe entries.
        return new("product:" + product.Id, product.DisplayName, product.Kind.ToString(),
            product.Icon?.ResourcePath ?? OverviewFoodArt(product.Kind.ToString()));
    }

    private static string? OverviewFoodArt(string visual)
    {
        string? relative = visual switch
        {
            "Pancake" => "TianJin/装袋后的通用煎饼果子",
            "Youtiao" => "TianJin/熟油条", "SoyMilk" => "TianJin/成品豆浆杯",
            "HotDryNoodles" => "Wuhan/热干面完整成品", "Doupi" => "Wuhan/DoupiPieces_v1/piece-01",
            "EggRiceWine" => "Wuhan/成品蛋酒杯_v2", "Roujiamo" => "XiAn/通用卡通腊汁肉夹馍成品",
            "Hulatang" => "XiAn/成品肉丸胡辣汤", _ => null,
        };
        return relative is null ? null : "res://resource/art/" + relative + ".png";
    }
}
