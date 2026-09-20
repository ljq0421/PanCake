using Godot;
using ProjectCake.Core;

namespace ProjectCake.UI;

public partial class StartScreen
{
    private int? _pendingNewSlot;
    private bool _selectEmptySlot;

    private void RenderSaves(bool selectEmpty = false)
    {
        if (_save is null) return;
        _selectEmptySlot = selectEmpty; _pendingNewSlot = null;
        Begin(JourneyPage.Saves); Chrome(RenderHome, selectEmpty ? "选择一本新手账" : "存档管理"); BookFrame();
        var slots = _save.GetSlots();
        Text(_body, "SavesHeading", "五段旅程 · 各自珍藏", new(385, 225, 450, 50), 32);
        Text(_body, "SavesHint", selectEmpty ? "选择空槽位，从天津重新出发。" : "继续一段旅程，或翻开新的篇章。", new(1030, 225, 490, 50), 25);
        foreach (var slot in slots)
        {
            float x = slot.Id <= 3 ? 365 : 1015;
            float y = 295 + (slot.Id <= 3 ? slot.Id - 1 : slot.Id - 4) * 185;
            var panel = new Panel { Name = "Slot" + slot.Id, Position = new(x, y), Size = new(535, 175), MouseFilter = MouseFilterEnum.Ignore };
            panel.AddThemeStyleboxOverride("panel", StartScreenTheme.Box(new Color(1f, .95f, .83f, .65f), 1, true)); _body.AddChild(panel);
            bool current = _save.ActiveSlotId == slot.Id;
            var title = Text(panel, "Name", $"{slot.Id:00}  {slot.Name}", new(18, 7, current ? 415 : 500, 38), 28);
            if (current) Text(panel, "CurrentSlot", "当前", new(450, 7, 70, 38), 23);
            title.AutowrapMode = TextServer.AutowrapMode.Off; title.TextOverrunBehavior = TextServer.OverrunBehavior.TrimEllipsis;
            title.TooltipText = slot.Name;
            if (!slot.Exists)
            {
                Text(panel, "Details", "空白手账，等待新的旅程", new(18, 51, 490, 35), 23);
                Button(panel, "CreateSlot" + slot.Id, "新建旅程", new(18, 115, 180, 48), () =>
                { _pendingNewSlot = slot.Id; RenderOpening(); }, true);
                continue;
            }
            string city = JourneyModel.Cities.FirstOrDefault(c => c.Id == slot.CityId)?.Name ?? "";
            Text(panel, "Details", slot.Corrupt ? "存档无法读取 · 可删除后重新开始" : $"{city} · 已开放第 {slot.Day} 天 · {slot.Coins} 金币", new(18, 48, 500, 34), 22);
            Text(panel, "SavedAt", slot.SavedAt is { } time ? "保存于 " + time.ToLocalTime().ToString("yyyy-MM-dd HH:mm") : "原文件已保留，其他旅程不受影响", new(18, 80, 500, 30), 19);
            var resume = Button(panel, "LoadSlot" + slot.Id, "继续", new(18, 119, 145, 46), () => ContinueSlot(slot.Id), true);
            resume.Disabled = slot.Corrupt;
            var rename = Button(panel, "RenameSlot" + slot.Id, "改名", new(183, 119, 145, 46), () => RenameSlot(slot));
            rename.Disabled = slot.Corrupt;
            Button(panel, "DeleteSlot" + slot.Id, "删除", new(348, 119, 145, 46), () => DeleteSlot(slot));
        }
        Text(_body, "SlotsNote", "自动保存各自进度\n删除前会再次确认，其他旅程不受影响。", new(1035, 724, 490, 100), 23);
        if (slots.All(s => s.Exists))
            Text(_body, "SlotsFull", "五个槽位已满，请先删除一个存档。", new(1035, 807, 490, 45), 24);
        if (_save.SlotError.Length > 0)
            Button(_body, "RetrySlots", "重新读取", new(1040, 892, 220, 50), () => { _busy = true; _save.Load(); RenderSaves(selectEmpty); });
        var firstEmpty = slots.FirstOrDefault(s => !s.Exists);
        Focus(selectEmpty && firstEmpty is not null ? "CreateSlot" + firstEmpty.Id
            : _save.ActiveSlotId is int active ? "LoadSlot" + active : slots.First().Exists ? "LoadSlot1" : "CreateSlot1");
    }

    private void ContinueSlot(int id)
    {
        _busy = true;
        if (!_save!.TryLoadSlot(id, out string error)) { RenderSaves(); ShowError(error); return; }
        // No page-local selection or deferred celebration should survive a profile switch.
        _selectedEquipment = null; _equipmentCity = null; _completedCity = null;
        _mapReturn = null; _cityReturn = null; _pendingNewSlot = null;
        ContinueRequested?.Invoke();
    }
    private void DeleteSlot(SaveSlotSummary slot)
    {
        OpenModal("confirm");
        ConfirmationTitle(_modal, "DeleteTitle", "删除这段旅程？");
        ConfirmationMessage(_modal, "DeleteMessage", $"槽位 {slot.Id} · {slot.Name}\n该旅程的全部进度将被删除，无法撤销。\n其他旅程不受影响。");
        ConfirmationAction(_modal, "Cancel", "保留旅程", CloseModal);
        ConfirmationAction(_modal, "Confirm", "确认删除", () =>
        {
            _busy = true;
            bool ok = _save!.TryDeleteSlot(slot.Id, out string error);
            RenderSaves(_selectEmptySlot); if (!ok) ShowError(error);
        }, true);
        _modalControls[0].GrabFocus();
    }
    private void RenameSlot(SaveSlotSummary slot)
    {
        OpenModal("confirm");
        ConfirmationTitle(_modal, "RenameTitle", "为旅程起个名字");
        Text(_modal, "RenameHint", $"槽位 {slot.Id} · 1–20 个文字字符", new(590, 385, 740, 45), 28, true);
        var input = new LineEdit { Name = "SlotName", Text = slot.Name, Position = new(595, 465), Size = new(730, 75) };
        input.AddThemeFontSizeOverride("font_size", 32); _modal.AddChild(input); _modalControls.Add(input);
        var validation = Text(_modal, "NameError", "", new(560, 555, 800, 60), 24, true);
        ConfirmationAction(_modal, "Cancel", "取消", CloseModal);
        void Confirm()
        {
            _busy = true;
            if (!_save!.TryRenameSlot(slot.Id, input.Text, out string error)) { _busy = false; validation.Text = error; return; }
            RenderSaves(_selectEmptySlot); Focus("RenameSlot" + slot.Id);
        }
        ConfirmationAction(_modal, "Confirm", "保存名称", Confirm, true);
        input.TextSubmitted += _ => Confirm(); input.GrabFocus(); input.SelectAll();
    }
}
