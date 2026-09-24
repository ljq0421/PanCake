using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private Control? _saveDeleteOverlay;
    private int _saveDeleteSlotId;
    private readonly Dictionary<Control, FocusModeEnum> _saveDeleteFocusModes = new();

    private void CloseSaveDeleteConfirmation(bool restoreFocus = true)
    {
        if (_saveDeleteOverlay is null) return;
        _modalControls.RemoveAll(c => _saveDeleteOverlay.IsAncestorOf(c));
        _modal.RemoveChild(_saveDeleteOverlay);
        _saveDeleteOverlay.QueueFree();
        _saveDeleteOverlay = null;
        foreach (var (control, mode) in _saveDeleteFocusModes)
            if (GodotObject.IsInstanceValid(control)) control.FocusMode = mode;
        _saveDeleteFocusModes.Clear();
        if (restoreFocus) _modal.GetNodeOrNull<Button>("DeleteSlot" + _saveDeleteSlotId)?.GrabFocus();
    }

    private void RequestDeleteSaveSlot(SaveSlotSummary slot)
    {
        if (_save is null || !slot.Exists || _busy || _saveDeleteOverlay is not null) return;
        _saveDeleteSlotId = slot.Id;
        CloseSettingsPopups();
        foreach (var control in _modal.FindChildren("*", "Control", true, false).OfType<Control>())
            if (control.FocusMode != FocusModeEnum.None)
            { _saveDeleteFocusModes[control] = control.FocusMode; control.FocusMode = FocusModeEnum.None; }
        _saveDeleteOverlay = new Control { Name = "SaveDeleteOverlay", Size = new(1920, 1080), ZIndex = 10 };
        _modal.AddChild(_saveDeleteOverlay);
        _saveDeleteOverlay.AddChild(new ColorRect { Size = new(1920, 1080), Color = new Color(.12f, .08f, .04f, .22f) });
        // Reuse the existing dialog art at 65%, centred over the archive book.
        var dialog = new Control { Name = "SaveDeleteDialog", Position = new(336, 189),
            Scale = new(.65f, .65f), Size = new(1920, 1080), MouseFilter = MouseFilterEnum.Ignore };
        _saveDeleteOverlay.AddChild(dialog);
        AddConfirmationPanel(dialog, "DeleteSave");
        ConfirmationTitle(dialog, "DeleteSaveTitle", "删除这段旅程？");
        string description = slot.Corrupt ? $"存档 {slot.Id} · 无法读取" : $"{slot.Name} · {Tr(JourneyModel.City(slot.CityId).Name)} · 第 {slot.Day} 天";
        ConfirmationMessage(dialog, "DeleteSaveMessage", $"{description}\n该存档的进度与收藏将被永久删除，无法恢复。");
        ConfirmationAction(dialog, "CancelDeleteSave", "保留存档", () => CloseSaveDeleteConfirmation()).GrabFocus();
        ConfirmationAction(dialog, "ConfirmDeleteSave", "确认删除", () =>
        {
            _busy = true;
            bool deleted = _save.TryDeleteSlot(slot.Id, out string error);
            _busy = false;
            if (deleted)
            {
                _selectedEquipment = null; _equipmentCity = null; _completedCity = null;
                _mapReturn = null; _cityReturn = null;
                _error = "";
                RenderHome();
            }
            if (deleted) OpenJourneyArchives();
            else CloseSaveDeleteConfirmation();
            if (!deleted && _archiveMessage is not null) _archiveMessage.Text = error;
        }, true);
    }
}
