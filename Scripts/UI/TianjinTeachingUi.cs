using Godot;

namespace ProjectCake.UI;

/// <summary>Artwork-backed chrome for Tianjin's guided first-breakfast lesson.</summary>
public static class TianjinTeachingUi
{
    private const string PanelFramePath = "res://resource/art/TianJin/TutorialUI/teaching-panel-v1.tres";
    private const string ActionPath = "res://resource/art/TianJin/TutorialUI/teaching-action-v1.png";

    public static void ApplyPanel(Panel panel)
    {
        panel.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        var frame = GD.Load<StyleBoxTexture>(PanelFramePath);
        var art = new MeshInstance2D
        {
            Name = "TeachingPanelArt", Texture = frame.Texture,
            ShowBehindParent = true,
            Material = new ShaderMaterial { Shader = GD.Load<Shader>("res://resource/shaders/teaching_panel_ink.gdshader") },
        };
        panel.AddChild(art);
        void ResizeArtwork()
        {
            var previous = art.Mesh;
            art.Mesh = CurvedFrame(frame, panel.Size);
            previous?.Dispose();
        }
        panel.Resized += ResizeArtwork;
        ResizeArtwork();
    }

    // Tessellate the incumbent nine-slice, preserving its paper, border and transparent accents.
    // Bow the horizontal AND vertical edges; only artwork moves, never text or hit targets.
    private static ArrayMesh CurvedFrame(StyleBoxTexture frame, Vector2 size)
    {
        Vector2 textureSize = frame.Texture.GetSize();
        float left = frame.GetTextureMargin(Side.Left), right = frame.GetTextureMargin(Side.Right);
        float top = frame.GetTextureMargin(Side.Top), bottom = frame.GetTextureMargin(Side.Bottom);
        float[] Axis(float length, float first, float last) => Enumerable.Range(0, 33)
            .Select(i => length * i / 32).Concat(new[] { first * .65f, length - last * .65f }).Distinct().Order().ToArray();
        float Uv(float p, float length, float source, float first, float last)
        {
            float a = first * .65f, b = last * .65f;
            return (p <= a ? p / .65f : p >= length - b ? source - (length - p) / .65f
                : first + (p - a) / (length - a - b) * (source - first - last)) / source;
        }
        size = size.Max(new Vector2(160, 90));
        // Retain the original cap/decoration scale. Expand only the border cross-section,
        // with explicit mesh rows at its ink, gold and paper boundaries.
        float[] xs = Axis(size.X, left, right).Concat(new[] { 5f, 10f, 17f, 26f, 46f, size.X - 46, size.X - 26, size.X - 17, size.X - 10, size.X - 5 }).Distinct().Order().ToArray();
        float[] ys = Axis(size.Y, top, bottom).Concat(new[] { 17.5f, 21f, 28f, 38f, 49f, size.Y - 24, size.Y - 12, size.Y - 7, size.Y - 2 }).Distinct().Order().ToArray();
        var vertices = new Vector2[xs.Length * ys.Length];
        var uvs = new Vector2[vertices.Length];
        float bowX = Mathf.Min(9, size.X * .016f), bowY = Mathf.Min(10, size.Y * .045f);
        for (int y = 0; y < ys.Length; y++)
        for (int x = 0; x < xs.Length; x++)
        {
            int i = y * xs.Length + x;
            float px = xs[x], py = ys[y];
            float borderX = BorderExpansion(px, 5, 17, 46) - BorderExpansion(size.X - px, 5, 17, 46);
            float borderY = BorderExpansion(py, 17.5f, 28, 49) - BorderExpansion(size.Y - py, 2, 12, 24);
            px += borderX; py += borderY;
            float u = px / size.X, v = py / size.Y;
            vertices[i] = new(px + bowX * (1 - 2 * u) * Mathf.Pow(2 * v - 1, 2),
                py + bowY * (1 - 2 * v) * Mathf.Pow(2 * u - 1, 2));
            uvs[i] = new(Uv(xs[x], size.X, textureSize.X, left, right), Uv(ys[y], size.Y, textureSize.Y, top, bottom));
        }
        var indices = new List<int>();
        for (int y = 0; y < ys.Length - 1; y++)
        for (int x = 0; x < xs.Length - 1; x++)
        {
            int a = y * xs.Length + x, b = a + 1, c = a + xs.Length, d = c + 1;
            indices.AddRange(new[] { a, b, c, b, d, c });
        }
        var arrays = new Godot.Collections.Array(); arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = vertices;
        arrays[(int)Mesh.ArrayType.TexUV] = uvs;
        arrays[(int)Mesh.ArrayType.Index] = indices.ToArray();
        var mesh = new ArrayMesh(); mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
        return mesh;
    }

    private static float BorderExpansion(float distance, float outer, float inner, float paper)
    {
        if (distance <= outer || distance >= paper) return 0;
        const float growth = .6f;
        return distance <= inner ? (distance - outer) * growth
            : (inner - outer) * growth * (paper - distance) / (paper - inner);
    }

    public static Panel ActionFrame(Button action, Vector2 position, Vector2 size)
    {
        var frame = new Panel { Position = position, Size = size, MouseFilter = Control.MouseFilterEnum.Ignore };
        frame.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        var art = new TextureRect
        {
            Texture = GD.Load<Texture2D>(ActionPath),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        FullRect(art);
        frame.AddChild(art);

        action.Position = Vector2.Zero;
        action.Size = size;
        action.Flat = true;
        action.AddThemeStyleboxOverride("normal", new StyleBoxEmpty());
        action.AddThemeStyleboxOverride("hover", new StyleBoxEmpty());
        action.AddThemeStyleboxOverride("pressed", new StyleBoxEmpty());
        action.AddThemeStyleboxOverride("disabled", new StyleBoxEmpty());
        action.AddThemeStyleboxOverride("focus", new StyleBoxEmpty());
        action.FocusEntered += () => art.SelfModulate = new Color(1.06f, 1.06f, 1.06f);
        action.FocusExited += () => art.SelfModulate = Colors.White;
        action.AddThemeFontSizeOverride("font_size", 21);
        action.AddThemeColorOverride("font_color", TianjinUi.BrownText);
        action.AddThemeColorOverride("font_hover_color", TianjinUi.BrownText);
        action.AddThemeColorOverride("font_pressed_color", TianjinUi.BrownText);
        action.AddThemeColorOverride("font_focus_color", TianjinUi.BrownText);
        action.AddThemeColorOverride("font_disabled_color", new Color("#826F5D"));
        frame.AddChild(action);
        return frame;
    }

    private static void FullRect(Control control)
    {
        control.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        control.OffsetLeft = control.OffsetTop = control.OffsetRight = control.OffsetBottom = 0;
    }
}
