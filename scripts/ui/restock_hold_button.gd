class_name RestockHoldButton
extends Button

signal restock_feedback(result: Dictionary)

@export var effective_hit_size := Vector2(66.0, 66.0)

var _stock_id: StringName = &""
var _held := false


func _ready() -> void:
	button_down.connect(func(): _held = true)
	button_up.connect(func(): _held = false)
	mouse_exited.connect(func(): _held = false)


func configure(stock_id: StringName, enabled: bool, hint: String) -> void:
	_stock_id = stock_id
	disabled = not enabled
	tooltip_text = hint
	if disabled:
		_held = false


func _has_point(point: Vector2) -> bool:
	var hit_size := Vector2(maxf(size.x, effective_hit_size.x), maxf(size.y, effective_hit_size.y))
	var hit_position := (size - hit_size) * 0.5
	return Rect2(hit_position, hit_size).has_point(point)


func _process(delta: float) -> void:
	if not _held or _stock_id.is_empty():
		return
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("advance_five_area_restock_hold"):
		return
	var result: Dictionary = session.call("advance_five_area_restock_hold", _stock_id, delta)
	if int(result.get("completed_units", 0)) > 0 or not bool(result.get("success", false)):
		restock_feedback.emit(result)
	if bool(result.get("auto_stopped", false)):
		_held = false
