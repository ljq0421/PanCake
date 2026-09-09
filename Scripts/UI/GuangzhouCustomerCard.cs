using Godot;

namespace ProjectCake.UI;

public partial class GuangzhouCustomerCard : Button
{
    public Func<string, bool>? Accepts { get; set; }
    public Action<string>? Delivered { get; set; }
    public override bool _CanDropData(Vector2 atPosition, Variant data) => data.VariantType == Variant.Type.String && Accepts?.Invoke(data.AsString()) == true;
    public override void _DropData(Vector2 atPosition, Variant data) => Delivered?.Invoke(data.AsString());
}
