using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

public readonly record struct ArtVisual(Texture2D Texture, Vector2 DisplaySize);

public sealed class TianjinArtCatalog
{
    private const string Root = "res://resource/art/TianJin/";
    private static readonly Dictionary<string, Texture2D> SharedTextures = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Texture2D> _textures = SharedTextures;

    public TianjinArtCatalog()
    {
        Load("background", "早餐铺主界面-1920x1080.png");
        Load("coin", "金币图标.png", true);
        Load("customer", "普通男上班族顾客_1.png", true);
        Load("pancake_base", "展开煎饼基础层-v2.png");
        Load("pancake_egg", "鸡蛋覆盖层.png");
        Load("pancake_sauce", "酱料覆盖层.png");
        Load("pancake_finished", "折叠后通用煎饼成品_1.png", true);
        Load("batter", "面糊勺.png", true);
        Load("egg", "鸡蛋.png", true);
        Load("sauce_brush", "酱刷.png", true);
        Load("crispy", "薄脆.png", true);
        Load("scallion", "香葱碎.png", true);
        Load("ham", "火腿片.png", true);
        Load("raw_youtiao", "生油条面坯.png", true);
        Load("youtiao", "熟油条.png", true);
        Load("soy_tray", "成品豆浆托盘.png", true);
        Load("soy_milk", "成品豆浆杯.png", true);
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
            Load($"fryer_{level}", level switch
            {
                1 => "Lv1基础油条炸锅-v2.png",
                2 => "Lv2中级油条炸锅-v2.png",
                _ => "Lv3高级油条炸锅-v2.png",
            });
        }
    }

    public Texture2D Background => Get("background");
    public Texture2D Coin => Get("coin");
    public Texture2D Customer(string _) => Get("customer");
    public Texture2D PancakeBase => Get("pancake_base");
    public Texture2D PancakeEgg => Get("pancake_egg");
    public Texture2D PancakeSauce => Get("pancake_sauce");
    public Texture2D FinishedPancake => Get("pancake_finished");
    public Texture2D Scraper => Get("scraper");
    public Texture2D Spatula => Get("spatula");
    public Texture2D Stove(int level) => Get($"stove_{Math.Clamp(level, 1, 3)}");
    public Texture2D Fryer(int level) => Get($"fryer_{Math.Clamp(level, 1, 3)}");
    public Texture2D SoyTray => Get("soy_tray");

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

    public ArtVisual BackgroundVisual => new(Background, new Vector2(1920, 1080));
    public ArtVisual CoinVisual => new(Coin, new Vector2(44, 44));
    public ArtVisual CustomerVisual(string stableId) => new(Customer(stableId), new Vector2(220, 154));
    public ArtVisual StoveVisual(int level) => new(Stove(level), new Vector2(360, 340));
    public ArtVisual FryerVisual(int level) => new(Fryer(level), new Vector2(330, 340));
    public ArtVisual IngredientVisual(string stableId) => new(Ingredient(stableId), new Vector2(62, 58));
    public ArtVisual ProductVisual(ProductKind kind) => new(Product(kind), new Vector2(68, 60));

    public IReadOnlyList<string> MissingRequiredAssets()
    {
        string[] required =
        {
            "background", "coin", "customer", "pancake_base", "pancake_egg", "pancake_sauce", "pancake_finished",
            "batter", "egg", "sauce_brush", "crispy", "scallion", "ham", "raw_youtiao", "youtiao", "soy_tray", "soy_milk",
            "scraper", "spatula", "stove_1", "stove_2", "stove_3", "fryer_1", "fryer_2", "fryer_3",
        };
        return required.Where(key => !_textures.ContainsKey(key)).ToArray();
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
