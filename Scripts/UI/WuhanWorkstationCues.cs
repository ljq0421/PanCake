using Godot;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

public partial class WuhanWorkstationView
{
    internal string DoupiSupplyHint => _doupi is null ? "" : _doupi.State switch
    {
        DoupiState.Burnt => "长按右键拖入垃圾桶后再做一锅",
        DoupiState.Cut => "已收火 · 成品待入盘",
        DoupiState.Cutting => $"已收火 · 已切 {_doupi.CompletedCuts}/4 刀",
        DoupiState.Spreading => $"按住铺开 · {_doupi.Coverage:P0}",
        DoupiState.Empty => PendingDoupiDemand > _stock.Count ? "订单缺豆皮，做一锅" : "",
        _ => "制作中",
    };

    private string HoverDescription(string target)
    {
        if (target.StartsWith("ingredient"))
        {
            int index = int.Parse(target[^1..]);
            string timing = index == 3 ? "搅拌完成后点击加入；无需补货"
                : index == 0 ? "放入熟面后点击加入；无需补货" : "开始拌面前点击加入；无需补货";
            return $"{new[] { "基础调味", "葱花", "辣油", "牛肉" }[index]}\n{timing}";
        }
        if (target.StartsWith("basket"))
        {
            var state = _cooker.Baskets[int.Parse(target[^1..])].State;
            return state switch
            {
                NoodleBasketState.Empty => "拖入生面",
                NoodleBasketState.Cooking => "正在烫面；漏勺亮起后向上提篮",
                NoodleBasketState.Soft => "面条偏软；向上提篮后拖到空碗",
                NoodleBasketState.Overcooked => "面条过熟；向上提篮后拖到空碗",
                NoodleBasketState.Raised or NoodleBasketState.Draining => "沥水中；可拖到空碗上方自动等待",
                NoodleBasketState.Drained => "已沥干；拖到空碗",
                _ => "最佳火候；向上提篮后拖到空碗",
            };
        }
        return target switch
        {
            "raw" => "生面无限供应，拖进空漏勺",
            "bowl" => "基础调味、辣油和葱花在拌面前加入；划动拌匀后可加牛肉，再拖给顾客",
            "stock" => "豆皮拖给顾客，按订单所需数量出餐",
            "pan" when _doupi is null => "豆皮锅 · Day 4 解锁",
            "pan" when _doupi.State == DoupiState.Burnt => "豆皮焦糊；长按右键拖入底部垃圾桶",
            "batter" => "拖一勺浆到空锅，松手倒入",
            "doupi_egg" => "倒浆后点击蛋液容器，自动舀取倒入并摊开",
            "filling" => "翻面后拖馅入锅，继续按住铺开",
            "pan" when _doupi?.State == DoupiState.Batter => "点击锅右上方金黄色蛋液容器",
            "pan" when _doupi?.State == DoupiState.Flipped => "从馅碗拖入一份馅，继续按住铺开",
            "pan" when _doupi?.State == DoupiState.Spreading => "按住锅面铺开馅料；松手保留进度",
            "pan" when _doupi?.State is DoupiState.ReadyToCut or DoupiState.Cutting or DoupiState.Overbrowned => "横一刀、竖一刀；竖划同时切三条，第一刀后收火",
            "pan" when _doupi?.State == DoupiState.ReadyToFlip => "按住锅面向上划动，松手翻面",
            "pan" when _doupi?.State == DoupiState.Empty => "从浆碗拖一勺浆到空锅",
            "pan" => "正在煎制；观察火候提示",
            _ => "",
        };
    }

}
