using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public sealed record JourneyFood(string Name, string Visual, string? Art = null);
public sealed record JourneyCity(string Id, string Name, string? Art, JourneyFood[] Foods)
{
    public int Days => SaveService.ChapterDays(Id);
}

/// <summary>Read-only presentation of the existing five-city progression.</summary>
public static class JourneyModel
{
    public const string ArtRoot = "res://resource/art/Global/StartPage/";
    public static readonly JourneyCity[] Cities =
    {
        new(StableIds.Cities.Tianjin, "天津", ArtRoot + "天津旅行明信片.png", new[] {
            new JourneyFood("煎饼果子", "Pancake"), new JourneyFood("油条", "Youtiao"), new JourneyFood("豆浆", "SoyMilk") }),
        new(StableIds.Cities.Wuhan, "武汉", ArtRoot + "武汉旅行明信片.png", new[] {
            new JourneyFood("热干面", "HotDryNoodles"), new JourneyFood("三鲜豆皮", "Doupi"), new JourneyFood("蛋酒", "EggRiceWine") }),
        new(StableIds.Cities.Xian, "西安", ArtRoot + "西安旅行明信片.png", new[] {
            new JourneyFood("肉夹馍", "Roujiamo"), new JourneyFood("肉丸胡辣汤", "Hulatang", "res://resource/art/XiAn/成品肉丸胡辣汤.png") }),
        new(StableIds.Cities.Guangzhou, "广州", null, new[] {
            new JourneyFood("肠粉", "RiceRoll"), new JourneyFood("虾饺", "HarGow"), new JourneyFood("早茶", "MorningTea") }),
        new(StableIds.Cities.Yangzhou, "扬州", null, new[] {
            new JourneyFood("烫干丝", "G01"), new JourneyFood("三丁包", "B01"), new JourneyFood("茶水", "T01") }),
    };
    public static JourneyCity City(string id) => Cities.First(c => c.Id == id);
    public static string Stamp(JourneyCity city) => city.Name switch
    { "天津" => "天津城市印章", "武汉" => "武汉城市旅行印章", "西安" => "西安城市旅行印章", _ => "已完成城市节点" };
    public static string NodeArt(JourneyCity city) => city.Name switch
    { "天津" => "第一站天津节点专属素材", "武汉" => "武汉世界地图城市节点专属图标", "西安" => "西安世界地图城市节点专属图标", _ => "世界地图城市节点母版" };
    public static CityProgressData Progress(SaveService save, string id) =>
        save.Data.Cities.TryGetValue(id, out var progress) ? progress : new CityProgressData();
    public static JourneyCity? Next(string id) => Cities.SkipWhile(c => c.Id != id).Skip(1).FirstOrDefault();
    public static string State(SaveService save, JourneyCity city)
    {
        if (save.IsDemo)
            return city.Id == StableIds.Cities.Tianjin ? $"天津试玩 · 已开放 {save.Data.Tianjin.HighestUnlockedDay} / {save.ChapterLength(city.Id)} 局" : "下一站预告 · 本次不可营业";
        if (!save.Data.UnlockedCityIds.Contains(city.Id)) return "尚未抵达";
        var p = Progress(save, city.Id);
        return p.Completed ? "章节已完成" : $"已开放至第 {p.HighestUnlockedDay} / {city.Days} 天";
    }
    public static string Goal(SaveService save, JourneyCity city)
    {
        if (save.IsDemo)
        {
            if (city.Id != StableIds.Cities.Tianjin) return "新城市的早餐，留待下一段旅程。";
            return save.DemoContent is { } demo && save.DemoProgress.CompletedStages.Contains(demo.Stages[^1].Id)
                ? "天津试玩已完成。选择升级，再次营业感受变化。"
                : "完成至少 1 单并收摊保存后开放下一局。";
        }
        var next = Next(city.Id);
        if (Progress(save, city.Id).Completed) return next is null ? "五城旅程已完成，回访喜欢的早餐铺。" : $"下一站：{next.Name} · 已开放";
        return next is null ? "完成扬州章节，收集五城旅行印记。" : $"完成第 {city.Days} 天并获得至少一星\n下一站：{next.Name}";
    }
}
