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
        var wuhan = GetNode<WuhanDayScreen>(WuhanDayPath);
        _cityHubs[StableIds.Cities.Wuhan] = GetNode<WuhanHub>(WuhanHubPath);
        wuhan.ConnectController(controller);
        ConnectBusinessContinuation(screen.BusinessDetails, StableIds.Cities.Tianjin);
        ConnectBusinessContinuation(wuhan.BusinessDetails, StableIds.Cities.Wuhan);
        void ReturnFromBusiness(string city)
        {
            if (_save.TakeJourneyCompletion() is { } completed) PresentCompletionOverHub(_cityHubs[city], completed);
            else { ShowOnly(_startScreen); _startScreen.PresentCity(city); }
        }
        screen.HubRequested += () => ReturnFromBusiness(StableIds.Cities.Tianjin);
        wuhan.HubRequested += () => ReturnFromBusiness(StableIds.Cities.Wuhan);
        wuhan.HomeRequested += () => { ShowOnly(_startScreen); _startScreen.PresentHome(); };
        _startScreen.Initialize(_save);
        _startScreen.ConfigureCities(catalog, null);
        _startScreen.BusinessRequested += (city, day) => StartCityBusiness(city, day);
        _startScreen.DemoTutorialRequested += () =>
        {
            if (_startScreen.SelectedCityId == StableIds.Cities.Wuhan) wuhan.ForceDemoTutorial = true;
            else screen.ForceDemoTutorial = true;
            StartCityBusiness(_startScreen.SelectedCityId, Math.Max(1, _startScreen.SelectedDay));
        };
        _startScreen.UpgradeRequested += (city, id) =>
        {
            bool ok = _save.TryPurchase(city, id, catalog, out string error);
            _startScreen.RefreshCityPage(); _startScreen.ShowError(ok ? "设备已升级，下次营业生效。" : error);
        };
        _startScreen.NewGameRequested += slotId => CreateJourney(slotId, startBusiness: false);
        _startScreen.NewGameBusinessRequested += slotId => CreateJourney(slotId, startBusiness: true);
        _startScreen.FirstStationDepartureRequested += () => StartCityBusiness(StableIds.Cities.Tianjin, 1, firstJourneyDeparture: true);
        _startScreen.ContinueRequested += () =>
        {
            if (_save.CanContinue && catalog.IsValid) _startScreen.PresentCity(_save.ContinueCityId, fromHome: true);
            else _startScreen.ShowError("试玩存档或配置无法读取，请检查后重试。");
        };
        _startScreen.QuitRequested += () => GetTree().Quit();
        InitializeMusic();
        ShowOnly(_startScreen); _startScreen.Present();
        if (_save.DemoMigrationRetryAvailable) _startScreen.ShowError("旧试玩存档升级失败，请检查写入权限后重试。原存档已保留。");
        if (!catalog.IsValid) _startScreen.ShowError("试玩配置无法读取，请重新安装后重试。");
    }
}
