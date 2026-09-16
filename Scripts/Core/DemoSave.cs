using System.Text.Json;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.Gameplay;

namespace ProjectCake.Core;

public sealed class DemoSaveFile
{
    public string ProfileId { get; set; } = ExperienceProfile.DemoId;
    public int SchemaVersion { get; set; } = 2;
    public int ContentRevision { get; set; } = 1;
    public Dictionary<string, int> WuhanEquipment { get; set; } = new() { ["noodle_cooker"] = 1, ["ingredient_station"] = 1, ["doupi_griddle"] = 0, ["egg_rice_wine_station"] = 0 };
    public HashSet<string> WuhanLearnedActions { get; set; } = new(StringComparer.Ordinal);
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
    public DemoCatalog? DemoContent { get; private set; }
    public DemoSaveFile DemoProgress { get; private set; } = new();
    public int ContinueDay => IsDemo && DemoContent?.Stage(DemoProgress.LastStartedStageId) is { } stage ? stage.Day
        : Data.GetCity(ContinueCityId).HighestUnlockedDay;
    public int ChapterLength(string cityId) => IsDemo
        ? DemoContent?.CityStages(cityId).Length ?? 0
        : ChapterDays(cityId);
    public bool CanEnter(string cityId, int day) => CanContinue && (!IsDemo || ChapterLength(cityId) > 0)
        && Data.UnlockedCityIds.Contains(cityId) && day >= 1 && day <= ChapterLength(cityId)
        && day <= Data.GetCity(cityId).HighestUnlockedDay;

    public void UseDemoPathForTests(string path, DemoCatalog catalog)
    {
        IsDemo = true; DemoContent = catalog; _savePath = path; _legacyPath = null; Load();
    }

    private void LoadDemo()
    {
        PendingJourneyCompletion = null; ClearLoadError(); HasSavedGame = false; MigratedLegacySave = false;
        Data = new SaveData(); DemoProgress = NewDemoProgress();
        string absolute = Godot.ProjectSettings.GlobalizePath(_savePath);
        try
        {
            if (DemoContent is null) throw new InvalidDataException("Demo content is unavailable.");
            if (File.Exists(absolute))
            {
                var file = JsonSerializer.Deserialize<DemoSaveFile>(File.ReadAllText(absolute), DemoCatalog.JsonOptions)
                    ?? throw new InvalidDataException("Demo save is empty.");
                bool migrate = file.SchemaVersion == 1 || file.ContentRevision < DemoContent.ContentRevision;
                if (migrate)
                {
                    if (file.SchemaVersion is not (1 or 2) || file.ContentRevision < 1)
                        throw new InvalidDataException("Unsupported Demo save version.");
                    if (file.SchemaVersion == 1 && (file.ContentRevision != 1
                        || file.CompletedStages.Any(id => id is not ("demo_tj_01" or "demo_tj_02" or "demo_tj_03"))))
                        throw new InvalidDataException("Invalid pilot save.");
                    file.SchemaVersion = 2; file.ContentRevision = DemoContent.ContentRevision;
                    if (file.CompletedStages.Contains(file.LastStartedStageId)
                        && DemoContent.Stage(file.LastStartedStageId) is { } last
                        && DemoContent.Next(last) is { } next && !file.CompletedStages.Contains(next.Id))
                        file.LastStartedStageId = next.Id;
                }
                ValidateDemoSave(file, DemoContent);
                if (migrate)
                {
                    string backup = absolute + ".before-v2-r" + DemoContent.ContentRevision + ".bak";
                    if (!File.Exists(backup)) File.Copy(absolute, backup);
                    string temp = absolute + ".migration.tmp";
                    File.WriteAllText(temp, JsonSerializer.Serialize(file, DemoCatalog.JsonOptions));
                    File.Move(temp, absolute, true);
                }
                DemoProgress = file; Data = RestoreDemoData(file); HasSavedGame = true;
            }
        }
        catch (Exception e)
        {
            if (File.Exists(absolute)) SetCorruptError(absolute, e);
            else { HasLoadError = true; LoadErrorMessage = e.Message; }
        }
        Changed?.Invoke();
    }

    private DemoSaveFile NewDemoProgress() => new()
    {
        ContentRevision = DemoContent?.ContentRevision ?? 1,
        LastStartedStageId = DemoContent?.Stages[0].Id ?? "demo_tj_01",
    };

