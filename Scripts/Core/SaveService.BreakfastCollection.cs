namespace ProjectCake.Core;

public partial class SaveService
{
    public IEnumerable<string> CollectedBreakfastIds => Data.BreakfastRecords.Keys;

    public BreakfastStatistics BreakfastStatsFor(string id) =>
        Data.BreakfastStats.GetValueOrDefault(id) ?? new();

    public int? BreakfastRecordDay(string id)
    {
        return Data.BreakfastRecords.TryGetValue(id, out int day) ? day : null;
    }
}
