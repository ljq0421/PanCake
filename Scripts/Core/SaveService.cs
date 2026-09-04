using System.Text.Json;
using System.Text.Json.Serialization;
using Godot;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;

namespace ProjectCake.Core;

public sealed class DayBestRecord
{
    public int TotalRevenue { get; set; }
    public int CompletedCustomers { get; set; }
    public int PerfectOrders { get; set; }
    public int HighestCorrectStreak { get; set; }
    public double Satisfaction { get; set; }
    public int YoutiaoUsed { get; set; }
    public int YoutiaoBurnt { get; set; }
}

public sealed class SaveData
{
    public int Version { get; set; } = SaveService.CurrentVersion;
    public int Coins { get; set; }
    public int HighestUnlockedDay { get; set; } = 1;
    public int PurchasedStoveLevel { get; set; } = 1;
    public int PurchasedIngredientStationLevel { get; set; } = 1;
    public int PurchasedFryerLevel { get; set; }
    public List<string> UnlockedUpgradeIds { get; set; } = new();
    public Dictionary<int, DayBestRecord> DayBestRecords { get; set; } = new();
    public DayPlan? LastDayPlan { get; set; }
    public int TianjinBestStars { get; set; }
    public bool TianjinCompleted { get; set; }
    public List<string> UnlockedCityIds { get; set; } = new();
}

internal sealed class LegacySaveDataV1
{
    public int Version { get; set; }
    public int Coins { get; set; }
    public int HighestUnlockedDay { get; set; } = 1;
    public int PurchasedStoveLevel { get; set; } = 1;
    public int PurchasedIngredientStationLevel { get; set; } = 1;
    public List<string> UnlockedUpgradeIds { get; set; } = new();
    public Dictionary<int, DayBestRecord> DayBestRecords { get; set; } = new();
    public DayPlan? LastDayPlan { get; set; }
}

public readonly record struct DayCommitResult(int PermanentCoinGain, bool NewBest, int EarnedStars = 0, bool NewChapterCompletion = false);

