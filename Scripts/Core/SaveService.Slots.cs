using System.Globalization;
using System.Text.Json;
using Godot;

namespace ProjectCake.Core;

public sealed record SaveSlotSummary(int Id, string Name, bool Exists, bool Corrupt,
    string CityId = "", int Day = 0, int Coins = 0, DateTimeOffset? SavedAt = null);

public partial class SaveService
{
    public const int SlotCount = 5;
    private sealed class SlotFile
    {
        public int Version { get; set; } = 1;
        public string JourneyId { get; set; } = Guid.NewGuid().ToString("N");
        public string Name { get; set; } = "";
        public DateTimeOffset SavedAt { get; set; } = DateTimeOffset.UtcNow;
        public SaveData Data { get; set; } = new();
    }
    private sealed class SlotIndex
    {
        public int Version { get; set; } = 1;
        public bool MigrationCompleted { get; set; }
        public int? ActiveSlotId { get; set; }
    }
    private string? _slotRoot;
    private bool _explicitTestPath;
    private bool _loadIoFailure;
    private SlotFile? _activeSlot;
    private SlotIndex _slotIndex = new();
    private Guid _sessionEpoch = Guid.NewGuid();
    private sealed record RunOwner(Guid Epoch);
    private readonly System.Runtime.CompilerServices.ConditionalWeakTable<object, RunOwner> _runOwners = new();
    public int? ActiveSlotId { get; private set; }
    public bool UsesSlots => _slotRoot is not null;
    public string SlotError { get; private set; } = "";
    private string IndexPath => Path.Combine(_slotRoot!, "index.json");
    private string SlotPath(int id) => Path.Combine(_slotRoot!, $"slot-{id}.json");
    private static void CheckSlot(int id)
    { if (id < 1 || id > SlotCount) throw new ArgumentOutOfRangeException(nameof(id)); }

    public void BindRun(object run)
    {
        if (!_runOwners.TryGetValue(run, out _)) _runOwners.Add(run, new(_sessionEpoch));
    }
    private void CheckRunOwner(object run)
    {
        if (!UsesSlots) return; // Legacy isolated test harnesses do not manage profiles.
        if (ActiveSlotId is null || !_runOwners.TryGetValue(run, out var owner) || owner.Epoch != _sessionEpoch)
            throw new IOException("这次营业不属于当前旅程，请返回首页重新进入。");
    }

