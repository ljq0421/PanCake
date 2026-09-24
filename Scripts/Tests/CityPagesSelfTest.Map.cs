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
        CheckMapLayout(); await CaptureMap(prefix + "no-save");

        // Failure must retain the map, release the input guard, and allow a successful retry.
        Directory.CreateDirectory(_path);
        await MapClick("Node0");
        Check(_screen.Visible && _screen.Page == JourneyPage.Map && !_save.CanContinue
            && Find<Label>("Status").Text.Length > 0, $"failed map creation stays on map (visible={_screen.Visible}, page={_screen.Page}, save={_save.CanContinue}, status={Find<Label>("Status").Text})");
        Directory.Delete(_path);
        await MapClick("Node0");
        Check(_save.ActiveSlotId == 1 && _screen.Visible && _screen.Page == JourneyPage.City
            && _screen.SelectedDay == 1, "empty map creates first slot and opens Tianjin overview");
        await MapClick("OpenBusiness");
        Check(!_screen.Visible && _main.GetNode<DayController>("DayController").CurrentConfig?.Day == 1,
            "first journey starts only after confirming business");
        _main.OpenCity(StableIds.Cities.Tianjin); _screen.PresentMap(); await Frames();
        Check(Find<Button>("Node0").HasFocus(), "map focuses current city");
        Check(_screen.FindChild("MapCurrentProgress", true, false) is null
            && _screen.FindChild("WuhanPreparation", true, false) is null
            && _screen.FindChild("ContinueTianjin", true, false) is null,
            "map omits the lower-left text and continue button");
        CheckMapLayout(); await CaptureMap(prefix + "initial");
        await CheckMapHover(prefix + "initial");
        string persisted = File.ReadAllText(_path);
        await MapClick("Node1");
        if (_screen.DeveloperToolsVisible)
        {
            Check(_screen.Visible && _screen.Page == JourneyPage.City, "developer map entry opens available preview");
            _main.OpenCity(StableIds.Cities.Wuhan, true); _screen.PresentMap(); await Frames();
        }
        else
        {
            Check(_screen.Visible && _screen.Page == JourneyPage.Map
                && _screen.Descendants<Label>().Any(l => l.Name == "MapName" && l.Text == "下一站预告"), "locked next city stays on map anonymously");
            Check(File.ReadAllText(_path) == persisted, "locked selection does not modify save");
            CheckMapLayout(); await CaptureMap(prefix + "locked");
            for (int i = 2; i < JourneyModel.Cities.Length; i++)
            {
                await MapClick("Node" + i);
                Check(_screen.Visible && _screen.Page == JourneyPage.Map, "later locked station cannot start business");
                Check(File.ReadAllText(_path) == persisted, "anonymous station browsing does not modify save");
                CheckMapLayout();
            }
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
        Check(_screen.Visible && _screen.Page == JourneyPage.City && _screen.SelectedDay == 1, "Enter on city opens overview");
        _screen._Input(new InputEventKey { Keycode = Key.Escape, Pressed = true });
        await Frames(); Check(_screen.Page == JourneyPage.Map, "city Escape returns to world map");
        _main.OpenCity(StableIds.Cities.Tianjin); _screen.PresentMap(); await Frames();
        await MapClick("Home"); Check(_screen.Page == JourneyPage.Home, "map returns home");
        await MapClick("WorldMap"); Check(_screen.Page == JourneyPage.Map, "world map entry opens map");

        foreach (var city in playable)
        {
            if (!_save.Data.UnlockedCityIds.Contains(city.Id)) _save.Data.UnlockedCityIds.Add(city.Id);
            var p = _save.Data.GetCity(city.Id);
            p.HighestUnlockedDay = Math.Min(3, _save.ChapterLength(city.Id));
            _screen.PresentMap(); await Frames();
            CheckMapLayout(); await CaptureMap(prefix + "unlocked-" + city.Id.Replace(':', '-'));
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
            Check(requests == 0 && _screen.Visible && _screen.Page == JourneyPage.City
                && _screen.SelectedCityId == city.Id, "map opens selected city without starting business " + city.Name);
            Check(Find<Button>("ContinueTab").Disabled && !Find<Button>("LedgerTab").Disabled
                && !Find<Button>("UpgradeTab").Disabled, "city overview exposes all three tabs " + city.Name);
            await MapClick("LedgerTab");
            Check(_screen.Page == JourneyPage.Ledger && _screen.SelectedCityId == city.Id, "ledger keeps selected city");
            await MapClick("UpgradeTab");
            Check(_screen.Page == JourneyPage.Upgrades && _screen.SelectedCityId == city.Id, "upgrades keep selected city");
            await MapClick("ContinueTab");
            await Capture(prefix + "city-" + city.Id.Replace(':', '-'));
            await MapClick("OpenBusiness");
            Check(requests == 1 && !_screen.Visible && _screen.SelectedCityId == city.Id
                && _screen.SelectedDay == Math.Min(3, _save.ChapterLength(city.Id)),
                "overview button starts latest day once " + city.Name);
            _screen.BusinessRequested -= CountRequest;
            Check(_save.ContinueCityId == city.Id, "business records selected city " + city.Name);
            _main.OpenCity(city.Id); _screen.PresentMap(); await Frames();
            Check(Find<Button>("Node" + i).HasFocus(), "map restores current city focus " + city.Name);
            CheckMapLayout();
        }
        await CaptureMap(prefix + "progress");
        await CheckMapHover(prefix + "progress");
        if (demo)
        {
            await MapClick("Node2");
            Check(_screen.Visible && _screen.Page == JourneyPage.Map
                && _screen.Descendants<Label>().Any(l => l.Name == "MapName" && l.Text == "下一站预告"), "demo preview cannot start business");
            Check(_screen.FindChildren("Node*", "Button", true, false).Count == 5, "demo shows five stations with only two playable cities");
            CheckMapLayout(); await CaptureMap(prefix + "preview");
        }
        foreach (var city in playable)
        {
            var p = _save.Data.GetCity(city.Id);
            p.Completed = true; p.BestStars = 1; p.HighestUnlockedDay = _save.ChapterLength(city.Id) + 1;
        }
        _save.Data.LastVisitedCityId = StableIds.Cities.Wuhan;
        Check(_save.TrySave(out string completedError), "completed fixture saves: " + completedError);
        _screen.PresentMap(); await Frames();
        Check(((MapMarkerButton)Find<Button>("Node0")).State == "已完成", "completed route retains completed markers");
        CheckMapLayout(); await CaptureMap(prefix + "complete");
        await MapClick("Node0");
        Directory.CreateDirectory(_path + ".tmp");
        await MapClick("OpenBusiness");
        Check(_screen.Visible && _screen.Page == JourneyPage.City && Find<Label>("Status").Text.Length > 0
            && _save.ContinueCityId == StableIds.Cities.Wuhan, "failed business preserves map and resume city");
        Directory.Delete(_path + ".tmp");
        Check(_save.TrySave(out string retryError), "storage recovered: " + retryError);
        await MapClick("OpenBusiness");
        Check(!_screen.Visible && _screen.SelectedCityId == StableIds.Cities.Tianjin
            && _main.GetNode<DayController>("DayController").CurrentConfig?.Day == _save.ChapterLength(StableIds.Cities.Tianjin) + 1,
            "retry starts latest unlocked Tianjin day beyond the completed chapter");
        for (int i = 1; i < playable.Length; i++)
        {
            _main.OpenCity(playable[i - 1].Id); _screen.PresentMap(); await Frames();
            await MapClick("Node" + i);
            Check(_screen.Visible && _screen.Page == JourneyPage.City, "completed city opens overview");
            await MapClick("OpenBusiness");
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
            Check(glow.GetRect().GetCenter().DistanceTo(node.Position + node.Size / 2) < 1, "unlock glow centers on compact landmark");
            Check(_screen.FindChildren("MapRoute*", "", true, false).Count == 0, "unlock presentation has no connecting routes");
            CheckMapLeaders();
            await CaptureMap(prefix + "unlock-reveal");
            await MapClick("Skip"); Check(_screen.Page == JourneyPage.City, "unlock presentation still enters next city");
        }
    }

    private async Task CaptureMap(string name)
    {
        if (!_capture) return;
        while (JourneyTransition.For(this).Active) await Frames();
        await Capture(name);
    }

    private async Task CheckMapHover(string prefix)
    {
        while (JourneyTransition.For(this).Active) await Frames();
        Check(_screen.FindChild("MapTooltip", true, false) is null, "map has no hover card");
        for (int i = 0; i < JourneyModel.Cities.Length; i++)
        {
            var node = (MapMarkerButton)Find<Button>("Node" + i);
            var caption = node.GetNodeOrNull<Label>("MapName");
            string before = caption?.Text ?? "";
            Vector2 at = node.GetGlobalTransformWithCanvas() * (node.Size / 2);
            GetViewport().PushInput(new InputEventMouseMotion { Position = at, GlobalPosition = at }, true);
            await Frames();
            Check(GetViewport().GuiGetHoveredControl() == node, "enlarged marker receives its own hover " + i);
            Check(node.TooltipText.Length == 0 && _screen.FindChild("MapTooltip", true, false) is null,
                "hover never shows city tooltips " + i);
            Check(caption is null || (caption.IsVisibleInTree() && caption.Text == before),
                "hover leaves permanent caption unchanged " + i);
            if (i == 1) await CaptureMap(prefix + "-hover-wuhan");
        }
        var outside = _screen.GetGlobalTransformWithCanvas() * new Vector2(400, 900);
        GetViewport().PushInput(new InputEventMouseMotion { Position = outside, GlobalPosition = outside }, true);
        await Frames();
        Check(Find<Button>("Node0").GetNode<Label>("MapName").IsVisibleInTree(), "city name stays visible without hover");
        await CaptureMap(prefix + "-idle");
        Find<Button>("Node0").GrabFocus(); await Frames();
        Check(_screen.FindChild("MapTooltip", true, false) is null, "keyboard focus does not show a city card");
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
        Check(world.GetRect().GetCenter().DistanceTo(new Vector2(960, 540)) < 1, "map artwork centers on the whole design viewport");
        Check(world.GetGlobalRect().GetCenter().DistanceTo(_screen.GetGlobalRect().GetCenter()) < 1,
            "map artwork centers on the actual resized viewport");
        var nodes = _screen.Descendants<Button>().Where(b => b.Name.ToString().StartsWith("Node")).ToArray();
        Check(nodes.Length == 5, "all five city positions are present");
        var futureStops = _screen.Descendants<Control>().Where(c => c.Name.ToString().StartsWith("MapFuture")).ToArray();
        Check(futureStops.Length == 8, "world map includes eight decorative future stops");
        foreach (var future in futureStops)
        {
            Check(future.Size.IsEqualApprox(nodes[0].Size), "all future and city markers use the same size " + future.Name);
            Check(future is not Button && future.MouseFilter == Control.MouseFilterEnum.Ignore
                && future.TooltipText.Length == 0 && !future.Descendants<Label>().Any(),
                "future stop is anonymous and cannot intercept input " + future.Name);
            var lockedArt = future.GetNode<TextureRect>("MapLock");
            Check(lockedArt.Material is ShaderMaterial gray && gray.Shader.ResourcePath.EndsWith("map_locked_landmark.gdshader"),
                "future stop uses the grayscale material " + future.Name);
            Check(((AtlasTexture)lockedArt.Texture).Atlas.ResourcePath.EndsWith("地标-未解锁.png"),
                "future stop uses the requested locked landmark asset " + future.Name);
            Check(world.GetRect().Encloses(future.GetRect()), "future stop stays on map " + future.Name);
            foreach (var other in nodes.Cast<Control>().Concat(futureStops).Where(c => c != future))
                Check(!future.GetGlobalRect().Intersects(other.GetGlobalRect()), "future stops clear other markers " + future.Name + " " + other.Name);
        }
        Check(_screen.FindChildren("MapRoute*", "", true, false).Count == 0, "world map has no inter-city routes");
        CheckMapLeaders();
        int next = Array.FindIndex(JourneyModel.Cities, c => !JourneyModel.MapCityUnlocked(_save, c) || _save.ChapterLength(c.Id) <= 0);
        for (int i = 0; i < nodes.Length; i++)
        {
            var node = Find<Button>("Node" + i);
            var city = JourneyModel.Cities[i];
            bool unlocked = JourneyModel.MapCityUnlocked(_save, city) && _save.ChapterLength(city.Id) > 0;
            Check(world.GetRect().Encloses(node.GetRect()), "city marker fits map " + node.Name);
            foreach (string nav in new[] { "Home", "Settings", "Help", "Quit" })
                Check(!node.GetGlobalRect().Intersects(Find<Button>(nav).GetGlobalRect()), "city marker clears navigation " + node.Name + " " + nav);
            for (int j = 0; j < nodes.Length; j++)
            {
                if (i == j) continue;
                var other = (MapMarkerButton)Find<Button>("Node" + j);
                Vector2 center = node.GetGlobalTransformWithCanvas() * (node.Size / 2);
                Check(!other._HasPoint(other.GetGlobalTransformWithCanvas().AffineInverse() * center), "adjacent marker does not steal center clicks " + i + " " + j);
            }
            var pin = Find<Control>("MapPin" + i);
            Check(node.Size.IsEqualApprox(new Vector2(64, 80)), "map landmark uses the larger approved size " + i);
            var caption = node.GetNodeOrNull<Label>("MapName");
            Check(node.TooltipText.Length == 0, "map marker has no native tooltip " + i);
            if (caption is not null)
            {
                Check(caption.IsVisibleInTree() && caption.Position.Y >= node.Size.Y,
                    "caption is always visible below landmark " + i);
                foreach (var other in nodes.Where(other => other != node))
                    Check(!caption.GetGlobalRect().Intersects(other.GetGlobalRect()), "caption clears other landmarks " + i + " " + other.Name);
                foreach (var otherCaption in _screen.Descendants<Label>().Where(l => l.Name == "MapName" && l != caption))
                    Check(!caption.GetGlobalRect().Intersects(otherCaption.GetGlobalRect()), "city captions do not overlap " + i);
                foreach (var line in _screen.Descendants<Line2D>().Where(l => l.Name.ToString().StartsWith("MapLeader")))
                    Check(Enumerable.Range(0, 41).All(sample => !caption.GetGlobalRect().HasPoint(
                        line.GetGlobalTransformWithCanvas() * line.Points[0].Lerp(line.Points[1], sample / 40f))),
                        "straight leaders clear city captions " + i + " " + line.Name);
            }
            var normalized = (pin.Position - world.Position) / world.Size;
            Check(new Rect2(.73f, .36f, .09f, .19f).HasPoint(normalized), "geographic pin lies in China on the cropped artwork " + i);
            if (unlocked)
            {
                Check(caption?.Text == city.Name && node.GetNodeOrNull<TextureRect>("Art/Landmark") is not null,
                    "unlocked city retains its landmark and permanent name " + i);
                if (JourneyModel.Progress(_save, city.Id).Completed)
                    Check(node.GetNodeOrNull<TextureRect>("Art/CompletedStamp") is not null, "completed stamp supplements the landmark " + i);
            }
            else
            {
                Check(node.GetNodeOrNull<TextureRect>("Art/Landmark") is null
                    && node.GetNodeOrNull<Control>("Art/MapLock") is not null, "locked city has an anonymous lock without a name or landmark " + i);
                Check(((AtlasTexture)node.GetNode<TextureRect>("Art/MapLock").Texture).Atlas.ResourcePath.EndsWith("地标-未解锁.png"),
                    "locked city uses the requested locked landmark asset " + i);
                Check(node.GetNode<TextureRect>("Art/MapLock").Material is ShaderMaterial gray
                    && gray.Shader.ResourcePath.EndsWith("map_locked_landmark.gdshader"), "locked city landmark is grayscale " + i);
                Check(JourneyModel.Cities.All(c => !node.TooltipText.Contains(c.Name)), "locked tooltip never exposes a city name " + i);
                Check(i == next ? caption?.Text == "下一站预告" : caption is null,
                    "only the first locked station has a next-stop preview " + i);
            }
        }
        Vector2 tianjin = Find<Control>("MapPin0").Position, wuhan = Find<Control>("MapPin1").Position,
            xian = Find<Control>("MapPin2").Position, guangzhou = Find<Control>("MapPin3").Position,
            yangzhou = Find<Control>("MapPin4").Position;
        Check(tianjin.Y < xian.Y && xian.Y < wuhan.Y && wuhan.Y < guangzhou.Y,
            "cities preserve their north-south geographic order");
        Check(xian.X < wuhan.X && wuhan.X < yangzhou.X && yangzhou.Y < wuhan.Y,
            "Xi'an is west and Yangzhou is northeast of Wuhan");
    }

    private void CheckMapLeaders()
    {
        Check(_screen.FindChildren("MapLeader*", "Line2D", true, false).Count == 5, "five independent straight leaders are present");
        float scale = Find<TextureRect>("WorldMapArt").Size.Y / 680;
        for (int i = 0; i < JourneyModel.Cities.Length; i++)
        {
            var node = (MapMarkerButton)Find<Button>("Node" + i);
            var line = Find<Line2D>("MapLeader" + i);
            Vector2 tip = node.GetTransform() * new Vector2(node.Size.X / 2, node.Size.Y);
            Check(line.Points.Length == 2 && line.Points[0].DistanceTo(Find<Control>("MapPin" + i).Position) < .1f
                && line.Points[1].DistanceTo(tip) < .1f, "straight leader joins geographic dot to bottom tip " + i);
            float length = line.Points[0].DistanceTo(line.Points[1]) / scale;
            Check(length >= 40 && length <= 95 && Math.Abs(node.Rotation) < .001f, "leader length is local and landmark stays upright " + i);
            if ((node.GetNodeOrNull<TextureRect>("Art/Landmark") ?? node.GetNodeOrNull<TextureRect>("Art/MapLock")) is { } art)
            {
                Vector2 artTip = art.GetGlobalTransformWithCanvas() * new Vector2(art.Size.X / 2, art.Size.Y);
                Check(artTip.DistanceTo(line.GetGlobalTransformWithCanvas() * line.Points[1]) < .1f,
                    "visible landmark bottom touches its leader without an aspect-ratio gap " + i);
            }
            foreach (var other in _screen.Descendants<MapMarkerButton>())
            {
                bool clears = Enumerable.Range(0, 20).All(sample =>
                {
                    Vector2 point = line.GetGlobalTransformWithCanvas() * line.Points[0].Lerp(line.Points[1], sample / 20f);
                    return !other._HasPoint(other.GetGlobalTransformWithCanvas().AffineInverse() * point);
                });
                Check(clears, "leader clears landmark silhouettes " + i + " " + other.Name);
            }
            for (int j = i + 1; j < JourneyModel.Cities.Length; j++)
            {
                var other = Find<Line2D>("MapLeader" + j);
                Check(Geometry2D.SegmentIntersectsSegment(line.Points[0], line.Points[1], other.Points[0], other.Points[1]).VariantType == Variant.Type.Nil,
                    "leaders do not cross " + i + " " + j);
            }
        }
    }
}
