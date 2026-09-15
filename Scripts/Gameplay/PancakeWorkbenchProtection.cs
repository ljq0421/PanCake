using ProjectCake.Pancake;
using ProjectCake.Data;

namespace ProjectCake.Gameplay;

public partial class PancakeWorkstation
{
    public TutorialProtection Tutorial { get; set; } = TutorialProtection.None;

    private double TutorialCookingDelta(double delta)
    {
        if (!Tutorial.ProtectPancakeHeat) return delta;
        var state = Machine.Runtime;
        return state.State switch
        {
            PancakeState.SideACooking when state.HasEgg => Math.Min(delta, Math.Max(0, Machine.Stove.SideAReadySeconds - state.CookingSeconds)),
            PancakeState.SideBCooking => Math.Min(delta, Math.Max(0, Machine.Stove.SideBReadySeconds - state.CookingSeconds)),
            _ => 0,
        };
    }
}
