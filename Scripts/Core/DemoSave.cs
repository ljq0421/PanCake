using System.Text.Json;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.Gameplay;

namespace ProjectCake.Core;

public sealed class DemoSaveFile
{
    public bool UpgradeTeachingCompleted { get; set; }
    public string ProfileId { get; set; } = ExperienceProfile.DemoId;
    public int SchemaVersion { get; set; } = 2;
    public int ContentRevision { get; set; } = 1;
    public Dictionary<string, int> WuhanEquipment { get; set; } = new() { ["noodle_cooker"] = 1, ["ingredient_station"] = 1, ["doupi_griddle"] = 0 };
    public HashSet<string> WuhanLearnedActions { get; set; } = new(StringComparer.Ordinal);
    public Dictionary<string, BreakfastStatistics> BreakfastStats { get; set; } = new(StringComparer.Ordinal);
    public Dictionary<string, string> BreakfastRecords { get; set; } = new(StringComparer.Ordinal);
    public int Coins { get; set; }
    public string LastStartedStageId { get; set; } = "demo_tj_01";
    public Dictionary<string, int> Equipment { get; set; } = new() { ["pancake_stove"] = 1, ["ingredient_station"] = 1, ["fryer"] = 0 };
    public Dictionary<string, DayBestRecord> BestRecords { get; set; } = new(StringComparer.Ordinal);
    public HashSet<string> CompletedStages { get; set; } = new(StringComparer.Ordinal);
    public HashSet<string> LearnedActions { get; set; } = new(StringComparer.Ordinal);
    public HashSet<string> CompletedTutorials { get; set; } = new(StringComparer.Ordinal);
    public HashSet<string> SkippedTutorials { get; set; } = new(StringComparer.Ordinal);
    public HashSet<string> AcceptedRuns { get; set; } = new(StringComparer.Ordinal);
}

public partial class SaveService
{
    public bool IsDemo { get; private set; }
    public bool DemoMigrationRetryAvailable { get; private set; }
    public int ContinueDay => Data.GetCity(ContinueCityId).HighestUnlockedDay;
    public bool IsCityAvailable(string cityId) => ExperienceProfile.IsCityAvailable(cityId, IsDemo);
    public int ChapterLength(string cityId) => IsCityAvailable(cityId) ? ChapterDays(cityId) : 0;
    public bool CanEnter(string cityId, int day) => CanContinue && IsCityAvailable(cityId)
        && Data.UnlockedCityIds.Contains(cityId) && day >= 1
        && day <= Data.GetCity(cityId).HighestUnlockedDay;

    public void UseDemoPathForTests(string path)
    { _explicitTestPath = true; _slotRoot = null; ActiveSlotId = null; IsDemo = true; _savePath = path; _legacyPath = null; Load(); }

    // Validate old data before touching it. Unknown formats must never reset.
    private bool TryResetLegacyDemo(string absolute, string json)
    {
        using var document = JsonDocument.Parse(json);
        if (!document.RootElement.TryGetProperty("profileId", out _)) return false;
        foreach (string field in new[] { "profileId", "schemaVersion", "contentRevision", "coins", "lastStartedStageId",
            "equipment", "bestRecords", "completedStages", "learnedActions", "completedTutorials", "skippedTutorials", "acceptedRuns" })
            if (!document.RootElement.TryGetProperty(field, out _)) throw new InvalidDataException("Incomplete legacy Demo save.");
        var file = JsonSerializer.Deserialize<DemoSaveFile>(json, DemoCatalog.JsonOptions)
            ?? throw new InvalidDataException("Demo save is empty.");
        file.WuhanEquipment.Remove("egg_rice_wine_station");
        if (file.SchemaVersion is not (1 or 2) || file.ContentRevision is < 1 or > 3)
            throw new InvalidDataException("Unsupported Demo save version.");
        if (file.SchemaVersion == 1 && (file.ContentRevision != 1 || file.CompletedStages is null
            || file.CompletedStages.Any(id => id is not ("demo_tj_01" or "demo_tj_02" or "demo_tj_03"))))
            throw new InvalidDataException("Invalid pilot save.");
        var content = JsonSerializer.Deserialize<DemoCatalog>(Godot.FileAccess.GetFileAsString(ExperienceProfile.ManifestPath), DemoCatalog.JsonOptions)
            ?? throw new InvalidDataException("Legacy Demo manifest is missing.");
        file.SchemaVersion = 2; file.ContentRevision = content.ContentRevision;
        ValidateDemoSave(file, content);
        DemoMigrationRetryAvailable = true;
        string backup = absolute + ".before-shared-cities.bak";
        if (File.Exists(backup)) backup = absolute + ".before-shared-cities-" + Guid.NewGuid().ToString("N") + ".bak";
        File.Copy(absolute, backup, false);
        var fresh = new SaveData();
        string temporary = absolute + ".migration.tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(fresh, JsonOptions));
        File.Move(temporary, absolute, true);
        DemoMigrationRetryAvailable = false;
        Data = fresh; HasSavedGame = true; MigratedLegacySave = true;
        return true;
    }

