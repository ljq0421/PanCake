namespace ProjectCake.Core;

public sealed class BreakfastStatistics
{
    public int Delivered { get; set; }
    public int Perfect { get; set; }
    [System.Text.Json.Serialization.JsonIgnore] public bool Skilled => Delivered >= 20;
    [System.Text.Json.Serialization.JsonIgnore] public bool PerfectStamp => Perfect >= 10;

    public static void Validate(Dictionary<string, BreakfastStatistics>? values)
    {
        if (values is null || values.Any(p => !DemoBreakfastCollection.Cards.Any(c => c.Id == p.Key)
            || p.Value is null || p.Value.Delivered < 0 || p.Value.Perfect < 0
            || p.Value.Perfect > p.Value.Delivered || p.Key == "soy_milk" && p.Value.Perfect != 0))
            throw new InvalidDataException("Invalid breakfast statistics.");
    }

    public static void Merge(Dictionary<string, BreakfastStatistics> target,
        Dictionary<string, BreakfastStatistics> pending, string cityId)
    {
        foreach (var card in DemoBreakfastCollection.Cards.Where(c => c.CityId == cityId))
        {
            if (!pending.TryGetValue(card.Id, out var addition)) continue;
            if (!target.TryGetValue(card.Id, out var value)) target[card.Id] = value = new();
            value.Delivered = (int)Math.Min(int.MaxValue, (long)value.Delivered + addition.Delivered);
            value.Perfect = (int)Math.Min(int.MaxValue, (long)value.Perfect + addition.Perfect);
        }
    }
}
