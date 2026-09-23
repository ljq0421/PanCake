using Godot;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private void DecorateDemoIntroduction(bool wuhan)
    {
        // Keep the entry composition inside the printed page, including the button's hover scale.
        foreach (var control in _body.GetChildren().OfType<Control>())
        {
            string name = control.Name;
            if (name.StartsWith(wuhan ? "WuhanBreakfast" : "Breakfast", StringComparison.Ordinal)
                || name == (wuhan ? "WuhanReturnHint" : "DepartureHint")
                || name == (wuhan ? "WuhanOpeningContinue" : "Depart"))
                control.Position -= new Vector2(0, 44);
        }

        var title = _body.GetNode<Label>(wuhan ? "WuhanOpeningTitle" : "StationTitle");
        var ribbon = HomeArt(_body, "Dayx背景", new(340, 248, 550, 140), stretch: true);
        ribbon.Name = "IntroductionTitleBacking";
        _body.MoveChild(ribbon, title.GetIndex());

        var postcard = _body.GetNode<Control>(wuhan ? "WuhanJourneyPostcard" : "JourneyPostcard");
        postcard.PivotOffset = postcard.Size / 2;
        postcard.Scale = Vector2.One * 1.1f;
        postcard.RotationDegrees = -3;
        if (wuhan)
        {
            postcard.Position += new Vector2(0, 20);
            _body.GetNode<Control>("WuhanPostcardMarker").Position += new Vector2(0, 58);
            _body.GetNode<Control>("WuhanPostcardCity").Position += new Vector2(0, 58);
        }

        var heading = _body.GetNode<Label>(wuhan ? "WuhanBreakfastHeading" : "BreakfastHeading");
        var note = new TextureRect
        {
            Name = "IntroductionHeadingBacking", Texture = BookArtCatalog.Get("今日手记便签底板"),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            Position = new(995, 220), Size = new(555, 104),
            StretchMode = TextureRect.StretchModeEnum.Scale, MouseFilter = MouseFilterEnum.Ignore
        };
        _body.AddChild(note);
        _body.MoveChild(note, heading.GetIndex());

        foreach (var icon in _body.GetChildren().OfType<BookFoodIcon>().ToArray())
        {
            float padding = icon.Size.X > 150 ? 18 : 10;
            var backing = Art(_body, "res://resource/art/Global/UpgradeUI/设备涂鸦背景-v1.png",
                new(icon.Position - Vector2.One * padding, icon.Size + Vector2.One * padding * 2));
            backing.Name = icon.Name + "Backing";
            _body.MoveChild(backing, icon.GetIndex());
        }
    }
}
