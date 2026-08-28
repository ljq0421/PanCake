class_name OrderItemDropButton
extends Button

signal product_source_dropped(item_index: int, source_ref: Dictionary)

@export_range(0, 2, 1) var item_index := 0

var _selection_highlight := false


func _ready() -> void:
	# The product image is the delivery target. Give that target a restrained,
	# local response without turning the whole customer card into a selected tile.
	flat = false
	focus_mode = Control.FOCUS_ALL
	_refresh_target_styles()



func set_selection_highlight(value: bool) -> void:
	if _selection_highlight == value:
		return
	_selection_highlight = value
	if is_node_ready():
		_refresh_target_styles()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if disabled or not data is Dictionary:
		return false
	var payload := Dictionary(data)
	return StringName(payload.get("kind", &"")) == &"product_source" and not Dictionary(payload.get("source_ref", {})).is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	product_source_dropped.emit(item_index, Dictionary(Dictionary(data).get("source_ref", {})).duplicate(true))


func _refresh_target_styles() -> void:
	var selected_fill := Color(1.0, 0.76, 0.18, 0.20) if _selection_highlight else Color.TRANSPARENT
	var selected_border := Color("ffe17a") if _selection_highlight else Color.TRANSPARENT
	var selected_width := 4 if _selection_highlight else 0
	add_theme_stylebox_override(&"normal", _target_style(selected_fill, selected_border, selected_width))
	add_theme_stylebox_override(&"hover", _target_style(Color(1.0, 0.82, 0.32, 0.28) if _selection_highlight else Color(1.0, 0.82, 0.32, 0.16), Color("ffe17a") if _selection_highlight else Color("edae35"), 4 if _selection_highlight else 3))
	add_theme_stylebox_override(&"pressed", _target_style(Color(0.95, 0.62, 0.16, 0.34) if _selection_highlight else Color(0.95, 0.62, 0.16, 0.24), Color("ffe17a") if _selection_highlight else Color("c97924"), 4 if _selection_highlight else 3))
	add_theme_stylebox_override(&"focus", _target_style(selected_fill, Color("ffe17a") if _selection_highlight else Color("ffd166"), 4 if _selection_highlight else 3))
	add_theme_stylebox_override(&"disabled", _target_style(Color(0.32, 0.22, 0.12, 0.05), Color.TRANSPARENT, 0))


func _target_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	style.expand_margin_left = 3.0
	style.expand_margin_top = 3.0
	style.expand_margin_right = 3.0
	style.expand_margin_bottom = 3.0
	return style
