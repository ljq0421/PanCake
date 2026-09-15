using System.Text.Json;
using ProjectCake.Data;
using ProjectCake.Orders;
using ProjectCake.Gameplay;

namespace ProjectCake.Core;

public sealed class DemoSaveFile
{
    public string ProfileId { get; set; } = ExperienceProfile.DemoId;
    public int SchemaVersion { get; set; } = 1;
    public int ContentRevision { get; set; } = 1;
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
        ? cityId == StableIds.Cities.Tianjin ? DemoContent?.Stages.Length ?? 0 : 0
        : ChapterDays(cityId);
    public bool CanEnter(string cityId, int day) => CanContinue && (!IsDemo || cityId == StableIds.Cities.Tianjin)
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
                ValidateDemoSave(file, DemoContent);
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
        if (file.ProfileId != ExperienceProfile.DemoId || file.SchemaVersion != 1 || file.ContentRevision != content.ContentRevision
            || file.Coins < 0 || file.BestRecords is null || file.CompletedStages is null || file.Equipment is null
            || file.LearnedActions is null || file.CompletedTutorials is null || file.SkippedTutorials is null || file.AcceptedRuns is null
            || content.Stage(file.LastStartedStageId) is null)
            throw new InvalidDataException("Incompatible or invalid Demo save. The original file has been preserved.");
        if (file.Equipment.Count != 3 || file.Equipment.GetValueOrDefault("pancake_stove") is < 1 or > 2
            || file.Equipment.GetValueOrDefault("ingredient_station") is < 1 or > 2 || file.Equipment.GetValueOrDefault("fryer", -1) != 0
            || file.BestRecords.Any(pair => content.Stage(pair.Key) is null || pair.Value is null || pair.Value.TotalRevenue < 0 || pair.Value.CompletedCustomers < 0)
            || file.CompletedStages.Any(id => content.Stage(id) is null)
            || file.CompletedTutorials.Concat(file.SkippedTutorials).Any(id => content.Stage(id) is null))
            throw new InvalidDataException("Invalid Demo progress or equipment.");
        bool gap = false;
        foreach (var stage in content.Stages)
        {
            if (!file.CompletedStages.Contains(stage.Id)) gap = true;
            else if (gap) throw new InvalidDataException("Demo progress skips a locked stage.");
        }
    }

    private SaveData RestoreDemoData(DemoSaveFile file)
    {
        var data = new SaveData { Coins = file.Coins };
        var city = data.Tianjin;
        city.EquipmentLevels = new(file.Equipment, StringComparer.Ordinal);
        city.LearnedWorkbenchActions = new(file.LearnedActions, StringComparer.Ordinal);
        foreach (var stage in DemoContent!.Stages)
        {
            if (file.BestRecords.TryGetValue(stage.Id, out var best)) city.DayBestRecords[stage.Day] = best;
            if (file.CompletedStages.Contains(stage.Id))
            {
                city.HighestUnlockedDay = Math.Min(DemoContent.Stages.Length, stage.Day + 1);
                foreach (var unlock in stage.CompletionUnlocks)
                    if (!city.UnlockedContentIds.Contains(unlock)) city.UnlockedContentIds.Add(unlock);
            }
        }
        foreach (var stage in DemoContent.Stages.Where(s => s.Day <= city.HighestUnlockedDay))
            foreach (var recipe in stage.AvailableRecipes)
                if (!city.UnlockedContentIds.Contains("recipe:" + recipe)) city.UnlockedContentIds.Add("recipe:" + recipe);
        // Completing this short pilot does not award a full-city completion or open Wuhan.
        return data;
    }

    private string SerializeDemo()
    {
        if (DemoContent is null) throw new InvalidDataException("Cannot save without Demo content.");
        var file = CloneDemoProgress();
        file.Coins = Data.Coins;
        file.Equipment = new(Data.Tianjin.EquipmentLevels, StringComparer.Ordinal);
        file.LearnedActions = new(Data.Tianjin.LearnedWorkbenchActions, StringComparer.Ordinal);
        file.BestRecords = Data.Tianjin.DayBestRecords.ToDictionary(pair => DemoContent.Stage(pair.Key)!.Id, pair => pair.Value);
        ValidateDemoSave(file, DemoContent);
        return JsonSerializer.Serialize(file, DemoCatalog.JsonOptions);
    }

    private DemoSaveFile CloneDemoProgress() => JsonSerializer.Deserialize<DemoSaveFile>(
        JsonSerializer.Serialize(DemoProgress, DemoCatalog.JsonOptions), DemoCatalog.JsonOptions)!;

    private DayCommitResult CommitDemoDay(DayResult result, DayPlan plan, DayConfig config)
    {
        if (HasLoadError || DemoContent?.Stage(plan.StageId) is not { } stage || stage.Day != result.Day
            || config.CityId != StableIds.Cities.Tianjin || config.Day != stage.Day || !CanEnter(config.CityId, stage.Day)
            || string.IsNullOrEmpty(plan.RunId)) throw new IOException("Invalid Demo settlement or stage.");
        if (DemoProgress.AcceptedRuns.Contains(plan.RunId)) return new(0, false);
        var snapshot = Clone(Data); var demoSnapshot = CloneDemoProgress();
        var city = Data.Tianjin;
        bool hadBest = city.DayBestRecords.TryGetValue(result.Day, out var best);
        int gain = Math.Max(0, result.TotalRevenue - (best?.TotalRevenue ?? 0));
        bool newBest = !hadBest || result.TotalRevenue > best!.TotalRevenue;
        Data.Coins += gain;
        if (newBest) city.DayBestRecords[result.Day] = ToRecord(result);
        if (result.CompletedCustomers >= 1)
        {
            bool firstCompletion = DemoProgress.CompletedStages.Add(stage.Id);
            city.HighestUnlockedDay = Math.Max(city.HighestUnlockedDay, Math.Min(DemoContent.Stages.Length, stage.Day + 1));
            if (firstCompletion && DemoContent.Stage(stage.Day + 1) is { } next)
                DemoProgress.LastStartedStageId = next.Id;
            foreach (string unlock in stage.CompletionUnlocks)
                if (!city.UnlockedContentIds.Contains(unlock)) city.UnlockedContentIds.Add(unlock);
        }
        DemoProgress.AcceptedRuns.Add(plan.RunId);
        if (!TrySave(out string error)) { Data = snapshot; DemoProgress = demoSnapshot; throw new IOException(error); }
        Changed?.Invoke(); return new(gain, newBest);
    }

    public bool TryRecordDemoStart(int day, out string error)
    {
        error = string.Empty;
        if (!IsDemo) return true;
        if (!CanEnter(StableIds.Cities.Tianjin, day) || DemoContent?.Stage(day) is not { } stage)
        { error = "Demo stage is not available."; return false; }
        string previous = DemoProgress.LastStartedStageId;
        DemoProgress.LastStartedStageId = stage.Id;
        if (!TrySave(out error)) { DemoProgress.LastStartedStageId = previous; return false; }
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
