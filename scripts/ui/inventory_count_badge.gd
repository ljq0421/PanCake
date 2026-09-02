class_name InventoryCountBadge
extends Label

var _count := 0
var _capacity := 0
var _hidden_for_context := false


func _ready() -> void:
	z_index = 240
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(54.0, 28.0)
	add_theme_font_size_override(&"font_size", 17)
	add_theme_color_override(&"font_outline_color", Color(0.04, 0.025, 0.015, 0.96))
	add_theme_constant_override(&"outline_size", 3)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_presentation()


func set_stock(count: int, capacity: int, hidden_for_context: bool = false) -> void:
	_count = maxi(count, 0)
	_capacity = maxi(capacity, 0)
	_hidden_for_context = hidden_for_context
	if is_node_ready():
		_apply_presentation()


func stock_count() -> int:
	return _count


func _apply_presentation() -> void:
	visible = not _hidden_for_context
	if not visible:
		return
	text = "×%d" % _count
	var low_threshold := maxi(ceili(float(_capacity) * 0.25), 1)
	var foreground := Color("ff8f78") if _count <= 0 else Color("ffd06a") if _count <= low_threshold else Color("f7ecd2")
	var border := Color("d75b49") if _count <= 0 else Color("c8872e") if _count <= low_threshold else Color("4d9875")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.085, 0.08, 0.94)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	add_theme_stylebox_override(&"normal", style)
	add_theme_color_override(&"font_color", foreground)
