class_name TrayHandoffDragHandle
extends Button

@export var drag_threshold_pixels := 10.0

var _order_id: StringName = &""
var _press_position := Vector2.ZERO
var _pressed_for_drag := false


func configure(order_id: StringName) -> void:
	_order_id = order_id
	disabled = order_id.is_empty()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed_for_drag = true
			_press_position = event.position
		else:
			_pressed_for_drag = false
	elif event is InputEventMouseMotion and _pressed_for_drag and event.position.distance_to(_press_position) > drag_threshold_pixels:
		_pressed_for_drag = false
		var preview := Label.new()
		preview.text = "递餐托盘"
		preview.add_theme_font_size_override("font_size", 22)
		preview.add_theme_color_override("font_color", Color("fff2cf"))
		force_drag({"kind": &"order_tray", "order_id": _order_id}, preview)
		accept_event()

