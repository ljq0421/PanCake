using Godot;

namespace ProjectCake.UI;

/// <summary>Customer cards retain their authored fill and can opt into a contour for interaction feedback.</summary>
public static class CustomerInteractionPresentation
{
    public static void RemoveButtonBorders(Button customer)
        => ButtonContourHighlight.RemoveBorders(customer);

    public static ButtonContourHighlight BindButtonHighlight(Button customer, Func<InteractionHighlightState> state)
        => ButtonContourHighlight.Attach(customer, state);
}
