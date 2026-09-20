using Godot;
using ProjectCake.Core;
using ProjectCake.Data;

namespace ProjectCake.UI;

public sealed record JourneyFood(string Name, string Visual, string? Art = null);
public sealed record MapJourneyView(JourneyCity City, JourneyCity? NextCity, bool IsCurrent,
    bool IsPreview, bool NextIsPreview, int LitCities, int TotalCities, string Goal, bool CanView);
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
    public static bool MapCityUnlocked(SaveService? save, JourneyCity city) => save?.CanContinue == true
        ? save.Data.UnlockedCityIds.Contains(city.Id) : city.Id == Cities[0].Id;

    public static MapJourneyView MapSummary(SaveService save, JourneyCity city, bool developerPreview = false)
    {
        var playable = Cities.Where(c => save.ChapterLength(c.Id) > 0).ToArray();
        bool preview = save.IsDemo && save.ChapterLength(city.Id) == 0;
        bool unlocked = MapCityUnlocked(save, city);
        var next = preview ? null : Next(city.Id);
        string goal;
        if (preview) goal = "下一站预告 · 本次不可营业";
        else if (!unlocked)
            goal = $"完成{Cities[Math.Max(0, Array.IndexOf(Cities, city) - 1)].Name}章节后开放";
        else if (playable.Length > 0 && playable.All(c => Progress(save, c.Id).Completed))
            goal = save.IsDemo ? "本站试玩已完成。可回访营业，继续早餐旅程。" : "五城旅程已完成，回访喜欢的早餐铺。";
        // The destination already has its own column; keep the goal line for the actual requirement.
        else goal = Goal(save, city).Split('\n')[0];
        return new(city, next, city.Id == (save.CanContinue ? save.ContinueCityId : Cities[0].Id),
            preview, next is not null && save.IsDemo && save.ChapterLength(next.Id) == 0,
            playable.Count(c => MapCityUnlocked(save, c)), playable.Length, goal,
            !preview && (!save.CanContinue || unlocked || developerPreview));
    }
    public static string State(SaveService save, JourneyCity city)
    {
        if (!save.IsCityAvailable(city.Id)) return "下一站预告 · 本次不可营业";
        if (!save.Data.UnlockedCityIds.Contains(city.Id)) return "尚未抵达";
        var p = Progress(save, city.Id);
        return $"已开放至第 {p.HighestUnlockedDay} 天";
    }
    public static string Goal(SaveService save, JourneyCity city)
    {
        if (!save.IsCityAvailable(city.Id)) return "新城市的早餐，留待下一段旅程。";
        if (ExperienceProfile.HasTwoCityEnding(save.IsDemo) && city.Id == StableIds.Cities.Wuhan)
            return Progress(save, city.Id).Completed ? "本站试玩已完成。可回访营业，继续早餐旅程。"
                : $"完成第 {city.Days} 天并获得至少一星\n下一站预告 · 西安";
        var next = Next(city.Id);
        if (Progress(save, city.Id).Completed) return next is null ? "五城旅程已完成，回访喜欢的早餐铺。" : $"下一站：{next.Name} · 已开放";
        return next is null ? "完成扬州章节，收集五城旅行印记。" : $"完成第 {city.Days} 天并获得至少一星\n下一站：{next.Name}";
    }
}
