using Godot;

namespace ProjectCake.Pancake;

// Freeze the actual food layers in one small transparent viewport so sauce and
// toppings follow the same fold, including their alpha edges and join order.
public partial class PancakeFoldVisual : Node2D
{
    private PancakeCanvas _source = null!;
    private SubViewport _snapshot = null!;
    private Rect2 _bounds;
    private int _direction;
    private float _grabY;
    private float _progress;
    private int _warmup;
    private bool _finishing;
    private bool _commit;
    private float _from;
    private float _time;
    private bool _disposed;
    private const int Strips = 36, Rows = 12;
    private readonly ArrayMesh _mesh = new();
    private readonly Vector2[] _grid = new Vector2[(Strips + 1) * (Rows + 1)];
    private readonly Vector3[] _vertices = new Vector3[Strips * Rows * 4];
    private readonly Vector2[] _uv = new Vector2[Strips * Rows * 4];
    private readonly Color[] _colors = new Color[Strips * Rows * 4];
    private readonly int[] _indices = new int[Strips * Rows * 6];

    public void Configure(PancakeCanvas source, int direction, float grabY)
    {
        _source = source;
        _direction = direction;
        _grabY = Mathf.Clamp(grabY, 0, 1);
        _bounds = source.GetSurfaceRect().Grow(8);
        Vector2I resolution = new((int)Math.Ceiling(_bounds.Size.X * 2), (int)Math.Ceiling(_bounds.Size.Y * 2));
        _snapshot = new SubViewport { Name = "FoldFoodSnapshot", Size = resolution * new Vector2I(1, 2),
            TransparentBg = true, Disable3D = true, GuiDisableInput = true,
            RenderTargetUpdateMode = SubViewport.UpdateMode.Always };
        AddChild(_snapshot);
        _snapshot.AddChild(source.CreateFoodPreview(resolution, composite: true));
        Control underside = source.CreateFoodPreview(resolution, bare: true, composite: true);
        underside.Position = new Vector2(0, resolution.Y);
        _snapshot.AddChild(underside);
        for (int cell = 0; cell < Strips * Rows; cell++)
        {
            int v = cell * 4, index = cell * 6;
            _indices[index] = v; _indices[index + 1] = v + 1; _indices[index + 2] = v + 2;
            _indices[index + 3] = v; _indices[index + 4] = v + 2; _indices[index + 5] = v + 3;
        }
    }

    public void SetProgress(float amount) { _progress = amount; QueueRedraw(); }

    public void Finish(bool commit, bool reducedMotion)
    {
        if (_disposed) return;
        if (reducedMotion || _warmup < 3) { DisposePreview(); return; }
        _finishing = true; _commit = commit; _from = _progress; _time = 0;
    }

    public override void _Process(double delta)
    {
        if (_disposed) return;
        if (++_warmup == 3)
        {
            _source.FoldPreviewVisible = true;
            _source.QueueRedraw();
            _snapshot.RenderTargetUpdateMode = SubViewport.UpdateMode.Disabled;
        }
        if (_finishing)
        {
            _time += (float)delta;
            float t = Mathf.Clamp(_time / (_commit ? .22f : .18f), 0, 1);
            _progress = Mathf.Lerp(_from, _commit ? 1 : 0, 1 - Mathf.Pow(1 - t, 3));
            if (t >= 1) { DisposePreview(); return; }
        }
        QueueRedraw();
    }

    public void DisposePreview()
    {
        if (_disposed) return;
        _disposed = true;
        _source.FoldPreviewVisible = false;
        _source.QueueRedraw();
        Hide();
        QueueFree();
    }

    public override void _ExitTree() => _mesh.Dispose();

    public override void _Draw()
    {
        if (_disposed || _warmup < 3) return;
        Texture2D texture = _snapshot.GetTexture();
        // The half on the stove supports a continuously curved, sagging flap.
        float x = _direction > 0 ? .5f : 0;
        DrawTextureRectRegion(texture,
            new Rect2(_bounds.Position + new Vector2(_bounds.Size.X * x, 0), _bounds.Size * new Vector2(.5f, 1)),
            new Rect2(texture.GetSize() * new Vector2(x, 0), texture.GetSize() * .5f));
        DrawFlap(texture);
    }

    private void DrawFlap(Texture2D texture)
    {
        for (int i = 0; i <= Strips; i++)
            for (int row = 0; row <= Rows; row++)
                _grid[i * (Rows + 1) + row] = BendPoint((float)i / Strips, (float)row / Rows);
        for (int i = 0; i < Strips; i++)
        {
            float s0 = (float)i / Strips, s1 = (float)(i + 1) / Strips;
            for (int row = 0; row < Rows; row++)
            {
                float v0 = (float)row / Rows, v1 = (float)(row + 1) / Rows;
                float face = BendAngle((s0 + s1) * .5f, (v0 + v1) * .5f) > Mathf.Pi * .5f ? .5f : 0;
                int first = (i * Rows + row) * 4;
                for (int c = 0; c < 4; c++)
                {
                    bool nextColumn = c is 1 or 2, nextRow = c is 2 or 3;
                    float s = nextColumn ? s1 : s0, v = nextRow ? v1 : v0;
                    Vector2 point = _grid[(i + (nextColumn ? 1 : 0)) * (Rows + 1) + row + (nextRow ? 1 : 0)];
                    _vertices[first + c] = new Vector3(point.X, point.Y, 0);
                    _uv[first + c] = new(.5f - _direction * .5f * s, v * .5f + face);
                    float shade = 1 - .22f * Mathf.Sin(BendAngle(s, v));
                    _colors[first + c] = new Color(shade, shade, shade, 1);
                }
            }
        }
        // Explicit triangles also handle the edge-on and locally overlapping
        // parts of a soft curl, for which polygon auto-triangulation is ambiguous.
        var arrays = new Godot.Collections.Array(); arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = _vertices;
        arrays[(int)Mesh.ArrayType.TexUV] = _uv;
        arrays[(int)Mesh.ArrayType.Color] = _colors;
        arrays[(int)Mesh.ArrayType.Index] = _indices;
        _mesh.ClearSurfaces(); _mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
        DrawMesh(_mesh, texture);
    }

    private float BendAngle(float distance, float across)
    {
        // The grabbed part leads; unsupported corners lag and the outer rim curls
        // more than the material near the crease. Both ends flatten naturally.
        float p = Mathf.Clamp(_progress - .14f * Mathf.Sin(_progress * Mathf.Pi)
            * Math.Abs(across - _grabY), 0, 1);
        return Mathf.Clamp(Mathf.Pi * p + 1.9f * Mathf.Sin(Mathf.Pi * p) * (distance - .42f), 0, Mathf.Pi);
    }

    private Vector2 BendPoint(float distance, float across)
    {
        // Integrate the changing tangent instead of rotating a rigid half-disc.
        // Preserve arc length along the skin; project height into the stove view.
        const int steps = 24;
        float travel = 0, height = 0;
        for (int j = 0; j < steps; j++)
        {
            float angle = BendAngle(distance * (j + .5f) / steps, across);
            travel += Mathf.Cos(angle) * distance / steps;
            height += Mathf.Sin(angle) * distance / steps;
        }
        float radius = _bounds.Size.X * .5f;
        float slack = Mathf.Sin(_progress * Mathf.Pi) * Mathf.Sin(distance * Mathf.Pi)
            * Mathf.Sin(across * Mathf.Pi);
        return new Vector2(_bounds.GetCenter().X - _direction * radius * travel,
            _bounds.Position.Y + _bounds.Size.Y * across - radius * .48f * height + 13 * slack);
    }
}
