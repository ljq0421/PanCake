class_name OpeningRestockChecklist
extends PanelContainer

const PANEL_WIDTH := 420.0
const ROW_HEIGHT := 38.0

var _title: Label
var _rows: VBoxContainer
var _signature := ""


func _ready() -> void:
	name = "OpeningRestockChecklist"
	z_index = 180
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(24.0, 82.0)
	custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_theme_stylebox_override(&"panel", _panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_top", 14)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_bottom", 14)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 8)
	margin.add_child(content)
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", 26)
	_title.add_theme_color_override(&"font_color", Color("ffd166"))
	content.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 5)
	content.add_child(_rows)
	visible = false


func present(tasks: Array, remaining_seconds: float, active: bool) -> void:
	visible = active
	if not active:
		return
	_title.text = "开张备货 · %d 秒" % ceili(maxf(remaining_seconds, 0.0))
	var signature := str(tasks)
	if signature == _signature:
		return
	_signature = signature
	for child in _rows.get_children():
		child.queue_free()
	var has_next := false
	for task_value in tasks:
		var task := Dictionary(task_value)
		var row := PanelContainer.new()
		row.custom_minimum_size.y = ROW_HEIGHT
		var is_next := bool(task.get("is_next", false))
		has_next = has_next or is_next
		row.add_theme_stylebox_override(&"panel", _row_style(is_next, bool(task.get("completed", false))))
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override(&"font_size", 24)
		label.add_theme_color_override(&"font_color", Color("fff6dc") if is_next else Color("d8e5dc"))
		var quantity := "充足" if bool(task.get("is_unlimited", false)) else "%d/%d" % [int(task.get("current", 0)), int(task.get("target", 0))]
		var prefix := "▶ " if is_next else "✓ " if bool(task.get("completed", false)) else "  "
		label.text = "%s%s  %s" % [prefix, str(task.get("label", "原料")), quantity]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		_rows.add_child(row)
	if not has_next:
		var done := Label.new()
		done.add_theme_font_size_override(&"font_size", 24)
		done.add_theme_color_override(&"font_color", Color("8ff0b5"))
		done.text = "✓ 备货完成，可以提前制作"
		_rows.add_child(done)


static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.085, 0.09, 0.94)
	style.border_color = Color(0.35, 0.76, 0.62, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 8
	return style


static func _row_style(is_next: bool, completed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.bg_color = Color(0.12, 0.34, 0.25, 0.88) if is_next else Color(0.08, 0.15, 0.15, 0.62)
	style.border_color = Color("ffd166") if is_next else Color(0.32, 0.54, 0.48, 0.65) if not completed else Color(0.35, 0.76, 0.62, 0.40)
	style.set_border_width_all(2 if is_next else 1)
	style.set_corner_radius_all(8)
	return style
