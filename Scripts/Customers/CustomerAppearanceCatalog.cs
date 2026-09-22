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

    public static IReadOnlyList<CustomerAppearanceDefinition> Wuhan { get; } = new CustomerAppearanceDefinition[]
    {
        new("wuhan_cyclist", "东湖骑行女青年"),
        new("wuhan_engineer", "光谷青年女工程师"),
        new("wuhan_opera_actress", "汉剧演员女"),
        new("wuhan_embroidery_artisan", "汉绣年轻手艺人男"),
        new("wuhan_clothing_owner", "汉正街服装店女老板"),
        new("wuhan_grandma", "老汉口街坊婆婆"),
        new("wuhan_industry_worker", "青山产业工人男"),
        new("wuhan_cultural_owner", "昙华林文创小店女店主"),
        new("wuhan_student", "武汉高校男学生"),
        new("wuhan_ferry_worker", "武汉轮渡工作人员男"),
    };

    // Generic identities remain available; Tianjin-local identities stay in their existing city pools.
    public static IReadOnlyList<string> Generic { get; } = new[]
    {
        "young_woman", "male_office", "female_office", "elder_regular", "morning_elder",
        "morning_aunt", "student", "delivery_rider", "taxi_driver", "tourist",
    };
    private static readonly IReadOnlyList<string> WuhanNormalPool = Generic.Concat(Wuhan.Select(item => item.Id)).ToArray();
    private static readonly IReadOnlyList<string> WuhanOfficePool = new[]
        { "male_office", "female_office", "student", "delivery_rider", "taxi_driver",
          "wuhan_engineer", "wuhan_student", "wuhan_ferry_worker", "wuhan_industry_worker" };
    private static readonly IReadOnlyList<string> WuhanRegularPool = new[]
        { "elder_regular", "morning_elder", "morning_aunt", "wuhan_grandma", "wuhan_cyclist",
          "wuhan_embroidery_artisan", "wuhan_opera_actress" };
    private static readonly IReadOnlyList<string> WuhanBigOrderPool = new[]
        { "female_office", "tourist", "wuhan_clothing_owner", "wuhan_cultural_owner" };

    public static IReadOnlyList<CustomerAppearanceDefinition> Tianjin => Definitions;
    public static IReadOnlyList<CustomerAppearanceDefinition> All { get; } = Definitions.Concat(Wuhan).ToArray();
    private static readonly HashSet<string> KnownIds = All.Select(item => item.Id).ToHashSet(StringComparer.Ordinal);

    public static bool IsKnown(string appearanceId) => KnownIds.Contains(appearanceId);

    public static IReadOnlyList<string> CandidatesFor(string customerTypeId) => customerTypeId switch
    {
        "wuhan_normal" => WuhanNormalPool,
        "wuhan_office_worker" => WuhanOfficePool,
        "wuhan_regular" => WuhanRegularPool,
        "wuhan_big_order" => WuhanBigOrderPool,
        "normal" or "xian_normal" => NormalPool,
        "office_worker" or "xian_office_worker" => OfficeWorkerPool,
        "regular" or "xian_regular" => RegularPool,
        "wuhan_tourist" or "xian_tourist" => new[] { "tourist" },
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
