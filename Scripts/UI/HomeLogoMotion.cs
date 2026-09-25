using Godot;

namespace ProjectCake.UI;

/// <summary>Only the original painted steam moves; the rest of the logo stays unchanged.</summary>
public partial class HomeLogoMotion : Node
{
    public StartScreen Screen { get; init; } = null!;
    public TextureRect Logo { get; init; } = null!;
    private static readonly Dictionary<string, (ImageTexture Backplate, ImageTexture Steam)> Layers = new();
    private Control _canvas = null!;
    private TextureRect _backplate = null!, _steam = null!;
    private Texture2D? _source;
    private double _clock;
    private bool _focused = true, _entranceSettled;
    public double MotionTime => _clock;

    public override void _Ready()
    {
        _canvas = new Control { Name = "LogoCanvas", MouseFilter = Control.MouseFilterEnum.Ignore };
        Logo.AddChild(_canvas);
        _backplate = Layer("LogoBackplate");
        _steam = Layer("LogoSteam");
        RefreshArtwork();
        Logo.Resized += RefreshArtwork;
    }

    private TextureRect Layer(string name)
    {
        var layer = new TextureRect { Name = name, ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.Scale, MouseFilter = Control.MouseFilterEnum.Ignore,
            TextureFilter = CanvasItem.TextureFilterEnum.Linear };
        _canvas.AddChild(layer);
        return layer;
    }

    private void RefreshArtwork()
    {
        if (Logo.Texture is not AtlasTexture atlas) return;
        string path = atlas.Atlas.ResourcePath;
        if (!Layers.TryGetValue(path, out var layers))
        {
            using var original = atlas.Atlas.GetImage();
            original.Convert(Image.Format.Rgba8);
            int width = original.GetWidth(), height = original.GetHeight();
            byte[] pixels = original.GetData(), steam = new byte[pixels.Length];
            bool english = path.Contains("World, Breakfast");
            var selected = new bool[width * height];
            var weights = new float[selected.Length];
            // Original outlines touch the sign. Limit extraction to the steam side
            // of the lettering/leaf boundary without replacing the original artwork.
            SelectSteam(english ? new(330, 270) : new(350, 280), false);
            SelectSteam(english ? new(430, 200) : new(445, 225), true);
            // Include the translucent edge without letting stray alpha connect to lettering.
            var core = (bool[])selected.Clone();
            for (int y = 1; y < height - 1; y++)
                for (int x = 1; x < width - 1; x++)
                {
                    int i = y * width + x;
                    if (pixels[i * 4 + 3] is > 0 and < 20
                        && (core[i - 1] || core[i + 1] || core[i - width] || core[i + width]))
                    {
                        selected[i] = true;
                        weights[i] = Math.Max(Math.Max(weights[i - 1], weights[i + 1]), Math.Max(weights[i - width], weights[i + width]));
                    }
                }
            for (int i = 0; i < selected.Length; i++)
                if (selected[i])
                {
                    Array.Copy(pixels, i * 4, steam, i * 4, 4);
                    // A short feather at touching outlines anchors the vapor naturally;
                    // neither the moving tip nor the stationary drawing has a hard cut.
                    steam[i * 4 + 3] = (byte)Mathf.RoundToInt(pixels[i * 4 + 3] * weights[i]);
                    pixels[i * 4 + 3] -= steam[i * 4 + 3];
                }
            using var baseImage = Image.CreateFromData(width, height, false, Image.Format.Rgba8, pixels);
            using var steamImage = Image.CreateFromData(width, height, false, Image.Format.Rgba8, steam);
            layers = (ImageTexture.CreateFromImage(baseImage), ImageTexture.CreateFromImage(steamImage));
            Layers[path] = layers;

            void SelectSteam(Vector2I seed, bool large)
            {
                var queue = new Queue<Vector2I>();
                var visited = new HashSet<Vector2I>();
                queue.Enqueue(seed);
                while (queue.TryDequeue(out var p))
                {
                    if (p.X < 0 || p.Y < 0 || p.X >= width || p.Y >= height || !visited.Add(p)) continue;
                    bool inside = large
                        ? p.X >= 360 && p.X < 528 && p.Y > 80 && p.Y < (english ? 336 : 324)
                            && p.Y < (english ? 975 - 1.4f * p.X : 660 - .75f * p.X)
                        : p.X >= 280 && p.X < 435 && p.Y > 190 && p.Y < (english ? 350 : 386);
                    int index = p.Y * width + p.X;
                    if (!inside || pixels[index * 4 + 3] < 20) continue;
                    selected[index] = true;
                    float distance = large
                        ? Math.Min(english ? 336 : 324, english ? 975 - 1.4f * p.X : 660 - .75f * p.X) - p.Y
                        : english ? 350 - p.Y : 100;
                    weights[index] = Math.Max(weights[index], Mathf.SmoothStep(0, 20, distance));
                    queue.Enqueue(p + Vector2I.Left); queue.Enqueue(p + Vector2I.Right);
                    queue.Enqueue(p + Vector2I.Up); queue.Enqueue(p + Vector2I.Down);
                }
            }
        }
        _backplate.Texture = layers.Backplate; _steam.Texture = layers.Steam;
        _backplate.Size = atlas.Atlas.GetSize(); _steam.Size = atlas.Atlas.GetSize();
        float fit = Math.Min(Logo.Size.X / atlas.Region.Size.X, Logo.Size.Y / atlas.Region.Size.Y);
        _canvas.Scale = Vector2.One * fit;
        _canvas.Position = (Logo.Size - atlas.Region.Size * fit) * .5f - atlas.Region.Position * fit;
        _source = Logo.Texture;
        Apply();
    }

    public override void _Process(double delta)
    {
        if (Logo.Texture != _source) RefreshArtwork();
        if (JourneyTransition.Reduced) { Apply(); return; }
        if (!_focused || !Screen.IsVisibleInTree() || Screen.ModalOpen || Screen.Page != JourneyPage.Home) return;
        if (!_entranceSettled)
        {
            if (Logo.GetParent().GetChildren().OfType<HomeEntranceMotion>().Any(m => !m.Finished)) return;
            _entranceSettled = true;
        }
        _clock += Math.Min(delta, .05);
        Apply();
    }

    private void Apply()
    {
        bool reduced = JourneyTransition.Reduced;
        Logo.SelfModulate = new(1, 1, 1, reduced ? 1 : 0);
        _canvas.Visible = !reduced;
        float phase = (float)(_clock % 2.4 / 2.4);
        _steam.Position = reduced ? Vector2.Zero : new Vector2(5 * Mathf.Sin(phase * Mathf.Pi), -36 * phase);
        _steam.Modulate = new(1, 1, 1, reduced ? 1 : .85f * Mathf.SmoothStep(0, .16f, phase) * (1 - Mathf.SmoothStep(.58f, 1, phase)));
    }

    public override void _Notification(int what)
    {
        if (what == NotificationApplicationFocusOut) _focused = false;
        else if (what == NotificationApplicationFocusIn) _focused = true;
    }

    public override void _ExitTree()
    {
        // The journey opening reparents the outgoing home before freeing it.
        if (Logo.IsConnected(Control.SignalName.Resized, Callable.From(RefreshArtwork)))
            Logo.Resized -= RefreshArtwork;
    }
}
