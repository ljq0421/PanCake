using Godot;
using ProjectCake.UI;
using ProjectCake.Data;

namespace ProjectCake.Core;

public partial class GameController
{
    private Control? _businessBackdrop;
    private ProcessModeEnum _backdropProcessMode;
    private Control.MouseBehaviorRecursiveEnum _backdropMouse;
    private Control.FocusBehaviorRecursiveEnum _backdropFocus;
    private int _startScreenZ;

    private void ReturnFromBusiness(string city, bool showCompletion = true, bool retainWorkbench = true)
    {
        if (!retainWorkbench)
        {
            ShowOnly(_startScreen);
            _startScreen.PresentHome();
            _startScreen.PresentCity(city, fromHome: true);
            return;
        }
        string path = city switch
        {
            StableIds.Cities.Tianjin => "UI/TianjinDayScreen",
            StableIds.Cities.Wuhan => "UI/WuhanDayScreen",
            StableIds.Cities.Xian => "UI/XianDayScreen",
            StableIds.Cities.Guangzhou => "UI/GuangzhouDayScreen",
            StableIds.Cities.Yangzhou => "UI/YangzhouDayScreen",
            _ => throw new ArgumentOutOfRangeException(nameof(city))
        };
        _startScreen.ReleaseCityBackdrop();
        var screen = GetNode<Control>(path);
        _businessBackdrop = screen;
        _backdropProcessMode = screen.ProcessMode;
        _backdropMouse = screen.MouseBehaviorRecursive;
        _backdropFocus = screen.FocusBehaviorRecursive;
        _startScreenZ = _startScreen.ZIndex;
        screen.ProcessMode = ProcessModeEnum.Disabled;
        screen.MouseBehaviorRecursive = Control.MouseBehaviorRecursiveEnum.Disabled;
        screen.FocusBehaviorRecursive = Control.FocusBehaviorRecursiveEnum.Disabled;
        _startScreen.ZIndex = 300;
        _startScreen.CityBackdropReleased += ReleaseBusinessBackdrop;
        _startScreen.RetainCityBackdrop(city);
        foreach (Control page in GetNode("UI").GetChildren().OfType<Control>())
            page.Visible = page == screen || page == _startScreen;
        GetNode<Node2D>("ShopRoot").Visible = true;
        if (showCompletion && _save.TakeJourneyCompletion() is { } completed)
            _startScreen.PresentCompletion(completed, () => _startScreen.PresentCity(city), overCityWorkbench: true);
        else _startScreen.PresentCity(city);
    }

    private void ReleaseBusinessBackdrop()
    {
        _startScreen.CityBackdropReleased -= ReleaseBusinessBackdrop;
        if (_businessBackdrop is not { } screen) return;
        screen.Hide();
        screen.ProcessMode = _backdropProcessMode;
        screen.MouseBehaviorRecursive = _backdropMouse;
        screen.FocusBehaviorRecursive = _backdropFocus;
        _businessBackdrop = null;
        _startScreen.ZIndex = _startScreenZ;
        GetNode<Node2D>("ShopRoot").Hide();
    }
}
