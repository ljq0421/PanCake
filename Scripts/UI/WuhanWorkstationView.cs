using Godot;
using ProjectCake.Data;
using ProjectCake.Wuhan;

namespace ProjectCake.UI;

/// <summary>
/// Artwork, hit targets and transient presentation for the four Wuhan stations.
/// All tweens are manually stepped by the day screen, so pause, tests and cooking
/// share one clock. Completion never changes inventory or production state.
/// </summary>
public partial class WuhanWorkstationView : Control
{
    public event Action<int>? BasketPressed;
    public event Action<string>? IngredientPressed;
    public event Action? DoupiPressed, StockPressed, EggPressed, NoodlesPressed;
    public event Action<float>? MixMoved;
    public Func<bool>? CanInteract { get; set; }

    public static readonly string[] IngredientIds = { StableIds.Ingredients.WuhanBaseSeasoning,
        StableIds.Ingredients.WuhanScallion, StableIds.Ingredients.WuhanChiliOil, StableIds.Ingredients.WuhanBraisedBeef };
    private WuhanArtCatalog _art = null!;
    private NoodleCookerStateMachine _cooker = null!;
    private HotDryNoodlesStateMachine _bowl = null!;
    private DoupiStateMachine? _doupi;
    private DoupiInventory _stock = null!;
    private EggRiceWineRuntime? _egg;
    private WuhanIngredientInventory _ingredients = null!;
    private int _cookerLevel, _doupiLevel;
    private readonly Dictionary<Texture2D, Rect2> _bounds = new();
    private readonly List<Motion> _motions = new();
    private readonly NoodleBasketState[] _previousBaskets = new NoodleBasketState[2];
    private DoupiState _previousDoupi;
    private float _phase;
    private Vector2? _mixLast;
    private string _hover = "";
    public bool IsMixing => _mixLast.HasValue;
    public int ActiveMotionCount => _motions.Count;
    public static bool ReducedMotion => ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();

    private sealed class Motion
    {
        public required string Kind;
        public required string[] Locks;
        public required Tween Tween;
        public float Progress;
        public int Index;
        public string Ingredient = "";
        public Vector2 Target;
        public NoodleQuality Quality;
        public string[] Toppings = Array.Empty<string>();
        public DoupiState Before;
    }

