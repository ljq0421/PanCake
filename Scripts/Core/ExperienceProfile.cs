using Godot;

namespace ProjectCake.Core;

/// <summary>Resolved before autoloads read any content or progress.</summary>
public static class ExperienceProfile
{
    public static bool IsDemo => OS.HasFeature("demo_pilot")
        || OS.HasFeature("editor") && OS.GetCmdlineUserArgs().Contains("--demo-pilot");
    public const string DemoId = "demo_pilot";
    public const string ManifestPath = "res://Data/Demo/manifest.json";
    public const string SavePath = "user://demo/project_cake_demo_pilot_v1.json";
}
