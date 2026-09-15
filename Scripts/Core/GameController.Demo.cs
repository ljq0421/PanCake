using Godot;
using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Core;

public partial class GameController
{
    private void InitializeDemo()
    {
        var catalog = GetNode<DataCatalog>("/root/DataCatalog");
        _save = GetNode<SaveService>("/root/SaveService");
        _startScreen = GetNode<StartScreen>("UI/StartScreen");
        var controller = GetNode<DayController>(DayControllerPath);
        var screen = GetNode<TianjinDayScreen>(TianjinDayPath);
        _cityHubs[StableIds.Cities.Tianjin] = GetNode<MorningHub>(HubPath);
        screen.ConnectController(controller);
        screen.HubRequested += () => { ShowOnly(_startScreen); _startScreen.PresentCity(StableIds.Cities.Tianjin); };
        _startScreen.Initialize(_save);
        _startScreen.ConfigureCities(catalog, null);
        _startScreen.BusinessRequested += (city, day) => StartCityBusiness(city, day);
        _startScreen.DemoTutorialRequested += () =>
        {
            screen.ForceDemoTutorial = true;
            StartCityBusiness(StableIds.Cities.Tianjin, Math.Max(1, _startScreen.SelectedDay));
        };
        _startScreen.UpgradeRequested += (city, id) =>
        {
            bool ok = _save.TryPurchase(city, id, catalog, out string error);
            _startScreen.RefreshCityPage(); _startScreen.ShowError(ok ? "设备已升级，下次营业生效。" : error);
        };
        _startScreen.NewGameRequested += () =>
        {
            if (!catalog.IsValid) { _startScreen.ShowError("试玩配置无法读取，请重新安装后重试。"); return; }
            if (!_save.ResetProgress(out string error)) { _startScreen.ShowError(error); return; }
            _startScreen.PresentCity(StableIds.Cities.Tianjin);
        };
        _startScreen.ContinueRequested += () =>
        {
            if (_save.CanContinue && catalog.IsValid) _startScreen.PresentCity(StableIds.Cities.Tianjin);
            else _startScreen.ShowError("试玩存档或配置无法读取，请检查后重试。");
        };
        _startScreen.QuitRequested += () => GetTree().Quit();
        ShowOnly(_startScreen); _startScreen.Present();
        if (!catalog.IsValid) _startScreen.ShowError("试玩配置无法读取，请重新安装后重试。");
    }
}
