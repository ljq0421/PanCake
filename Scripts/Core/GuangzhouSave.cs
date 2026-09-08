using ProjectCake.Data;
using ProjectCake.Guangzhou;

namespace ProjectCake.Core;

public partial class SaveService
{
    public static CityProgressData NewGuangzhouProgress() => new()
    {
        EquipmentLevels = new(StringComparer.Ordinal)
        { [GuangzhouRules.Stove] = 1, [GuangzhouRules.Station] = 1, [GuangzhouRules.Cabinet] = 0 },
    };
    private void EnsureGuangzhouUnlocked()
    {
        if (!Data.Cities.TryGetValue(StableIds.Cities.Xian, out var xian) || !xian.Completed || xian.BestStars < 1) return;
        if (!Data.UnlockedCityIds.Contains(StableIds.Cities.Guangzhou)) Data.UnlockedCityIds.Add(StableIds.Cities.Guangzhou);
        Data.GetCity(StableIds.Cities.Guangzhou);
    }
    private static (string, int, int, string) ResolveGuangzhouUpgrade(string id, DataCatalog catalog)
    {
        if (catalog.GuangzhouEquipment.TryGetValue(id.Replace("equipment:", ""), out var data) && data.Level > 1)
            return (data.EquipmentId, data.Level, data.UpgradePrice, $"{GuangzhouRules.Name(data.EquipmentId)} Lv{data.Level}");
        return ("", 0, 0, "");
    }
}
