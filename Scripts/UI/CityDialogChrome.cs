using Godot;

namespace ProjectCake.UI;

/// <summary>Shared blocking prompts using the approved illustrated panel and native dialog input.</summary>
public static class CityDialogChrome
{
    public static void ApplyConfirmation(AcceptDialog dialog, string cityId, bool compact = false)
    {
        ButtonHoverFeedback.Attach(dialog.GetOkButton());
        if (dialog is ConfirmationDialog confirmation)
            ButtonHoverFeedback.Attach(confirmation.GetCancelButton());
        dialog.SetMeta("illustrated_dialog", true);
        dialog.SetMeta("dialog_city", cityId);
        if (cityId is "city:tianjin" or "city:wuhan") JourneyDialogMotion.Attach(dialog);
        dialog.Borderless = true;
        dialog.Transparent = true;
        dialog.TransparentBg = true;
        dialog.Theme = new Theme();

        Label message = dialog.GetLabel();
        message.HorizontalAlignment = HorizontalAlignment.Center;
        message.VerticalAlignment = VerticalAlignment.Center;
        message.AutowrapMode = TextServer.AutowrapMode.WordSmart;

        var header = dialog.GetNodeOrNull<CanvasLayer>("CityDialogHeader");
        if (header is null)
        {
            header = new CanvasLayer { Name = "CityDialogHeader" };
            dialog.AddChild(header);
            var artwork = new Control { Name = "Artwork", MouseFilter = Control.MouseFilterEnum.Ignore };
            header.AddChild(artwork);
            artwork.AddChild(new Label
            {
                Name = "Title", HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center, MouseFilter = Control.MouseFilterEnum.Ignore, ZIndex = 2,
            });
            // Retain the shared node contract without an invisible active close target.
            artwork.AddChild(new Button { Name = "Close", Visible = false, FocusMode = Control.FocusModeEnum.None });
            void Layout()
            {
                artwork.Size = dialog.Size;
                IllustratedCityDialogTheme.LayoutHeader(artwork, dialog, dialog.GetMeta("dialog_city").AsString());
            }
            dialog.SizeChanged += Layout;
            dialog.AboutToPopup += Layout;
        }
        IllustratedCityDialogTheme.ApplyConfirmation(dialog, cityId, compact);
        IllustratedCityDialogTheme.LayoutHeader(header.GetNode<Control>("Artwork"), dialog, cityId);
    }
}
