class_name GameSettingsPanel
extends Control

signal closed(saved: bool)

const UI_SCALE_APPLIER := preload("res://scripts/ui/ui_scale_applier.gd")
const ACTION_IDS: Array[StringName] = [
	&"tool_ladle",
	&"tool_spreader",
	&"tool_sauce_brush",
	&"tool_fold_package",
]

var _session: Node
var _panel: PanelContainer
var _scroll: ScrollContainer
var _master_slider: HSlider
var _sfx_slider: HSlider
var _fullscreen_check: CheckButton
var _ui_scale_option: OptionButton
var _drag_slider: HSlider
var _drag_value: Label
var _message: Label
var _key_buttons: Dictionary = {}
var _pending_bindings: Dictionary = {}
var _capture_action: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1700
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false


func open_with_session(session: Node) -> void:
	_session = session
	var settings := Dictionary(_session.call("get_settings"))
	_master_slider.value = float(settings.get("master_volume", 80.0))
	_sfx_slider.value = float(settings.get("sfx_volume", 85.0))
	_fullscreen_check.button_pressed = bool(settings.get("fullscreen", false))
	var scale_value := float(settings.get("ui_scale", 100.0))
	_ui_scale_option.select(0 if scale_value <= 100.0 else 1 if scale_value <= 125.0 else 2)
	_drag_slider.value = float(settings.get("drag_sensitivity", 100.0))
	_pending_bindings = Dictionary(settings.get("key_bindings", _session.call("default_key_bindings"))).duplicate(true)
	_capture_action = &""
	_message.text = "设置会保存在本机；Esc 可取消按键录入。"
	_refresh_values()
	visible = true
	_fit_panel()
	UI_SCALE_APPLIER.apply_to(_panel, scale_value)
	_master_slider.grab_focus()


func close_without_saving() -> void:
	_capture_action = &""
	visible = false
	closed.emit(false)


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible or _capture_action.is_empty() or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
		_capture_action = &""
		_message.text = "已取消按键录入。"
		_refresh_key_buttons()
		get_viewport().set_input_as_handled()
		return
	var keycode := int(key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode)
	for action_value in _pending_bindings:
		var action := StringName(action_value)
		if action != _capture_action and int(_pending_bindings[action_value]) == keycode:
			_message.text = "%s 已被“%s”使用，请换一个按键。" % [_key_name(keycode), _session.call("key_binding_display_name", action)]
			get_viewport().set_input_as_handled()
			return
	_pending_bindings[str(_capture_action)] = keycode
	_message.text = "已将“%s”设为 %s。" % [_session.call("key_binding_display_name", _capture_action), _key_name(keycode)]
	_capture_action = &""
	_refresh_key_buttons()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _capture_action.is_empty() and event.is_action_pressed(&"ui_cancel"):
		close_without_saving()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_fit_panel()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.04, 0.045, 0.82)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override(&"panel", _panel_style())
	center.add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 28)
	margin.add_theme_constant_override(&"margin_top", 24)
	margin.add_theme_constant_override(&"margin_right", 28)
	margin.add_theme_constant_override(&"margin_bottom", 24)
	_scroll.add_child(margin)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override(&"separation", 14)
	margin.add_child(rows)
	rows.add_child(_label("设置", 38, Color("ffd166")))
	rows.add_child(_label("音量、界面、拖拽与工具快捷键", 24, Color("d9cdb9")))
	_master_slider = _slider(0.0, 100.0, 80.0)
	rows.add_child(_setting_row("主音量", _master_slider))
	_sfx_slider = _slider(0.0, 100.0, 85.0)
	rows.add_child(_setting_row("音效音量", _sfx_slider))
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "全屏显示"
	_fullscreen_check.add_theme_font_size_override(&"font_size", 24)
	rows.add_child(_fullscreen_check)
	_ui_scale_option = OptionButton.new()
	for value in [100, 125, 150]:
		_ui_scale_option.add_item("%d%%" % value, value)
	rows.add_child(_setting_row("UI 缩放", _ui_scale_option))
	_drag_slider = _slider(50.0, 150.0, 100.0)
	_drag_value = _label("100%", 24, Color("8ff0b5"))
	var drag_box := HBoxContainer.new()
	drag_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drag_box.add_child(_drag_slider)
	drag_box.add_child(_drag_value)
	rows.add_child(_setting_row("拖拽灵敏度", drag_box))
	_drag_slider.value_changed.connect(func(_value: float) -> void: _refresh_values())
	rows.add_child(HSeparator.new())
	rows.add_child(_label("工具快捷键", 28, Color("ffd166")))
	for action_id in ACTION_IDS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 50)
		button.add_theme_font_size_override(&"font_size", 24)
		button.pressed.connect(_begin_key_capture.bind(action_id))
		_key_buttons[action_id] = button
		rows.add_child(_setting_row(_action_fallback_name(action_id), button))
	var reset_button := Button.new()
	reset_button.text = "恢复默认按键"
	reset_button.add_theme_font_size_override(&"font_size", 24)
	reset_button.pressed.connect(_reset_key_bindings)
	rows.add_child(reset_button)
	_message = _label("", 24, Color("d9cdb9"))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override(&"separation", 14)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(140, 52)
	cancel.add_theme_font_size_override(&"font_size", 24)
	cancel.pressed.connect(close_without_saving)
	actions.add_child(cancel)
	var save := Button.new()
	save.text = "保存设置"
	save.custom_minimum_size = Vector2(180, 52)
	save.add_theme_font_size_override(&"font_size", 24)
	save.pressed.connect(_save)
	actions.add_child(save)
	rows.add_child(actions)


