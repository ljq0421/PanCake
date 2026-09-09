using System.Collections;
using System.Reflection;
using Godot;

namespace ProjectCake.UI;

/// <summary>Binds scene-authored nodes to private C# fields using migration metadata stored in .tscn files.</summary>
internal static class SceneNodeBinder
{
    private const string Metadata = "_scene_bindings";

    public static void Bind(Node owner)
    {
        for (Type? type = owner.GetType(); type is not null && typeof(Node).IsAssignableFrom(type); type = type.BaseType)
            BindDeclaredFields(owner, type);
    }

    private static void BindDeclaredFields(Node owner, Type type)
    {
        string prefix = (type.FullName ?? type.Name) + "|";
        var direct = new List<(FieldInfo Field, Node Value)>();
        var indexed = new Dictionary<FieldInfo, SortedDictionary<int, Node>>();

        foreach (Node node in DescendantsAndSelf(owner))
        {
            if (!node.HasMeta(Metadata)) continue;
            foreach (string token in node.GetMeta(Metadata).AsStringArray())
            {
                if (!token.StartsWith(prefix, StringComparison.Ordinal)) continue;
                string[] parts = token[prefix.Length..].Split('|');
                FieldInfo? field = type.GetField(parts[0], BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly);
                if (field is null) continue;
                if (parts.Length == 1) direct.Add((field, node));
                else if (parts.Length == 3 && int.TryParse(parts[2], out int index))
                {
                    if (!indexed.TryGetValue(field, out SortedDictionary<int, Node>? values))
                        indexed[field] = values = new();
                    values[index] = node;
                }
            }
        }

        foreach ((FieldInfo field, Node value) in direct) field.SetValue(owner, value);
        foreach ((FieldInfo field, SortedDictionary<int, Node> values) in indexed)
        {
            object? target = field.GetValue(owner);
            if (target is Array array)
            {
                foreach ((int index, Node value) in values) array.SetValue(value, index);
            }
            else if (target is IList list)
            {
                list.Clear();
                foreach (Node value in values.Values) list.Add(value);
            }
        }
    }

    private static IEnumerable<Node> DescendantsAndSelf(Node root)
    {
        yield return root;
        foreach (Node child in root.GetChildren())
            foreach (Node descendant in DescendantsAndSelf(child))
                yield return descendant;
    }
}
