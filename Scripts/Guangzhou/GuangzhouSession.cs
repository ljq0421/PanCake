using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.Guangzhou;

/// <summary>A shift owns all transient stock. Dates gate products, saved levels gate equipment.</summary>
public sealed class GuangzhouSession
{
    public GuangzhouSession(DataCatalog catalog, CityProgressData city, DayConfig config)
    {
        Config = config;
        GuangzhouEquipmentData Equipment(string id) => catalog.GetGuangzhouEquipment(id, Math.Clamp(city.EquipmentLevels.GetValueOrDefault(id, 1), 1, 3));
        StoveData = Equipment(GuangzhouRules.Stove); CabinetData = Equipment(GuangzhouRules.Cabinet); StationData = Equipment(GuangzhouRules.Station);
        Trays = Enumerable.Range(0, StoveData.Capacity).Select(_ => new RiceRollStateMachine(StoveData)).ToArray();
        if (config.AvailableProductKinds.Contains(ProductKind.SiuMai)) Cabinet = new(CabinetData);
        if (config.AvailableProductKinds.Contains(ProductKind.MorningTea)) Tea = new();
        int[] capacities = { StationData.BatterCapacity, StationData.EggCapacity, StationData.PorkCapacity, StationData.ShrimpCapacity, StationData.SauceCapacity };
        for (int i = 0; i < capacities.Length; i++) Ingredients[GuangzhouRules.Ingredients[i]] = new(capacities[i], .8);
    }
    public DayConfig Config { get; }
    public GuangzhouEquipmentData StoveData { get; }
    public GuangzhouEquipmentData CabinetData { get; }
    public GuangzhouEquipmentData StationData { get; }
    public IReadOnlyList<RiceRollStateMachine> Trays { get; }
    public DimSumCabinet? Cabinet { get; }
    public DimSumInventory DimSum { get; } = new();
    public GuangzhouTea? Tea { get; }
    public Dictionary<string, GuangzhouStock> Ingredients { get; } = new(StringComparer.Ordinal);
    public bool Paused { get; set; }
    public bool IngredientUnlocked(string id) => id is GuangzhouRules.Batter or GuangzhouRules.Sauce
        || Config.AvailableRecipeIds.Contains(id);
    public bool AddIngredient(int tray, string id) => !Paused && IngredientUnlocked(id)
        && tray >= 0 && tray < Trays.Count && Ingredients.TryGetValue(id, out var stock) && Trays[tray].TryAdd(id, stock);
    public bool LoadBasket(int index, string id) => !Paused && Config.AvailableProductKinds.Contains(GuangzhouRules.DimSumKind(id)) && Cabinet?.TryLoad(index, id) == true;
    public void Tick(double delta)
    {
        if (Paused || delta <= 0) return;
        foreach (var tray in Trays) tray.Tick(delta);
        Cabinet?.Tick(delta); Tea?.Tick(delta);
        foreach (var stock in Ingredients.Values) stock.Tick(delta);
    }
}
