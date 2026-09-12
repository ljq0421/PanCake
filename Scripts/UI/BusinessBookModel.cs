using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.Orders;
using ProjectCake.Pancake;

namespace ProjectCake.UI;

public enum BookOutcome { Correct, Perfect, Incorrect, Lost, Unreceived }
public enum BookFilter { All, Completed, Incorrect, Lost }
public sealed record BookProduct(string Id, string Name, int Quantity, string Visual, string Preference = "");
public sealed record BookOrder(int Number, string Id, string Customer, string Appearance,
    IReadOnlyList<BookProduct> Products, BookOutcome Outcome, int Sales, int Tips, double? Score, string Reason = "")
{
    public bool Lost => Outcome is BookOutcome.Lost or BookOutcome.Unreceived;
    public int Revenue => Sales + Tips;
}

/// <summary>Presentation snapshot; never persists, pays a customer, or commits a day.</summary>
public sealed class BusinessBookModel
{
    public string CityId { get; init; } = "tianjin";
    public string CityName => CityId switch { "wuhan" => "武汉", "xian" => "西安", "guangzhou" => "广州", "yangzhou" => "扬州", _ => "天津" };
    public string Unit => CityId == "yangzhou" ? "组" : "位";
    public DayResult Result { get; init; } = new();
    public IReadOnlyList<BookOrder> Orders { get; init; } = Array.Empty<BookOrder>();
    public bool Closing { get; set; }
    public bool Practice { get; set; }
    public bool CanClose { get; set; } = true;
    public bool CanRetry { get; set; }
    public string SaveMessage { get; set; } = "";
    public string[] Stickers { get; set; } = Array.Empty<string>();
    public string[] ExtraNotes { get; set; } = Array.Empty<string>();
    public int Resolved => Result.CompletedCustomers + Result.LostCustomers;
    public double? CompletionRate => Resolved == 0 ? null : 100d * Result.CompletedCustomers / Resolved;
    public double? Satisfaction => Result.CompletedCustomers == 0 ? null : Result.Satisfaction;
    public BookProduct? BestSeller => Orders.Where(o => !o.Lost).SelectMany(o => o.Products)
        .GroupBy(p => p.Id, StringComparer.Ordinal).Select(g => g.First() with { Quantity = g.Sum(p => p.Quantity), Preference = "" })
        .OrderByDescending(p => p.Quantity).ThenBy(p => p.Id, StringComparer.Ordinal).FirstOrDefault();
    public string DailyNote => Resolved == 0 ? "第一份客单还没记下，慢慢来。"
        : Result.CompletedCustomers == 0 ? "先照顾等得最久的客人，让大家吃上早餐。"
        : (CompletionRate >= 80, Satisfaction >= 80) switch
        {
            (true, true) => "今天又快又稳，街坊们都吃得很满意！",
            (false, true) => "味道不错，就是让客人等太久啦。",
            (true, false) => "今天出餐挺快，不过味道还得再稳一些。",
            _ => "先看清客人的点单，再稳稳做好每一份早餐。",
        };
    public IEnumerable<BookOrder> Filter(BookFilter filter) => Orders.Where(o => filter switch
    {
        BookFilter.Completed => !o.Lost, BookFilter.Incorrect => o.Outcome == BookOutcome.Incorrect,
        BookFilter.Lost => o.Lost, _ => true,
    });

    public static BusinessBookModel From(string city, DayResult result, IReadOnlyList<BusinessOrderRecord> records, DataCatalog catalog) => new()
    {
        CityId = city.Replace("city:", ""), Result = result,
        Orders = records.Select((r, i) => new BookOrder(i + 1, r.OrderId, r.CustomerName, r.AppearanceId,
            Array.AsReadOnly(r.Lines.Select(l => Product(l, catalog)).ToArray()),
            r.Lost ? BookOutcome.Lost : r.Evaluation!.Grade switch
            { DeliveryGrade.Perfect => BookOutcome.Perfect, DeliveryGrade.Correct => BookOutcome.Correct, _ => BookOutcome.Incorrect },
            r.Evaluation?.SaleRevenue ?? 0, r.Evaluation?.Tip ?? 0, r.Evaluation?.SatisfactionScore,
            r.Evaluation?.Grade == DeliveryGrade.Incorrect ? r.Evaluation.Message : "")).ToArray(),
        ExtraNotes = new[] { $"最高连续正确 {result.HighestCorrectStreak} 单" }
            .Concat(city.EndsWith("tianjin", StringComparison.Ordinal) ? new[] { $"油条使用 {result.YoutiaoUsed} 根 · 炸焦 {result.YoutiaoBurnt} 根" } : Array.Empty<string>()).ToArray(),
    };
    private static BookProduct Product(OrderLineData line, DataCatalog catalog)
    {
        string name = catalog.RecipesById.TryGetValue(line.DefinitionId, out var recipe) ? recipe.DisplayName
            : catalog.ProductsById.TryGetValue(line.DefinitionId, out var product) ? product.DisplayName : line.DefinitionId;
        string preference = line.ProductKind == ProductKind.Pancake && line.Sauce != SaucePreference.Normal
            ? line.Sauce == SaucePreference.Light ? "少酱" : "多酱" : "";
        return new(line.DefinitionId, name, line.Quantity, line.ProductKind.ToString(), preference);
    }
}
