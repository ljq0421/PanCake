using Godot;
using ProjectCake.Customers;
using ProjectCake.Data;

namespace ProjectCake.UI;

public readonly record struct ArtVisual(Texture2D Texture, Vector2 DisplaySize);
public readonly record struct CustomerPortraitVisual(Texture2D Body, Texture2D Head, Vector2 DisplaySize);

public enum CustomerExpression
{
    Happy,
    Normal,
    Impatient,
    Angry,
}

public sealed class TianjinArtCatalog
{
    private const string Root = "res://resource/art/TianJin/";
    private static readonly Dictionary<string, Texture2D> SharedTextures = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Texture2D> _textures = SharedTextures;

    public TianjinArtCatalog()
    {
        Load("background", "早餐铺主界面-1920x1080.png");
        Load("coin", "金币图标.png", true);
        Load("pancake_base", "展开煎饼基础层-v2.png", true);
        Load("pancake_egg", "鸡蛋覆盖层.png", true);
        Load("pancake_sauce", "酱料覆盖层.png", true);
        Load("pancake_folded", "折叠后通用煎饼成品_1.png", true);
        Load("pancake_bagged", "装袋后的通用煎饼果子.png", true);
        Load("pancake_burnt_overlay", "煎饼焦糊覆盖层.png", true);
        Load("batter", "面糊勺.png", true);
        Load("egg", "鸡蛋.png", true);
        Load("sauce_brush", "酱刷.png", true);
        Load("crispy", "薄脆.png", true);
        Load("scallion", "香葱碎.png", true);
        Load("ham", "火腿片.png", true);
        Load("raw_youtiao", "生油条面坯.png", true);
        Load("youtiao", "熟油条.png", true);
        Load("burnt_youtiao", "炸焦油条.png", true);
        Load("youtiao_rack", "油条沥油架.png", true);
        Load("soy_tray", "成品豆浆托盘.png", true);
        Load("soy_milk", "成品豆浆杯.png", true);
        Load("serving_tray", "出餐托盘.png", true);
        Load("ingredient_tray", "通用食材托盘.png", true);
        Load("batter_container", "面糊容器.png", true);
        Load("sauce_container", "酱料容器.png", true);
        Load("trash", "卡通垃圾桶.png", true);
        Load("heart_effect", "开心爱心特效.png", true);
        Load("star_effect", "星星特效图标.png", true);
        Load("map_background", "中国区域地图基础背景.png");
        Load("tianjin_map_node", "天津城市节点.png", true);
        Load("locked_map_node", "通用未解锁城市节点.png", true);
        Load("scraper", "煎饼刮板.png", true);
        Load("spatula", "煎饼铲子.png", true);
        for (int level = 1; level <= 3; level++)
        {
            Load($"stove_{level}", level switch
            {
                1 => "Lv1基础煎饼炉-v2.png",
                2 => "Lv2恒温煎饼炉-v2.png",
                _ => "Lv3恒温快热煎饼炉-v2.png",
            });
            Load($"fryer_body_{level}", level switch
            {
                1 => "油条炸锅_Lv1_基础锅体.png",
                2 => "油条炸锅_Lv2_中级锅体.png",
                _ => "油条炸锅_Lv3_高级自动锅体.png",
            });
        }
        Load("fryer_basket_6", "6根容量油条滤篮.png");
        Load("fryer_basket_8", "8根容量油条滤篮.png");
    }

