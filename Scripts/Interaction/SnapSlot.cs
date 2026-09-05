using Godot;

namespace ProjectCake.Interaction;

/// <summary>
/// A stable visual socket inside a device. Pointer coordinates decide whether a
/// drop is legal; the slot decides where the item finally lands.
/// </summary>
public readonly record struct SnapSlot(
    Vector2 NormalizedPosition,
    float RotationDegrees = 0,
    float Scale = 1,
    int DrawOrder = 0);

