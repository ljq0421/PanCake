using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public partial class StartScreen
{
    // Fixed coordinates on the alpha-cropped world artwork (1608 x 823).
    // Geographic dots remain fixed; upright landmarks are displaced locally.
    private static readonly Vector2[] MapCityPins =
    {
        new(.785f, .385f), new(.773f, .468f), new(.743f, .434f),
        new(.768f, .532f), new(.790f, .446f)
    };
    // Offsets in the 1920x1080 layout. Each straight leader ends at the pin tip.
    private static readonly Vector2[] MapMarkerOffsets =
    {
        new(0, -78), new(-66, 60), new(-62, -34), new(62, 70), new(70, 4)
    };
    // Decorative future stops, independent of the five playable city definitions.
    private static readonly Vector2[] MapFuturePins =
    {
        new(.18f, .27f), new(.18f, .43f), new(.27f, .66f), new(.25f, .80f),
        new(.51f, .30f), new(.53f, .54f), new(.52f, .73f), new(.88f, .83f)
    };
    private static readonly Rect2 MapArtworkBounds = new(235, 225, 1450, 535);
    private Rect2 _mapArtworkRect;
    private static ShaderMaterial? _mapLockedMaterial;
    private float MapMarkerScale => _mapArtworkRect.Size.Y / 680f;
    private Vector2 MapMarkerSize => new Vector2(64, 80) * MapMarkerScale;
    private Vector2 MapPoint(Vector2 normalized) => _mapArtworkRect.Position + normalized * _mapArtworkRect.Size;
    private Vector2 MapArtworkPoint(Vector2 referencePoint) =>
        MapPoint((referencePoint - MapArtworkBounds.Position) / MapArtworkBounds.Size);
    private bool MapUnlocked(int index) => JourneyModel.MapCityUnlocked(_save, JourneyModel.Cities[index])
        && (_save is null || _save.ChapterLength(JourneyModel.Cities[index].Id) > 0);
    private Vector2 MapMarkerTip(int index) => MapPoint(MapCityPins[index]) + MapMarkerOffsets[index] * MapMarkerScale;
    private Vector2 MapNodePosition(int index) => MapMarkerTip(index) - new Vector2(MapMarkerSize.X / 2, MapMarkerSize.Y);

    private void RenderMap()
    {
        Begin(JourneyPage.Map); DrawMap();
        Chrome(() => (_mapReturn ?? RenderHome)(), showBack: false);
        Focus("Node" + Math.Max(0, Array.FindIndex(JourneyModel.Cities, c => c.Id == _city)));
        _status.Position = new(340, 75); _status.Size = new(1000, 40);
        _status.AddThemeColorOverride("font_color", StartScreenTheme.Ink);
        _status.MoveToFront();
    }

    private void DrawMap(bool reveal = false)
    {
        Rect2 frameBounds = reveal ? new(160, 125, 1600, 685) : new(100, 105, 1720, 870);
        Rect2 artworkBounds = reveal ? MapArtworkBounds : new(175, 200, 1570, 680);
        HomeArt(_body, "世界地图墙挂底板", frameBounds).Name = "MapFrame";
        var map = HomeArt(_body, "卡通世界地图母版", artworkBounds);
        map.Name = "WorldMapArt";
        Vector2 nativeSize = map.Texture.GetSize();
        float mapScale = Math.Min(artworkBounds.Size.X / nativeSize.X, artworkBounds.Size.Y / nativeSize.Y);
        map.Size = nativeSize * mapScale;
        map.Position = artworkBounds.GetCenter() - map.Size / 2;
        _mapArtworkRect = new(map.Position, map.Size);
        if (!reveal && _save?.CanContinue == true)
        {
            var current = JourneyModel.City(_save.ContinueCityId);
            int day = Math.Max(1, JourneyModel.Progress(_save, current.Id).HighestUnlockedDay);
            string journey = _save.GetSlots().FirstOrDefault(s => s.Id == _save.ActiveSlotId)?.Name ?? "当前旅程";
            var progress = Text(_body, "MapCurrentProgress", $"{journey} · {current.Name} · 第 {day} 天", new(345, 142, 825, 46), 30);
            progress.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream);
            progress.AddThemeConstantOverride("outline_size", 4);
            FitTextWidth(progress, 30, 20);
            Button(_body, "MapSwitchJourney", "切换旅程", new(1330, 139, 226, 54), OpenMapJourneySwitch);
        }
        Art(_body, "美洲区域装饰", new(MapArtworkPoint(new(380, 417.5f)) - new Vector2(65, 47.5f), new Vector2(130, 95))).Modulate = new Color(1, 1, 1, .3f);
        Art(_body, "欧洲区域装饰", new(MapArtworkPoint(new(905, 282.5f)) - new Vector2(55, 37.5f), new Vector2(110, 75))).Modulate = new Color(1, 1, 1, .3f);
        if (_save is not null && JourneyModel.Cities.All(c => JourneyModel.Progress(_save, c.Id).Completed))
            Art(_body, "中国阶段完成纪念章", new(MapArtworkPoint(new(790, 555)) - new Vector2(90, 90), new Vector2(180, 180)));

        for (int i = 0; i < MapFuturePins.Length; i++)
        {
            Vector2 size = MapMarkerSize;
            var future = new Control
            {
                Name = "MapFuture" + i, Size = size,
                Position = MapPoint(MapFuturePins[i]) - new Vector2(size.X / 2, size.Y),
                MouseFilter = MouseFilterEnum.Ignore
            };
            _body.AddChild(future);
            MapLandmark(future, "MapLock", "地标-未解锁", size);
        }

        int nextIndex = Enumerable.Range(0, JourneyModel.Cities.Length).FirstOrDefault(i => !MapUnlocked(i), -1);
        // Render the independent, two-point straight leaders below all markers.
        for (int i = 0; i < JourneyModel.Cities.Length; i++)
        {
            Vector2 location = MapPoint(MapCityPins[i]);
            _body.AddChild(new Line2D
            {
                Name = "MapLeader" + i, Points = new[] { location, MapMarkerTip(i) },
                Width = 2 * MapMarkerScale, DefaultColor = new Color("#805B40"), Antialiased = true
            });
            var pin = new Control { Name = "MapPin" + i, Position = location, MouseFilter = MouseFilterEnum.Ignore };
            _body.AddChild(pin);
            var dot = new Panel
            {
                Name = "Dot", Position = Vector2.One * (-4 * MapMarkerScale),
                Size = Vector2.One * (8 * MapMarkerScale), MouseFilter = MouseFilterEnum.Ignore
            };
            var dotStyle = new StyleBoxFlat { BgColor = new Color("#805B40") };
            dotStyle.SetCornerRadiusAll(4);
            dot.AddThemeStyleboxOverride("panel", dotStyle); pin.AddChild(dot);
        }
        for (int i = 0; i < JourneyModel.Cities.Length; i++)
        {
            var city = JourneyModel.Cities[i];
            bool unlocked = MapUnlocked(i), next = i == nextIndex;
            bool completed = unlocked && _save is not null && JourneyModel.Progress(_save, city.Id).Completed;
            bool playable = _save is null || _save.ChapterLength(city.Id) > 0;
            var node = new MapMarkerButton
            {
                Name = "Node" + i, Position = MapNodePosition(i), Size = MapMarkerSize,
                PivotOffset = MapMarkerSize / 2,
                MouseDefaultCursorShape = CursorShape.PointingHand,
                State = !unlocked ? "" : completed ? "已完成"
                    : city.Id == (_save?.ContinueCityId ?? JourneyModel.Cities[0].Id) ? "当前城市" : "可前往",
                Disabled = reveal
            };
            // Keep the tip stationary on hover so its leader never detaches.
            foreach (string state in new[] { "normal", "hover", "pressed", "disabled", "focus" })
                node.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
            _body.AddChild(node); _buttons.Add(node);
            node.Pressed += () =>
            {
                if (node.Disabled || _busy || !IsVisibleInTree() || ModalOpen) return;
                _city = city.Id;
                if (playable && (unlocked || (_save?.CanContinue == true && DeveloperToolsVisible))) OpenMapCity(city.Id);
                else RenderMap();
            };
            var visual = new Control
            {
                Name = "Art", Size = new(40, 50), Scale = Vector2.One * (MapMarkerSize.Y / 50),
                MouseFilter = MouseFilterEnum.Ignore
            };
            node.AddChild(visual);
            var ring = HomeArt(visual, "城市节点悬停高亮环", new(-5, -6, 50, 50));
            ring.Name = "Highlight"; ring.Visible = next || (unlocked && city.Id == (_save?.ContinueCityId ?? JourneyModel.Cities[0].Id));
            if (unlocked)
            {
                MapLandmark(visual, "Landmark", JourneyModel.NodeArt(city), new(40, 50));
                if (completed) HomeArt(visual, JourneyModel.Stamp(city), new(27, 2, 13, 13)).Name = "CompletedStamp";
            }
            else MapLandmark(visual, "MapLock", "地标-未解锁", new(40, 50));
            if (unlocked || next)
            {
                // Place names below the pin and beside downward leaders.
                Vector2 offset = i == 0 ? new(10, 4) : i == 2 ? new(-138, 4) : new(-64, 5);
                var caption = Text(node, "MapName", unlocked ? city.Name : "下一站预告",
                    new Rect2(new Vector2(MapMarkerSize.X / 2, MapMarkerSize.Y) + offset * MapMarkerScale,
                        new Vector2(128, 28) * MapMarkerScale), 22);
                caption.HorizontalAlignment = i == 0 ? HorizontalAlignment.Left
                    : i == 2 ? HorizontalAlignment.Right : HorizontalAlignment.Center;
                caption.MouseFilter = MouseFilterEnum.Ignore;
                caption.AddThemeColorOverride("font_outline_color", new Color("#F8EACA"));
                caption.AddThemeConstantOverride("outline_size", 4);
                FitTextWidth(caption, (int)(22 * MapMarkerScale), (int)(16 * MapMarkerScale));
            }
            if (unlocked && _save?.CanContinue == true && city.Id == _save.ContinueCityId)
            {
                var marker = Text(node, "LastStopTag", "上次停留", new(-34, -34, 135, 32), 19, true);
                marker.MouseFilter = MouseFilterEnum.Ignore;
                marker.AddThemeColorOverride("font_color", new Color("#983F32"));
                marker.AddThemeColorOverride("font_outline_color", StartScreenTheme.Cream);
                marker.AddThemeConstantOverride("outline_size", 4);
            }
            bool persistentHighlight = ring.Visible;
            void RefreshHighlight() => ring.Visible = persistentHighlight || node.IsHovered() || node.HasFocus();
            node.MouseEntered += RefreshHighlight; node.MouseExited += RefreshHighlight;
            node.MouseEntered += () =>
            {
                if (!node.Disabled && !_busy && !ModalOpen && node.IsVisibleInTree())
                    ButtonHoverAudio.For(node).Play(node);
            };
            node.FocusEntered += RefreshHighlight; node.FocusExited += RefreshHighlight;
        }
        if (!reveal && _save is { CanContinue: true } && !_save.Data.UnlockedCityIds.Contains(StableIds.Cities.Wuhan))
        {
            int coins = _save.Data.Coins;
            bool dayReady = _save.Data.Tianjin.DayBestRecords.ContainsKey(SaveService.WuhanUnlockDay);
            string state = dayReady ? $"武汉新店筹备金  {coins} / {SaveService.WuhanDepartureCoins} 金币"
                : $"先完成天津第 7 天  ·  当前金币 {coins} / {SaveService.WuhanDepartureCoins}";
            Text(_body, "WuhanPreparation", state, new(350, 855, 890, 62), 30);
            if (_save.CanDepartForWuhan)
                Button(_body, "DepartWuhan", "出发武汉！", new(1260, 850, 300, 72), () => WuhanDepartureRequested?.Invoke());
            else
                Button(_body, "ContinueTianjin", "继续在天津营业", new(1260, 850, 300, 72), () => OpenMapCity(StableIds.Cities.Tianjin));
        }
    }

    private TextureRect MapLandmark(Control parent, string name, string asset, Vector2 bounds)
    {
        var art = HomeArt(parent, asset, new Rect2(Vector2.Zero, bounds));
        art.Name = name;
        if (name == "MapLock")
            art.Material = _mapLockedMaterial ??= new ShaderMaterial
            {
                Shader = GD.Load<Shader>("res://resource/shaders/map_locked_landmark.gdshader")
            };
        // Bottom-align the cropped artwork so the straight leader meets its tip.
        Vector2 source = art.Texture.GetSize();
        art.Size = source * Math.Min(bounds.X / source.X, bounds.Y / source.Y);
        art.Position = new((bounds.X - art.Size.X) / 2, bounds.Y - art.Size.Y);
        return art;
    }
}

// Keep the transparent corners of adjacent enlarged pins from stealing clicks.
internal partial class MapMarkerButton : Button
{
    internal string State = "";
    public override bool _HasPoint(Vector2 point)
    {
        Vector2 p = point / Size;
        if (p.X < 0 || p.X > 1 || p.Y < 0 || p.Y > 1) return false;
        var face = new Vector2((p.X - .5f) / .5f, (p.Y - .38f) / .38f);
        return face.LengthSquared() <= 1 || (p.Y >= .60f && Math.Abs(p.X - .5f) <= (1 - p.Y) * .7f);
    }
}
