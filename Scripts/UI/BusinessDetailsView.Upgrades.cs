using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class BusinessDetailsView
{
    private Control? _upgradeModal;
    private Button? _upgradeEntry;
    private bool _buying;
    private string? _selectedUpgrade;
    private bool CanUpgrade => _model.Closing && _model.Upgrades is not null;
    private TutorialFocusLayer _upgradeTeaching = null!;
    private void BuildUpgradeTeaching()
    {
        _upgradeTeaching = new TutorialFocusLayer
        {
            AllowDismiss = false,
            Resolve = () => CanUpgrade && _model.CanClose && !DetailVisible && _upgradeModal is null
                && _entrance?.IsRunning() != true && _pageTween?.IsRunning() != true
                && GetNodeOrNull<InterfaceTeaching>("InterfaceTeaching") is null
                && IsInstanceValid(_upgradeEntry) && _upgradeEntry!.IsVisibleInTree()
                && _model.Upgrades!.NeedsUpgradeTeaching
                ? new TutorialFocusStep("first-shop-upgrade", "店铺可以升级了！\n点击「升级」查看设备效果和价格。\n升级后，下次营业生效。",
                    new[] { TutorialFocusTarget.Control(_upgradeEntry) }) : null
        };
        _canvas.AddChild(_upgradeTeaching);
    }
    private void RefreshUpgradeCaptions()
    {
        if (_model.Upgrades is null) return;
        var stickers = _model.Stickers.Where(s => !s.Contains("升级")).ToList();
        var offers = CanUpgrade ? _model.Upgrades.Offers : Array.Empty<BookUpgradeOffer>();
        if (offers.Count > 0) stickers.Add($"可升级：{offers[0].Name} Lv{offers[0].TargetLevel}" + (offers.Count > 1 ? $"等{offers.Count}项" : ""));
        else if (CanUpgrade) stickers.Add("店铺升级 · 查看设备");
        _model.Stickers = stickers.ToArray();
    }
    private void AddPlainUpgradeEntry()
    {
        if (!CanUpgrade) return;
        _upgradeEntry = ButtonAt(_summary, "店铺升级 · 查看设备", new(1130, 605, 350, 58), OpenUpgrades);
        _upgradeEntry.Name = "UpgradeSticker";
    }
    private void OpenUpgrades()
    {
        if (!CanUpgrade || _upgradeModal is not null) return;
        PlayBookSpread();
        string message = "";
        if (_model.Upgrades!.NeedsUpgradeTeaching)
            _model.Upgrades.CompleteUpgradeTeaching(out message);
        FinishAnimation(); _selectedUpgrade = null; RenderUpgradeModal(message);
        _upgradeTeaching.Refresh();
    }
    private void RenderUpgradeModal(string message)
    {
        RemoveUpgradeModal();
        var source = _model.Upgrades!;
        var modal = new Control { Name = "BookUpgradeModal", Size = new(1920, 1080), MouseFilter = MouseFilterEnum.Stop };
        _upgradeModal = modal; _canvas.AddChild(modal);
        _book.Hide();
        var page = GD.Load<PackedScene>("res://Scenes/UI/StartScreen.tscn").Instantiate<StartScreen>();
        page.HostedByBook = true;
        modal.AddChild(page);
        page.PresentBookUpgrades(source, _selectedUpgrade, id => _selectedUpgrade = id, e =>
        {
            var offer = source.Offers.FirstOrDefault(o => o.EquipmentId == e.Id && o.CurrentLevel == e.Level && o.Price == e.Price);
            if (offer is null) { RenderUpgradeModal("设备状态已变化，请查看最新升级信息。"); return; }
            BuyUpgrade(offer);
        }, CanContinueBusiness && !_model.NewWuhanUnlock ? RequestPrimary : null, message);
    }
    private void BuyUpgrade(BookUpgradeOffer offer)
    {
        if (_buying || !CanUpgrade || _upgradeModal is null) return;
        _buying = true;
        try
        {
            var previous = _model.Upgrades!.Equipment.FirstOrDefault(e => e.Id == offer.EquipmentId);
            bool ok = _model.Upgrades.Purchase(offer, out string error);
            RefreshUpgradeCaptions(); BuildSummary(); RefreshRows();
            RenderUpgradeModal(ok ? "" : error);
            if (ok) _upgradeModal?.GetChildren().OfType<StartScreen>().FirstOrDefault()?.ShowUpgradeSuccess(offer.EquipmentId, previous);
        }
        finally { _buying = false; }
    }
    private void RemoveUpgradeModal()
    {
        if (_upgradeModal is null) return;
        _upgradeModal.GetParent().RemoveChild(_upgradeModal); _upgradeModal.QueueFree(); _upgradeModal = null;
        _book.Show();
    }
    private void CloseUpgrades()
    {
        PlayBookSpread();
        RemoveUpgradeModal();
        if (IsInstanceValid(_upgradeEntry) && _upgradeEntry!.IsVisibleInTree()) _upgradeEntry.GrabFocus();
        else CloseButton.GrabFocus();
    }
    private void PlayBookSpread() => JourneyTransition.For(this).Play(JourneyTransition.Effect.SpreadOpen,
        bounds: new Rect2(_book.GetGlobalTransformWithCanvas().Origin, _book.Size * _canvas.Scale), ledger: true, dimBackdrop: false);
}
