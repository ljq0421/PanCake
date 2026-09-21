using ProjectCake.Data;

namespace ProjectCake.Core;

public partial class SaveService
{
    // Consume atomically before presentation so reopening an abandoned shift cannot replay it.
    public bool TryConsumeUpgradeCelebrations(string cityId, IEnumerable<string> visibleEquipment,
        out Dictionary<string, int> upgrades, out string error)
    {
        upgrades = new(StringComparer.Ordinal); error = "";
        if (cityId is not (StableIds.Cities.Tianjin or StableIds.Cities.Wuhan)) return true;
        var city = Data.GetCity(cityId);
        foreach (string id in visibleEquipment.Distinct())
            if (city.PendingUpgradeCelebrations.TryGetValue(id, out int level)
                && level > 1 && city.EquipmentLevels.GetValueOrDefault(id) == level)
                upgrades.Add(id, level);
        if (upgrades.Count == 0) return true;
        var snapshot = Clone(Data);
        foreach (string id in upgrades.Keys) city.PendingUpgradeCelebrations.Remove(id);
        if (!TrySave(out error)) { Data = snapshot; upgrades.Clear(); return false; }
        Changed?.Invoke(); return true;
    }
}
