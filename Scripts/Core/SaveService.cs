using System.Text.Json;
using System.Text.Json.Serialization;
using Godot;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;

namespace ProjectCake.Core;

public sealed class DayBestRecord
{
    public int PerfectGansi { get; set; }
    public int TotalRevenue { get; set; }
    public int CompletedCustomers { get; set; }
    public int PerfectOrders { get; set; }
    public int IncorrectOrders { get; set; }
    public int HighestCorrectStreak { get; set; }
    public double Satisfaction { get; set; }
    public int YoutiaoUsed { get; set; }
    public int YoutiaoBurnt { get; set; }
}

public sealed class CityProgressData
{
    public int HighestUnlockedDay { get; set; } = 1;
    public int BestStars { get; set; }
    public bool Completed { get; set; }
    public Dictionary<string, int> EquipmentLevels { get; set; } = new(StringComparer.Ordinal);
    public List<string> UnlockedContentIds { get; set; } = new();
    public List<string> UnlockedCollectibleIds { get; set; } = new();
    public Dictionary<int, DayBestRecord> DayBestRecords { get; set; } = new();
    public DayPlan? LastDayPlan { get; set; }
    public HashSet<string> LearnedWorkbenchActions { get; set; } = new(StringComparer.Ordinal);
}

public sealed class SaveData
{
    public int Version { get; set; } = SaveService.CurrentVersion;
    public string LastVisitedCityId { get; set; } = StableIds.Cities.Tianjin;
    public int Coins { get; set; }
    public Dictionary<string, CityProgressData> Cities { get; set; } = new(StringComparer.Ordinal) { [StableIds.Cities.Tianjin] = SaveService.NewTianjinProgress() };
    public List<string> UnlockedCityIds { get; set; } = new() { StableIds.Cities.Tianjin };

    [JsonIgnore] public CityProgressData Tianjin => GetCity(StableIds.Cities.Tianjin);
    [JsonIgnore] public CityProgressData Wuhan => GetCity(StableIds.Cities.Wuhan);
    [JsonIgnore] public CityProgressData Xian => GetCity(StableIds.Cities.Xian);
    [JsonIgnore] public CityProgressData Guangzhou => GetCity(StableIds.Cities.Guangzhou);
    [JsonIgnore] public CityProgressData Yangzhou => GetCity(StableIds.Cities.Yangzhou);
    [JsonIgnore] public int HighestUnlockedDay { get => Tianjin.HighestUnlockedDay; set => Tianjin.HighestUnlockedDay = value; }
    [JsonIgnore] public int PurchasedStoveLevel { get => Equipment(Tianjin, "pancake_stove", 1); set => Tianjin.EquipmentLevels["pancake_stove"] = value; }
    [JsonIgnore] public int PurchasedIngredientStationLevel { get => Equipment(Tianjin, "ingredient_station", 1); set => Tianjin.EquipmentLevels["ingredient_station"] = value; }
    [JsonIgnore] public int PurchasedFryerLevel { get => Equipment(Tianjin, "fryer", 0); set => Tianjin.EquipmentLevels["fryer"] = value; }
    [JsonIgnore] public List<string> UnlockedUpgradeIds { get => Tianjin.UnlockedContentIds; set => Tianjin.UnlockedContentIds = value; }
    [JsonIgnore] public Dictionary<int, DayBestRecord> DayBestRecords { get => Tianjin.DayBestRecords; set => Tianjin.DayBestRecords = value; }
    [JsonIgnore] public DayPlan? LastDayPlan { get => Tianjin.LastDayPlan; set => Tianjin.LastDayPlan = value; }
    [JsonIgnore] public int TianjinBestStars { get => Tianjin.BestStars; set => Tianjin.BestStars = value; }
    [JsonIgnore] public bool TianjinCompleted { get => Tianjin.Completed; set => Tianjin.Completed = value; }

