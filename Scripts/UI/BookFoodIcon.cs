using Godot;
namespace ProjectCake.UI;

public partial class BookStatusMark : Control
{
    public BookOutcome Outcome { get; set; }
    public Color Ink { get; set; }
    public override void _Ready() => MouseFilter = MouseFilterEnum.Ignore;
    public override void _Draw()
    {
        var c = Size / 2; float r = Math.Min(Size.X, Size.Y) * .43f;
        if (Outcome == BookOutcome.Perfect)
        {
            var points = Enumerable.Range(0, 10).Select(i => c + Vector2.FromAngle(-Mathf.Pi / 2 + i * Mathf.Pi / 5) * r * (i % 2 == 0 ? 1 : .45f)).ToArray();
            DrawColoredPolygon(points, Ink); return;
        }
        DrawArc(c, r, 0, Mathf.Tau, 36, Ink, 2, true);
        if (Outcome is BookOutcome.Lost or BookOutcome.Unreceived) { DrawLine(c, c + new Vector2(0, -r * .6f), Ink, 3, true); DrawLine(c, c + new Vector2(r * .5f, r * .2f), Ink, 3, true); }
        else if (Outcome == BookOutcome.Incorrect) { DrawLine(c - new Vector2(0, r * .6f), c + new Vector2(0, r * .15f), Ink, 3, true); DrawCircle(c + new Vector2(0, r * .55f), 2, Ink); }
        else DrawPolyline(new[] { c + new Vector2(-r * .55f, 0), c + new Vector2(-r * .1f, r * .4f), c + new Vector2(r * .6f, -r * .45f) }, Ink, 3, true);
    }
}

/// <summary>Existing food art where available; otherwise a named, vector food symbol.</summary>
public partial class BookFoodIcon : Control
{
    public BookProduct Product { get; set; } = new("", "", 0, "");
    private static readonly Dictionary<string, Texture2D> Cache = new();
    public override void _Ready() => MouseFilter = MouseFilterEnum.Ignore;
    public override void _Draw()
    {
        string? path = Product.Visual switch
        {
            "Pancake" => "TianJin/装袋后的通用煎饼果子.png",
            "SoyMilk" => "TianJin/成品豆浆杯.png",
            "Youtiao" => "TianJin/熟油条.png",
            "HotDryNoodles" => "Wuhan/热干面完整成品.png",
            "Doupi" => "Wuhan/单块三鲜豆皮成品.png",
            "EggRiceWine" => "Wuhan/成品蛋酒杯_v2.png",
            "Roujiamo" => "XiAn/通用卡通腊汁肉夹馍成品.png", _ => null,
        };
        if (path is not null && ResourceLoader.Exists("res://resource/art/" + path))
        {
            if (!Cache.TryGetValue(path, out var texture)) Cache[path] = texture = GD.Load<Texture2D>("res://resource/art/" + path);
            Vector2 s = texture.GetSize(); s *= Math.Min(Size.X / s.X, Size.Y / s.Y);
            DrawTextureRect(texture, new Rect2((Size - s) / 2, s), false); return;
        }
        var ink = new Color("#795437"); var cream = new Color("#F3D591"); var c = Size / 2;
        float w = Size.X, h = Size.Y;
        bool drink = Product.Visual is "SoyMilk" or "MorningTea" or "T01" or "Hulatang";
        if (drink)
        {
            var p = new[] { new Vector2(w*.23f,h*.2f), new Vector2(w*.77f,h*.2f), new Vector2(w*.68f,h*.82f), new Vector2(w*.32f,h*.82f) };
            DrawColoredPolygon(p, new Color("#EEE2BF")); DrawPolyline(p.Append(p[0]).ToArray(), ink, 2, true);
            DrawLine(new(w*.31f,h*.32f),new(w*.69f,h*.32f),ink,2,true);
        }
        else if (Product.Visual is "RiceRoll" or "Youtiao")
        {
            for(int i=0;i<3;i++) { var box = TianjinUi.Box(cream, 8, 2, false); box.BorderColor=ink; DrawStyleBox(box,new Rect2(w*.17f,h*(.2f+i*.2f),w*.66f,h*.17f)); }
        }
        else if (Product.Visual == "G01")
        {
            DrawCircle(c,w*.4f,new Color("#DCE5CD"));
            for(int i=0;i<7;i++) DrawLine(new(w*.28f+i*w*.07f,h*.25f),new(w*.23f+i*w*.07f,h*.74f),cream,3,true);
            DrawArc(c,w*.4f,0,Mathf.Tau,32,ink,2,true);
        }
        else
        {
            DrawCircle(c,w*.37f,cream); DrawArc(c,w*.37f,0,Mathf.Tau,32,ink,2,true);
            for(int i=0;i<4;i++) DrawLine(c+new Vector2((i-1.5f)*w*.12f,-h*.18f),c+new Vector2(0,-h*.02f),ink,2,true);
        }
    }
}
