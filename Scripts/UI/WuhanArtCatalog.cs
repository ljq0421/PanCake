using Godot;
using ProjectCake.Data;

namespace ProjectCake.UI;

public sealed class WuhanArtCatalog
{
    private const string Root = "res://resource/art/Wuhan/";
    private readonly Dictionary<string, Texture2D> _textures = new(StringComparer.Ordinal);
    private readonly List<string> _missing = new();
    private readonly TianjinArtCatalog _shared = new();

    public WuhanArtCatalog()
    {
        Load("background", "武汉早餐铺主界面背景＋空工作台_v3.png");
        Load("city_node", "武汉已解锁城市节点.png");
        Load("mix_station", "热干面拌面主操作台_v2.png"); Load("empty_bowl", "热干面空碗_v2.png");
        Load("bowl_noodles", "碗中熟面基础层.png"); Load("unmixed", "芝麻酱未拌匀覆盖层.png"); Load("half_mixed", "半拌匀热干面状态覆盖层.png"); Load("mixed", "拌匀热干面基础层.png"); Load("overcooked", "煮过头热干面覆盖层.png"); Load("chopsticks", "拌面筷子_v2.png");
        Load("raw_noodles", "生热干面面条.png"); Load("basket", "通用热干面漏勺_v2.png"); Load("cooked_basket", "漏勺中的熟面状态.png");
        Load("base_seasoning", "芝麻酱容器_v2.png"); Load("scallion", "葱花覆盖层.png"); Load("chili", "辣油壶_v2.png"); Load("beef", "卤牛肉片.png");
        Load("doupi_batter", "豆皮豆米浆容器_v2.png"); Load("doupi_skin", "豆皮薄皮基础层.png"); Load("doupi_egg", "豆皮鸡蛋覆盖层.png"); Load("doupi_filling", "三鲜糯米馅容器_v2.png"); Load("doupi_finished", "整张三鲜豆皮完成状态.png"); Load("doupi_cut", "切块后的整锅豆皮 .png"); Load("doupi_single", "单块三鲜豆皮成品.png"); Load("doupi_stock", "豆皮成品备货托盘.png"); Load("doupi_burnt", "豆皮焦糊覆盖层.png");
        Load("egg_station", "蛋酒冲泡台_v2.png"); Load("egg_base", "蛋酒底料杯_v2.png"); Load("egg_finished", "成品蛋酒杯_v2.png");
        Load("base_sauce", "基础酱汁瓶_v2.png"); Load("chili_overlay", "辣油覆盖层.png"); Load("beef_overlay", "牛肉覆盖层.png");
        Load("doupi_filling_overlay", "豆皮糯米馅覆盖层.png"); Load("flip_tool", "豆皮手动翻面铲.png");
        Load("auto_flip_tool", "Lv3豆皮锅自动翻面铲.png"); Load("cut_tool", "豆皮切块铲刀.png");
        for (int level = 1; level <= 3; level++)
        {
            Load($"cooker_{level}", level switch { 1 => "煮面锅 Lv1 基础锅体_v2.png", 2 => "煮面锅 Lv2 自动提篮版锅体_v2.png", _ => "煮面锅 Lv3 双漏勺快热版锅体_v2.png" });
            Load($"griddle_{level}", level switch { 1 => "三鲜豆皮锅 Lv1 基础锅体_v2.png", 2 => "三鲜豆皮锅 Lv2 恒温版_v2.png", _ => "三鲜豆皮锅 Lv3 自动翻面快热版锅体_v2.png" });
        }
    }

    public Texture2D Background => Get("background");
    public Texture2D CityNode => Get("city_node");
    public Texture2D Cooker(int level) => Get($"cooker_{Math.Clamp(level, 1, 3)}");
    public Texture2D Griddle(int level) => Get($"griddle_{Math.Clamp(level, 1, 3)}");
    public Texture2D Texture(string id) => Get(id);
    public Texture2D Ingredient(string id) => id switch { StableIds.Ingredients.WuhanBaseSeasoning => Get("base_seasoning"), StableIds.Ingredients.WuhanScallion => Get("scallion"), StableIds.Ingredients.WuhanChiliOil => Get("chili"), StableIds.Ingredients.WuhanBraisedBeef => Get("beef"), _ => Get("raw_noodles") };
    public Texture2D Product(ProductKind kind) => kind switch { ProductKind.HotDryNoodles => Get("mixed"), ProductKind.Doupi => Get("doupi_single"), ProductKind.EggRiceWine => Get("egg_finished"), _ => _shared.Product(kind) };
    public TianjinArtCatalog Shared => _shared;
    public IReadOnlyList<string> MissingRequiredAssets() => _missing.ToArray();
    private Texture2D Get(string id) => _textures.TryGetValue(id, out Texture2D? value) ? value : throw new InvalidOperationException($"武汉美术资源未加载：{id}");
    private void Load(string id, string file) { Texture2D? texture = ResourceLoader.Load<Texture2D>(Root + file); if (texture is not null) _textures[id] = texture; else _missing.Add($"{id}: {Root + file}"); }
}
