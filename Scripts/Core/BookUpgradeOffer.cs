using ProjectCake.Yangzhou;

namespace ProjectCake.Core;

public sealed record BookUpgradeOffer(string CityId, string PurchaseId, string EquipmentId,
    string Name, int CurrentLevel, int TargetLevel, int Price);

public partial class SaveService
{
    internal IReadOnlyList<BookUpgradeOffer> BookOffers(string cityId, DataCatalog catalog)
    {
        if (HasLoadError) return Array.Empty<BookUpgradeOffer>();
        var result = new List<BookUpgradeOffer>();
        foreach (string id in Data.GetCity(cityId).UnlockedContentIds.OrderBy(id => id, StringComparer.Ordinal))
            if (DescribePurchase(cityId, id, catalog, out var o, out _))
                result.Add(new(cityId, id, o.Equipment, o.Display[..o.Display.LastIndexOf(" Lv", StringComparison.Ordinal)], o.Target - 1, o.Target, o.Price));
        return result;
    }

    internal IReadOnlyList<BookUpgradeOffer> BookOffers(YangzhouCatalog catalog)
    {
        if (HasLoadError) return Array.Empty<BookUpgradeOffer>();
        var result = new List<BookUpgradeOffer>();
        foreach (string id in new[] { YangzhouCatalog.BoardId, YangzhouCatalog.SteamerId })
            if (DescribeYangzhouPurchase(id, catalog, out int price, out int level, out _))
                result.Add(new(YangzhouCatalog.CityId, id, id, id == YangzhouCatalog.BoardId ? "干丝台" : "蒸笼", level, level + 1, price));
        return result;
    }
}
