using Godot;

namespace ProjectCake.Core;

/// <summary>Resolved before autoloads read any content or progress.</summary>
public static class ExperienceProfile
{
    public static bool IsDemo => OS.HasFeature("demo_pilot")
        || OS.HasFeature("editor") && OS.GetCmdlineUserArgs().Contains("--demo-pilot");
    public static bool IsCityAvailable(string cityId, bool demo) => cityId is "city:tianjin" or "city:wuhan"
        || !demo && cityId is "city:xian" or "city:guangzhou" or "city:yangzhou";
    public static bool HasTwoCityEnding(bool demo) => demo;
    public static string ProgressPath(bool demo) => demo ? SavePath : SaveService.DefaultSavePath;
    public const string DemoId = "demo_pilot";
    public const string ManifestPath = "res://Data/Demo/manifest.json";
    public const string SavePath = "user://demo/project_cake_demo_pilot_v1.json";
}
