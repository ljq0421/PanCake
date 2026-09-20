using Godot;
using ProjectCake.Customers;

namespace ProjectCake.UI;

/// <summary>Presentation sampled from the business clock: pausing or skipping frames cannot delay service.</summary>
public static class CustomerArrivalMotion
{
    public const double Duration = .44;
    public static bool Reduced => ProjectSettings.GetSetting("accessibility/reduce_motion", false).AsBool();

    public static double Age(CustomerRuntime? customer) => customer?.State switch
    {
        CustomerState.Entering => customer.PhaseSeconds,
        CustomerState.Happy or CustomerState.Normal or CustomerState.Impatient or CustomerState.Angry
            => CustomerQueue.EnterDurationSeconds + customer.PhaseSeconds,
        _ => Duration,
    };

    public static void Apply(CustomerPortraitView portrait, OrderBubbleView card, CustomerRuntime? customer)
    {
        double age = Age(customer);
        portrait.SetArrivalMotion(age, customer?.SlotIndex ?? 2, Reduced);
        card.SetArrivalMotion(age, Reduced);
    }

    public static (Vector2 Position, Vector2 Scale, float Rotation) Sample(double age, int slot, bool reduced)
    {
        if (reduced || age >= Duration) return (Vector2.Zero, Vector2.One, 0);
        float t = Math.Clamp((float)(age / .28), 0, 1);
        float remaining = MathF.Pow(1 - t, 3);
        float direction = slot <= 2 ? -1 : 1;
        Vector2 position = new(direction * 32 * remaining, -10 * remaining - 2 * MathF.Sin(t * MathF.PI));
        Vector2 scale = Vector2.One * (1 - .03f * remaining);
        float rotation = direction * Mathf.DegToRad(.7f) * MathF.Sin(t * MathF.PI);
        if (age >= .28)
        {
            float rebound = (float)(age - .28);
            scale = rebound < .055f ? Vector2.One.Lerp(new(1.025f, .976f), rebound / .055f)
                : rebound < .11f ? new Vector2(1.025f, .976f).Lerp(new(.990f, 1.010f), (rebound - .055f) / .055f)
                : new Vector2(.990f, 1.010f).Lerp(Vector2.One, (rebound - .11f) / .05f);
        }
        return (position, scale, rotation);
    }
}