    public CityProgressData GetCity(string cityId)
    {
        if (!Cities.TryGetValue(cityId, out CityProgressData? progress))
        {
            progress = cityId switch { StableIds.Cities.Yangzhou => SaveService.NewYangzhouProgress(), StableIds.Cities.Guangzhou => SaveService.NewGuangzhouProgress(), StableIds.Cities.Xian => SaveService.NewXianProgress(), StableIds.Cities.Wuhan => SaveService.NewWuhanProgress(), StableIds.Cities.Tianjin => SaveService.NewTianjinProgress(), _ => throw new ArgumentException("未知城市", nameof(cityId)) };
            Cities[cityId] = progress;
        }
        return progress;
    }
    private static int Equipment(CityProgressData city, string id, int fallback) => city.EquipmentLevels.GetValueOrDefault(id, fallback);
}

internal sealed class LegacySaveDataV2
{
    public int Version { get; set; }
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
    public const int CurrentVersion = 3;
    public const string DefaultSavePath = "user://project_cake_save_v3.json";
    public const string LegacySavePath = "user://project_cake_save_v2.json";
    private const string LegacyV1Path = "user://project_cake_save_v1.json";
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true, PropertyNameCaseInsensitive = false, UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
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
    public bool HasSavedGame { get; private set; }
    public bool CanContinue => HasSavedGame && !HasLoadError;
    public bool RequiresNewGameConfirmation => HasSavedGame || HasLoadError;
    public string ContinueCityId => IsKnownCity(Data.LastVisitedCityId)
        && Data.UnlockedCityIds.Contains(Data.LastVisitedCityId)
        ? Data.LastVisitedCityId : StableIds.Cities.Tianjin;

    private static bool IsKnownCity(string? cityId) => cityId is StableIds.Cities.Tianjin
        or StableIds.Cities.Wuhan or StableIds.Cities.Xian or StableIds.Cities.Guangzhou or StableIds.Cities.Yangzhou;

    public bool TryRecordCityVisit(string cityId, out string error)
    {
        error = string.Empty;
        // Previewing locked cities through developer tools must never change the resume target.
        if (!IsKnownCity(cityId) || !Data.UnlockedCityIds.Contains(cityId)) return true;
        if (HasLoadError) { error = LoadErrorMessage; return false; }
        if (!HasSavedGame || Data.LastVisitedCityId == cityId) return true;
        string previous = Data.LastVisitedCityId;
        Data.LastVisitedCityId = cityId;
        if (!TrySave(out error)) { Data.LastVisitedCityId = previous; return false; }
        Changed?.Invoke();
        return true;
    }
    public override void _Ready() => Load();
    public void UsePathForTests(string path) { _savePath = path; _legacyPath = null; Load(); }
    public void UsePathsForTests(string currentPath, string legacyPath) { _savePath = currentPath; _legacyPath = legacyPath; Load(); }

    public void Load()
    {
        ClearLoadError(); MigratedLegacySave = false; HasSavedGame = false;
        string absolute = ProjectSettings.GlobalizePath(_savePath);
        if (!File.Exists(absolute))
        {
            string? legacy = FindLegacyAbsolute();
            if (legacy is not null) { MigrateLegacy(legacy); Changed?.Invoke(); return; }
            Data = new SaveData(); Changed?.Invoke(); return;
        }
        try { SaveData? loaded = JsonSerializer.Deserialize<SaveData>(File.ReadAllText(absolute), JsonOptions); Validate(loaded); Data = loaded!; EnsureXianUnlocked(); EnsureGuangzhouUnlocked(); EnsureYangzhouUnlocked(); Data.LastVisitedCityId = ContinueCityId; HasSavedGame = true; }
        catch (Exception exception) { SetCorruptError(absolute, exception); Data = new SaveData(); }
        Changed?.Invoke();
    }

    public bool ConfirmCreateNewAfterCorruption(out string error)
    {
        if (!HasLoadError) { error = "当前没有需要恢复的损坏存档。"; return false; }
        return ResetProgress(out error);
    }

