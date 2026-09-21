using ProjectCake.Data;

namespace ProjectCake.Core;

public partial class SaveService
{
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
