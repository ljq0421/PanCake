using Godot;

namespace ProjectCake.UI;

public enum CustomerPortraitPresentation
{
    FullBody,
    CounterHalfBody,
}

public partial class CustomerPortraitView : Control
{
    private const float PortraitCanvasWidth = 1086.0f;
    private const float PortraitCanvasHeight = 328.0f;
    private const float PortraitSourceHeight = 1448.0f;
    private const float TopInset = 6.0f;
    private const float CounterVisibleFraction = 0.65f;

    private TextureRect _body = null!;
    private TextureRect _head = null!;
    private Vector2 _displaySize;
    private CustomerPortraitPresentation _presentation;
    private float _portraitScale = 1.0f;
    private Vector2 _headAnchor = new(0.5f, 0.25f);
    private Rect2? _counterHeadBounds;

    /// <summary>Tianjin-only fitting: a 155px head above a fixed 240px waist crop.</summary>
    public void SetCounterCalibration(Rect2 normalHeadBounds)
    {
        _counterHeadBounds = normalHeadBounds;
        LayoutLayers();
    }

    public override void _Ready()
    {
        SceneNodeBinder.Bind(this);
        Resized += LayoutLayers;
        LayoutLayers();
    }

    public Texture2D? BodyTexture => _body.Texture;
    public Texture2D? HeadTexture => _head.Texture;
    public float PortraitScale => _portraitScale;
    public Vector2 HeadAnchor => _headAnchor;
    public Vector2 BodyLayerScale => _body.Scale;
    public Vector2 HeadLayerScale => _head.Scale;
    public float VisibleBodyFraction => _presentation == CustomerPortraitPresentation.CounterHalfBody
        ? CounterVisibleFraction
        : 1.0f;

    [Export]
    public CustomerPortraitPresentation Presentation
    {
        get => _presentation;
        set
        {
            if (_presentation == value) return;
            _presentation = value;
            if (!IsInstanceValid(_body) || !IsInstanceValid(_head)) return;
            RefreshMinimumSize();
            LayoutLayers();
        }
    }

    public void SetVisual(CustomerPortraitVisual visual)
    {
        if (_body.Texture != visual.Body) _body.Texture = visual.Body;
        if (_head.Texture != visual.Head) _head.Texture = visual.Head;
        _displaySize = visual.DisplaySize;
        _portraitScale = visual.PortraitScale;
        _headAnchor = visual.HeadAnchor;
        RefreshMinimumSize();
        LayoutLayers();
    }

    private void LayoutLayers()
    {
        if (_counterHeadBounds is Rect2 head)
        {
            float counterScale = 155f / head.Size.Y;
            Vector2 sourceWaist = new(head.GetCenter().X, head.Position.Y + 240f / counterScale);
            Vector2 position = new Vector2(Size.X * .5f, Size.Y) - sourceWaist * counterScale;
            foreach (TextureRect layer in new[] { _body, _head })
            {
                layer.Position = position;
                layer.Size = new Vector2(PortraitCanvasWidth, PortraitSourceHeight) * counterScale;
                layer.PivotOffset = Vector2.Zero;
                layer.Scale = Vector2.One;
            }
            return;
        }
        float layerHeight = _presentation == CustomerPortraitPresentation.CounterHalfBody
            ? Math.Max(PortraitCanvasHeight, Size.Y / CounterVisibleFraction)
            : PortraitCanvasHeight;
        Vector2 layerPosition = new(0, TopInset);
        Vector2 layerSize = new(Size.X, layerHeight);
        _body.Position = layerPosition;
        _body.Size = layerSize;
        _head.Position = layerPosition;
        _head.Size = layerSize;

        float sourceAspect = PortraitCanvasWidth / PortraitSourceHeight;
        Vector2 fittedSize = layerSize.X / layerSize.Y > sourceAspect
            ? new Vector2(layerSize.Y * sourceAspect, layerSize.Y)
            : new Vector2(layerSize.X, layerSize.X / sourceAspect);
        Vector2 fittedOffset = (layerSize - fittedSize) * 0.5f;
        Vector2 pivot = fittedOffset + new Vector2(fittedSize.X * _headAnchor.X, fittedSize.Y * _headAnchor.Y);
        Vector2 scale = Vector2.One * _portraitScale;
        _body.PivotOffset = pivot;
        _head.PivotOffset = pivot;
        _body.Scale = scale;
        _head.Scale = scale;
    }

    private void RefreshMinimumSize()
    {
        float height = _presentation == CustomerPortraitPresentation.CounterHalfBody
            ? Math.Max(220, _displaySize.Y)
            : _displaySize.Y;
        CustomMinimumSize = new Vector2(0, height);
    }
}
