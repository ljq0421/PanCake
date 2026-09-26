using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

internal sealed record InterfaceLesson(string Title, string Text, string Target = "");

internal static class InterfaceLessons
{
    internal const string CalendarKey = "interface.calendar.v1", BusinessKey = "interface.business.v1", BookKey = "interface.book.v1";
    internal static readonly string[] Keys = { CalendarKey, BusinessKey, BookKey };
    internal static InterfaceLesson[] Calendar => new[]
    {
        new InterfaceLesson("查看经营日历", "点击日期，查看当天主题、历史最佳收入和满意度。\n未解锁的日期会显示开放条件；没有记录时显示等待开店。", "Date1")
    };
    internal static InterfaceLesson[] Business => new[]
    {
        new InterfaceLesson("今天是第几天", "顶部挂牌的日历旁显示当前营业日。\n当天主题可以在开店前的经营手账中查看。", "DaySign"),
        new InterfaceLesson("留意营业时间", "计时器显示剩余营业时间。\n开门时倒数，打烊后进入收尾；暂停时停止计时。", "TimeSign"),
        new InterfaceLesson("今天赚了多少", "顶部挂牌的金币旁显示本场营业收入进度，已经包含小费。\n具体销售和小费可以在营业账本中查看。", "IncomeSign"),
        new InterfaceLesson("需要歇一会儿", "点击暂停按钮，或按 Esc 暂停营业。\n在暂停菜单中选择继续营业即可返回。", "HudPause")
    };
    internal static InterfaceLesson[] Pendant => new[]
    {
        new InterfaceLesson("挂件里有营业明细", "天津、武汉收到付款后会自动入账。\n点击收银挂件可暂停营业，查看本次营业明细。", "CashPendant")
    };
    internal const string PendantKey = "interface.pendant.v1";
    internal const string ChallengeKey = "interface.challenge.v1";
    internal const string RevenueGoalKey = "interface.revenue-goal.v1";
    internal static InterfaceLesson[] RevenueGoal => new[]
    {
        new InterfaceLesson("达到营业额目标", "金币旁的数字按“本场收入/营业额目标”显示，例如 0/130。\n销售额、小费和本场领取的挑战奖金计入进度；达标后才能进入下一天。", "IncomeSign")
    };
    internal static InterfaceLesson[] Challenge => new[]
    {
        new InterfaceLesson("完成挑战，赚取额外收入", "完成每日挑战，可获得额外金币收入。\n挑战奖金会在营业结算时发放。", "DailyChallengePendant")
    };
    internal static InterfaceLesson[] Book => new[]
    {
        new InterfaceLesson("完成率怎么算", "完成率 = 完成 ÷（完成 + 流失）。\n只统计已结束的客单，错误完成也计入完成。", "BookCompletionRate"),
        new InterfaceLesson("满意度看哪些顾客", "满意度只按已完成订单的顾客计算。\n流失的顾客不计入满意度平均值。", "BookSatisfaction"),
        new InterfaceLesson("留意解锁与升级", "新解锁的内容可以回店查看。\n收摊后，点击可升级贴片查看设备效果和价格；升级下次营业生效。", "UpgradeSticker")
    };
    internal static InterfaceLesson[] Replay(string city) => Calendar.Concat(city is "city:tianjin" or "city:wuhan" or "city:xian" ? Business : Array.Empty<InterfaceLesson>())
        .Concat(city is "city:tianjin" or "city:wuhan" ? Pendant : Array.Empty<InterfaceLesson>()).Concat(Book).ToArray();
    internal static void MarkAllSeen(JourneySettings settings)
    {
        foreach (string key in Keys.Append(PendantKey).Append(ChallengeKey).Append(RevenueGoalKey)) settings.MarkInterfaceLessonSeen(key);
    }
}
