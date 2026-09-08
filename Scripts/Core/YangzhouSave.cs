using ProjectCake.Yangzhou;

namespace ProjectCake.Core;

public partial class SaveService
{
    public static CityProgressData NewYangzhouProgress() => new()
    {
        EquipmentLevels = new(StringComparer.Ordinal) { [YangzhouCatalog.BoardId] = 1, [YangzhouCatalog.SteamerId] = 0 },
    };
    private void EnsureYangzhouUnlocked()
    {
        if (!Data.Cities.TryGetValue(ProjectCake.Data.StableIds.Cities.Guangzhou, out var previous) || !previous.Completed || previous.BestStars < 1) return;
        if (!Data.UnlockedCityIds.Contains(YangzhouCatalog.CityId)) Data.UnlockedCityIds.Add(YangzhouCatalog.CityId);
        Data.GetCity(YangzhouCatalog.CityId);
    }
    public bool PrepareYangzhou(int day, out string error)
    {
        if (day < 1 || day > Data.Yangzhou.HighestUnlockedDay) return Fail("该营业日尚未开放。", out error);
        if (HasLoadError) return Fail(LoadErrorMessage, out error);
        if (day < 3 || Data.Yangzhou.EquipmentLevels.GetValueOrDefault(YangzhouCatalog.SteamerId) >= 1) { error = ""; return true; }
        var snapshot = Clone(Data); Data.Yangzhou.EquipmentLevels[YangzhouCatalog.SteamerId] = 1;
        if (!TrySave(out error)) { Data = snapshot; return false; }
        Changed?.Invoke(); return true;
    }
    public bool PurchaseYangzhou(string equipment, YangzhouCatalog catalog, out string error)
    {
        var city = Data.Yangzhou;
        if (equipment is not (YangzhouCatalog.BoardId or YangzhouCatalog.SteamerId)) return Fail("未知设备。", out error);
        int level = city.EquipmentLevels.GetValueOrDefault(equipment);
        if (level is < 1 or >= 3) return Fail("设备未开放或已经升满。", out error);
        int price, day;
        if (equipment == YangzhouCatalog.BoardId) { var next = catalog.Boards.Single(b => b.Level == level + 1); price = next.Price; day = next.UnlockAfterDay; }
        else { var next = catalog.Steamers.Single(b => b.Level == level + 1); price = next.Price; day = next.UnlockAfterDay; }
        if (!city.DayBestRecords.ContainsKey(day)) return Fail($"完成 Day {day} 后开放。", out error);
        if (Data.Coins < price) return Fail("金币不足，继续营业后再来。", out error);
        var snapshot = Clone(Data); Data.Coins -= price; city.EquipmentLevels[equipment] = level + 1;
        if (!TrySave(out error)) { Data = snapshot; return false; }
        Changed?.Invoke(); return true;
    }
    public DayCommitResult CommitYangzhou(YangzhouSession session)
    {
        if (session.Phase != YangzhouPhase.Results) throw new InvalidOperationException("营业尚未结算。");
        var result = session.Result(); var snapshot = Clone(Data); var city = Data.Yangzhou;
        city.DayBestRecords.TryGetValue(result.Day, out var previous);
        int gain = Math.Max(0, result.Revenue - (previous?.TotalRevenue ?? 0));
        bool newBest = previous is null || result.Revenue > previous.TotalRevenue;
        Data.Coins += gain;
        if (newBest) city.DayBestRecords[result.Day] = new DayBestRecord
        {
            TotalRevenue = result.Revenue, CompletedCustomers = result.Completed, Satisfaction = result.Satisfaction,
            PerfectOrders = result.PerfectOrders, PerfectGansi = result.PerfectGansi,
        };
        city.HighestUnlockedDay = Math.Min(12, Math.Max(city.HighestUnlockedDay, result.Day + 1));
        if (city.HighestUnlockedDay >= 3 && city.EquipmentLevels.GetValueOrDefault(YangzhouCatalog.SteamerId) < 1) city.EquipmentLevels[YangzhouCatalog.SteamerId] = 1;
        bool complete = !city.Completed && result.Stars >= 1;
        city.Completed |= result.Stars >= 1; city.BestStars = Math.Max(city.BestStars, result.Stars);
        if (result.Stars == 3)
            foreach (string id in new[] { "collectible:yangzhou_crab_soup_bun", "badge:yangzhou_three_stars" })
                if (!city.UnlockedCollectibleIds.Contains(id)) city.UnlockedCollectibleIds.Add(id);
        if (!TrySave(out string error)) { Data = snapshot; throw new IOException(error); }
        Changed?.Invoke(); return new(gain, newBest, result.Stars, complete);
    }
}
