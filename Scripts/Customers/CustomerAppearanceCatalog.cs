namespace ProjectCake.Customers;

public sealed record CustomerAppearanceDefinition(string Id, string DisplayName);

public static class CustomerAppearanceCatalog
{
    public const string DefaultAppearanceId = "young_woman";

    private static readonly CustomerAppearanceDefinition[] Definitions =
    {
        new("young_woman", "年轻女性"),
        new("male_office", "普通男上班族"),
        new("elder_regular", "老大爷熟客"),
        new("female_office", "普通女上班族"),
        new("xiangsheng_performer", "相声演员男"),
        new("tianjin_aunt", "天津本地阿姨"),
        new("morning_elder", "晨练大爷"),
        new("morning_aunt", "晨练阿姨"),
        new("student", "学生顾客"),
        new("delivery_rider", "外卖骑手"),
        new("taxi_driver", "出租车司机"),
        new("tourist", "外地游客"),
        new("kuaiban_performer", "快板演员男"),
        new("yangliuqing_painter", "杨柳青年画年轻画师"),
        new("clay_figurine_artisan", "泥人张手艺人"),
        new("culture_street_shopkeeper", "古文化街老店掌柜"),
        new("haihe_cruise_worker", "海河游船工作人员"),
        new("wudadao_clerk", "五大道文艺店员"),
        new("breakfast_shop_peer", "天津老字号早点铺同行大叔"),
        new("culture_street_owner", "古文化街文创店年轻女店主"),
        new("haihe_runner", "海河晨跑青年"),
        new("tianjin_port_worker", "天津港码头工作者"),
        new("folk_art_performer", "鼓曲从业者女"),
        new("kite_artisan", "风筝手艺人"),
    };

    private static readonly IReadOnlyList<string> NormalPool = Definitions.Select(item => item.Id).ToArray();

    private static readonly IReadOnlyList<string> OfficeWorkerPool = new[]
    {
        "male_office", "female_office", "student", "delivery_rider", "taxi_driver", "haihe_runner",
        "tianjin_port_worker", "haihe_cruise_worker", "wudadao_clerk",
    };

    private static readonly IReadOnlyList<string> RegularPool = new[]
    {
        "elder_regular", "tianjin_aunt", "morning_elder", "morning_aunt", "culture_street_shopkeeper",
        "breakfast_shop_peer", "yangliuqing_painter", "clay_figurine_artisan", "kite_artisan",
    };

    private static readonly IReadOnlyList<string> BigOrderPool = new[]
    {
        "female_office", "tianjin_aunt", "tourist", "culture_street_shopkeeper", "breakfast_shop_peer",
        "culture_street_owner",
    };

    private static readonly HashSet<string> KnownIds = Definitions.Select(item => item.Id).ToHashSet(StringComparer.Ordinal);

    public static IReadOnlyList<CustomerAppearanceDefinition> All => Definitions;

    public static bool IsKnown(string appearanceId) => KnownIds.Contains(appearanceId);

    public static IReadOnlyList<string> CandidatesFor(string customerTypeId) => customerTypeId switch
    {
        "normal" => NormalPool,
        "office_worker" => OfficeWorkerPool,
        "regular" => RegularPool,
        "big_order" => BigOrderPool,
        _ => new[] { DefaultAppearanceId },
    };

    public static string Select(
        string customerTypeId,
        int randomSeed,
        string customerId,
        IReadOnlySet<string>? unavailableAppearanceIds = null)
    {
        IReadOnlyList<string> candidates = CandidatesFor(customerTypeId);
        string[] ranked = candidates
            .OrderBy(candidate => StableHash($"{randomSeed}|{customerId}|{candidate}"))
            .ThenBy(candidate => candidate, StringComparer.Ordinal)
            .ToArray();

        if (unavailableAppearanceIds is not null)
        {
            string? available = ranked.FirstOrDefault(candidate => !unavailableAppearanceIds.Contains(candidate));
            if (available is not null) return available;
        }

        return ranked.FirstOrDefault() ?? DefaultAppearanceId;
    }

    private static ulong StableHash(string value)
    {
        const ulong offsetBasis = 14695981039346656037UL;
        const ulong prime = 1099511628211UL;
        ulong hash = offsetBasis;
        foreach (char character in value)
        {
            hash ^= character;
            hash *= prime;
        }
        return hash;
    }
}
