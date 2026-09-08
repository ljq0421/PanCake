using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class TianjinMapScreen
{
    private Label _guangzhouState = null!;
    private Button _guangzhouEnter = null!;
    private void BuildGuangzhouEntry(VBoxContainer root)
    {
        var panel = new PanelContainer { CustomMinimumSize = new(0, 110) };
        panel.AddThemeStyleboxOverride("panel", GuangzhouUi.Style(GuangzhouUi.Paper)); root.AddChild(panel);
        var row = new HBoxContainer(); row.AddThemeConstantOverride("separation", 22); panel.AddChild(row);
        var emblem = Text("广", 52, GuangzhouUi.Green); row.AddChild(emblem);
        var title = Text("广州 · 蒸汽早茶\n肠粉 · 烧卖 · 虾饺 · 早茶", 24, GuangzhouUi.Ink); row.AddChild(title);
        _guangzhouState = Text("", 20, GuangzhouUi.Muted); _guangzhouState.SizeFlagsHorizontal = SizeFlags.ExpandFill; row.AddChild(_guangzhouState);
        _guangzhouEnter = TianjinUi.Button("前往广州", true, new(180, 58));
        _guangzhouEnter.Pressed += () => CityRequested?.Invoke(StableIds.Cities.Guangzhou); row.AddChild(_guangzhouEnter);
        var test = TianjinUi.Button("测试直达广州", false, new(210, 58));
        test.TooltipText = "临时入口：从广州Day 1正常推进并保存，不改变正式城市解锁状态。";
        test.Pressed += () => CityRequested?.Invoke(StableIds.Cities.Guangzhou); row.AddChild(test);
    }
    private void RenderGuangzhouEntry()
    {
        if (_guangzhouState is null) return;
        bool unlocked = _save.Data.UnlockedCityIds.Contains(StableIds.Cities.Guangzhou);
        var city = _save.Data.Guangzhou;
        _guangzhouEnter.Disabled = !unlocked || _save.HasLoadError;
        _guangzhouState.Text = city.Completed ? $"已点亮 {new string('★', city.BestStars)}\n最佳成绩已保存" : unlocked ? $"路线已开放\n广州 Day {city.HighestUnlockedDay}" : "西安 Day 12 一星后开放\n可使用临时测试入口";
    }
}
