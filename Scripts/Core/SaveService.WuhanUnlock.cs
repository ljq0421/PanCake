using ProjectCake.Data;

namespace ProjectCake.Core;

public partial class SaveService
{
    public const int WuhanDepartureCoins = 600;
    public bool CanDepartForWuhan => CanContinue && IsCityAvailable(StableIds.Cities.Wuhan)
        && !Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan)
        && Data.Tianjin.DayBestRecords.ContainsKey(WuhanUnlockDay)
        && Data.Coins >= WuhanDepartureCoins;

    public bool TryDepartForWuhan(out string error)
    {
        if (!CanDepartForWuhan)
        {
            error = "完成天津第 7 天营业并攒够 600 金币后才能出发。";
            return false;
        }
        var snapshot = Clone(Data);
        Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
        Data.UnlockedCityIds.Sort(StringComparer.Ordinal);
        Data.GetCity(StableIds.Cities.Wuhan);
        if (!TrySave(out error)) { Data = snapshot; return false; }
        Changed?.Invoke();
        return true;
    }

    public bool HasUnseenWuhanUnlock => Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan)
        && !Data.WuhanUnlockPresentationSeen;

    public bool TryMarkWuhanUnlockSeen(out string error)
    {
        error = "";
        if (!HasUnseenWuhanUnlock) return true;
        Data.WuhanUnlockPresentationSeen = true;
        if (TrySave(out error)) return true;
        Data.WuhanUnlockPresentationSeen = false;
        return false;
    }
}
