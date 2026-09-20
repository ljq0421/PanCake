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
        string slotRoot = Path.Combine(Path.GetDirectoryName(_path)!, "map-slots");
        _save.UseSlotsForTests(slotRoot, demo);
        _path = Path.Combine(slotRoot, "slot-1.json");
        _screen.PresentMap(); await Frames();
        Check(!_save.CanContinue && JourneyModel.MapCityUnlocked(_save, JourneyModel.Cities[0]), "missing save shows first unlocked city");
        Check(!File.Exists(_path), "map browsing never creates a save");
        CheckMapLayout(); await Capture(prefix + "no-save");

        // Failure must retain the map, release the input guard, and allow a successful retry.
        Directory.CreateDirectory(_path);
        await MapClick("Node0");
        Check(_screen.Visible && _screen.Page == JourneyPage.Map && !_save.CanContinue
            && Find<Label>("Status").Text.Length > 0, "failed map creation stays on map");
        Directory.Delete(_path);
        await MapClick("Node0");
        Check(_save.ActiveSlotId == 1 && !_screen.Visible
            && _main.GetNode<DayController>("DayController").CurrentConfig?.Day == 1,
            "empty map creates first slot and starts Tianjin day one");
        _main.OpenCity(StableIds.Cities.Tianjin); _screen.PresentMap(); await Frames();
        Check(Find<Button>("Node0").HasFocus(), "map focuses current city");
        CheckMapLayout(); await Capture(prefix + "initial");
        string persisted = File.ReadAllText(_path);
        await MapClick("Node1");
        if (_screen.DeveloperToolsVisible)
        {
            Check(!_screen.Visible, "developer map entry starts available preview");
            _main.OpenCity(StableIds.Cities.Wuhan, true); _screen.PresentMap(); await Frames();
        }
        else
        {
            Check(_screen.Visible && _screen.Page == JourneyPage.Map
                && Find<Button>("Node1").GetNode<Label>("State").Text == "尚未抵达", "locked city stays on map with prerequisite");
            Check(File.ReadAllText(_path) == persisted, "locked selection does not modify save");
            CheckMapLayout(); await Capture(prefix + "locked");
        }

        Find<Button>("Node0").GrabFocus();
        _screen._Input(new InputEventKey { Keycode = Key.Tab, Pressed = true });
        Check(GetViewport().GuiGetFocusOwner()?.Name == "Node1", "keyboard traverses map nodes");
        await Frames();
        while (JourneyTransition.For(this).Active) await Frames();
        Find<Button>("Node0").GrabFocus();
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Enter, Pressed = true }, true);
        await Frames();
        GetViewport().PushInput(new InputEventKey { Keycode = Key.Enter, Pressed = false }, true);
        await Frames();
        Check(!_screen.Visible && _screen.SelectedDay == 1, "Enter on city starts business");
        _main.OpenCity(StableIds.Cities.Tianjin); _screen.PresentMap(); await Frames();
        await MapClick("Home"); Check(_screen.Page == JourneyPage.Home, "map returns home");
        await MapClick("Continue"); Check(_screen.Page == JourneyPage.Map, "continue opens map");

        foreach (var city in playable)
        {
            if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
            var p = _save.Data.GetCity(city.Id);
            p.HighestUnlockedDay = Math.Min(3, _save.ChapterLength(city.Id));
        }
        Check(_save.TrySave(out _), "persist unlocked city fixture");
        for (int i = 0; i < playable.Length; i++)
        {
            var city = playable[i];
            _screen.PresentMap(); await Frames();
            int requests = 0;
            void CountRequest(string id, int day) { requests++; }
            _screen.BusinessRequested += CountRequest;
            var node = Find<Button>("Node" + i);
            node.EmitSignal(Button.SignalName.Pressed);
            node.EmitSignal(Button.SignalName.Pressed);
            Check(requests == 1 && !_screen.Visible && _screen.SelectedCityId == city.Id
                && _screen.SelectedDay == Math.Min(3, _save.ChapterLength(city.Id)),
                "city click starts latest day once " + city.Name);
            _screen.BusinessRequested -= CountRequest;
            Check(_save.ContinueCityId == city.Id, "business records selected city " + city.Name);
            _main.OpenCity(city.Id); _screen.PresentMap(); await Frames();
            Check(Find<Button>("Node" + i).HasFocus(), "map restores current city focus " + city.Name);
            CheckMapLayout();
        }
        await Capture(prefix + "progress");
        if (demo)
        {
            await MapClick("Node2");
            Check(_screen.Visible && _screen.Page == JourneyPage.Map
                && Find<Button>("Node2").GetNode<Label>("State").Text == "下一站预告", "demo preview cannot start business");
            Check(_screen.FindChildren("Node*", "Button", true, false).Count == 3, "demo keeps two playable cities and one preview");
            CheckMapLayout(); await Capture(prefix + "preview");
        }
        foreach (var city in playable)
        {
            var p = _save.Data.GetCity(city.Id);
            p.Completed = true; p.BestStars = 1; p.HighestUnlockedDay = _save.ChapterLength(city.Id) + 1;
        }
        _save.Data.LastVisitedCityId = StableIds.Cities.Wuhan;
        Check(_save.TrySave(out string completedError), "completed fixture saves: " + completedError);
        _screen.PresentMap(); await Frames();
        Check(Find<Button>("Node0").GetNode<Label>("State").Text == "已完成", "completed route retains completed markers");
        CheckMapLayout(); await Capture(prefix + "complete");
        Directory.CreateDirectory(_path + ".tmp");
        await MapClick("Node0");
        Check(_screen.Visible && _screen.Page == JourneyPage.Map && Find<Label>("Status").Text.Length > 0
            && _save.ContinueCityId == StableIds.Cities.Wuhan, "failed business preserves map and resume city");
        Directory.Delete(_path + ".tmp");
        Check(_save.TrySave(out string retryError), "storage recovered: " + retryError);
        await MapClick("Node0");
        Check(!_screen.Visible && _screen.SelectedCityId == StableIds.Cities.Tianjin
            && _main.GetNode<DayController>("DayController").CurrentConfig?.Day == _save.ChapterLength(StableIds.Cities.Tianjin) + 1,
            "retry starts latest unlocked Tianjin day beyond the completed chapter");
        for (int i = 1; i < playable.Length; i++)
        {
            _main.OpenCity(playable[i - 1].Id); _screen.PresentMap(); await Frames();
            await MapClick("Node" + i);
            Check(!_screen.Visible && _screen.SelectedDay == _save.ChapterLength(playable[i].Id) + 1
                && _save.ContinueCityId == playable[i].Id, "completed city starts next unlocked day " + playable[i].Name);
        }
        _main.OpenCity(StableIds.Cities.Tianjin); _screen.PresentMap(); await Frames();
        await MapClick("Home"); Check(_screen.Page == JourneyPage.Home, "map Home opens home");
        _screen.PresentMap(() => _screen.PresentCity(StableIds.Cities.Tianjin)); await Frames();
        _screen._Input(new InputEventKey { Keycode = Key.Escape, Pressed = true });
        await Frames(); Check(_screen.Page == JourneyPage.City, "map Escape preserves caller return destination");
        if (!demo)
        {
            _screen.PresentCompletion(StableIds.Cities.Tianjin, () => _screen.PresentHome());
            await ToSignal(GetTree().CreateTimer(2.15), SceneTreeTimer.SignalName.Timeout);
            var node = Find<Button>("Node1"); var glow = Find<TextureRect>("MapUnlockGlow");
            Check(glow.Position.DistanceTo(node.Position + new Vector2(-10, -45)) < 5, "unlock glow shares map node coordinates");
            var route = Find<TextureRect>("MapRoute1");
            Check((route.Position + Vector2.Right.Rotated(route.Rotation) * route.Size.X).DistanceTo(node.Position + new Vector2(65, 40)) < 5, "route terminates at next map marker");
            await MapClick("Skip"); Check(_screen.Page == JourneyPage.City, "unlock presentation still enters next city");
        }
    }

    private async Task MapClick(string name)
    {
        while (JourneyTransition.For(this).Active) await Frames();
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
        Check(_screen.FindChildren("MapJourneyStrip", "", true, false).Count == 0
            && _screen.FindChildren("Back", "Button", true, false).Count == 0, "map summary and back button removed");
        var frame = Find<TextureRect>("MapFrame");
        var world = Find<TextureRect>("WorldMapArt");
        Vector2 native = world.Texture.GetSize();
        Check(Math.Abs(world.Size.X / native.X - world.Size.Y / native.Y) < .0001f,
            "world map preserves the original artwork proportions");
        Check(frame.Size.Y > 685 && world.Size.Y > 535, "frame and artwork enlarged");
        Check(new Rect2(Vector2.Zero, new Vector2(1920, 1080)).Encloses(frame.GetRect()), "frame fits design viewport");
        Check(frame.GetRect().Encloses(world.GetRect()), "world artwork fits frame");
        foreach (var node in _screen.Descendants<Button>().Where(b => b.Name.ToString().StartsWith("Node")))
        {
            Check(world.GetRect().Encloses(node.GetRect()), "city marker fits map " + node.Name);
            Check(!node.GetGlobalRect().Intersects(Find<Button>("Home").GetGlobalRect()), "city marker clears navigation " + node.Name);
        }
    }
}
