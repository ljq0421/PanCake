using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class TianjinMapScreen
{
    private Label _guangzhouState = null!;
    private Button _guangzhouEnter = null!;
    private void RenderGuangzhouEntry()
    {
        if (_guangzhouState is null) return;
        bool unlocked = _save.Data.UnlockedCityIds.Contains(StableIds.Cities.Guangzhou);
        var city = _save.Data.Guangzhou;
        _guangzhouEnter.Disabled = !unlocked || _save.HasLoadError;
        _guangzhouState.Text = city.Completed ? $"已点亮 {new string('★', city.BestStars)}\n最佳成绩已保存" : unlocked ? $"路线已开放\n广州 Day {city.HighestUnlockedDay}" : "西安 Day 12 一星后开放\n可使用临时测试入口";
    }
}