    private void ValidateProfile(SaveData data)
    {
        if (!IsDemo) return;
        if (!IsCityAvailable(data.LastVisitedCityId) || data.UnlockedCityIds.Any(id => !IsCityAvailable(id))
            || data.Cities.Any(pair => !IsCityAvailable(pair.Key) && (pair.Value.Completed
                || pair.Value.HighestUnlockedDay > 1 || pair.Value.DayBestRecords.Count > 0)))
            throw new InvalidDataException("Demo save contains progress outside the available cities.");
    }

    private static void ValidateDemoSave(DemoSaveFile file, DemoCatalog content)
    {
        if (file.ProfileId != ExperienceProfile.DemoId || file.SchemaVersion != 2 || file.ContentRevision != content.ContentRevision
            || file.Coins < 0 || file.WuhanEquipment is null || file.WuhanLearnedActions is null || file.BreakfastRecords is null || file.BestRecords is null || file.CompletedStages is null || file.Equipment is null
            || file.LearnedActions is null || file.CompletedTutorials is null || file.SkippedTutorials is null || file.AcceptedRuns is null
            || content.Stage(file.LastStartedStageId) is null)
            throw new InvalidDataException("Incompatible or invalid Demo save. The original file has been preserved.");
        if (file.Equipment.Count != 3 || file.Equipment.GetValueOrDefault("pancake_stove") is < 1 or > 2
            || file.Equipment.GetValueOrDefault("ingredient_station") is < 1 or > 2 || file.Equipment.GetValueOrDefault("fryer", -1) is < 0 or > 2
            || file.WuhanEquipment.Count != 3 || file.WuhanEquipment.GetValueOrDefault("noodle_cooker") is < 1 or > 2
            || file.WuhanEquipment.GetValueOrDefault("ingredient_station") != 1
            || file.WuhanEquipment.GetValueOrDefault("doupi_griddle", -1) is < 0 or > 2
            || file.BestRecords.Any(pair => content.Stage(pair.Key) is null || pair.Value is null || pair.Value.TotalRevenue < 0 || pair.Value.CompletedCustomers < 0)
            || file.CompletedStages.Any(id => content.Stage(id) is null)
            || file.CompletedTutorials.Concat(file.SkippedTutorials).Any(id => content.Stage(id) is null))
            throw new InvalidDataException("Invalid Demo progress or equipment.");
        if (file.BreakfastRecords.Any(p => !DemoBreakfastCollection.Cards.Any(c => c.Id == p.Key) || content.Stage(p.Value) is null))
            throw new InvalidDataException("Invalid breakfast record.");
        BreakfastStatistics.Validate(file.BreakfastStats);
        bool gap = false;
        foreach (var stage in content.Stages)
        {
            if (!file.CompletedStages.Contains(stage.Id)) gap = true;
            else if (gap) throw new InvalidDataException("Demo progress skips a locked stage.");
        }
    }

}