    private static void ValidateDemoSave(DemoSaveFile file, DemoCatalog content)
    {
        if (file.ProfileId != ExperienceProfile.DemoId || file.SchemaVersion != 2 || file.ContentRevision != content.ContentRevision
            || file.Coins < 0 || file.WuhanEquipment is null || file.WuhanLearnedActions is null || file.BreakfastRecords is null || file.BestRecords is null || file.CompletedStages is null || file.Equipment is null
            || file.LearnedActions is null || file.CompletedTutorials is null || file.SkippedTutorials is null || file.AcceptedRuns is null
            || content.Stage(file.LastStartedStageId) is null)
            throw new InvalidDataException("Incompatible or invalid Demo save. The original file has been preserved.");
        if (file.Equipment.Count != 3 || file.Equipment.GetValueOrDefault("pancake_stove") is < 1 or > 2
            || file.Equipment.GetValueOrDefault("ingredient_station") is < 1 or > 2 || file.Equipment.GetValueOrDefault("fryer", -1) is < 0 or > 2
            || file.WuhanEquipment.Count != 4 || file.WuhanEquipment.GetValueOrDefault("noodle_cooker") is < 1 or > 2
            || file.WuhanEquipment.GetValueOrDefault("ingredient_station") != 1
            || file.WuhanEquipment.GetValueOrDefault("doupi_griddle", -1) is < 0 or > 2
            || file.WuhanEquipment.GetValueOrDefault("egg_rice_wine_station", -1) != 0
            || file.BestRecords.Any(pair => content.Stage(pair.Key) is null || pair.Value is null || pair.Value.TotalRevenue < 0 || pair.Value.CompletedCustomers < 0)
            || file.CompletedStages.Any(id => content.Stage(id) is null)
            || file.CompletedTutorials.Concat(file.SkippedTutorials).Any(id => content.Stage(id) is null))
            throw new InvalidDataException("Invalid Demo progress or equipment.");
        if (file.BreakfastRecords.Any(p => !DemoBreakfastCollection.Cards.Any(c => c.Id == p.Key) || content.Stage(p.Value) is null))
            throw new InvalidDataException("Invalid breakfast record.");
        bool gap = false;
        foreach (var stage in content.Stages)
        {
            if (!file.CompletedStages.Contains(stage.Id)) gap = true;
            else if (gap) throw new InvalidDataException("Demo progress skips a locked stage.");
        }
    }

    private SaveData RestoreDemoData(DemoSaveFile file)
    {
        var data = new SaveData { Coins = file.Coins, LastVisitedCityId = DemoContent!.Stage(file.LastStartedStageId)!.CityId };
        data.Tianjin.EquipmentLevels = new(file.Equipment, StringComparer.Ordinal);
        data.Tianjin.LearnedWorkbenchActions = new(file.LearnedActions, StringComparer.Ordinal);
        data.Wuhan.EquipmentLevels = new(file.WuhanEquipment, StringComparer.Ordinal);
        data.Wuhan.LearnedWorkbenchActions = new(file.WuhanLearnedActions, StringComparer.Ordinal);
        foreach (var s in DemoContent.Stages)
        {
            var city = data.GetCity(s.CityId);
            if (file.BestRecords.TryGetValue(s.Id, out var best)) city.DayBestRecords[s.Day] = best;
            if (!file.CompletedStages.Contains(s.Id)) continue;
            foreach (var unlock in s.CompletionUnlocks)
                if (!city.UnlockedContentIds.Contains(unlock)) city.UnlockedContentIds.Add(unlock);
            var next = DemoContent.Next(s);
            if (next is not null)
            {
                if (!data.UnlockedCityIds.Contains(next.CityId)) data.UnlockedCityIds.Add(next.CityId);
                data.GetCity(next.CityId).HighestUnlockedDay = Math.Max(data.GetCity(next.CityId).HighestUnlockedDay, next.Day);
            }
            city.Completed = s.Day == ChapterLength(s.CityId) && ChapterLength(s.CityId) >= (s.CityId == StableIds.Cities.Tianjin ? 7 : 6);
        }
        foreach (var s in DemoContent.Stages.Where(s => data.UnlockedCityIds.Contains(s.CityId) && s.Day <= data.GetCity(s.CityId).HighestUnlockedDay))
        {
            var city = data.GetCity(s.CityId);
            foreach (var unlock in s.AvailableRecipes.Select(id => "recipe:" + id).Concat(s.StartUnlocks))
                if (!city.UnlockedContentIds.Contains(unlock)) city.UnlockedContentIds.Add(unlock);
            if (s.StartUnlocks.Contains("equipment:fryer_lv1")) city.EquipmentLevels["fryer"] = Math.Max(1, city.EquipmentLevels.GetValueOrDefault("fryer"));
            if (s.StartUnlocks.Contains("equipment:doupi_griddle_lv1")) city.EquipmentLevels["doupi_griddle"] = Math.Max(1, city.EquipmentLevels.GetValueOrDefault("doupi_griddle"));
        }
        return data;
    }

    private string SerializeDemo()
    {
        if (DemoContent is null) throw new InvalidDataException("Cannot save without Demo content.");
        var file = SnapshotDemo();
        ValidateDemoSave(file, DemoContent);
        return JsonSerializer.Serialize(file, DemoCatalog.JsonOptions);
    }

