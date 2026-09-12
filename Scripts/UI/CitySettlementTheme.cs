using Godot;

namespace ProjectCake.UI;

/// <summary>Formal settlement palette. City colors never recolor food or outcome symbols.</summary>
public sealed record CitySettlementTheme(string Id, Color Primary, Color Secondary, Color Weak, Color Divider)
{
    public static readonly Color Paper = new("#F5E8CF"), Section = new("#EFDDBD"), Ink = new("#4D352A"), Muted = new("#765648"), Border = new("#594034");
    public static readonly Color Completed = new("#79A56B"), Incorrect = new("#D88948"), Lost = new("#AF6F64"), Satisfaction = new("#D97C6B"), Perfect = new("#D5A243"), Stamp = new("#A65C47");
    private static readonly CitySettlementTheme Tianjin = new("tianjin", new("#D7A45F"), new("#729DAC"), new("#B8C9CC"), new("#D7A45F"));
    private static readonly CitySettlementTheme Wuhan = new("wuhan", new("#71A08D"), new("#A9C1B3"), new("#DFC88D"), new("#71A08D"));
    private static readonly CitySettlementTheme Xian = new("xian", new("#98594D"), new("#CBB38B"), new("#D0A04E"), new("#B98870"));
    public static CitySettlementTheme For(string city) => city switch { "wuhan" => Wuhan, "xian" => Xian, _ => Tianjin };
    public Color Ornament => Id == "xian" ? Secondary : Primary;
}
