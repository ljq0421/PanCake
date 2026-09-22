using ProjectCake.Orders;
using ProjectCake.Data;
using System.Text.Json.Serialization;

namespace ProjectCake.Core;

public sealed record CustomerCard(string Id, string Category, string Name, string Description, string Saying, string Anecdote);

public sealed class CustomerStatistics
{
    public int Served { get; set; }
    public string FirstCity { get; set; } = "";
    public int FirstDay { get; set; }
    [JsonIgnore] public bool Known => Served >= 1;
    [JsonIgnore] public bool StoryUnlocked => Served >= 3;
    [JsonIgnore] public bool Regular => Served >= 5;
}

public static partial class CustomerCollection
{
    public const string Generic = "generic";
    public static string FullBodyArtPath(CustomerCard card) => card.Category switch
    {
        Generic => $"res://resource/art/Global/Customer/{card.Name}.png",
        StableIds.Cities.Tianjin => $"res://resource/art/TianJin/{card.Name}.png",
        StableIds.Cities.Wuhan => $"res://resource/art/Wuhan/{card.Name}.png",
        _ => throw new InvalidDataException($"顾客图鉴分类无全身照：{card.Category}"),
    };

    // Same identity mapping used by Yangzhou's existing business book portraits.
    public static string YangzhouAppearance(string customerType) => customerType switch
        { "regular" => "elder_regular", "office" => "male_office", _ => "young_woman" };
    public static CustomerCard? Find(string id) => Cards.FirstOrDefault(c => c.Id == id);
    public static bool Eligible(CustomerCard card, string city) =>
        card.Category == Generic || card.Category == city;

    public static void Observe(DayPlan plan, string runId, string city, string orderId,
        string appearance, DeliveryEvaluation? evaluation, bool tutorial)
    {
        if (tutorial || runId != plan.RunId || string.IsNullOrEmpty(orderId)
            || evaluation?.Grade is not (DeliveryGrade.Correct or DeliveryGrade.Perfect)
            || Find(appearance) is not { } card || !Eligible(card, city)
            || !plan.RecordedCustomerOrders.Add(orderId)) return;
        plan.PendingCustomerVisits[appearance] = plan.PendingCustomerVisits.GetValueOrDefault(appearance) + 1;
    }

    public static void Merge(Dictionary<string, CustomerStatistics> target, DayPlan plan, string city, int day)
    {
        foreach (var (id, count) in plan.PendingCustomerVisits)
        {
            if (count <= 0 || Find(id) is not { } card || !Eligible(card, city)) continue;
            if (!target.TryGetValue(id, out var stats))
                target[id] = stats = new CustomerStatistics { FirstCity = city, FirstDay = day };
            stats.Served = checked(stats.Served + count);
        }
    }

    public static void Validate(Dictionary<string, CustomerStatistics>? records)
    {
        if (records is null || records.Any(p => Find(p.Key) is not { } card || p.Value is null
            || p.Value.Served < 1 || p.Value.FirstDay < 1
            || p.Value.FirstCity is not ("city:tianjin" or "city:wuhan" or "city:xian" or "city:guangzhou" or "city:yangzhou")
            || !Eligible(card, p.Value.FirstCity)))
            throw new InvalidDataException("顾客图鉴记录无效。");
    }

    public static IEnumerable<string> MilestoneMessages(Dictionary<string, int> before, Dictionary<string, CustomerStatistics> after)
    {
        int[] thresholds = { 1, 3, 5 };
        string[] captions = { "认识了新朋友", "解锁人物趣闻", "获得熟客印章" };
        for (int i = 0; i < thresholds.Length; i++)
        {
            int count = after.Count(p => p.Value.Served >= thresholds[i] && before.GetValueOrDefault(p.Key) < thresholds[i]);
            if (count > 0) yield return $"{captions[i]} · {count} 位";
        }
    }
}
