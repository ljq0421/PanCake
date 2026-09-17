namespace ProjectCake.Core;

public partial class SaveService
{
    public IEnumerable<string> CollectedBreakfastIds => IsDemo ? DemoProgress.BreakfastRecords.Keys : Data.BreakfastRecords.Keys;

    public int? BreakfastRecordDay(string id)
    {
        if (IsDemo) return DemoProgress.BreakfastRecords.TryGetValue(id, out var stage) ? DemoContent?.Stage(stage)?.Day : null;
        return Data.BreakfastRecords.TryGetValue(id, out int day) ? day : null;
    }
}
