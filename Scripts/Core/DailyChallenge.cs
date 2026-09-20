using ProjectCake.Data;
using ProjectCake.Gameplay;

namespace ProjectCake.Core;

public enum DailyChallengeKind { Service, Perfect, Streak }

/// <summary>Immutable terms captured when preparing a real business run.</summary>
public sealed record DailyChallenge(string CityId, int Day, DailyChallengeKind Kind, int Target, int Reward)
{
    public string Name => Kind switch { DailyChallengeKind.Service => "稳稳接待", DailyChallengeKind.Perfect => "招牌品质", _ => "连续好评" };
    public string Requirement => Kind switch
    {
        DailyChallengeKind.Service => $"正确完成 {Target} 单",
        DailyChallengeKind.Perfect => $"完美完成 {Target} 单",
        _ => $"连续正确 {Target} 单",
    };
    public int Progress(DayResult result) => Kind switch
    {
        DailyChallengeKind.Service => result.CorrectOrders + result.PerfectOrders,
        DailyChallengeKind.Perfect => result.PerfectOrders,
        _ => result.HighestCorrectStreak,
    };
    public bool Achieved(DayResult result) => result.Day == Day && Progress(result) >= Target;
    public string Preview(bool claimed = false) => claimed
        ? $"每日挑战：{Requirement} · 奖励已领取"
        : $"每日挑战：{Requirement} · 奖励 {Reward} 金币";
    public string Live(DayResult result, bool claimed) =>
        $"{Godot.TranslationServer.Translate(Name)} {Math.Min(Target, Progress(result))}/{Target} · "
        + (claimed ? Godot.TranslationServer.Translate("奖励已领取").ToString() : $"+{Reward}");

    public static DailyChallenge? Create(DayConfig config)
    {
        if (config.Day < 2 || config.CityId is not (StableIds.Cities.Tianjin or StableIds.Cities.Wuhan)
            || config.Tutorial.FreezeBusinessClocks) return null;
        var kind = (DailyChallengeKind)((config.Day - 2) % 3);
        int n = config.CustomerCount;
        int target = kind switch
        {
            DailyChallengeKind.Service => (int)Math.Ceiling(n * .8),
            DailyChallengeKind.Perfect => (int)Math.Ceiling(n * .3),
            _ => Math.Min(8, Math.Max(3, (int)Math.Ceiling(n * .4))),
        };
        int reward = config.CityId == StableIds.Cities.Tianjin
            ? config.Day <= 5 ? 20 : config.Day <= 10 ? 30 : 40
            : config.Day <= 4 ? 20 : config.Day <= 8 ? 30 : 40;
        return new(config.CityId, config.Day, kind, target, reward);
    }
}
