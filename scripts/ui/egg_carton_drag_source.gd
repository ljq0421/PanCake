class_name EggCartonDragSource
extends ProductDragSource

## The order matches the inventory artwork: left to right, then top to bottom.
const SLOT_CENTERS := [
	Vector2(0.25, 0.348), Vector2(0.50, 0.348), Vector2(0.75, 0.348),
	Vector2(0.25, 0.504), Vector2(0.50, 0.504), Vector2(0.75, 0.504),
]

var _filled_slot_count := 0
var _pressed_slot_index := -1


func set_filled_slot_count(value: int) -> void:
	_filled_slot_count = clampi(value, 0, SLOT_CENTERS.size())


func _has_point(point: Vector2) -> bool:
	# The whole *visible* carton remains a long-press restock target.
	# _slot_index_at() still gates dragging, so a blank slot can never consume
	# an arbitrary egg.
	return super._has_point(point)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pressed_slot_index = _slot_index_at(event.position)
		if _pressed_slot_index >= 0:
			_source_ref["carton_slot_index"] = _pressed_slot_index
		else:
			_source_ref.erase("carton_slot_index")
	super._gui_input(event)


func update_gesture(viewport_position: Vector2, perform_native_drag: bool = true) -> void:
	# Starting a drag from a blank part of a partially filled carton must not
	# silently consume an arbitrary egg. It may still become a hold-to-restock.
	if _drag_available and _pressed_slot_index < 0:
		return
	super.update_gesture(viewport_position, perform_native_drag)


func end_gesture() -> void:
	super.end_gesture()
	_pressed_slot_index = -1


func _slot_index_at(point: Vector2) -> int:
	if size.x <= 0.0 or size.y <= 0.0:
		return -1
	var radius := Vector2(size.x * 0.105, size.y * 0.135)
	for index in _filled_slot_count:
		var center: Vector2 = Vector2(SLOT_CENTERS[index]) * size
		var distance: Vector2 = (point - center) / radius
		if distance.length_squared() <= 1.0:
			return index
	return -1
