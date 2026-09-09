using Godot;

namespace ProjectCake.UI;

internal static class SceneQueries
{
    public static IEnumerable<T> Descendants<T>(this Node root) where T : Node
    {
        foreach (Node child in root.GetChildren())
        {
            if (child is T match) yield return match;
            foreach (T descendant in child.Descendants<T>()) yield return descendant;
        }
    }

    public static Button FindButton(this Node root, string text) =>
        root.Descendants<Button>().First(button => button.Text == text);

    public static Button? FindOptionalButton(this Node root, string text) =>
        root.Descendants<Button>().FirstOrDefault(button => button.Text == text);
}
