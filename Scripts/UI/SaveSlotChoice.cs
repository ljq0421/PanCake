using Godot;

namespace ProjectCake.UI;

/// <summary>Journal dropdown with separate load and delete hit targets.</summary>
public partial class SaveSlotChoice : Button
{
    private readonly List<string> _items = new();
    private readonly HashSet<int> _disabled = new();
    private readonly HashSet<int> _deletable = new();
    private Control _popup = null!;
    private int _selected;
    public event Action<int>? ItemSelected;
    public event Action<int>? DeleteRequested;
    public int ItemCount => _items.Count;
    public void AddItem(string text) => _items.Add(text);
    public string GetItemText(int index) => _items[index];
    public bool IsItemDisabled(int index) => _disabled.Contains(index);
    public void SetItemDisabled(int index, bool disabled) { if (disabled) _disabled.Add(index); else _disabled.Remove(index); }
    public void SetDeletable(int index, bool value) { if (value) _deletable.Add(index); else _deletable.Remove(index); }
    public void Select(int index) { _selected = index; Text = (index >= 0 ? _items[index] : Tr("选择存档").ToString()) + "  ▾"; }
    public void ActivateItem(int index)
    {
        if (IsItemDisabled(index)) return;
        Select(index); _popup.Hide(); GrabFocus(); ItemSelected?.Invoke(index);
    }
    public Control GetPopup() => _popup;
    public override void _Ready()
    {
        ClipText = true; Alignment = HorizontalAlignment.Left;
        MouseDefaultCursorShape = CursorShape.PointingHand;
        _popup = new Control { Name = "SaveSlotPopup", Size = new(1920, 1080), Visible = false, ZIndex = 5 };
        GetParent().AddChild(_popup);
        _popup.GuiInput += input => { if (input is InputEventMouseButton { Pressed: true }) { _popup.Hide(); GrabFocus(); AcceptEvent(); } };
        Pressed += ShowPopup;
    }
    public void ShowPopup()
    {
        foreach (Node node in _popup.GetChildren()) { _popup.RemoveChild(node); node.QueueFree(); }
        var panel = new Panel { Position = Position + new Vector2(0, Size.Y + 4), Size = new(Size.X, 250) };
        panel.AddThemeStyleboxOverride("panel", JournalSettingsTheme.Box(JournalSettingsTheme.Cream));
        _popup.AddChild(panel);
        using var iconImage = new Image();
        iconImage.LoadSvgFromString("<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'><g fill='none' stroke='#99533D' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><path d='M4 6h16M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7M14 10v7'/></g></svg>");
        var icon = ImageTexture.CreateFromImage(iconImage);
        for (int i = 0; i < ItemCount; i++)
        {
            int index = i;
            var row = new Button { Name = "LoadSlot" + (i + 1), Text = (i == _selected ? "● " : "○ ") + _items[i],
                Position = new(8, 5 + i * 48), Size = new(Size.X - 60, 48), ClipText = true,
                Alignment = HorizontalAlignment.Left, Disabled = IsItemDisabled(i), TooltipText = _items[i] };
            JournalSettingsTheme.Apply(row, i == _selected, 6);
            row.AddThemeFontSizeOverride("font_size", 21);
            row.AddThemeStyleboxOverride("normal", JournalSettingsTheme.Box(Colors.Transparent, 6, 0));
            row.AddThemeStyleboxOverride("disabled", JournalSettingsTheme.Box(Colors.Transparent, 6, 0));
            panel.AddChild(row); row.Pressed += () => ActivateItem(index);
            if (!_deletable.Contains(i)) continue;
            var delete = new Button { Name = "DeleteSlot" + (i + 1), Icon = icon, Position = new(Size.X - 48, 7 + i * 48),
                Size = new(40, 42), MouseDefaultCursorShape = CursorShape.PointingHand };
            JournalSettingsTheme.Apply(delete, radius: 6);
            delete.AddThemeStyleboxOverride("normal", JournalSettingsTheme.Box(Colors.Transparent, 6, 0));
            panel.AddChild(delete);
            delete.Pressed += () => { _popup.Hide(); DeleteRequested?.Invoke(index); };
        }
        _popup.Show();
        panel.GetChildren().OfType<Button>().FirstOrDefault(b => !b.Disabled)?.GrabFocus();
    }
    public bool HandleKey(InputEventKey key)
    {
        if (!_popup.Visible) return false;
        if (key.Keycode == Key.Escape) { _popup.Hide(); GrabFocus(); return true; }
        if (key.Keycode is not (Key.Tab or Key.Up or Key.Down or Key.Left or Key.Right)) return false;
        var buttons = _popup.FindChildren("*", "Button", true, false).OfType<Button>().Where(b => !b.Disabled).ToArray();
        if (buttons.Length == 0) return true;
        int current = Array.IndexOf(buttons, GetViewport().GuiGetFocusOwner());
        int direction = key.Keycode is Key.Up or Key.Left || key.Keycode == Key.Tab && key.ShiftPressed ? -1 : 1;
        buttons[(current + direction + buttons.Length) % buttons.Length].GrabFocus(); return true;
    }
}
