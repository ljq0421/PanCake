using Godot;
using ProjectCake.Wuhan;

namespace ProjectCake.Tests;

internal static class DoupiTestFixture
{
    // For tests isolating inventory, quality or animation. Input tests use real pointer strokes instead.
    internal static void Spread(DoupiStateMachine pan, float aspect = 2.75f)
    {
        for (int row = 0; row < 3; row++)
            pan.Spread(new Vector2(.02f, .15f + row * .35f), new Vector2(.98f, .15f + row * .35f), aspect);
        if (pan.State != DoupiState.SecondCooking) throw new InvalidOperationException("Fixture did not finish spreading.");
    }
}