    private DemoSaveFile SnapshotDemo()
    {
        var file = CloneDemoProgress();
        file.Coins = Data.Coins;
        file.Equipment = new(Data.Tianjin.EquipmentLevels, StringComparer.Ordinal);
        file.LearnedActions = new(Data.Tianjin.LearnedWorkbenchActions, StringComparer.Ordinal);
        file.WuhanEquipment = new(Data.Wuhan.EquipmentLevels, StringComparer.Ordinal);
        file.WuhanLearnedActions = new(Data.Wuhan.LearnedWorkbenchActions, StringComparer.Ordinal);
        file.BestRecords = DemoContent!.Stages.Where(s => Data.GetCity(s.CityId).DayBestRecords.ContainsKey(s.Day))
            .ToDictionary(s => s.Id, s => Data.GetCity(s.CityId).DayBestRecords[s.Day]);
        return file;
    }

    private DemoSaveFile CloneDemoProgress() => JsonSerializer.Deserialize<DemoSaveFile>(
        JsonSerializer.Serialize(DemoProgress, DemoCatalog.JsonOptions), DemoCatalog.JsonOptions)!;

    private DayCommitResult CommitDemoDay(DayResult result, DayPlan plan, DayConfig config)
    {
        if (HasLoadError || DemoContent?.Stage(plan.StageId) is not { } stage || stage.Day != result.Day
            || config.CityId != stage.CityId || config.Day != stage.Day || !CanEnter(config.CityId, stage.Day)
            || string.IsNullOrEmpty(plan.RunId)) throw new IOException("Invalid Demo settlement or stage.");
        if (DemoProgress.AcceptedRuns.Contains(plan.RunId)) return new(0, false);
        var snapshot = Clone(Data); var demoSnapshot = CloneDemoProgress();
        var city = Data.GetCity(stage.CityId);
        bool hadBest = city.DayBestRecords.TryGetValue(result.Day, out var best);
        int gain = Math.Max(0, result.TotalRevenue - (best?.TotalRevenue ?? 0));
        bool newBest = !hadBest || result.TotalRevenue > best!.TotalRevenue;
        Data.Coins += gain;
        if (newBest) city.DayBestRecords[result.Day] = ToRecord(result);
        if (result.CompletedCustomers >= 1)
        {
            bool firstCompletion = DemoProgress.CompletedStages.Add(stage.Id);
            city.HighestUnlockedDay = Math.Max(city.HighestUnlockedDay, Math.Min(ChapterLength(stage.CityId), stage.Day + 1));
            if (DemoContent.Next(stage) is { } next)
            {
                if (!Data.UnlockedCityIds.Contains(next.CityId)) Data.UnlockedCityIds.Add(next.CityId);
                Data.GetCity(next.CityId).HighestUnlockedDay = Math.Max(Data.GetCity(next.CityId).HighestUnlockedDay, next.Day);
                if (firstCompletion) { DemoProgress.LastStartedStageId = next.Id; Data.LastVisitedCityId = next.CityId; }
            }
            city.Completed |= stage.Day == ChapterLength(stage.CityId) && ChapterLength(stage.CityId) >= (stage.CityId == StableIds.Cities.Tianjin ? 7 : 6);
            foreach (string unlock in stage.CompletionUnlocks)
                if (!city.UnlockedContentIds.Contains(unlock)) city.UnlockedContentIds.Add(unlock);
        }
        foreach (string id in plan.PendingBreakfastRecords)
            DemoProgress.BreakfastRecords.TryAdd(id, stage.Id);
        DemoProgress.AcceptedRuns.Add(plan.RunId);
        if (!TrySave(out string error)) { Data = snapshot; DemoProgress = demoSnapshot; throw new IOException(error); }
        Changed?.Invoke(); return new(gain, newBest, 0, !snapshot.GetCity(stage.CityId).Completed && city.Completed);
    }

    public bool TryRecordDemoStart(int day, out string error) => TryRecordDemoStart(StableIds.Cities.Tianjin, day, out error);
    public bool TryRecordDemoStart(string cityId, int day, out string error)
    {
        error = string.Empty;
        if (!IsDemo) return true;
        if (!CanEnter(cityId, day) || DemoContent?.Stage(cityId, day) is not { } stage)
        { error = "Demo stage is not available."; return false; }
        if (DemoProgress.LastStartedStageId == stage.Id && Data.LastVisitedCityId == cityId) return true;
        string previous = DemoProgress.LastStartedStageId, previousCity = Data.LastVisitedCityId;
        DemoProgress.LastStartedStageId = stage.Id; Data.LastVisitedCityId = cityId;
        if (!TrySave(out error)) { DemoProgress.LastStartedStageId = previous; Data.LastVisitedCityId = previousCity; return false; }
        return true;
    }

    public bool SaveDemoTutorial(string stageId, bool skipped, out string error)
    {
        error = string.Empty;
        if (!IsDemo || DemoContent?.Stage(stageId) is null) return false;
        var snapshot = CloneDemoProgress();
        if (skipped) DemoProgress.SkippedTutorials.Add(stageId);
        else DemoProgress.CompletedTutorials.Add(stageId);
        if (!TrySave(out error)) { DemoProgress = snapshot; return false; }
        return true;
    }
}
