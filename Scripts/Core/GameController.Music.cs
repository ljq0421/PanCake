using ProjectCake.Data;
using ProjectCake.Gameplay;
using ProjectCake.UI;

namespace ProjectCake.Core;

public partial class GameController
{
    private void InitializeMusic()
    {
        var controller = GetNode<DayController>(DayControllerPath);
        var music = new DemoMusicPlayer { Name = "DemoMusic" };
        AddChild(music);
        music.Bind(() =>
        {
            if (GetNodeOrNull<WuhanUnlockPresentation>("WuhanUnlockPresentation") is { } unlock)
                return (unlock.WuhanMusicReady ? StableIds.Cities.Wuhan : StableIds.Cities.Tianjin, false);
            bool business = GetNode<TianjinDayScreen>(TianjinDayPath).IsVisibleInTree()
                || GetNode<WuhanDayScreen>(WuhanDayPath).IsVisibleInTree()
                || _xianDay?.IsVisibleInTree() == true || _guangzhouDay?.IsVisibleInTree() == true;
            if (_yangzhouDay?.IsVisibleInTree() == true)
                return (StableIds.Cities.Yangzhou, _yangzhouDay.Session?.Paused == true);
            string key = business ? controller.CurrentConfig?.CityId ?? "home"
                : _startScreen.Page is JourneyPage.City or JourneyPage.Ledger or JourneyPage.Upgrades or JourneyPage.Collection
                    || _startScreen.Page == JourneyPage.Opening && _startScreen.SelectedCityId == StableIds.Cities.Wuhan
                    ? _startScreen.SelectedCityId : "home";
            return (key, business ? controller.IsPaused : _startScreen.ModalOpen);
        });
    }
}
