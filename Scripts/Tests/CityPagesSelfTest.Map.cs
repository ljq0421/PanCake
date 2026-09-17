using Godot;
using ProjectCake.Core;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Tests;

public partial class CityPagesSelfTest
{
    // Focused entry point: CityPagesSelfTest.tscn -- --map-only [--demo-pilot] [--capture].
    private async Task ReviewWorldMap()
    {
        bool demo = _save.IsDemo;
        string locale = GetNode<JourneySettings>("/root/JourneySettings").Language;
        string prefix = $"map-{(demo ? "demo" : "full")}-{locale}-";
        var playable = JourneyModel.Cities.Where(c => _save.ChapterLength(c.Id) > 0).ToArray();
        int total = playable.Length;
        _path += ".map-new";
        _save.UsePathForTests(_path);
        _screen.PresentMap(); await Frames();
        Check(!_save.CanContinue && Find<Label>("MapLitCount").Text == $"1/{total}", "missing save shows the first unlocked city");
        Check(Find<Label>("SummaryCity").Text == "天津" && Find<Label>("MapSelection").Text == "当前城市", "missing save selects Tianjin");
        CheckMapLayout(); await Capture(prefix + "no-save");
        await MapClick("Node0");
        Check(_screen.Page == JourneyPage.Opening && !File.Exists(_path), "Tianjin node starts a new journey without creating a save early");
        Check(_save.ResetProgress(out _), "isolated map save created");
        _screen.PresentMap(); await Frames();
        Check(Find<Label>("MapLitCount").Text == $"1/{total}" && Find<Label>("MapNextCity").Text == "武汉", "initial route and unlock count");
        Check(Find<TextureRect>("MapLandmark天津").Texture is AtlasTexture tianjin && tianjin.Atlas.ResourcePath.EndsWith("早餐地图-天津.png")
            && Find<TextureRect>("MapLandmark武汉").Texture is AtlasTexture wuhan && wuhan.Atlas.ResourcePath.EndsWith("早餐地图-武汉.png"), "current and next city use supplied landmarks");
        CheckMapLayout(); await Capture(prefix + "initial");
        string persisted = File.ReadAllText(_path);

        await MapClick("Node1");
        if (_screen.DeveloperToolsVisible)
        {
            Check(_screen.Page == JourneyPage.City && _screen.SelectedCityId == StableIds.Cities.Wuhan, "developer node previews locked city");
            _screen._Input(new InputEventKey { Keycode = Key.Escape, Pressed = true }); await Frames();
        }
        else Check(_screen.Page == JourneyPage.Map, "locked city node only displays its goal");
        Check(Find<Label>("MapSelection").Text == "所选城市" && Find<Label>("SummaryCity").Text == "武汉", "mouse selects a locked city without entering");
        Check(Find<Label>("SummaryGoal").Text == "完成天津章节后开放", "locked city explains its prerequisite");
        Check(Find<Label>("MapLitCount").Text == $"1/{total}", "selection does not unlock a city");
        CheckMapLayout(); await Capture(prefix + "locked");

        Find<Button>("Node0").GrabFocus();
        _screen._Input(new InputEventKey { Keycode = Key.Tab, Pressed = true });
        Check(GetViewport().GuiGetFocusOwner()?.Name == "Node1", "keyboard traverses map nodes");
        await MapClick("Node0");
        Check(_screen.Page == JourneyPage.City && _screen.SelectedCityId == StableIds.Cities.Tianjin, "Tianjin node directly opens its continue page");
        Check(Find<Control>("ContinuePostcard") is not null && !Find<Button>("OpenBusiness").Disabled
            && _screen.SelectedDay == 1, "Tianjin continue page shows the saved business progress");
        await Capture(prefix + "tianjin-continue");
        _screen._Input(new InputEventKey { Keycode = Key.Escape, Pressed = true }); await Frames();
        Check(_screen.Page == JourneyPage.Map && Find<Button>("Node0").HasFocus(), "Escape returns to selected map node");
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Enter, Pressed = true }, true);
        await Frames();
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Enter, Pressed = false }, true);
        await Frames();
        Check(_screen.Page == JourneyPage.City && _screen.SelectedCityId == StableIds.Cities.Tianjin, "keyboard activation opens Tianjin continue page");
        _screen._Input(new InputEventKey { Keycode = Key.Escape, Pressed = true }); await Frames();
        Check(_screen.Page == JourneyPage.Map && Find<Button>("Node0").HasFocus(), "city Escape returns to the Tianjin map node");
        await Capture(prefix + "tianjin-return");
        await MapClick("Back"); Check(_screen.Page == JourneyPage.Home, "map Back returns to its source");

        _save.Data.UnlockedCityIds.Add(StableIds.Cities.Wuhan);
        _save.Data.GetCity(StableIds.Cities.Tianjin).Completed = true;
        _save.Data.LastVisitedCityId = StableIds.Cities.Wuhan;
        _screen.PresentMap(); await Frames();
        Check(Find<Label>("SummaryCity").Text == "武汉" && Find<Label>("MapSelection").Text == "当前城市", "map initially selects saved current city");
        Check(Find<Label>("MapLitCount").Text == $"2/{total}" && Find<Label>("MapNextCity").Text == "西安", "next stop and counts follow progress");
        CheckMapLayout(); await Capture(prefix + "progress");
        Check(File.ReadAllText(_path) == persisted, "map selection leaves persisted progress untouched");
        await MapClick("Node1");
        Check(_screen.Page == JourneyPage.City && _screen.SelectedCityId == StableIds.Cities.Wuhan, "unlocked Wuhan node opens its city page");
        if (demo)
        {
            Check(_save.DemoProgress.LastStartedStageId == _save.DemoContent!.Stage(StableIds.Cities.Wuhan, _screen.SelectedDay)!.Id,
                "entering demo Wuhan preserves existing stage recording");
            persisted = File.ReadAllText(_path);
        }
        _screen._Input(new InputEventKey { Keycode = Key.Escape, Pressed = true }); await Frames();
        Check(_screen.Page == JourneyPage.Map && Find<Button>("Node1").HasFocus(), "city return restores Wuhan selection and focus");
        if (demo)
        {
            Check(Find<Label>("MapNextLabel").Text == "下一站预告", "demo marks the next city as a preview");
            await MapClick("Node2");
            Check(_screen.Page == JourneyPage.Map && Find<Label>("SummaryGoal").Text == "下一站预告 · 本次不可营业", "demo preview is explicitly unavailable");
            Check(Find<Label>("MapLitCount").Text == $"2/{total}", "demo preview excluded from both counts");
            Check(!JourneyModel.MapSummary(_save, JourneyModel.Cities[2], true).CanView, "developer preview cannot bypass demo boundary");
            CheckMapLayout(); await Capture(prefix + "preview");
        }
        else
        {
            foreach (var city in playable)
                if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
            _screen.PresentMap(); await Frames();
            for (int i = 0; i < playable.Length; i++)
            {
                await MapClick("Node" + i);
                Check(_screen.Page == JourneyPage.City && _screen.SelectedCityId == playable[i].Id, "unlocked node opens city " + playable[i].Name);
                _screen._Input(new InputEventKey { Keycode = Key.Escape, Pressed = true }); await Frames();
                Check(Find<Label>("SummaryCity").Text == playable[i].Name && Find<Button>("Node" + i).HasFocus(), "return preserves city selection and focus " + playable[i].Name);
                CheckMapLayout();
            }
            Check(Find<Label>("MapNextLabel").Text == "最终站", "last city has no invented next destination");
            await Capture(prefix + "final-stop");
        }
        foreach (var city in playable) _save.Data.GetCity(city.Id).Completed = true;
        _screen.PresentMap(); await Frames();
        Check(Find<Label>("SummaryGoal").Text.Contains("回访"), "completed route offers revisiting shops");
        Check(Find<Label>("MapLitCount").Text == $"{total}/{total}", "completed count uses playable roster");
        CheckMapLayout(); await Capture(prefix + "complete");
        Check(File.ReadAllText(_path) == persisted, "map browsing leaves the persisted progress untouched");
        _save.Data.LastVisitedCityId = StableIds.Cities.Wuhan;
        _screen.PresentMap(); await Frames();
        Check(Find<Label>("SummaryCity").Text == "武汉", "cross-city navigation starts on Wuhan");
        await MapClick("Node0");
        Check(_screen.Page == JourneyPage.City && _screen.SelectedCityId == StableIds.Cities.Tianjin, "Tianjin node opens Tianjin when the saved current city is Wuhan");
        _screen._Input(new InputEventKey { Keycode = Key.Escape, Pressed = true }); await Frames();
        Check(_screen.Page == JourneyPage.Map && Find<Label>("SummaryCity").Text == "天津"
            && Find<Button>("Node0").HasFocus(), "cross-city return preserves Tianjin selection and focus");
        await MapClick("Home"); Check(_screen.Page == JourneyPage.Home, "map Home opens home");
        _screen.PresentMap(() => _screen.PresentCity(StableIds.Cities.Tianjin)); await Frames();
        await MapClick("Back"); Check(_screen.Page == JourneyPage.City, "map respects the caller return destination");

        if (!demo)
        {
            _screen.PresentCompletion(StableIds.Cities.Tianjin, () => _screen.PresentHome());
            await ToSignal(GetTree().CreateTimer(2.15), SceneTreeTimer.SignalName.Timeout);
            var node = Find<Button>("Node1"); var glow = Find<TextureRect>("MapUnlockGlow");
            Check(glow.Position.DistanceTo(node.Position + new Vector2(-10, -45)) < 5, "unlock glow shares the map node coordinates");
            var route = Find<TextureRect>("MapRoute1");
            Check((route.Position + Vector2.Right.Rotated(route.Rotation) * route.Size.X).DistanceTo(node.Position + new Vector2(65, 40)) < 5, "route terminates at the next map marker");
            await Capture(prefix + "unlock");
            await MapClick("Skip"); Check(_screen.Page == JourneyPage.City, "unlock presentation still enters next city");
        }
    }

    private async Task MapClick(string name)
    {
        var button = Find<Button>(name);
        Vector2 at = button.GetGlobalTransformWithCanvas() * (button.Size / 2);
        GetViewport().PushInput(new InputEventMouseMotion { Position = at, GlobalPosition = at }, true);
        GetViewport().PushInput(new InputEventMouseButton { Position = at, GlobalPosition = at, ButtonIndex = MouseButton.Left, Pressed = true }, true);
        GetViewport().PushInput(new InputEventMouseButton { Position = at, GlobalPosition = at, ButtonIndex = MouseButton.Left, Pressed = false }, true);
        await Frames();
    }

    private void CheckMapLayout()
    {
        Check(_screen.FindChildren("MapJourneyCard", "", true, false).Count == 0
            && _screen.FindChildren("PageTitle", "", true, false).Count == 0, "old title and side card removed");
        var strip = Find<Panel>("MapJourneyStrip"); var map = Find<TextureRect>("MapFrame");
        var world = Find<TextureRect>("WorldMapArt");
        Vector2 native = world.Texture.GetSize();
        Check(Math.Abs(world.Size.X / native.X - world.Size.Y / native.Y) < .0001f,
            "world map preserves the original artwork proportions");
        Check(Find<TextureRect>("MapJourneyStripArt").Texture is AtlasTexture stripArt && stripArt.Atlas.ResourcePath.EndsWith("世界早餐地图解锁.png"), "map uses supplied strip artwork");
        Check(strip.Position.Y >= map.Position.Y + map.Size.Y, "information strip is below the map");
        Check(_screen.FindChildren("EnterCity", "Button", true, false).Count == 0, "separate view-city button removed");
        Check(Math.Abs(strip.Position.X + strip.Size.X / 2 - 960) < 1, "bottom strip is horizontally centered");
        foreach (string name in new[] { "MapSelection", "SummaryCity", "MapNextLabel", "MapNextCity", "MapLitLabel", "MapLitCount", "SummaryGoal" })
        {
            var label = Find<Label>(name);
            Check(label.Position.X >= 0 && label.Position.Y >= 0 && label.Position.X + label.Size.X <= strip.Size.X
                && label.Position.Y + label.Size.Y <= strip.Size.Y, name + " fits inside strip");
            Check(label.GetLineCount() <= (name == "SummaryGoal" ? 3 : 1), name + " stays within its line budget");
            if (name != "SummaryGoal")
                Check(label.GetThemeFont("font").GetStringSize(label.Tr(label.Text), HorizontalAlignment.Left, -1,
                    label.GetThemeFontSize("font_size")).X <= label.Size.X + 1, name + " translated text fits");
        }
        if (GetNode<JourneySettings>("/root/JourneySettings").Language == "en")
        {
            Check(Find<Label>("MapLitLabel").Tr("已点亮城市") == "Cities unlocked", "English map labels translated");
            string goal = Find<Label>("SummaryGoal").Tr(Find<Label>("SummaryGoal").Text);
            Check(!goal.Any(c => c is >= '\u4e00' and <= '\u9fff'), "English dynamic goal translated");
        }
    }
}
