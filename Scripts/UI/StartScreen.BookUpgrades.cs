using Godot;

namespace ProjectCake.UI;

public partial class StartScreen
{
    // The settlement book hosts the real start-screen scene, but owns navigation and input.
    internal bool HostedByBook { get; set; }
    private BookUpgradeSource? _bookUpgradeSource;
    private Action? _returnToBook;
    private Action<string>? _bookUpgradeSelection;
    private Action<CityEquipmentView>? _bookUpgradePurchase;

    internal void PresentBookUpgrades(BookUpgradeSource source, string? selected,
        Action<string> selection, Action<CityEquipmentView> purchase, Action back, string message)
    {
        _bookUpgradeSource = source; _city = source.CityId;
        _equipmentCity = _city; _selectedEquipment = selected;
        _bookUpgradeSelection = selection; _bookUpgradePurchase = purchase; _returnToBook = back;
        RenderUpgradePage();
        var feedback = Text(_body, "UpgradeFeedback", message, new(340, 872, 1220, 62), 23, true);
        feedback.AutowrapMode = TextServer.AutowrapMode.WordSmart;
        feedback.MaxLinesVisible = 2;
        feedback.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
    }

    private void BookUpgradeNavigation()
    {
        // Keep the return action on the right page, 16 px below the wallet's lower edge.
        var back = Button(_body, "CloseUpgrades", "", new(1355, 238, 225, 62), () => _returnToBook?.Invoke(), bare: true);
        Art(back, "账本翻页箭头｜左", new(0, 7, 55, 48));
        Text(back, "Caption", "返回账本", new(62, 0, 160, 62), 25);
    }
}