public partial class SaveService : Node
{
    public const int CurrentVersion = 2;
    public const string DefaultSavePath = "user://project_cake_save_v2.json";
    public const string LegacySavePath = "user://project_cake_save_v1.json";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = false,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        Converters = { new JsonStringEnumConverter() },
    };

    private string _savePath = DefaultSavePath;
    private string? _legacyPath = LegacySavePath;

    public event Action? Changed;
    public SaveData Data { get; private set; } = new();
    public bool HasLoadError { get; private set; }
    public string LoadErrorMessage { get; private set; } = string.Empty;
    public string CorruptBackupPath { get; private set; } = string.Empty;
    public bool MigratedLegacySave { get; private set; }

    public override void _Ready() => Load();

    public void UsePathForTests(string path)
    {
        _savePath = path;
        _legacyPath = null;
        Load();
    }

    public void UsePathsForTests(string currentPath, string legacyPath)
    {
        _savePath = currentPath;
        _legacyPath = legacyPath;
        Load();
    }

    public void Load()
    {
        ClearLoadError();
        MigratedLegacySave = false;
        string absolute = ProjectSettings.GlobalizePath(_savePath);
        if (!File.Exists(absolute))
        {
            if (_legacyPath is not null && File.Exists(ProjectSettings.GlobalizePath(_legacyPath)))
            {
                MigrateLegacy(ProjectSettings.GlobalizePath(_legacyPath));
                Changed?.Invoke();
                return;
            }
            Data = NewData();
            Changed?.Invoke();
            return;
        }

        try
        {
            SaveData? loaded = JsonSerializer.Deserialize<SaveData>(File.ReadAllText(absolute), JsonOptions);
            Validate(loaded);
            Data = loaded!;
        }
        catch (Exception exception)
        {
            SetCorruptError(absolute, exception);
            Data = NewData();
        }
        Changed?.Invoke();
    }

    public bool ConfirmCreateNewAfterCorruption(out string error)
    {
        if (!HasLoadError)
        {
            error = "当前没有需要恢复的损坏存档。";
            return false;
        }
        Data = NewData();
        ClearLoadError();
        bool saved = TrySave(out error);
        Changed?.Invoke();
        return saved;
    }

    public bool ApplyStartUnlocks(DayConfig config, out string error)
    {
        SaveData snapshot = Clone(Data);
        bool changed = false;
        if (config.StartUnlocks.Contains("equipment:fryer_lv1", StringComparer.Ordinal) && Data.PurchasedFryerLevel < 1)
        {
            Data.PurchasedFryerLevel = 1;
            changed = true;
        }
        if (!changed)
        {
            error = string.Empty;
            return true;
        }
        if (!TrySave(out error))
        {
            Data = snapshot;
            return false;
        }
        Changed?.Invoke();
        return true;
    }

    public DayCommitResult CommitDay(DayResult result, DayPlan plan, DayConfig config)
    {
        SaveData snapshot = Clone(Data);
        bool hadBest = Data.DayBestRecords.TryGetValue(result.Day, out DayBestRecord? best);
        int previousBest = hadBest ? best!.TotalRevenue : 0;
        int gain = Math.Max(0, result.TotalRevenue - previousBest);
        bool newBest = !hadBest || result.TotalRevenue > previousBest;
        Data.Coins += gain;
        if (newBest)
        {
            Data.DayBestRecords[result.Day] = new DayBestRecord
            {
                TotalRevenue = result.TotalRevenue,
                CompletedCustomers = result.CompletedCustomers,
                PerfectOrders = result.PerfectOrders,
                HighestCorrectStreak = result.HighestCorrectStreak,
                Satisfaction = result.Satisfaction,
                YoutiaoUsed = result.YoutiaoUsed,
                YoutiaoBurnt = result.YoutiaoBurnt,
            };
        }

        Data.HighestUnlockedDay = Math.Min(15, Math.Max(Data.HighestUnlockedDay, result.Day + 1));
        foreach (string unlock in config.CompletionUnlocks)
        {
            if (!Data.UnlockedUpgradeIds.Contains(unlock, StringComparer.Ordinal)) Data.UnlockedUpgradeIds.Add(unlock);
        }
        Data.UnlockedUpgradeIds.Sort(StringComparer.Ordinal);
        Data.LastDayPlan = plan;

        int stars = EvaluateStars(result, config);
        bool newlyCompleted = false;
        if (stars > Data.TianjinBestStars) Data.TianjinBestStars = stars;
        if (stars >= 1 && !Data.TianjinCompleted)
        {
            Data.TianjinCompleted = true;
            newlyCompleted = true;
        }
        if (Data.TianjinCompleted && !Data.UnlockedCityIds.Contains("city:wuhan", StringComparer.Ordinal))
        {
            Data.UnlockedCityIds.Add("city:wuhan");
            Data.UnlockedCityIds.Sort(StringComparer.Ordinal);
        }

        if (!TrySave(out string error))
        {
            Data = snapshot;
            throw new IOException(error);
        }
        Changed?.Invoke();
        return new DayCommitResult(gain, newBest, stars, newlyCompleted);
    }

    public bool TryPurchase(string upgradeId, DataCatalog catalog, out string error)
    {
        if (!Data.UnlockedUpgradeIds.Contains(upgradeId, StringComparer.Ordinal))
        {
            error = "该升级尚未开放。";
            return false;
        }

        int price;
        Action apply;
        if (upgradeId == "equipment:ingredient_station_lv2" && catalog.TryGetIngredientStation(2, out IngredientStationLevelData station2))
        {
            if (Data.PurchasedIngredientStationLevel >= 2) return AlreadyOwned("配料台 Lv2", out error);
            price = station2.UpgradePrice;
            apply = () => Data.PurchasedIngredientStationLevel = 2;
        }
        else if (upgradeId == "equipment:ingredient_station_lv3" && catalog.TryGetIngredientStation(3, out IngredientStationLevelData station3))
        {
            if (Data.PurchasedIngredientStationLevel >= 3) return AlreadyOwned("配料台 Lv3", out error);
            if (Data.PurchasedIngredientStationLevel != 2) return PreviousRequired("配料台 Lv2", out error);
            price = station3.UpgradePrice;
            apply = () => Data.PurchasedIngredientStationLevel = 3;
        }
        else if (upgradeId == "equipment:pancake_stove_lv2" && catalog.TryGetStove(2, out PancakeStoveLevelData stove2))
        {
            if (Data.PurchasedStoveLevel >= 2) return AlreadyOwned("煎饼炉 Lv2", out error);
            price = stove2.UpgradePrice;
            apply = () => Data.PurchasedStoveLevel = 2;
        }
        else if (upgradeId == "equipment:pancake_stove_lv3" && catalog.TryGetStove(3, out PancakeStoveLevelData stove3))
        {
            if (Data.PurchasedStoveLevel >= 3) return AlreadyOwned("煎饼炉 Lv3", out error);
            if (Data.PurchasedStoveLevel != 2) return PreviousRequired("煎饼炉 Lv2", out error);
            price = stove3.UpgradePrice;
            apply = () => Data.PurchasedStoveLevel = 3;
        }
        else if (upgradeId == "equipment:fryer_lv2" && catalog.TryGetFryer(2, out FryerLevelData fryer2))
        {
            if (Data.PurchasedFryerLevel >= 2) return AlreadyOwned("油条锅 Lv2", out error);
            if (Data.PurchasedFryerLevel != 1) return PreviousRequired("油条锅 Lv1", out error);
            price = fryer2.UpgradePrice;
            apply = () => Data.PurchasedFryerLevel = 2;
        }
        else if (upgradeId == "equipment:fryer_lv3" && catalog.TryGetFryer(3, out FryerLevelData fryer3))
        {
            if (Data.PurchasedFryerLevel >= 3) return AlreadyOwned("油条锅 Lv3", out error);
            if (Data.PurchasedFryerLevel != 2) return PreviousRequired("油条锅 Lv2", out error);
            price = fryer3.UpgradePrice;
            apply = () => Data.PurchasedFryerLevel = 3;
        }
        else
        {
            error = "不支持该升级。";
            return false;
        }

        if (Data.Coins < price)
        {
            error = $"金币不足，需要 ¥{price}。";
            return false;
        }

        SaveData snapshot = Clone(Data);
        Data.Coins -= price;
        apply();
        if (!TrySave(out error))
        {
            Data = snapshot;
            return false;
        }
        Changed?.Invoke();
        return true;
    }

    public bool ResetProgress(out string error)
    {
        SaveData snapshot = Clone(Data);
        Data = NewData();
        ClearLoadError();
        if (!TrySave(out error))
        {
            Data = snapshot;
            return false;
        }
        Changed?.Invoke();
        return true;
    }

    public bool TrySave(out string error)
    {
        if (HasLoadError)
        {
            error = "损坏存档尚未确认重置，禁止覆盖。";
            return false;
        }
        try
        {
            string absolute = ProjectSettings.GlobalizePath(_savePath);
            Directory.CreateDirectory(Path.GetDirectoryName(absolute)!);
            string temporary = absolute + ".tmp";
            File.WriteAllText(temporary, JsonSerializer.Serialize(Data, JsonOptions));
            File.Move(temporary, absolute, true);
            error = string.Empty;
            return true;
        }
        catch (Exception exception)
        {
            error = $"保存失败：{exception.Message}";
            GD.PushError(error);
            return false;
        }
    }

    public static int EvaluateStars(DayResult result, DayConfig config)
    {
        int stars = 0;
        foreach (StarGoalConfig goal in config.StarGoals.OrderBy(goal => goal.Stars))
        {
            if (result.CompletedCustomers >= goal.MinimumCompletedCustomers
                && result.Satisfaction + 0.0001 >= goal.MinimumSatisfaction
                && result.PerfectOrders >= goal.MinimumPerfectOrders)
            {
                stars = goal.Stars;
            }
        }
        return stars;
    }

    private void MigrateLegacy(string legacyAbsolute)
    {
        try
        {
            LegacySaveDataV1? legacy = JsonSerializer.Deserialize<LegacySaveDataV1>(File.ReadAllText(legacyAbsolute), JsonOptions);
            if (legacy is null || legacy.Version != 1) throw new InvalidDataException("旧存档版本无效。");
            CorruptBackupPath = legacyAbsolute + $".v1-backup-{DateTime.Now:yyyyMMdd-HHmmssfff}.bak";
            File.Copy(legacyAbsolute, CorruptBackupPath, true);
            int highest = legacy.DayBestRecords.ContainsKey(4) ? Math.Max(5, legacy.HighestUnlockedDay) : legacy.HighestUnlockedDay;
            Data = new SaveData
            {
                Coins = legacy.Coins,
                HighestUnlockedDay = Math.Clamp(highest, 1, 15),
                PurchasedStoveLevel = legacy.PurchasedStoveLevel,
                PurchasedIngredientStationLevel = legacy.PurchasedIngredientStationLevel,
                PurchasedFryerLevel = highest >= 5 ? 1 : 0,
                UnlockedUpgradeIds = legacy.UnlockedUpgradeIds.ToList(),
                DayBestRecords = legacy.DayBestRecords,
                LastDayPlan = legacy.LastDayPlan,
            };
            if (!TrySave(out string error)) throw new IOException(error);
            MigratedLegacySave = true;
        }
        catch (Exception exception)
        {
            HasLoadError = true;
            LoadErrorMessage = $"旧存档迁移失败：{exception.Message}";
            Data = NewData();
            GD.PushError(LoadErrorMessage);
        }
    }

    private void SetCorruptError(string absolute, Exception exception)
    {
        HasLoadError = true;
        LoadErrorMessage = $"存档无法读取：{exception.Message}";
        CorruptBackupPath = absolute + $".corrupt-{DateTime.Now:yyyyMMdd-HHmmssfff}.bak";
        File.Copy(absolute, CorruptBackupPath, true);
        GD.PushError($"{LoadErrorMessage} 已备份到 {CorruptBackupPath}");
    }

    private void ClearLoadError()
    {
        HasLoadError = false;
        LoadErrorMessage = string.Empty;
        CorruptBackupPath = string.Empty;
    }

    private static bool AlreadyOwned(string displayName, out string error)
    {
        error = $"{displayName} 已经购买。";
        return false;
    }

    private static bool PreviousRequired(string displayName, out string error)
    {
        error = $"需要先购买 {displayName}。";
        return false;
    }

    private static SaveData NewData() => new();
    private static SaveData Clone(SaveData data) => JsonSerializer.Deserialize<SaveData>(JsonSerializer.Serialize(data, JsonOptions), JsonOptions)!;

    private static void Validate(SaveData? data)
    {
        if (data is null || data.Version != CurrentVersion) throw new InvalidDataException("存档版本无效。");
        if (data.Coins < 0 || data.HighestUnlockedDay is < 1 or > 15
            || data.PurchasedStoveLevel is < 1 or > 3
            || data.PurchasedIngredientStationLevel is < 1 or > 3
            || data.PurchasedFryerLevel is < 0 or > 3
            || data.TianjinBestStars is < 0 or > 3)
        {
            throw new InvalidDataException("存档包含非法进度数值。");
        }
        if (data.TianjinCompleted && data.TianjinBestStars < 1) throw new InvalidDataException("天津完成状态与星级不一致。");
    }
}
