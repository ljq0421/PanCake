using Godot;
using ProjectCake.Yangzhou;

namespace ProjectCake.UI;

public partial class TianjinMapScreen
{
    private Label _yangzhouState = null!;
    private Button _yangzhouEnter = null!;
    private PanelContainer _yangzhouPanel = null!;
    private void RenderYangzhouEntry()
    {
        if (_yangzhouState is null) return;
        var city = _save.Data.Yangzhou; bool unlocked = _save.Data.UnlockedCityIds.Contains(YangzhouCatalog.CityId);
        _yangzhouEnter.Disabled = !unlocked || _save.HasLoadError;
        _yangzhouState.Text = city.Completed ? $"已点亮 {new string('★', city.BestStars)}\n" + (city.BestStars == 3 ? "蟹黄汤包图鉴 · 已收藏" : "可继续挑战三星") : unlocked ? $"路线已开放 · Day {city.HighestUnlockedDay}" : "广州 Day 12 一星后开放";
        if (_yangzhouPanel.GetThemeStylebox("panel") is StyleBoxFlat style)
            style.BgColor = city.BestStars == 3 ? new Color("#F1D48B") : city.Completed ? new Color("#C7DFCB") : GuangzhouUi.Paper;
    }
}