    public Texture2D Background => Get("background");
    public Texture2D Coin => Get("coin");
    public Texture2D PancakeBase => Get("pancake_base");
    public Texture2D PancakeEgg => Get("pancake_egg");
    public Texture2D PancakeSauce => Get("pancake_sauce");
    public Texture2D FoldedPancake => Get("pancake_folded");
    public Texture2D FinishedPancake => Get("pancake_bagged");
    public Texture2D PancakeBurntOverlay => Get("pancake_burnt_overlay");
    public Texture2D Scraper => Get("scraper");
    public Texture2D Spatula => Get("spatula");
    public Texture2D Stove(int level) => Get($"stove_{Math.Clamp(level, 1, 3)}");
    public Texture2D Fryer(int level) => FryerBody(level);
    public Texture2D FryerBody(int level) => Get($"fryer_body_{Math.Clamp(level, 1, 3)}");
    public Texture2D FryerBasket(int level) => Get(level <= 1 ? "fryer_basket_6" : "fryer_basket_8");
    public Texture2D SoyTray => Get("soy_tray");
    public Texture2D ServingTray => Get("serving_tray");
    public Texture2D IngredientTray => Get("ingredient_tray");
    public Texture2D BatterContainer => Get("batter_container");
    public Texture2D SauceContainer => Get("sauce_container");
    public Texture2D Trash => Get("trash");
    public Texture2D HeartEffect => Get("heart_effect");
    public Texture2D StarEffect => Get("star_effect");
    public Texture2D YoutiaoRack => Get("youtiao_rack");
    public Texture2D BurntYoutiao => Get("burnt_youtiao");
    public Texture2D MapBackground => Get("map_background");
    public Texture2D TianjinMapNode => Get("tianjin_map_node");
    public Texture2D LockedMapNode => Get("locked_map_node");

    public Texture2D Ingredient(string stableId) => stableId switch
    {
        StableIds.Ingredients.Batter => Get("batter"),
        StableIds.Ingredients.Egg => Get("egg"),
        StableIds.Ingredients.Sauce => Get("sauce_brush"),
        StableIds.Ingredients.Crispy => Get("crispy"),
        StableIds.Ingredients.Scallion => Get("scallion"),
        StableIds.Ingredients.Ham => Get("ham"),
        StableIds.Ingredients.Youtiao => Get("youtiao"),
        _ => Get("scraper"),
    };

    public Texture2D Product(ProductKind kind) => kind switch
    {
        ProductKind.Pancake => FinishedPancake,
        ProductKind.Youtiao => Get("youtiao"),
        ProductKind.SoyMilk => Get("soy_milk"),
        _ => FinishedPancake,
    };

    public Texture2D RawYoutiao => Get("raw_youtiao");

    public string CustomerAppearance(string appearanceId) => CustomerAppearanceCatalog.IsKnown(appearanceId)
        ? appearanceId
        : CustomerAppearanceCatalog.DefaultAppearanceId;

    public Texture2D CustomerBody(string appearanceId) => LoadCustomerTexture(CustomerAppearance(appearanceId), "body.png");

    public Texture2D CustomerHead(string appearanceId, CustomerExpression expression) =>
        LoadCustomerTexture(CustomerAppearance(appearanceId), $"head_{ExpressionKey(expression)}.png");

    public CustomerPortraitVisual CustomerPortrait(string appearanceId, CustomerExpression expression) =>
        new(CustomerBody(appearanceId), CustomerHead(appearanceId, expression), new Vector2(220, 154));

    public CustomerPortraitVisual CustomerPortrait(string appearanceId, CustomerState state, bool wasServed) =>
        CustomerPortrait(appearanceId, ResolveCustomerExpression(state, wasServed));

    public static CustomerExpression ResolveCustomerExpression(CustomerState state, bool wasServed = false) => state switch
    {
        CustomerState.Happy => CustomerExpression.Happy,
        CustomerState.Impatient => CustomerExpression.Impatient,
        CustomerState.Angry => CustomerExpression.Angry,
        CustomerState.Served => CustomerExpression.Happy,
        CustomerState.Leaving or CustomerState.Left => wasServed ? CustomerExpression.Happy : CustomerExpression.Angry,
        _ => CustomerExpression.Normal,
    };

    public ArtVisual BackgroundVisual => new(Background, new Vector2(1920, 1080));
    public ArtVisual CoinVisual => new(Coin, new Vector2(44, 44));
    public ArtVisual StoveVisual(int level) => new(Stove(level), new Vector2(360, 340));
    public ArtVisual FryerVisual(int level) => new(Fryer(level), new Vector2(330, 340));
    public ArtVisual IngredientVisual(string stableId) => new(Ingredient(stableId), new Vector2(62, 58));
    public ArtVisual ProductVisual(ProductKind kind) => new(Product(kind), new Vector2(68, 60));

