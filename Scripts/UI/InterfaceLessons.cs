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
        new InterfaceLesson("今天赚了多少", "顶部挂牌的金币旁显示今日营业收入，已经包含小费。\n具体销售和小费可以在营业账本中查看。", "IncomeSign"),
        new InterfaceLesson("需要歇一会儿", "点击暂停按钮，或按 Esc 暂停营业。\n在暂停菜单中选择继续营业即可返回。", "HudPause")
    };
    internal static InterfaceLesson[] Pendant => new[]
    {
        new InterfaceLesson("挂件里有营业明细", "天津、武汉收到付款后会自动入账。\n点击收银挂件可暂停营业，查看本次营业明细。", "CashPendant")
    };
    internal const string PendantKey = "interface.pendant.v1";
    internal static InterfaceLesson[] Book => new[]
    {
        new InterfaceLesson("完成率怎么算", "完成率 = 完成 ÷（完成 + 流失）。\n只统计已结束的客单，错误完成也计入完成。", "BookCompletionRate"),
        new InterfaceLesson("满意度看哪些顾客", "满意度只按已完成订单的顾客计算。\n流失的顾客不计入满意度平均值。", "BookSatisfaction"),
        new InterfaceLesson("找到今天的热销菜", "热销区域展示本次营业卖得最多的菜品和数量。\n顾客明细页可以查看各笔订单的商品。", "BookBestSeller"),
        new InterfaceLesson("留意解锁与升级", "新解锁的内容可以回店查看。\n收摊后，点击可升级贴片查看设备效果和价格；升级下次营业生效。", "UpgradeSticker")
    };
    internal static InterfaceLesson[] Replay(string city) => Calendar.Concat(city is "city:tianjin" or "city:wuhan" or "city:xian" ? Business : Array.Empty<InterfaceLesson>())
        .Concat(city is "city:tianjin" or "city:wuhan" ? Pendant : Array.Empty<InterfaceLesson>()).Concat(Book).ToArray();
    internal static void MarkAllSeen(JourneySettings settings)
    {
        foreach (string key in Keys.Append(PendantKey)) settings.MarkInterfaceLessonSeen(key);
    }
}
