using ProjectCake.Data;
using ProjectCake.Pancake;

namespace ProjectCake.Gameplay;

public sealed class PracticeSession
{
    private readonly RecipeData[] _sequence;

    public PracticeSession(IEnumerable<RecipeData> sequence, int targetCount = 30)
    {
        _sequence = sequence.ToArray();
        if (_sequence.Length == 0)
        {
            throw new ArgumentException("练习配方序列不能为空。", nameof(sequence));
        }

        TargetCount = targetCount > 0 ? targetCount : throw new ArgumentOutOfRangeException(nameof(targetCount));
    }

    public int TargetCount { get; }
    public int CompletedCount { get; private set; }
    public int PerfectCount { get; private set; }
    public int OverdoneCount { get; private set; }
    public int ErrorCount { get; private set; }
    public double ElapsedSeconds { get; private set; }
    public bool IsFinished => CompletedCount >= TargetCount;
    public RecipeData CurrentTarget => _sequence[CompletedCount % _sequence.Length];
    public RecipeData NextTarget => _sequence[(CompletedCount + 1) % _sequence.Length];

    public void Tick(double deltaSeconds)
    {
        if (!IsFinished && deltaSeconds > 0)
        {
            ElapsedSeconds += deltaSeconds;
        }
    }

    public PancakeDeliveryResult TryDeliver(PancakeStateMachine pancake)
    {
        PancakeDeliveryResult result = pancake.TryDeliver(CurrentTarget);
        if (!result.Success)
        {
            if (result.Error == PancakeActionError.RecipeMismatch)
            {
                ErrorCount++;
            }

            return result;
        }

        CompletedCount++;
        if (result.Quality == PancakeQuality.Perfect)
        {
            PerfectCount++;
        }
        else if (result.Quality == PancakeQuality.Overdone)
        {
            OverdoneCount++;
        }

        return result;
    }

    public void Reset()
    {
        CompletedCount = 0;
        PerfectCount = 0;
        OverdoneCount = 0;
        ErrorCount = 0;
        ElapsedSeconds = 0;
    }
}