func _setting_row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	var caption_label := _label(caption, 24, Color("f5e1c3"))
	caption_label.custom_minimum_size.x = 210.0
	row.add_child(caption_label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _begin_key_capture(action_id: StringName) -> void:
	_capture_action = action_id
	_message.text = "请按下“%s”的新按键；Esc 取消。" % _session.call("key_binding_display_name", action_id)
	_refresh_key_buttons()


func _reset_key_bindings() -> void:
	_pending_bindings = Dictionary(_session.call("default_key_bindings")).duplicate(true)
	_capture_action = &""
	_message.text = "已恢复默认数字键，保存后生效。"
	_refresh_key_buttons()


func _save() -> void:
	var result := Dictionary(_session.call(
		"save_settings",
		_master_slider.value,
		_sfx_slider.value,
		_fullscreen_check.button_pressed,
		float(_ui_scale_option.get_selected_id()),
		_drag_slider.value,
		_pending_bindings,
	))
	if not bool(result.get("success", false)):
		_message.text = "设置未保存：%s" % str(result.get("reason", &"unknown"))
		return
	visible = false
	closed.emit(true)


func _refresh_values() -> void:
	_drag_value.text = "%d%%" % roundi(_drag_slider.value)
	_refresh_key_buttons()


func _refresh_key_buttons() -> void:
	for action_id in ACTION_IDS:
		var button := _key_buttons.get(action_id) as Button
		if button == null:
			continue
		button.text = "请按键…" if _capture_action == action_id else _key_name(int(_pending_bindings.get(str(action_id), 0)))


func _fit_panel() -> void:
	if _panel == null or _scroll == null:
		return
	_panel.custom_minimum_size.x = maxf(minf(820.0, size.x - 48.0), 560.0)
	_scroll.custom_minimum_size.y = maxf(minf(650.0, size.y - 64.0), 420.0)


static func _slider(minimum: float, maximum: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(320, 42)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1.0
	slider.value = value
	return slider


static func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


static func _key_name(keycode: int) -> String:
	return "未设置" if keycode <= 0 else OS.get_keycode_string(keycode)


static func _action_fallback_name(action_id: StringName) -> String:
	return {
		&"tool_ladle": "面糊勺",
		&"tool_spreader": "摊饼器/压饼器",
		&"tool_sauce_brush": "酱刷",
		&"tool_fold_package": "折叠/包装",
	}.get(action_id, str(action_id))


static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.08, 0.085, 0.985)
	style.border_color = Color("ffd166")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 18
	return style
