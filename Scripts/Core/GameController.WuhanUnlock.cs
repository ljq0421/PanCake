using Godot;
using ProjectCake.Data;
using ProjectCake.UI;

namespace ProjectCake.Core;

public partial class GameController
{
    private void PresentWuhanUnlock(BusinessDetailsView book)
    {
        var presentation = new WuhanUnlockPresentation { Name = "WuhanUnlockPresentation" };
        if (DisplayServer.GetName() != "headless")
        {
            using var frame = GetViewport().GetTexture().GetImage();
            if (frame is not null && !frame.IsEmpty()) presentation.SourceFrame = ImageTexture.CreateFromImage(frame);
        }
        var previousProcessMode = _startScreen.ProcessMode;
        _startScreen.PresentWuhanOpening(animate: false);
        JourneyTransition.For(this).Finish();
        _startScreen.ProcessMode = ProcessModeEnum.Disabled;
        GetViewport().GuiReleaseFocus();
        book.Hide();
        foreach (Control page in GetNode("UI").GetChildren().OfType<Control>())
            page.Visible = page == _startScreen;
        GetNode<Node2D>("ShopRoot").Visible = false;
        presentation.TreeExited += () => _startScreen.ProcessMode = previousProcessMode;
        AddChild(presentation);
        presentation.Begin(_save, error =>
        {
            if (error.Length > 0) _startScreen.ShowError(error);
        });
    }
}
