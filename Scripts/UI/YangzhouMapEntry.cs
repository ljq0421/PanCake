using Godot;
using ProjectCake.Yangzhou;

namespace ProjectCake.UI;

public partial class TianjinMapScreen
{
    private Label _yangzhouState = null!;
    private Button _yangzhouEnter = null!;
    private PanelContainer _yangzhouPanel = null!;
    private void BuildYangzhouEntry(VBoxContainer root)
    {
        _yangzhouPanel = new PanelContainer { CustomMinimumSize = new(0, 110) }; root.AddChild(_yangzhouPanel);
        var row = new HBoxContainer(); row.AddThemeConstantOverride("separation", 22); _yangzhouPanel.AddChild(row);
        row.AddChild(Text("扬", 52, GuangzhouUi.Green));
        row.AddChild(Text("扬州 · 一席早茶\n烫干丝 · 三丁包 · 翡翠烧卖 · 绿杨春", 23, GuangzhouUi.Ink));
        _yangzhouState = Text("", 20, GuangzhouUi.Muted); _yangzhouState.SizeFlagsHorizontal = SizeFlags.ExpandFill; row.AddChild(_yangzhouState);
        _yangzhouEnter = TianjinUi.Button("前往扬州", true, new(180, 58)); _yangzhouEnter.Name = "EnterYangzhou";
        _yangzhouEnter.Pressed += () => CityRequested?.Invoke(YangzhouCatalog.CityId); row.AddChild(_yangzhouEnter);
        if (DeveloperToolsVisible)
        {
            var test = TianjinUi.Button("测试直达扬州", false, new(210, 58));
            test.Pressed += () => CityRequested?.Invoke(YangzhouCatalog.CityId); row.AddChild(test);
        }
    }
    private void RenderYangzhouEntry()
    {
        if (_yangzhouState is null) return;
        var city = _save.Data.Yangzhou; bool unlocked = _save.Data.UnlockedCityIds.Contains(YangzhouCatalog.CityId);
        _yangzhouEnter.Disabled = !unlocked || _save.HasLoadError;
        _yangzhouState.Text = city.Completed ? $"已点亮 {new string('★', city.BestStars)}\n" + (city.BestStars == 3 ? "蟹黄汤包图鉴 · 已收藏" : "可继续挑战三星") : unlocked ? $"路线已开放 · Day {city.HighestUnlockedDay}" : "广州 Day 12 一星后开放";
        _yangzhouPanel.AddThemeStyleboxOverride("panel", GuangzhouUi.Style(city.BestStars == 3 ? new Color("#F1D48B") : city.Completed ? new Color("#C7DFCB") : GuangzhouUi.Paper));
    }
}
