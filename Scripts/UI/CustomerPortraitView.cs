using Godot;

namespace ProjectCake.UI;

public partial class CustomerPortraitView : Control
{
    private const float HalfBodyZoom = 1.7f;
    private const float TopInset = 6.0f;

    private readonly TextureRect _body;
    private readonly TextureRect _head;

    public CustomerPortraitView()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        ClipContents = true;
        _body = CreateLayer();
        _head = CreateLayer();
        AddChild(_body);
        AddChild(_head);
        Resized += LayoutLayers;
        LayoutLayers();
    }

    public Texture2D? BodyTexture => _body.Texture;
    public Texture2D? HeadTexture => _head.Texture;

    public void SetVisual(CustomerPortraitVisual visual)
    {
        if (_body.Texture != visual.Body) _body.Texture = visual.Body;
        if (_head.Texture != visual.Head) _head.Texture = visual.Head;
        CustomMinimumSize = new Vector2(0, visual.DisplaySize.Y);
    }

    private static TextureRect CreateLayer()
    {
        return new TextureRect
        {
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
            MouseFilter = MouseFilterEnum.Ignore,
        };
    }

    private void LayoutLayers()
    {
        Vector2 layerPosition = new(0, TopInset);
        Vector2 layerSize = new(Size.X, Size.Y * HalfBodyZoom);
        _body.Position = layerPosition;
        _body.Size = layerSize;
        _head.Position = layerPosition;
        _head.Size = layerSize;
    }
}
