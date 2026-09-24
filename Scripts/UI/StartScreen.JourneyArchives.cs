using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private Label? _archiveMessage;

    private bool SwitchSaveSlot(int id)
    {
        if (_save is null || _busy) return false;
        if (_save.ActiveSlotId == id) return true;
        _busy = true;
        if (!_save.TryLoadSlot(id, out string error))
        {
            _busy = false;
            if (_archiveMessage is not null) _archiveMessage.Text = error;
            return false;
        }
        _selectedEquipment = null; _equipmentCity = null; _completedCity = null;
        _mapReturn = null; _cityReturn = null;
        _busy = false;
        SetStatus();
        return true;
    }

    private Button ArchiveButton(string name, string caption, Rect2 bounds, Action action)
    {
        var button = SettingsButton(name, caption, bounds, action);
        int size = 24;
        var font = button.GetThemeFont("font");
        string translated = button.Tr(caption);
        while (size > 16 && font.GetStringSize(translated, fontSize: size).X > bounds.Size.X - 18) size--;
        button.AddThemeFontSizeOverride("font_size", size);
        return button;
    }

    private void OpenJourneyArchives(bool newJourney = false)
    {
        if (_save is null || _busy) return;
        OpenModal("journey-archives");
        var slots = _save.GetSlots();
        var title = Text(_modal, "ArchivesTitle", newJourney ? "选择一本空白旅行手账" : "我的旅程档案",
            new(340, 214, 1180, 66), 44, true);
        title.AddThemeColorOverride("font_color", JournalSettingsTheme.Ink);
        Text(_modal, "ArchivesHint", newJourney
            ? slots.All(s => s.Exists) ? "五本手账已经写满。可到旅程档案删除不再需要的旅程。" : "选择空白手账，出发时才会创建旅程。"
            : "选择旅程继续旅行，也可以在这里改名或删除。", new(354, 282, 1150, 43), 23);
        for (int i = 0; i < slots.Count; i++) AddArchiveSlot(slots[i], i, newJourney);
        _archiveMessage = Text(_modal, "ArchivesMessage", "", new(355, 835, 950, 40), 22);
        _archiveMessage.AddThemeColorOverride("font_color", new Color("#983F32"));
        var close = SettingsButton("CloseArchives", newJourney && slots.All(s => s.Exists) ? "前往旅程档案" : "返回首页",
            new(1308, 833, 240, 58), newJourney && slots.All(s => s.Exists) ? () => OpenJourneyArchives() : CloseModal);
        JournalSettingsTheme.Apply(close, selected: true);
        _modal.GetNodeOrNull<Button>(newJourney ? "CreateSlot" + (slots.FirstOrDefault(s => !s.Exists)?.Id ?? 0) :
            "ArchiveSlot" + (_save.ActiveSlotId ?? slots.FirstOrDefault(s => s.Exists && !s.Corrupt)?.Id ?? 1))?.GrabFocus();
    }

    private void AddArchiveSlot(SaveSlotSummary slot, int index, bool newJourney)
    {
        int column = index % 2, row = index / 2;
        float x = column == 0 ? 335 : 1000, y = 349 + row * 153;
        var card = new Panel { Name = "ArchiveCard" + slot.Id, Position = new(x, y), Size = new(575, 136), MouseFilter = MouseFilterEnum.Ignore };
        card.AddThemeStyleboxOverride("panel", JournalSettingsTheme.Box(slot.Id == _save?.ActiveSlotId
            ? new Color("#F3DA9B") : new Color("#FFF8E8"), 13, 2));
        _modal.AddChild(card);
        HomeArt(_modal, slot.Exists ? "已有旅程手账封面" : "闭合旅行手账封面｜新旅程入口",
            new(x + 15, y + 16, 67, 98));
        string heading = slot.Corrupt ? $"旅程 {slot.Id} · 无法读取" : slot.Exists ? slot.Name : $"旅程 {slot.Id} · 空白手账";
        var label = Text(_modal, "ArchiveName" + slot.Id, heading, new(x + 91, y + 13, 295, 42), 26);
        FitTextWidth(label, 26, 19);
        string details = slot.Corrupt ? "可删除，其他旅程仍可使用" : slot.Exists
            ? $"{JourneyModel.City(slot.CityId).Name} · 第 {slot.Day} 天 · {slot.Coins} 金币" : "尚未出发";
        var progress = Text(_modal, "ArchiveProgress" + slot.Id, details, new(x + 91, y + 56, 375, 33), 19);
        FitTextWidth(progress, 19, 16);
        if (newJourney)
        {
            if (!slot.Exists) ArchiveButton("CreateSlot" + slot.Id, "开始旅程", new(x + 399, y + 83, 156, 42),
                () => RequestNewGame(slot.Id));
            return;
        }
        if (!slot.Exists)
        {
            ArchiveButton("CreateSlot" + slot.Id, "新的旅程", new(x + 399, y + 83, 156, 42),
                () => RequestNewGame(slot.Id));
            return;
        }
        if (!slot.Corrupt)
        {
            string action = slot.Id == _save?.ActiveSlotId ? "继续旅程" : "设为当前";
            ArchiveButton("ArchiveSlot" + slot.Id, action, new(x + 399, y + 83, 156, 42), () =>
            {
                if (slot.Id != _save?.ActiveSlotId && !SwitchSaveSlot(slot.Id)) return;
                CloseModal(); PresentMap();
            });
            ArchiveButton("RenameSlot" + slot.Id, "改名", new(x + 91, y + 96, 95, 32), () => ShowArchiveRename(slot, x, y));
        }
        ArchiveButton("DeleteSlot" + slot.Id, "删除", new(x + 198, y + 96, 95, 32), () => RequestDeleteSaveSlot(slot));
    }

    private void ShowArchiveRename(SaveSlotSummary slot, float x, float y)
    {
        if (_modal.GetNodeOrNull<LineEdit>("ArchiveRename") is not null) return;
        var input = new LineEdit { Name = "ArchiveRename", Text = slot.Name, MaxLength = 40,
            Position = new(x + 91, y + 11), Size = new(292, 44) };
        input.AddThemeStyleboxOverride("normal", JournalSettingsTheme.Box(new Color("#FFF8E8"), 8, 2));
        input.AddThemeFontSizeOverride("font_size", 23);
        input.AddThemeColorOverride("font_color", JournalSettingsTheme.Ink);
        _modal.AddChild(input); _modalControls.Add(input);
        var save = SettingsButton("SaveArchiveName", "保存", new(x + 390, y + 11, 78, 44), () =>
        {
            if (_save is null) return;
            if (!_save.TryRenameSlot(slot.Id, input.Text, out string error))
            { if (_archiveMessage is not null) _archiveMessage.Text = error; return; }
            OpenJourneyArchives();
        });
        SettingsButton("CancelArchiveName", "取消", new(x + 476, y + 11, 78, 44), () => OpenJourneyArchives());
        input.TextSubmitted += _ => save.EmitSignal(BaseButton.SignalName.Pressed);
        input.GrabFocus(); input.SelectAll();
    }

    private void OpenMapJourneySwitch()
    {
        if (_save is null || _busy) return;
        OpenModal("map-switch");
        var slots = _save.GetSlots();
        int occupied = slots.Count(s => s.Exists && !s.Corrupt);
        var empty = slots.FirstOrDefault(s => !s.Exists);
        float footerY = 267 + occupied * 99 + (empty is null ? 0 : 72);
        var panel = new Panel { Name = "JourneySwitchDrawer", Position = new(98, 165), Size = new(510, footerY - 165 + 85) };
        panel.AddThemeStyleboxOverride("panel", JournalSettingsTheme.Box(new Color("#FFF8E8"), 20, 2));
        _modal.AddChild(panel);
        Text(panel, "SwitchTitle", "切换旅程", new(34, 31, 420, 55), 36);
        int first = -1;
        int row = 0;
        foreach (var slot in slots)
        {
            if (!slot.Exists || slot.Corrupt) continue;
            string text = (slot.Id == _save.ActiveSlotId ? "● " : "○ ") + slot.Name
                + $"   {JourneyModel.City(slot.CityId).Name} · 第 {slot.Day} 天";
            var button = SettingsButton("MapSwitchSlot" + slot.Id, text,
                new(132, 267 + row++ * 99, 440, 72), () =>
                {
                    if (slot.Id != _save.ActiveSlotId && !SwitchSaveSlot(slot.Id)) return;
                    CloseModal(); PresentMap();
                });
            button.Alignment = HorizontalAlignment.Left;
            if (first < 0) first = slot.Id;
        }
        if (empty is not null)
            SettingsButton("MapSwitchNewJourney", "＋ 新的旅程", new(134, footerY - 72, 435, 54), () =>
            { CloseModal(); RenderHome(); OpenJourneyArchives(newJourney: true); });
        _archiveMessage = Text(_modal, "MapSwitchMessage", "", new(132, footerY + 57, 430, 30), 18);
        SettingsButton("MapSwitchArchives", "管理旅程档案", new(134, footerY, 435, 54), () =>
        { CloseModal(); RenderHome(); OpenJourneyArchives(); });
        SettingsButton("MapSwitchClose", "返回地图", new(1410, 833, 215, 58), CloseModal);
        _modal.GetNodeOrNull<Button>("MapSwitchSlot" + first)?.GrabFocus();
    }
}