    // Coordinates live in the existing 1920 x 1080 design space; this view starts at y=555.
    private static readonly Rect2 BowlRect = new(583, 97, 262, 202);
    private static readonly Rect2 BowlFood = new(602, 111, 224, 111);
    private static readonly Rect2 PanRect = new(987, 3, 433, 300);
    private static readonly Rect2 StockRect = new(1080, 274, 235, 87);
    private static readonly Rect2 EggMachine = new(1530, 2, 332, 343);
    private static readonly Rect2 CupRect = new(1687, 187, 75, 62);
    private static readonly Rect2 RawRect = new(45, 49, 94, 53);
    private static Rect2 IngredientRect(int index) => index switch
    {
        0 => new Rect2(475, 64, 88, 102), 1 => new Rect2(475, 208, 94, 67),
        2 => new Rect2(859, 61, 87, 108), _ => new Rect2(855, 207, 99, 73)
    };
    public Vector2 BowlCenter => BowlFood.GetCenter();
    public Vector2 IngredientCenter(int index) => IngredientRect(index).GetCenter();
    public Vector2 StockCenter => StockRect.GetCenter();
    public Vector2 PanCenter => new(1205, 154);
    public Vector2 CupCenter => CupRect.GetCenter();

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Stop;
        MouseExited += () => { EndMix(); _hover = ""; QueueRedraw(); };
    }

    public void Bind(WuhanArtCatalog art, NoodleCookerStateMachine cooker, HotDryNoodlesStateMachine bowl,
        DoupiStateMachine? doupi, DoupiInventory stock, EggRiceWineRuntime? egg,
        WuhanIngredientInventory ingredients, int cookerLevel, int doupiLevel)
    {
        CancelAnimations();
        _art = art; _cooker = cooker; _bowl = bowl; _doupi = doupi; _stock = stock;
        _egg = egg; _ingredients = ingredients; _cookerLevel = cookerLevel; _doupiLevel = doupiLevel;
        _phase=0; RememberStates(); QueueRedraw();
    }

    public bool Busy(string channel) => _motions.Any(m => m.Locks.Contains(channel));
    public float MotionProgress(string channel) => _motions.FirstOrDefault(m => m.Locks.Contains(channel))?.Progress ?? 1;
    public void EndMix() { _mixLast = null; QueueRedraw(); }
    public void CancelAnimations()
    {
        foreach (Motion m in _motions) m.Tween.Kill();
        _motions.Clear(); EndMix(); _hover = ""; QueueRedraw();
    }
    public override void _ExitTree() => CancelAnimations();

    private Motion Play(string kind, double seconds, params string[] channels)
    {
        var tween = CreateTween(); tween.Pause();
        var motion = new Motion { Kind = kind, Locks = channels, Tween = tween };
        tween.TweenMethod(Callable.From<float>(p => motion.Progress = p), 0f, 1f, ReducedMotion ? .12 : seconds);
        _motions.Add(motion); QueueRedraw(); return motion;
    }
    public void PlayBasket(int index, NoodleBasketState before, NoodleQuality quality)
    {
        string kind = before switch
        {
            NoodleBasketState.Empty => "drop", NoodleBasketState.Raised or NoodleBasketState.Draining => "shake",
            NoodleBasketState.Drained => "pour", _ => "raise"
        };
        Motion m = kind == "pour" ? Play(kind, .66, $"basket{index}", "bowl") : Play(kind, .24, $"basket{index}");
        m.Index = index; m.Quality = quality; RememberStates();
    }
    public void PlayIngredient(string ingredient)
    {
        Play("ingredient", .48, "bowl").Ingredient = ingredient;
    }
    public void PlayRefill(string ingredient) => Play("refill", 1, "refill:" + ingredient).Ingredient = ingredient;
    public void PlayDoupi(DoupiState before)
    {
        string kind = before switch { DoupiState.Empty => "batter", DoupiState.Batter => "egg",
            DoupiState.ReadyToFlip => "flip", DoupiState.Flipped => "filling",
            DoupiState.Cut => "stock", DoupiState.Burnt => "discard", _ => "cut" };
        Motion m = kind == "stock" ? Play(kind, .48, "pan", "stock") : Play(kind, kind == "flip" ? .48 : .36, "pan");
        m.Before = before; m.Index = _doupi?.CompletedCuts ?? 0; RememberStates();
    }
    public void PlayEgg(bool refill) => Play(refill ? "egg_refill" : "brew", .6, "egg");
    public void PlayDelivery(ProductKind kind, Vector2 target, NoodleQuality quality = NoodleQuality.Optimal, string[]? toppings = null)
    {
        Motion m = Play("delivery", .48, kind == ProductKind.HotDryNoodles ? "bowl" : kind == ProductKind.Doupi ? "stock" : "egg");
        m.Index = (int)kind; m.Target = target; m.Quality = quality; m.Toppings = toppings ?? Array.Empty<string>();
        EndMix();
    }

    public void Tick(double delta)
    {
        if (_cooker is null || delta <= 0) return;
        foreach (Motion m in _motions.ToArray())
        {
            m.Tween.CustomStep(delta);
            if (m.Progress >= .9999f) { m.Tween.Kill(); _motions.Remove(m); }
        }
        // Automatic equipment transitions use the same visual action as a manual click.
        NoodleBasketState[] previousBaskets = (NoodleBasketState[])_previousBaskets.Clone();
        DoupiState previousDoupi = _previousDoupi;
        for (int i = 0; i < _cooker.Baskets.Count; i++)
            if (_cooker.Baskets[i].State == NoodleBasketState.Draining && !IsRaised(previousBaskets[i]) && !Busy($"basket{i}"))
                PlayBasket(i, NoodleBasketState.Ready, _cooker.Baskets[i].Quality);
        if (_doupi?.State == DoupiState.Flipped && previousDoupi == DoupiState.SkinCooking && !Busy("pan"))
            PlayDoupi(DoupiState.ReadyToFlip);
        RememberStates(); _phase += (float)delta; QueueRedraw();
    }
    private void RememberStates()
    {
        if (_cooker is null) return;
        for (int i = 0; i < _cooker.Baskets.Count; i++) _previousBaskets[i] = _cooker.Baskets[i].State;
        _previousDoupi = _doupi?.State ?? DoupiState.Empty;
    }
    private static bool IsRaised(NoodleBasketState state) => state is NoodleBasketState.Raised or NoodleBasketState.Draining or NoodleBasketState.Drained;
    private Motion? Find(string channel) => _motions.FirstOrDefault(m => m.Locks.Contains(channel));
    private static float Ease(float t) => 1 - Mathf.Pow(1 - Mathf.Clamp(t, 0, 1), 3);
    private static float Segment(float t, float from, float to) => Ease((t - from) / (to - from));

    public override void _GuiInput(InputEvent input)
    {
        if (_cooker is null || CanInteract?.Invoke() != true) { EndMix(); return; }
        if (input is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
        {
            if (!mb.Pressed) { EndMix(); return; }
            string hit = HitTarget(mb.Position);
            if (hit.StartsWith("basket")) BasketPressed?.Invoke(int.Parse(hit[^1..]));
            else if (hit.StartsWith("ingredient")) IngredientPressed?.Invoke(IngredientIds[int.Parse(hit[^1..])]);
            else if (hit == "pan") DoupiPressed?.Invoke();
            else if (hit == "stock") StockPressed?.Invoke();
            else if (hit == "egg") EggPressed?.Invoke();
            else if (hit == "raw")
            {
                int index = Enumerable.Range(0, _cooker.Baskets.Count).FirstOrDefault(i => _cooker.Baskets[i].State == NoodleBasketState.Empty && !Busy($"basket{i}"), -1);
                if (index >= 0) BasketPressed?.Invoke(index);
            }
            else if (hit == "bowl" && !Busy("bowl"))
            {
                if (_bowl.State == NoodleBowlState.Ready) NoodlesPressed?.Invoke();
                else if (_bowl.State is NoodleBowlState.Seasoned or NoodleBowlState.Mixing) _mixLast = mb.Position;
            }
            AcceptEvent(); QueueRedraw();
        }
        else if (input is InputEventMouseMotion mm)
        {
            _hover = HitTarget(mm.Position);
            if ((mm.ButtonMask & MouseButtonMask.Left) == 0 || !InBowl(mm.Position) || Busy("bowl")) EndMix();
            else if (_mixLast is Vector2 previous)
            {
                MixMoved?.Invoke(previous.DistanceTo(mm.Position)); _mixLast = mm.Position;
                if (_bowl.State == NoodleBowlState.Ready) EndMix();
            }
            MouseDefaultCursorShape = _hover.Length > 0 ? CursorShape.PointingHand : CursorShape.Arrow;
            QueueRedraw();
        }
    }

    public bool InBowl(Vector2 p) => ((p - BowlFood.GetCenter()) / (BowlFood.Size * .5f)).LengthSquared() <= 1;
    public string HitTarget(Vector2 p)
    {
        if (_cooker is null) return "";
        if (InBowl(p)) return "bowl";
        for (int i = 0; i < 4; i++) if (IngredientRect(i).Grow(4).HasPoint(p)) return $"ingredient{i}";
        for (int i = 0; i < _cooker.Baskets.Count; i++)
            if (BasketRect(i).HasPoint(p)) return $"basket{i}";
        if (RawRect.HasPoint(p)) return "raw";
        if (StockRect.HasPoint(p)) return "stock";
        if (new Rect2(1003, 65, 400, 195).HasPoint(p)) return "pan";
        if (EggMachine.HasPoint(p)) return "egg";
        return "";
    }

    public override void _Draw()
    {
        if (_cooker is null) return;
        DrawCooker(); DrawMixStation(); DrawDoupi(); DrawEgg(); DrawRefills(); DrawTransfers();
    }

    private Rect2 Source(Texture2D texture)
    {
        if (!_bounds.TryGetValue(texture, out Rect2 bounds))
        {
            using Image img = texture.GetImage();
            // Generated PNGs contain almost-transparent matte residue outside the art.
            // GetUsedRect counts that residue and silently shifts every authored anchor.
            img.Convert(Image.Format.Rgba8);
            byte[] pixels=img.GetData();int width=img.GetWidth(),height=img.GetHeight();
            int left=width,top=height,right=-1,bottom=-1;
            for(int y=0;y<height;y++)for(int x=0;x<width;x++)
                if(pixels[(y*width+x)*4+3]>=32){left=Math.Min(left,x);right=Math.Max(right,x);top=Math.Min(top,y);bottom=Math.Max(bottom,y);}
            // Steam is already painted above the finished cup. Align the ceramic
            // body to the base cup and draw animated steam separately.
            if(texture==_art.Texture("egg_finished"))top=Math.Max(top,(int)(height*.222f));
            bounds=right>=left?new Rect2(left,top,right-left+1,bottom-top+1):new Rect2(Vector2.Zero,texture.GetSize());
            _bounds[texture] = bounds;
        }
        return bounds;
    }
    private void Sprite(string id, Rect2 rect, float alpha = 1, float angle = 0) => Sprite(_art.Texture(id), rect, alpha, angle);
    private void Sprite(Texture2D texture, Rect2 rect, float alpha = 1, float angle = 0)
    {
        if (alpha <= 0) return;
        DrawSetTransform(rect.GetCenter(), angle);
        DrawTextureRectRegion(texture, new Rect2(-rect.Size / 2, rect.Size), Source(texture), new Color(1, 1, 1, alpha));
        DrawSetTransform(Vector2.Zero);
    }
    private void Ellipse(Vector2 center, Vector2 radius, Color color)
    {
        Vector2[] points = Enumerable.Range(0, 48).Select(i => center + Vector2.FromAngle(i * Mathf.Tau / 48) * radius).ToArray();
        DrawColoredPolygon(points, color);
    }
    private void Hint(Rect2 rect, string target)
    {
        if (_hover == target && CanInteract?.Invoke() == true)
            Ellipse(rect.GetCenter(), rect.Size * .55f, new Color(1, .85f, .3f, .18f));
    }
    private static Rect2 At(Vector2 center, Vector2 size) => new(center - size / 2, size);

    private Rect2 CookerCanvas => _cookerLevel == 3 ? new Rect2(24, 74, 417, 282) : new Rect2(29, -7, 412, 412);
    private Vector2 BasketHome(int index) => _cookerLevel == 3 ? new Vector2(index == 0 ? 161 : 305, 187) : new Vector2(191, 162);
    public Rect2 BasketRect(int index)
    {
        Motion? m = Find($"basket{index}");
        float raised = IsRaised(_cooker.Baskets[index].State) ? 1 : 0;
        if (m?.Kind == "raise") raised = ReducedMotion ? 1 : Ease(m.Progress);
        Vector2 center = BasketHome(index) + new Vector2(0, -67 * raised);
        if (m?.Kind == "shake" && !ReducedMotion) center.Y += Mathf.Sin(m.Progress * Mathf.Tau * 2) * 10;
        return At(center, _cookerLevel == 3 ? new Vector2(121, 151) : new Vector2(144, 179));
    }
    private void DrawCooker()
    {
        Rect2 c = CookerCanvas;
        DrawTextureRect(_art.Cooker(_cookerLevel), c, false);
        // Rebuild the inner water surface only. It covers the baked-in baskets while
        // leaving the outer pot rim and upgrade machinery visible.
        Vector2[] water = _cookerLevel == 3
            ? new[] { new Vector2(.205f,.365f), new(.235f,.32f), new(.32f,.295f), new(.5f,.288f), new(.69f,.295f), new(.78f,.335f), new(.812f,.42f), new(.785f,.50f), new(.70f,.55f), new(.51f,.565f), new(.32f,.55f), new(.21f,.485f) }
            : new[] { new Vector2(.175f,.388f), new(.19f,.31f), new(.32f,.264f), new(.49f,.244f), new(.67f,.264f), new(.79f,.335f), new(.825f,.435f), new(.795f,.513f), new(.69f,.55f), new(.51f,.567f), new(.345f,.548f), new(.21f,.51f), new(.16f,.435f) };
        DrawColoredPolygon(water.Select(p => c.Position + p * c.Size).ToArray(), new Color("#8EDCF2"));
        Ellipse(c.Position + c.Size * new Vector2(.55f, .39f), c.Size * new Vector2(.145f, .045f), new Color("#AAE8F6"));
        Hint(RawRect, "raw"); Sprite(_art.Shared.IngredientTray, RawRect.Grow(8));
        Sprite("raw_noodles", RawRect, _ingredients.Count(StableIds.Ingredients.WuhanNoodles) > 0 ? 1 : .25f);
        DrawString(ThemeDB.FallbackFont, new Vector2(148, 78), $"面条 {_ingredients.Count(StableIds.Ingredients.WuhanNoodles)}", fontSize: 17, modulate: TianjinUi.BrownDark);
        for (int i = 0; i < _cooker.Baskets.Count; i++)
        {
            Motion? m = Find($"basket{i}"); NoodleBasketRuntime basket = _cooker.Baskets[i];
            if (m?.Kind == "pour" && !ReducedMotion) continue;
            Rect2 r = BasketRect(i); Hint(r, $"basket{i}"); Sprite("basket", r);
            if (basket.State != NoodleBasketState.Empty)
            {
                Rect2 noodles = new(r.Position + r.Size * new Vector2(.10f, .42f), r.Size * new Vector2(.59f, .24f));
                if (m?.Kind == "drop" && !ReducedMotion)
                {
                    float p = Ease(m.Progress); noodles = At(RawRect.GetCenter().Lerp(noodles.GetCenter(), p), RawRect.Size.Lerp(noodles.Size, p));
                }
                Sprite(basket.Quality == NoodleQuality.Overcooked ? "overcooked" : basket.State == NoodleBasketState.Cooking ? "raw_noodles" : "cooked_basket", noodles);
                if (basket.State is NoodleBasketState.Cooking or NoodleBasketState.Ready or NoodleBasketState.Soft or NoodleBasketState.Locked)
                {
                    Steam(noodles.GetCenter() + new Vector2(0,-10), .55f);
                    for (int j=0;j<4;j++) DrawArc(noodles.GetCenter()+new Vector2(j*15-22,13), 3 + Mathf.PosMod((ReducedMotion ? 0 : _phase*5)+j,4), 0, Mathf.Tau, 16, new Color(1,1,1,.55f), 1.5f, true);
                }
                if (basket.State is NoodleBasketState.Raised or NoodleBasketState.Draining || m?.Kind == "shake")
                    Drips(r.Position + r.Size * new Vector2(.38f,.94f), m?.Kind == "shake" ? 8 : 4);
            }
        }
        // Repaint the authored front rim over submerged basket bottoms. The source
        // starts below the baked-in baskets, so none of those can be reintroduced.
        Texture2D pot = _art.Cooker(_cookerLevel);
        const float front = .568f;
        DrawTextureRectRegion(pot, new Rect2(c.Position + new Vector2(0,c.Size.Y*front),c.Size*new Vector2(1,1-front)),
            new Rect2(new Vector2(0,pot.GetHeight()*front),pot.GetSize()*new Vector2(1,1-front)));
    }

    private void DrawMixStation()
    {
        Sprite("mix_station", new Rect2(465, 111, 493, 235));
        Hint(BowlRect, "bowl");
        Motion? m = Find("bowl");
        bool delivering = m?.Kind == "delivery";
        if (!delivering)
        {
            Sprite("empty_bowl", BowlRect);
            if (_bowl.State != NoodleBowlState.Empty && !(m?.Kind == "pour" && m.Progress < .66f && !ReducedMotion))
                DrawBowlContents(BowlFood, _bowl.State, (float)_bowl.MixProgress, _bowl.Quality, _bowl.Toppings,
                    m?.Kind == "ingredient" && m.Progress < .62f ? m.Ingredient : "");
        }
        for (int i=0;i<4;i++)
        {
            Rect2 r = IngredientRect(i); Hint(r, $"ingredient{i}");
            if (i is 1 or 3) Sprite(_art.Shared.IngredientTray, r.Grow(3));
            bool movingContainer=m?.Kind=="ingredient"&&m.Ingredient==IngredientIds[i]&&i is 0 or 2&&!ReducedMotion;
            if(!movingContainer)Sprite(_art.Ingredient(IngredientIds[i]), r, _ingredients.Count(IngredientIds[i]) > 0 ? 1 : .3f);
        }
        if(!(m?.Kind=="ingredient"&&m.Ingredient==IngredientIds[0]&&!ReducedMotion))Sprite("base_sauce", new Rect2(525, 175, 42, 64));
        if (_mixLast is Vector2 pointer)
        {
            Vector2 center = BowlFood.GetCenter();
            float angle = ReducedMotion ? -.3f : (pointer-center).Angle() * .12f - .4f;
            Sprite("chopsticks", At(pointer + new Vector2(20,-27), new Vector2(91,121)), 1, angle);
        }
        else Sprite("chopsticks", new Rect2(801,244,103,65), .9f, -.15f);
        if (m?.Kind == "ingredient") DrawIngredientMotion(m);
    }
    private void DrawBowlContents(Rect2 food, NoodleBowlState state, float progress, NoodleQuality quality,
        IEnumerable<string> toppings, string hidden = "", float opacity = 1)
    {
        Sprite("bowl_noodles", food,opacity);
        bool seasoned = state is NoodleBowlState.Seasoned or NoodleBowlState.Mixing or NoodleBowlState.Ready;
        if (seasoned && hidden != StableIds.Ingredients.WuhanBaseSeasoning)
        {
            float half = Mathf.Clamp(progress / 50, 0, 1), mixed = Mathf.Clamp((progress - 40) / 60, 0, 1);
            Sprite("unmixed", food, (1-half)*opacity);
            Sprite("half_mixed", food, half * (1-mixed)*opacity);
            Sprite("mixed", food, mixed*opacity);
        }
        if (quality == NoodleQuality.Overcooked) Sprite("overcooked", food, (seasoned ? .35f : .8f)*opacity);
        foreach (string topping in toppings)
            if (topping != hidden)
            {
                bool beef=topping==StableIds.Ingredients.WuhanBraisedBeef;
                Rect2 placement=beef?new Rect2(food.Position+food.Size*new Vector2(.25f,.17f),food.Size*new Vector2(.64f,.67f)):food;
                Sprite(topping == StableIds.Ingredients.WuhanScallion ? "scallion" : topping == StableIds.Ingredients.WuhanChiliOil ? "chili_overlay" : "beef_overlay", placement,opacity);
            }
    }
    private void DrawIngredientMotion(Motion m)
    {
        if (ReducedMotion) return;
        int index = Array.IndexOf(IngredientIds,m.Ingredient);
        Rect2 source = IngredientRect(index);
        float p=m.Progress, enter=Segment(p,0,.38f), leave=Segment(p,.72f,1);
        Vector2 target=BowlFood.GetCenter()+new Vector2(index<2?-42:48,-70);
        Vector2 center=source.GetCenter().Lerp(target,enter).Lerp(source.GetCenter(),leave);
        if (index is 0 or 2)
        {
            Sprite(_art.Ingredient(m.Ingredient), At(center,source.Size*.85f), 1, -.65f*enter*(1-leave));
            if(p>.35f&&p<.74f) DrawLine(center+new Vector2(12,22),BowlFood.GetCenter(),index==0?new Color("#BE803B"):new Color("#CB4627"),6,true);
            if(index==0&&p>.5f) Sprite("base_sauce",At(center+new Vector2(55,0),new Vector2(40,64)),1,-.65f);
        }
        else Sprite(index==1?"scallion":"beef_overlay",At(source.GetCenter().Lerp(BowlFood.GetCenter(),Ease(p)),source.Size.Lerp(BowlFood.Size,p)),1-p);
    }

    private Vector2[] PanCorners => _doupiLevel == 3
        ? new[] {new Vector2(1060,93),new Vector2(1361,93),new Vector2(1380,221),new Vector2(1041,221)}
        : new[] {new Vector2(1061,61),new Vector2(1356,61),new Vector2(1378,194),new Vector2(1038,194)};
    private void PanLayer(string id,float alpha=1,float grow=1,float flip=1)
    {
        Vector2[] corners=PanCorners; Vector2 center=(corners[0]+corners[2])/2;
        corners=corners.Select(p=>center+(p-center)*new Vector2(grow,grow*flip)).ToArray();
        Texture2D tex=_art.Texture(id);Rect2 source=Source(tex);Vector2 size=tex.GetSize();
        Vector2[] uv={source.Position/size,new Vector2(source.End.X,source.Position.Y)/size,source.End/size,new Vector2(source.Position.X,source.End.Y)/size};
        // Finished food is drawn in an oblique perspective in its source PNG.
        // Sample its top-face quadrilateral, not the surrounding transparent box.
        if(id=="doupi_finished")uv=new[]{new Vector2(.37f,.20f),new Vector2(.97f,.37f),new Vector2(.725f,.79f),new Vector2(.033f,.553f)};
        if(id=="doupi_cut")uv=new[]{new Vector2(.325f,.21f),new Vector2(.96f,.452f),new Vector2(.706f,.802f),new Vector2(.035f,.597f)};
        DrawPolygon(corners,new[]{new Color(1,1,1,alpha)},uv,tex);
    }
    private void DrawDoupi()
    {
        Sprite(_art.Griddle(Math.Max(1,_doupiLevel)),PanRect,_doupi is null?.4f:1);
        Sprite("doupi_batter",new Rect2(997,271,70,71),_doupi is null?.35f:1);
        Sprite("doupi_filling",new Rect2(1327,278,84,65),_doupi is null?.35f:1);
        Hint(StockRect,"stock");Sprite("doupi_stock",StockRect);
        int displayed=_stock.Count;
        Motion? m=Find("pan");
        if(m?.Kind=="stock")displayed=Math.Max(0,displayed-8);
        for(int i=0;i<displayed;i++)Sprite("doupi_single",StockItemRect(i));
        if(_doupi is null)return;
        Hint(new Rect2(1035,65,348,156),"pan");
        DoupiState state=_doupi.State;
        if(m?.Kind=="discard"){PanLayer("doupi_egg",1-m.Progress);PanLayer("doupi_burnt",1-m.Progress);}
        if(state!=DoupiState.Empty)
        {
            float grow=m?.Kind=="batter"&&!ReducedMotion?.25f+.75f*Ease(m.Progress):1;
            float flip=m?.Kind=="flip"&&!ReducedMotion?Mathf.Max(.06f,Mathf.Abs(Mathf.Cos(m.Progress*Mathf.Pi))):1;
            bool finished=state is DoupiState.ReadyToCut or DoupiState.Overbrowned or DoupiState.Cut;
            if(!finished)
            {
                PanLayer("doupi_skin",1,grow,flip);
                if(state!=DoupiState.Batter)PanLayer("doupi_egg",m?.Kind=="egg"?Ease(m.Progress):1,1,flip);
                if(state==DoupiState.SecondCooking)PanLayer("doupi_filling_overlay",m?.Kind=="filling"?Ease(m.Progress):1,m?.Kind=="filling"?.4f+.6f*Ease(m.Progress):1);
            }
            else PanLayer(state==DoupiState.Cut&&m?.Kind!="cut"?"doupi_cut":"doupi_finished");
            if(state==DoupiState.Overbrowned)PanLayer("doupi_burnt",.3f);
            if(state==DoupiState.Burnt)PanLayer("doupi_burnt");
            int cuts=_doupi.CompletedCuts;
            for(int i=0;i<cuts;i++)DrawCut(i,m?.Kind=="cut"&&i==cuts-1?m.Progress:1);
            if(state is DoupiState.SkinCooking or DoupiState.SecondCooking or DoupiState.ReadyToFlip or DoupiState.ReadyToCut)Steam(PanCenter+new Vector2(0,-30),.7f);
        }
        if(m is not null)DrawPanMotion(m);
    }
    private static Rect2 StockItemRect(int index)=>new(1100+(index%4)*45,289+(index/4)*13,48,27);
    private void DrawCut(int index,float progress)
    {
        Vector2[] c=PanCorners;
        Vector2 a=index<3?c[0].Lerp(c[1],(index+1)/4f):c[0].Lerp(c[3],.5f);
        Vector2 b=index<3?c[3].Lerp(c[2],(index+1)/4f):c[1].Lerp(c[2],.5f);
        DrawLine(a,a.Lerp(b,Ease(progress)),new Color("#744625"),3,true);
    }
    private void DrawPanMotion(Motion m)
    {
        if(ReducedMotion)return;
        float p=m.Progress;
        if(m.Kind is "flip" or "cut")
        {
            Vector2 center=PanCenter;
            if(m.Kind=="cut")
            {
                Vector2[] c=PanCorners;int index=Math.Max(0,m.Index-1);
                center=index<3?c[0].Lerp(c[1],(index+1)/4f).Lerp(c[3].Lerp(c[2],(index+1)/4f),Ease(p)):c[0].Lerp(c[3],.5f).Lerp(c[1].Lerp(c[2],.5f),Ease(p));
            }
            else center+=new Vector2(35,-Mathf.Sin(p*Mathf.Pi)*60);
            Sprite(m.Kind=="cut"?"cut_tool":_doupiLevel==3?"auto_flip_tool":"flip_tool",At(center+new Vector2(30,-23),new Vector2(138,91)),1,Mathf.Sin(p*Mathf.Pi)*-.4f);
        }
        else if(m.Kind is "batter" or "egg" or "filling")
        {
            Vector2 from=m.Kind=="filling"?new Vector2(1360,300):new Vector2(1030,300);
            Vector2 center=from.Lerp(PanCenter+new Vector2(0,-78),Mathf.Sin(p*Mathf.Pi));
            Texture2D tex=m.Kind=="egg"?_art.Shared.Ingredient(StableIds.Ingredients.Egg):_art.Texture(m.Kind=="batter"?"doupi_batter":"doupi_filling");
            Sprite(tex,At(center,new Vector2(73,68)),1,-Mathf.Sin(p*Mathf.Pi)*.65f);
            if(p>.2f&&p<.8f)DrawLine(center+new Vector2(0,28),PanCenter,m.Kind=="egg"?new Color("#FFC942"):new Color("#EACD8C"),7,true);
        }
        else if(m.Kind=="stock")
            for(int i=0;i<8;i++){Rect2 target=StockItemRect(Math.Max(0,_stock.Count-8)+i);Sprite("doupi_single",At((PanCenter+new Vector2((i%4)*35-55,(i/4)*27)).Lerp(target.GetCenter(),Ease(p)),new Vector2(50,36).Lerp(target.Size,p)));}
    }

    private void DrawEgg()
    {
        Hint(EggMachine,"egg");Sprite("egg_station",EggMachine,_egg is null?.4f:1);
        if(_egg is null)return;
        for(int i=0;i<_egg.BaseCups;i++)Sprite("egg_base",new Rect2(1450+(i%2)*37,227-(i/2)*50,42,45));
        Motion? m=Find("egg");
        if(_egg.HasFinishedCup||_egg.IsPreparing)
        {
            Rect2 r=CupRect;
            if(m?.Kind=="brew"&&!ReducedMotion)r=At(new Vector2(1490,233).Lerp(CupRect.GetCenter(),Segment(m.Progress,0,.28f)),CupRect.Size);
            float progress=_egg.HasFinishedCup?1:Mathf.Clamp(1-(float)(_egg.RemainingSeconds/EggRiceWineRuntime.ActionSeconds),0,1);
            Sprite("egg_base",r,1-progress);
            Sprite("egg_finished",r,progress);
            if(_egg.IsPreparing&&progress>.25f)
            {
                // The authored spout is at 58%/53% of the cropped station image.
                Vector2 spout=EggMachine.Position+EggMachine.Size*new Vector2(.584f,.525f);
                DrawLine(spout,r.Position+r.Size*new Vector2(.5f,.24f),new Color(.9f,.96f,1,.8f),5,true);
            }
            Steam(r.Position+new Vector2(r.Size.X/2,5),.45f);
        }
        if(m?.Kind=="egg_refill")
            for(int i=0;i<6;i++)Sprite("egg_base",new Rect2(1450+(i%2)*37,227-(i/2)*50-(ReducedMotion?0:30*(1-Ease(m.Progress))),42,45),m.Progress);
    }
    private void DrawRefills()
    {
        foreach(Motion m in _motions.Where(m=>m.Kind=="refill"))
        {
            int index=Array.IndexOf(IngredientIds,m.Ingredient);
            Rect2 target=index<0?RawRect:IngredientRect(index);
            if(!ReducedMotion)target.Position+=new Vector2(0,-35*(1-Ease(m.Progress)));
            Sprite(_art.Ingredient(m.Ingredient),target,.4f+.6f*m.Progress);
        }
    }
    private void DrawTransfers()
    {
        foreach(Motion m in _motions)
        {
            if(m.Kind=="pour"&&!ReducedMotion)
            {
                Rect2 home=At(BasketHome(m.Index)+new Vector2(0,-67),_cookerLevel==3?new Vector2(121,151):new Vector2(144,179));
                Vector2 destination=BowlFood.GetCenter()+new Vector2(-32,-105);
                float enter=Segment(m.Progress,0,.36f),leave=Segment(m.Progress,.7f,1);
                Vector2 center=home.GetCenter().Lerp(destination,enter).Lerp(BasketHome(m.Index),leave);
                float angle=Segment(m.Progress,.30f,.5f)*(1-leave)*1.15f;
                Sprite("basket",At(center,home.Size),1,angle);
                if(leave>0)
                {
                    // The returning empty basket descends behind the front rim.
                    Rect2 potRect=_cookerLevel==3?new Rect2(24,74,417,282):new Rect2(29,-7,412,412);
                    Texture2D pot=_art.Cooker(_cookerLevel);
                    const float front=.568f;
                    DrawTextureRectRegion(pot,new Rect2(potRect.Position+new Vector2(0,potRect.Size.Y*front),potRect.Size*new Vector2(1,1-front)),
                        new Rect2(new Vector2(0,pot.GetHeight()*front),pot.GetSize()*new Vector2(1,1-front)));
                }
                if(m.Progress<.68f)
                {
                    float fall=Segment(m.Progress,.42f,.67f);
                    Vector2 start=center+new Vector2(-19,15);
                    Sprite(m.Quality==NoodleQuality.Overcooked?"overcooked":"cooked_basket",At(start.Lerp(BowlFood.GetCenter(),fall),new Vector2(88,45).Lerp(BowlFood.Size,fall)),1,angle*(1-fall));
                }
            }
            if(m.Kind=="delivery")
            {
                ProductKind kind=(ProductKind)m.Index;
                Vector2 from=kind==ProductKind.HotDryNoodles?BowlRect.GetCenter():kind==ProductKind.Doupi?StockCenter:CupRect.GetCenter();
                float p=Ease(m.Progress);Vector2 center=ReducedMotion?from:from.Lerp(m.Target,p)+new Vector2(0,-Mathf.Sin(p*Mathf.Pi)*50);
                float scale=ReducedMotion?1:Mathf.Lerp(1,.55f,p),alpha=1-Segment(m.Progress,.8f,1);
                if(kind==ProductKind.HotDryNoodles)
                {
                    Sprite("empty_bowl",At(center,BowlRect.Size*scale),alpha);
                    // Food moves with the bowl, including its actual recipe and quality.
                    DrawBowlContents(At(center+new Vector2(0,-32)*scale,BowlFood.Size*scale),NoodleBowlState.Ready,100,m.Quality,m.Toppings,opacity:alpha);
                }
                else Sprite(kind==ProductKind.Doupi?"doupi_single":"egg_finished",At(center,new Vector2(100,85)*scale),alpha);
            }
        }
    }
    private void Steam(Vector2 origin,float scale)
    {
        if(ReducedMotion)return;
        for(int i=0;i<3;i++)
        {
            float t=Mathf.PosMod(_phase*.6f+i*.33f,1);
            Vector2 p=origin+new Vector2((i-1)*23+Mathf.Sin(t*5+i)*9,-t*65)*scale;
            DrawArc(p,8*scale,Mathf.Pi*.2f,Mathf.Pi*1.1f,12,new Color(1,1,1,(1-t)*.55f),2,true);
        }
    }
    private void Drips(Vector2 origin,int count)
    {
        if(ReducedMotion)return;
        for(int i=0;i<count;i++)
        {
            float t=Mathf.PosMod(_phase*2+i*.23f,1);
            Vector2 p=origin+new Vector2((i-(count-1)*.5f)*8,t*42);
            DrawLine(p,p+new Vector2(0,5),new Color(.65f,.9f,1,1-t),2.5f,true);
        }
    }
}
