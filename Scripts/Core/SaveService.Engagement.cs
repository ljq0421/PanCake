using ProjectCake.Data;

namespace ProjectCake.Core;

public partial class SaveService
{
    public bool ReconcileEngagementUnlocks(DataCatalog catalog, out string error)
    {
        error = "";
        if (HasLoadError || !catalog.IsValid) { error = "存档或配置无法读取。"; return false; }
        if (!HasSavedGame) return true;
        var snapshot = Clone(Data);
        bool changed = false;
        foreach (string id in new[] { StableIds.Cities.Tianjin, StableIds.Cities.Wuhan })
        {
            if (!Data.UnlockedCityIds.Contains(id)) continue;
            var city = Data.GetCity(id);
            int reached = Math.Min(ChapterDays(id), city.HighestUnlockedDay);
            for (int day = 1; day <= reached; day++)
            {
                if (!catalog.TryGetDay(id, day, out var config)) continue;
                var unlocks = config.StartUnlocks.AsEnumerable();
                if (day < city.HighestUnlockedDay || city.DayBestRecords.ContainsKey(day))
                    unlocks = unlocks.Concat(config.CompletionUnlocks);
                foreach (string unlock in unlocks)
                {
                    if (!city.UnlockedContentIds.Contains(unlock)) { city.UnlockedContentIds.Add(unlock); changed = true; }
                    string? free = unlock switch { "equipment:fryer_lv1" => "fryer", "equipment:doupi_griddle_lv1" => "doupi_griddle", _ => null };
                    if (free is not null && city.EquipmentLevels.GetValueOrDefault(free) < 1)
                    { city.EquipmentLevels[free] = 1; changed = true; }
                }
            }
            city.UnlockedContentIds.Sort(StringComparer.Ordinal);
        }
        if (!changed) return true;
        if (!TrySave(out error)) { Data = snapshot; return false; }
        Changed?.Invoke(); return true;
    }
}
