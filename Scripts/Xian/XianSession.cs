using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.Xian;

/// <summary>Fresh inventory for a shift; purchased levels apply, date gates remain intact on replay.</summary>
public sealed class XianSession
{
    public XianSession(DataCatalog catalog, CityProgressData city, int day)
    {
        Day = day;
        int Level(string id) => Math.Clamp(city.EquipmentLevels.GetValueOrDefault(id, 1), 1, 3);
        BoardData = catalog.GetXianEquipment(XianRules.Board, Level(XianRules.Board));
        OvenData = catalog.GetXianEquipment(XianRules.Oven, Level(XianRules.Oven));
        SoupData = catalog.GetXianEquipment(XianRules.Soup, Level(XianRules.Soup));
        int Initial(XianEquipmentData d) => day >= 9 && d.Level >= 2 ? 6 : 4;
        Buns = new BunInventory(OvenData.StockCapacity, Initial(OvenData));
        Meat = new RefillableStock(BoardData.IngredientCapacity, .8);
        Juice = new RefillableStock(BoardData.IngredientCapacity, .6);
        Board = new ChoppingStateMachine(BoardData, day >= 3 ? Initial(BoardData) : 0);
        Oven = new BunOvenStateMachine(OvenData);
        if (day >= 6) Soup = new HulatangRuntime(SoupData, Initial(SoupData));
    }
    public int Day { get; }
    public XianEquipmentData BoardData { get; }
    public XianEquipmentData OvenData { get; }
    public XianEquipmentData SoupData { get; }
    public BunInventory Buns { get; }
    public RefillableStock Meat { get; }
    public RefillableStock Juice { get; }
    public ChoppingStateMachine Board { get; }
    public BunOvenStateMachine? Oven { get; }
    public HulatangRuntime? Soup { get; }
    public RoujiamoStateMachine Sandwich { get; } = new();
    public double NoBunSeconds { get; private set; }
    public double NoChoppedMeatSeconds { get; private set; }
    public void Tick(double delta)
    {
        if (delta <= 0) return;
        Meat.Tick(delta); Juice.Tick(delta); Oven?.Tick(delta, Buns); Soup?.Tick(delta);
        if (!Buns.Tutorial && Buns.Count == 0) NoBunSeconds += delta;
        if (Board.Portions == 0) NoChoppedMeatSeconds += delta;
    }
    public bool AddMeat() => Sandwich.TryAddMeat(Board, Day >= 5 && (Day >= 7 || !Sandwich.HasJuice) ? 2 : 1);
    public bool AddJuice() => Sandwich.TryAddJuice(Juice, Day >= 2 && (Day >= 7 || Sandwich.MeatPortions == 1));
}
