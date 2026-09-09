using Godot;

namespace ProjectCake.Core;

/// <summary>Single entry point for constructing scene-backed production UI.</summary>
public static class SceneFactory
{
    public static T Instantiate<T>(string path) where T : Node
    {
        PackedScene scene = GD.Load<PackedScene>(path)
            ?? throw new InvalidOperationException($"Scene not found: {path}");
        return scene.Instantiate<T>();
    }
}
