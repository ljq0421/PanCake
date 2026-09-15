using System.Text.Json;
using System.Text.RegularExpressions;
using Godot;

namespace ProjectCake.Core;

/// <summary>Native Godot translation resource with parameterized keys for existing labels.</summary>
public partial class GameTranslation : Translation
{
    private readonly Dictionary<string, string> _messages = new(StringComparer.Ordinal);
    private readonly List<(Regex Pattern, string Target)> _templates = new();
    private static GameTranslation? _english;
    private static GameTranslation? _chinese;
    private bool _useSourceText;

    public static void Install()
    {
        if (_english is not null) return;
        _english = new GameTranslation { Locale = "en" };
        var messages = JsonSerializer.Deserialize<Dictionary<string, string>>(
            Godot.FileAccess.GetFileAsString("res://Data/Localization/en.json")) ?? new();
        foreach (var (key, value) in messages)
        {
            if (key.Contains("{0}"))
            {
                string pattern = Regex.Escape(key);
                for (int i = 0; i < 8; i++) pattern = pattern.Replace(Regex.Escape("{" + i + "}"), $"(?<arg{i}>.+?)");
                _english._templates.Add((new Regex("^" + pattern + "$", RegexOptions.CultureInvariant | RegexOptions.Singleline), value));
            }
            else _english._messages[key] = value;
        }
        // Source strings are Chinese, including dynamically formatted messages. Without
        // an identity translation, Godot falls back to English even under zh_CN.
        _chinese = new GameTranslation { Locale = "zh_CN", _useSourceText = true };
        TranslationServer.AddTranslation(_chinese);
        TranslationServer.AddTranslation(_english);
    }

    public override StringName _GetMessage(StringName srcMessage, StringName context)
        => _useSourceText ? srcMessage : TranslateText(srcMessage.ToString());

    private string TranslateText(string source)
    {
        if (_messages.TryGetValue(source, out string? value)) return value;
        foreach (var (pattern, target) in _templates)
        {
            var match = pattern.Match(source);
            if (!match.Success) continue;
            return Regex.Replace(target, @"\{([0-7])\}", placeholder =>
            {
                string argument = match.Groups["arg" + placeholder.Groups[1].Value].Value;
                string translated = TranslateText(argument);
                return translated.Length > 0 ? translated : argument;
            });
        }
        if (source.Contains('\n'))
        {
            var lines = source.Split('\n'); bool changed = false;
            for (int i = 0; i < lines.Length; i++)
            {
                string translated = TranslateText(lines[i]);
                if (translated.Length == 0) continue;
                lines[i] = translated; changed = true;
            }
            if (changed) return string.Join('\n', lines);
        }
        return string.Empty;
    }
}