    public bool ApplyStartUnlocks(DayConfig config, out string error)
    {
        SaveData snapshot = Clone(Data); CityProgressData city = Data.GetCity(config.CityId); bool changed = false;
        foreach (string unlock in config.StartUnlocks)
        {
            if (!city.UnlockedContentIds.Contains(unlock, StringComparer.Ordinal)) { city.UnlockedContentIds.Add(unlock); changed = true; }
            if (unlock == "equipment:fryer_lv1" && config.CityId == StableIds.Cities.Tianjin && Data.PurchasedFryerLevel < 1) { Data.PurchasedFryerLevel = 1; changed = true; }
            if (unlock == "equipment:doupi_griddle_lv1" && city.EquipmentLevels.GetValueOrDefault("doupi_griddle") < 1) { city.EquipmentLevels["doupi_griddle"] = 1; changed = true; }
            if (unlock == "equipment:egg_rice_wine_station" && city.EquipmentLevels.GetValueOrDefault("egg_rice_wine_station") < 1) { city.EquipmentLevels["egg_rice_wine_station"] = 1; changed = true; }
        }
        if (config.CityId == StableIds.Cities.Xian)
        {
            // Also repair pre-Day-3 saves continuing any later day; never downgrade an upgrade.
            const string freeOven = "equipment:xian_oven_lv1";
            if (!city.UnlockedContentIds.Contains(freeOven, StringComparer.Ordinal))
            { city.UnlockedContentIds.Add(freeOven); changed = true; }
            if (city.EquipmentLevels.GetValueOrDefault("xian_oven") < 1)
            { city.EquipmentLevels["xian_oven"] = 1; changed = true; }
            foreach (string equipment in new[] { "xian_oven", "xian_soup" })
                if (config.StartUnlocks.Contains($"equipment:{equipment}_lv1") && city.EquipmentLevels.GetValueOrDefault(equipment) < 1)
                { city.EquipmentLevels[equipment] = 1; changed = true; }
        }
        if (config.CityId == StableIds.Cities.Guangzhou && config.StartUnlocks.Contains("equipment:guangzhou_cabinet_lv1")
            && city.EquipmentLevels.GetValueOrDefault(ProjectCake.Guangzhou.GuangzhouRules.Cabinet) < 1)
        { city.EquipmentLevels[ProjectCake.Guangzhou.GuangzhouRules.Cabinet] = 1; changed = true; }
        if (!changed) { error = string.Empty; return true; }
        city.UnlockedContentIds.Sort(StringComparer.Ordinal);
        if (!TrySave(out error)) { Data = snapshot; return false; }
        Changed?.Invoke(); return true;
    }