    public IReadOnlyList<string> MissingRequiredAssets()
    {
        string[] required =
        {
            "background", "coin", "pancake_base", "pancake_egg", "pancake_sauce", "pancake_folded", "pancake_bagged", "pancake_burnt_overlay",
            "batter", "egg", "sauce_brush", "crispy", "scallion", "ham", "raw_youtiao", "youtiao", "burnt_youtiao", "youtiao_rack",
            "soy_tray", "soy_milk", "serving_tray", "ingredient_tray", "batter_container", "sauce_container", "trash", "heart_effect", "star_effect",
            "map_background", "tianjin_map_node", "locked_map_node", "scraper", "spatula", "stove_1", "stove_2", "stove_3",
            "fryer_body_1", "fryer_body_2", "fryer_body_3", "fryer_basket_6", "fryer_basket_8",
        };
        var missing = required.Where(key => !_textures.ContainsKey(key)).ToList();
        foreach (CustomerAppearanceDefinition appearance in CustomerAppearanceCatalog.All)
        {
            string folder = $"Customers/{appearance.Id}/";
            foreach (string fileName in new[] { "body.png", "head_happy.png", "head_normal.png", "head_impatient.png", "head_angry.png" })
            {
                if (!ResourceLoader.Exists(Root + folder + fileName)) missing.Add($"customer_{appearance.Id}_{fileName[..^4]}");
            }
        }
        return missing;
    }

    private Texture2D Get(string key) => _textures.TryGetValue(key, out Texture2D? texture)
        ? texture
        : throw new InvalidOperationException($"天津美术资源未加载：{key}");

    private void Load(string key, string fileName, bool trimTransparent = false)
    {
        if (_textures.ContainsKey(key)) return;
        Texture2D? texture = ResourceLoader.Load<Texture2D>(Root + fileName);
        if (texture is not null) _textures[key] = trimTransparent ? Trim(texture) : texture;
    }

    private static Texture2D LoadCustomerTexture(string appearance, string fileName)
    {
        string path = Root + $"Customers/{appearance}/{fileName}";
        Texture2D? texture = ResourceLoader.Load<Texture2D>(path);
        return texture ?? throw new InvalidOperationException($"天津顾客美术资源未加载：{path}");
    }

    private static string ExpressionKey(CustomerExpression expression) => expression switch
    {
        CustomerExpression.Happy => "happy",
        CustomerExpression.Impatient => "impatient",
        CustomerExpression.Angry => "angry",
        _ => "normal",
    };

    private static Texture2D Trim(Texture2D texture)
    {
        Image image = texture.GetImage();
        if (image.GetFormat() != Image.Format.Rgba8) image.Convert(Image.Format.Rgba8);
        byte[] pixels = image.GetData();
        int width = image.GetWidth(), height = image.GetHeight();
        int minX = width, minY = height, maxX = -1, maxY = -1;
        const byte visibleAlpha = 12;
        for (int y = 0; y < height; y++)
        {
            int row = y * width * 4;
            for (int x = 0; x < width; x++)
            {
                if (pixels[row + x * 4 + 3] <= visibleAlpha) continue;
                minX = Math.Min(minX, x); minY = Math.Min(minY, y);
                maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
            }
        }
        if (maxX < minX || maxY < minY) return texture;
        const int padding = 4;
        minX = Math.Max(0, minX - padding); minY = Math.Max(0, minY - padding);
        maxX = Math.Min(width - 1, maxX + padding); maxY = Math.Min(height - 1, maxY + padding);
        var used = new Rect2I(minX, minY, maxX - minX + 1, maxY - minY + 1);
        if (used.Size == image.GetSize()) return texture;
        return new AtlasTexture
        {
            Atlas = texture,
            Region = new Rect2(used.Position.X, used.Position.Y, used.Size.X, used.Size.Y),
        };
    }
}
