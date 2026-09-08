using System.Text.Json;
using Godot;

namespace ProjectCake.Yangzhou;

public sealed record YangzhouProduct(string Id, string Name, int Price, int UnlockDay);
public sealed record YangzhouTemplate(string Id, string Name, Dictionary<string, int> Items)
{
    public bool Complex => Id is "H" or "I" or "J" or "K";
    public bool Large => Id == "L";
    public bool MixedSteam => Items.ContainsKey("B01") && Items.ContainsKey("B02");
}
public sealed record YangzhouCustomerType(string Id, string Name, double Patience, double TipRate, Dictionary<string, int> Preferences);
public sealed record YangzhouBoardData(int Level, int Yield, int Capacity, double Snap, double Seconds, int Price, int UnlockAfterDay);
public sealed record YangzhouSteamerData(int Level, int Capacity, int Layers, bool Hold, double BunSeconds, double SiumaiSeconds, int Price, int UnlockAfterDay);
public sealed record YangzhouDay(int Day, double Duration, int Customers, string Title, string Hint, Dictionary<string, int> Weights, Dictionary<string, int> CustomerWeights, int MaxLarge, int Seed);

/// <summary>City-specific recipes and balancing, separate from the immediate-delivery cities.</summary>
public sealed class YangzhouCatalog
{
    public const string CityId = "city:yangzhou", BoardId = "yangzhou_board", SteamerId = "yangzhou_steamer";
    public List<YangzhouProduct> Products { get; set; } = new();
    public List<YangzhouTemplate> Templates { get; set; } = new();
    public List<YangzhouCustomerType> Customers { get; set; } = new();
    public List<YangzhouDay> Days { get; set; } = new();
    public List<YangzhouBoardData> Boards { get; set; } = new();
    public List<YangzhouSteamerData> Steamers { get; set; } = new();
    public YangzhouProduct Product(string id) => Products.Single(p => p.Id == id);
    public YangzhouTemplate Template(string id) => Templates.Single(t => t.Id == id);
    public YangzhouCustomerType Customer(string id) => Customers.Single(c => c.Id == id);
    public YangzhouDay Day(int day) => Days.Single(d => d.Day == day);
    public int Price(YangzhouTemplate template) => template.Items.Sum(i => Product(i.Key).Price * i.Value);
    public static YangzhouCatalog Load()
    {
        using var file = Godot.FileAccess.Open("res://Data/Yangzhou/chapter.json", Godot.FileAccess.ModeFlags.Read);
        if (file is null) throw new InvalidDataException("无法读取扬州章节配置。");
        var catalog = JsonSerializer.Deserialize<YangzhouCatalog>(file.GetAsText()) ?? throw new InvalidDataException("扬州配置为空。");
        catalog.Validate(); return catalog;
    }
    public void Validate()
    {
        void Require(bool condition, string message) { if (!condition) throw new InvalidDataException("扬州配置：" + message); }
        Require(Days.Count == 12 && Days.Select(d => d.Day).Order().SequenceEqual(Enumerable.Range(1, 12)), "需要完整12天。");
        Require(Products.Count == 4 && Products.Select(p => p.Id).Distinct().Count() == 4 && Products.All(p => p.Price > 0 && p.UnlockDay is >= 1 and <= 12), "商品无效。");
        Require(Templates.Count == 12 && Templates.Select(t => t.Id).Order().SequenceEqual("ABCDEFGHIJKL".Select(c => c.ToString())), "模板A～L不完整。");
        Require(Customers.Count == 4 && Customers.Select(c => c.Id).Distinct().Count() == 4 && Customers.All(c => c.Patience > 0 && c.TipRate is >= 0 and <= 1), "顾客无效。");
        foreach (var t in Templates) Require(t.Items.Count > 0 && t.Items.All(i => i.Value > 0 && Products.Any(p => p.Id == i.Key)), "模板商品无效。");
        foreach (var c in Customers) Require(c.Preferences.All(w => w.Value > 0 && Templates.Any(t => t.Id == w.Key)), "专属偏好无效。");
        foreach (var d in Days)
        {
            Require(d.Duration > 0 && d.Customers > 0 && d.MaxLarge >= 0 && d.Weights.Values.Sum() == 100 && d.CustomerWeights.Values.Sum() == 100, $"Day {d.Day} 权重或数量无效。");
            Require(d.CustomerWeights.All(w => w.Value >= 0 && Customers.Any(c => c.Id == w.Key)), "顾客权重无效。");
            Require(d.Weights.All(w => w.Value > 0 && Templates.Any(t => t.Id == w.Key) && Template(w.Key).Items.All(i => Product(i.Key).UnlockDay <= d.Day)), "生成未开放商品。");
        }
        Require(Boards.Count == 3 && Boards.Select(b => b.Level).SequenceEqual(new[] { 1, 2, 3 }) && Boards.All(b => b.Yield > 0 && b.Capacity >= b.Yield && b.Seconds > 0 && b.Snap is > 0 and <= 1 && b.Price >= 0), "干丝台无效。");
        Require(Steamers.Count == 3 && Steamers.Select(b => b.Level).SequenceEqual(new[] { 1, 2, 3 }) && Steamers.All(b => b.Capacity > 0 && b.Layers is >= 1 and <= 2 && b.BunSeconds > 0 && b.SiumaiSeconds > 0 && b.Price >= 0), "蒸笼无效。");
    }
}