    public DayCommitResult CommitDay(DayResult result, DayPlan plan, DayConfig config)
    {
        SaveData snapshot = Clone(Data); CityProgressData city = Data.GetCity(config.CityId);
        bool hadBest = city.DayBestRecords.TryGetValue(result.Day, out DayBestRecord? best);
        int previousBest = hadBest ? best!.TotalRevenue : 0; int gain = Math.Max(0, result.TotalRevenue - previousBest); bool newBest = !hadBest || result.TotalRevenue > previousBest;
        Data.Coins += gain; if (newBest) city.DayBestRecords[result.Day] = ToRecord(result);
        int chapterDays = ChapterDays(config.CityId);
        city.HighestUnlockedDay = Math.Min(chapterDays, Math.Max(city.HighestUnlockedDay, result.Day + 1));
        foreach (string unlock in config.CompletionUnlocks) if (!city.UnlockedContentIds.Contains(unlock, StringComparer.Ordinal)) city.UnlockedContentIds.Add(unlock);
        city.UnlockedContentIds.Sort(StringComparer.Ordinal); city.LastDayPlan = plan;
        int stars = EvaluateStars(result, config); bool newlyCompleted = false;
        if (stars > city.BestStars) city.BestStars = stars;
        if (result.Day == chapterDays && stars >= 1 && !city.Completed) { city.Completed = true; newlyCompleted = true; }
        if (config.CityId == StableIds.Cities.Tianjin && city.Completed)
        {
            if (!Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan, StringComparer.Ordinal)) Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
            Data.GetCity(StableIds.Cities.Wuhan);
        }
        if (config.CityId == StableIds.Cities.Wuhan && city.Completed)
            foreach (string id in new[] { "collectible:wuhan_hot_dry_noodles", "collectible:wuhan_doupi", "badge:wuhan_chapter" })
                if (!city.UnlockedCollectibleIds.Contains(id, StringComparer.Ordinal)) city.UnlockedCollectibleIds.Add(id);
        EnsureXianUnlocked();
        EnsureGuangzhouUnlocked();
        EnsureYangzhouUnlocked();
        Data.UnlockedCityIds.Sort(StringComparer.Ordinal);
        if (!TrySave(out string error)) { Data = snapshot; throw new IOException(error); }
        Changed?.Invoke(); return new DayCommitResult(gain, newBest, stars, newlyCompleted);
    }

    public bool TryPurchase(string upgradeId, DataCatalog catalog, out string error) => TryPurchase(StableIds.Cities.Tianjin, upgradeId, catalog, out error);
    public bool TryPurchase(string cityId, string upgradeId, DataCatalog catalog, out string error)
    {
        if (!DescribePurchase(cityId, upgradeId, catalog, out var offer, out error)) return false;
        var (equipment, target, price, _) = offer;
        CityProgressData city = Data.GetCity(cityId);
        SaveData snapshot = Clone(Data); Data.Coins -= price; city.EquipmentLevels[equipment] = target;
        if (!TrySave(out error)) { Data = snapshot; return false; }
        Changed?.Invoke(); return true;
    }

    private bool DescribePurchase(string cityId, string upgradeId, DataCatalog catalog,
        out (string Equipment, int Target, int Price, string Display) offer, out string error)
    {
        offer = default;
        CityProgressData city = Data.GetCity(cityId);
        if (!city.UnlockedContentIds.Contains(upgradeId, StringComparer.Ordinal)) { error = "该升级尚未开放。"; return false; }
        (string equipment, int target, int price, string display) = cityId == StableIds.Cities.Guangzhou ? ResolveGuangzhouUpgrade(upgradeId, catalog) : cityId == StableIds.Cities.Xian ? ResolveXianUpgrade(upgradeId, catalog) : cityId == StableIds.Cities.Wuhan ? ResolveWuhanUpgrade(upgradeId, catalog) : ResolveTianjinUpgrade(upgradeId, catalog);
        if (equipment.Length == 0) return Fail("不支持该升级。", out error);
        if (cityId == StableIds.Cities.Guangzhou && catalog.GuangzhouEquipment.TryGetValue(upgradeId.Replace("equipment:", ""), out var gzUpgrade)
            && !city.DayBestRecords.ContainsKey(gzUpgrade.UnlockAfterDay)) return Fail("请先完成对应营业日。", out error);
        int current = city.EquipmentLevels.GetValueOrDefault(equipment, equipment is "pancake_stove" or "ingredient_station" or "noodle_cooker" or "xian_board" ? 1 : 0);
        if (cityId == StableIds.Cities.Xian && catalog.XianEquipment.TryGetValue(upgradeId.Replace("equipment:", ""), out var xianUpgrade)
            && !city.DayBestRecords.ContainsKey(xianUpgrade.UnlockAfterDay)) return Fail("请先完成对应营业日。", out error);
        if (current >= target) return Fail($"{display} 已经购买。", out error);
        if (current != target - 1) return Fail($"需要先购买上一等级的{display[..^3]}。", out error);
        if (Data.Coins < price) return Fail($"金币不足，需要 ¥{price}。", out error);
        offer = (equipment, target, price, display); error = ""; return true;
    }
    internal string[] AvailableBookUpgrades(string cityId, DataCatalog catalog) =>
        Data.GetCity(cityId).UnlockedContentIds.OrderBy(id => id, StringComparer.Ordinal)
            .Select(id => DescribePurchase(cityId, id, catalog, out var offer, out _) ? offer.Display : null)
            .Where(name => name is not null).Select(name => name!).ToArray();

    public bool ResetProgress(out string error)
    {
        SaveData snapshot = Clone(Data);
        var previous = (HasLoadError, LoadErrorMessage, CorruptBackupPath, MigratedLegacySave, HasSavedGame);
        Data = new SaveData(); ClearLoadError(); MigratedLegacySave = false;
        if (!TrySave(out error))
        {
            Data = snapshot;
            (HasLoadError, LoadErrorMessage, CorruptBackupPath, MigratedLegacySave, HasSavedGame) = previous;
            return false;
        }
        Changed?.Invoke(); return true;
    }

    public bool TrySave(out string error)
    {
        if (HasLoadError) { error = "损坏存档尚未确认重置，禁止覆盖。"; return false; }
        try
        {
            string absolute = ProjectSettings.GlobalizePath(_savePath); Directory.CreateDirectory(Path.GetDirectoryName(absolute)!);
            string temporary = absolute + ".tmp"; File.WriteAllText(temporary, JsonSerializer.Serialize(Data, JsonOptions)); File.Move(temporary, absolute, true);
            HasSavedGame = true; error = string.Empty; return true;
        }
        catch (Exception exception) { error = $"保存失败：{exception.Message}"; GD.PushError(error); return false; }
    }

    public static int EvaluateStars(DayResult result, DayConfig config)
    {
        int stars = 0;
        foreach (StarGoalConfig goal in config.StarGoals.OrderBy(goal => goal.Stars))
            if (result.CompletedCustomers >= goal.MinimumCompletedCustomers && result.Satisfaction + .0001 >= goal.MinimumSatisfaction && result.PerfectOrders >= goal.MinimumPerfectOrders && (goal.MaximumIncorrectOrders is null || result.IncorrectOrders <= goal.MaximumIncorrectOrders)) stars = goal.Stars;
        return stars;
    }

    public static int ChapterDays(string cityId) => cityId switch { StableIds.Cities.Tianjin => 15, StableIds.Cities.Wuhan or StableIds.Cities.Xian or StableIds.Cities.Guangzhou or StableIds.Cities.Yangzhou => 12, _ => throw new ArgumentException("未知城市") };
    public static CityProgressData NewXianProgress() => new() { EquipmentLevels = new(StringComparer.Ordinal) { ["xian_board"] = 1, ["xian_oven"] = 0, ["xian_soup"] = 0 } };
    private void EnsureXianUnlocked()
    {
        if (!Data.Cities.TryGetValue(StableIds.Cities.Wuhan, out var wuhan) || !wuhan.Completed) return;
        if (!Data.UnlockedCityIds.Contains(StableIds.Cities.Xian)) Data.UnlockedCityIds.Add(StableIds.Cities.Xian);
        Data.GetCity(StableIds.Cities.Xian);
    }
    private static (string, int, int, string) ResolveXianUpgrade(string id, DataCatalog catalog)
    {
        if (catalog.XianEquipment.TryGetValue(id.Replace("equipment:", ""), out var d) && d.Level > 1)
            return (d.EquipmentId, d.Level, d.UpgradePrice, $"{ProjectCake.Xian.XianRules.EquipmentName(d.EquipmentId)} Lv{d.Level}");
        return (string.Empty, 0, 0, string.Empty);
    }

    public static CityProgressData NewTianjinProgress() => new() { EquipmentLevels = new(StringComparer.Ordinal) { ["pancake_stove"] = 1, ["ingredient_station"] = 1, ["fryer"] = 0 } };
    public static CityProgressData NewWuhanProgress() => new() { EquipmentLevels = new(StringComparer.Ordinal) { ["noodle_cooker"] = 1, ["ingredient_station"] = 1, ["doupi_griddle"] = 0, ["egg_rice_wine_station"] = 0 } };

    private string? FindLegacyAbsolute()
    {
        if (_legacyPath is not null && File.Exists(ProjectSettings.GlobalizePath(_legacyPath))) return ProjectSettings.GlobalizePath(_legacyPath);
        if (_savePath == DefaultSavePath && File.Exists(ProjectSettings.GlobalizePath(LegacyV1Path))) return ProjectSettings.GlobalizePath(LegacyV1Path);
        return null;
    }
    private void MigrateLegacy(string legacyAbsolute)
    {
        try
        {
            string json = File.ReadAllText(legacyAbsolute); int version = JsonDocument.Parse(json).RootElement.GetProperty("Version").GetInt32();
            LegacySaveDataV2 legacy = version switch { 2 => JsonSerializer.Deserialize<LegacySaveDataV2>(json, JsonOptions)!, 1 => ConvertV1(JsonSerializer.Deserialize<LegacySaveDataV1>(json, JsonOptions)!), _ => throw new InvalidDataException("旧存档版本无效。") };
            CorruptBackupPath = legacyAbsolute + $".v{version}-backup-{DateTime.Now:yyyyMMdd-HHmmssfff}.bak"; File.Copy(legacyAbsolute, CorruptBackupPath, true);
            CityProgressData tianjin = NewTianjinProgress();
            tianjin.HighestUnlockedDay = Math.Clamp(legacy.HighestUnlockedDay, 1, 15); tianjin.BestStars = legacy.TianjinBestStars; tianjin.Completed = legacy.TianjinCompleted;
            tianjin.EquipmentLevels["pancake_stove"] = legacy.PurchasedStoveLevel; tianjin.EquipmentLevels["ingredient_station"] = legacy.PurchasedIngredientStationLevel; tianjin.EquipmentLevels["fryer"] = legacy.PurchasedFryerLevel;
            tianjin.UnlockedContentIds = legacy.UnlockedUpgradeIds; tianjin.DayBestRecords = legacy.DayBestRecords; tianjin.LastDayPlan = legacy.LastDayPlan;
            Data = new SaveData { Coins = legacy.Coins, Cities = new(StringComparer.Ordinal) { [StableIds.Cities.Tianjin] = tianjin }, UnlockedCityIds = new() { StableIds.Cities.Tianjin } };
            if (legacy.TianjinCompleted || legacy.UnlockedCityIds.Contains(StableIds.Cities.Wuhan, StringComparer.Ordinal)) { Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan); Data.Cities[StableIds.Cities.Wuhan] = NewWuhanProgress(); }
            if (!TrySave(out string error)) throw new IOException(error); MigratedLegacySave = true;
        }
        catch (Exception exception) { HasLoadError = true; LoadErrorMessage = $"旧存档迁移失败：{exception.Message}"; Data = new SaveData(); GD.PushError(LoadErrorMessage); }
    }
    private static LegacySaveDataV2 ConvertV1(LegacySaveDataV1 legacy)
    {
        int highest = legacy.DayBestRecords.ContainsKey(4) ? Math.Max(5, legacy.HighestUnlockedDay) : legacy.HighestUnlockedDay;
        return new LegacySaveDataV2 { Version = 2, Coins = legacy.Coins, HighestUnlockedDay = highest, PurchasedStoveLevel = legacy.PurchasedStoveLevel, PurchasedIngredientStationLevel = legacy.PurchasedIngredientStationLevel, PurchasedFryerLevel = highest >= 5 ? 1 : 0, UnlockedUpgradeIds = legacy.UnlockedUpgradeIds, DayBestRecords = legacy.DayBestRecords, LastDayPlan = legacy.LastDayPlan };
    }
    private static (string, int, int, string) ResolveTianjinUpgrade(string id, DataCatalog catalog) => id switch
    {
        "equipment:ingredient_station_lv2" when catalog.TryGetIngredientStation(2, out var d) => ("ingredient_station", 2, d.UpgradePrice, "配料台 Lv2"),
        "equipment:ingredient_station_lv3" when catalog.TryGetIngredientStation(3, out var d) => ("ingredient_station", 3, d.UpgradePrice, "配料台 Lv3"),
        "equipment:pancake_stove_lv2" when catalog.TryGetStove(2, out var d) => ("pancake_stove", 2, d.UpgradePrice, "煎饼炉 Lv2"),
        "equipment:pancake_stove_lv3" when catalog.TryGetStove(3, out var d) => ("pancake_stove", 3, d.UpgradePrice, "煎饼炉 Lv3"),
        "equipment:fryer_lv2" when catalog.TryGetFryer(2, out var d) => ("fryer", 2, d.UpgradePrice, "油条锅 Lv2"),
        "equipment:fryer_lv3" when catalog.TryGetFryer(3, out var d) => ("fryer", 3, d.UpgradePrice, "油条锅 Lv3"), _ => (string.Empty, 0, 0, string.Empty),
    };
    private static (string, int, int, string) ResolveWuhanUpgrade(string id, DataCatalog catalog) => id switch
    {
        "equipment:noodle_cooker_lv2" when catalog.TryGetNoodleCooker(2, out var d) => ("noodle_cooker", 2, d.UpgradePrice, "煮面锅 Lv2"),
        "equipment:noodle_cooker_lv3" when catalog.TryGetNoodleCooker(3, out var d) => ("noodle_cooker", 3, d.UpgradePrice, "煮面锅 Lv3"),
        "equipment:doupi_griddle_lv2" when catalog.TryGetDoupiGriddle(2, out var d) => ("doupi_griddle", 2, d.UpgradePrice, "豆皮锅 Lv2"),
        "equipment:doupi_griddle_lv3" when catalog.TryGetDoupiGriddle(3, out var d) => ("doupi_griddle", 3, d.UpgradePrice, "豆皮锅 Lv3"), _ => (string.Empty, 0, 0, string.Empty),
    };
    private static DayBestRecord ToRecord(DayResult r) => new() { TotalRevenue = r.TotalRevenue, CompletedCustomers = r.CompletedCustomers, PerfectOrders = r.PerfectOrders, IncorrectOrders = r.IncorrectOrders, HighestCorrectStreak = r.HighestCorrectStreak, Satisfaction = r.Satisfaction, YoutiaoUsed = r.YoutiaoUsed, YoutiaoBurnt = r.YoutiaoBurnt };
    private static bool Fail(string message, out string error) { error = message; return false; }
    private static SaveData Clone(SaveData data) => JsonSerializer.Deserialize<SaveData>(JsonSerializer.Serialize(data, JsonOptions), JsonOptions)!;
    private static void Validate(SaveData? data)
    {
        if (data is null || data.Version != CurrentVersion || data.Coins < 0) throw new InvalidDataException("存档版本或金币数值无效。");
        foreach ((string id, CityProgressData city) in data.Cities)
        {
            city.LearnedWorkbenchActions ??= new(StringComparer.Ordinal);
            int max = ChapterDays(id);
            if (city.HighestUnlockedDay is < 1 || city.HighestUnlockedDay > max || city.BestStars is < 0 or > 3 || city.Completed && city.BestStars < 1) throw new InvalidDataException($"{id} 存档进度无效。");
        }
    }
    private void SetCorruptError(string absolute, Exception exception)
    {
        HasLoadError = true; LoadErrorMessage = $"存档无法读取：{exception.Message}"; CorruptBackupPath = absolute + $".corrupt-{DateTime.Now:yyyyMMdd-HHmmssfff}.bak";
        try { File.Copy(absolute, CorruptBackupPath, true); } catch { CorruptBackupPath = string.Empty; }
        GD.PushError(LoadErrorMessage);
    }
    private void ClearLoadError() { HasLoadError = false; LoadErrorMessage = string.Empty; CorruptBackupPath = string.Empty; }
}