    public void UseSlotsForTests(string root, bool demo = false, string? legacy = null)
    {
        _explicitTestPath = true;
        IsDemo = demo; _savePath = legacy ?? Path.Combine(root, "absent-legacy.json");
        _legacyPath = null; _slotRoot = ProjectSettings.GlobalizePath(root); LoadSlots();
    }
    internal void UseLegacySlotsForTests(string root, string current, string legacy)
    {
        _explicitTestPath = true;
        IsDemo = false; _savePath = current; _legacyPath = legacy;
        _slotRoot = ProjectSettings.GlobalizePath(root); LoadSlots();
    }
    private static void WriteAtomic<T>(string path, T value)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        string temporary = path + ".tmp";
        try { File.WriteAllText(temporary, JsonSerializer.Serialize(value, JsonOptions)); File.Move(temporary, path, true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    private void WriteIndex(int? active)
    {
        var next = new SlotIndex { MigrationCompleted = true, ActiveSlotId = active };
        WriteAtomic(IndexPath, next); _slotIndex = next;
    }
    private SlotFile ReadSlot(int id)
    {
        var file = JsonSerializer.Deserialize<SlotFile>(File.ReadAllText(SlotPath(id)), JsonOptions)
            ?? throw new InvalidDataException("存档为空。");
        if (file.Version != 1 || string.IsNullOrWhiteSpace(file.JourneyId) || !ValidSlotName(file.Name))
            throw new InvalidDataException("旅程信息无效。");
        ValidateSlotData(file.Data); return file;
    }
    private void ValidateSlotData(SaveData data)
    {
        Validate(data); ValidateProfile(data);
        if (data.UnlockedCityIds is null || data.Cities is null || data.Cities.Values.Any(city =>
            city.EquipmentLevels is null || city.UnlockedContentIds is null || city.UnlockedCollectibleIds is null
            || city.DayBestRecords is null || city.DayBestRecords.Values.Any(record => record is null)))
            throw new InvalidDataException("旅程数据不完整。");
    }
    private static bool ValidSlotName(string? name) => !string.IsNullOrWhiteSpace(name)
        && new StringInfo(name).LengthInTextElements <= 20 && !name.Any(char.IsControl);

    public IReadOnlyList<SaveSlotSummary> GetSlots()
    {
        var slots = new List<SaveSlotSummary>();
        for (int id = 1; id <= SlotCount; id++)
        {
            string name = $"旅程 {id}";
            if (!UsesSlots || !File.Exists(SlotPath(id))) { slots.Add(new(id, name, false, false)); continue; }
            try
            {
                var file = ReadSlot(id);
                string city = file.Data.LastVisitedCityId;
                if (!IsKnownCity(city) || !IsCityAvailable(city) || !file.Data.UnlockedCityIds.Contains(city)) city = ProjectCake.Data.StableIds.Cities.Tianjin;
                slots.Add(new(id, file.Name, true, false, city, file.Data.GetCity(city).HighestUnlockedDay, file.Data.Coins, file.SavedAt));
            }
            catch { slots.Add(new(id, name, true, true)); }
        }
        return slots;
    }
    private void ClearActiveSlot()
    {
        ActiveSlotId = null; _activeSlot = null; Data = new(); HasSavedGame = false;
        ClearLoadError(); PendingJourneyCompletion = null; _sessionEpoch = Guid.NewGuid();
    }
    private void Activate(int id, SlotFile file)
    {
        ClearActiveSlot(); ActiveSlotId = id; _activeSlot = file; Data = file.Data;
        EnsureXianUnlocked(); EnsureGuangzhouUnlocked(); EnsureYangzhouUnlocked();
        Data.LastVisitedCityId = ContinueCityId; HasSavedGame = true; SlotError = "";
    }
    private void LoadSlots()
    {
        ClearActiveSlot(); SlotError = ""; MigratedLegacySave = false;
        DemoMigrationRetryAvailable = false; _slotIndex = new();
        try
        {
            Directory.CreateDirectory(_slotRoot!);
            if (File.Exists(IndexPath))
            {
                _slotIndex = JsonSerializer.Deserialize<SlotIndex>(File.ReadAllText(IndexPath), JsonOptions)
                    ?? throw new InvalidDataException("存档选择记录为空。");
                if (_slotIndex.Version != 1 || _slotIndex.ActiveSlotId is < 1 or > SlotCount)
                    throw new InvalidDataException("存档选择记录无效。");
            }
            else _slotIndex = new();
            if (!_slotIndex.MigrationCompleted) MigrateSingleSave();
            if (_slotIndex.ActiveSlotId is int id)
            {
                try { Activate(id, ReadSlot(id)); }
                catch { SlotError = "上次使用的存档无法读取，请打开设置中的存档管理选择旅程。"; }
            }
        }
        catch (Exception e) { SlotError = "存档管理无法读取：" + e.Message + "。请打开设置中的存档管理选择旅程或重试。"; }
        Changed?.Invoke();
    }
    private void MigrateSingleSave()
    {
        // Existing slots are authoritative, including after an interrupted migration or lost index.
        if (Enumerable.Range(1, SlotCount).Any(id => File.Exists(SlotPath(id)))) { WriteIndex(null); return; }
        string source = ProjectSettings.GlobalizePath(_savePath);
        bool current = File.Exists(source);
        if (!current) source = FindLegacyAbsolute() ?? "";
        if (source.Length == 0) { WriteIndex(null); return; }
        // Run the existing converters against a staging copy, never the player's original file.
        string staging = Path.Combine(_slotRoot!, ".legacy-import"); Directory.CreateDirectory(staging);
        string copy = Path.Combine(staging, "source.json"), converted = Path.Combine(staging, "converted.json");
        File.Copy(source, copy, true);
        if (File.Exists(converted)) File.Delete(converted);
        var importer = new SaveService { IsDemo = IsDemo };
        try
        {
            if (current) importer.UsePathForTests(copy);
            else importer.UsePathsForTests(converted, copy);
            if (importer.HasLoadError)
            {
                // A failed write is retryable; only malformed input becomes a corrupt occupied slot.
                if (importer._loadIoFailure || importer.DemoMigrationRetryAvailable) throw new IOException(importer.LoadErrorMessage);
                File.Copy(source, SlotPath(1), false); WriteIndex(null);
                SlotError = "旧存档无法读取，已保留在槽位 1；可在其他空槽开启旅程。";
                return;
            }
            var file = new SlotFile { Name = "旅程 1", Data = importer.Data,
                SavedAt = new DateTimeOffset(File.GetLastWriteTimeUtc(source)) };
            WriteAtomic(SlotPath(1), file); WriteIndex(1);
            MigratedLegacySave = true;
        }
        finally { importer.Free(); }
    }
    public bool TryCreateSlot(int id, out string error)
    {
        CheckSlot(id); error = "";
        if (!UsesSlots) return Fail("存档管理尚未初始化。", out error);
        if (File.Exists(SlotPath(id))) return Fail("该槽位已有旅程，请选择空槽位。", out error);
        try
        {
            var file = new SlotFile { Name = $"旅程 {id}" };
            WriteAtomic(SlotPath(id), file);
            try { WriteIndex(id); } catch { File.Delete(SlotPath(id)); throw; }
            Activate(id, file); Changed?.Invoke(); return true;
        }
        catch (Exception e) { return Fail("新建失败：" + e.Message, out error); }
    }
    public bool TryLoadSlot(int id, out string error)
    {
        CheckSlot(id); error = "";
        if (!UsesSlots) return Fail("存档管理尚未初始化。", out error);
        try { var file = ReadSlot(id); WriteIndex(id); Activate(id, file); Changed?.Invoke(); return true; }
        catch (Exception e) { return Fail("读取失败：" + e.Message, out error); }
    }
    public bool TryRenameSlot(int id, string name, out string error)
    {
        CheckSlot(id); name = name.Trim(); error = "";
        if (!UsesSlots) return Fail("存档管理尚未初始化。", out error);
        if (!ValidSlotName(name)) return Fail("名称请输入 1–20 个文字字符，不能包含换行。", out error);
        try
        {
            var file = ReadSlot(id); file.Name = name; WriteAtomic(SlotPath(id), file);
            if (ActiveSlotId == id) _activeSlot!.Name = name;
            Changed?.Invoke(); return true;
        }
        catch (Exception e) { return Fail("改名失败：" + e.Message, out error); }
    }
    public bool TryDeleteSlot(int id, out string error)
    {
        CheckSlot(id); error = "";
        if (!UsesSlots) return Fail("存档管理尚未初始化。", out error);
        try
        {
            // Write the migration marker before deletion, so the legacy file cannot reappear.
            int? previous = ActiveSlotId;
            WriteIndex(previous == id ? null : previous);
            try { File.Delete(SlotPath(id)); } catch { WriteIndex(previous); throw; }
            if (ActiveSlotId == id) ClearActiveSlot();
            SlotError = ""; Changed?.Invoke(); return true;
        }
        catch (Exception e) { return Fail("删除失败：" + e.Message, out error); }
    }
    private bool SaveActiveSlot(out string error)
    {
        if (ActiveSlotId is not int id || _activeSlot is null) return Fail("请先在存档管理中新建或选择旅程。", out error);
        try
        {
            ValidateSlotData(Data);
            var file = new SlotFile { JourneyId = _activeSlot.JourneyId, Name = _activeSlot.Name, Data = Data };
            WriteAtomic(SlotPath(id), file); _activeSlot = file; HasSavedGame = true; error = ""; return true;
        }
        catch (Exception e) { return Fail("保存失败：" + e.Message, out error); }
    }
}
