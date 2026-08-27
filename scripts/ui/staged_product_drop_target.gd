class_name StagedProductDropTarget
extends Control

signal disposition_completed(result: Dictionary)
signal product_source_discarded(source_ref: Dictionary)
signal active_griddle_clear_requested()

@export_enum("return_stock", "waste") var disposition := "waste"
@export var clear_active_griddle_hold_seconds := 0.6

var _clear_hold_active := false
var _clear_hold_elapsed := 0.0
var _clear_hint: Label


func _ready() -> void:
	_clear_hint = get_node_or_null("Hint") as Label
	if _clear_hint != null:
		_clear_hint.visible = false
	mouse_entered.connect(_show_idle_hint)
	mouse_exited.connect(_on_mouse_exited)
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_clear_hold_active = true
		_clear_hold_elapsed = 0.0
		_set_clear_hint("长按清空鏊面")
		set_process(true)
		accept_event()
		return
	_clear_hold_active = false
	_clear_hold_elapsed = 0.0
	_set_clear_hint("拖入报废\n长按清空鏊面")
	set_process(false)
	accept_event()


func _process(delta: float) -> void:
	if not _clear_hold_active:
		set_process(false)
		return
	_clear_hold_elapsed += maxf(delta, 0.0)
	var progress := clampf(_clear_hold_elapsed / maxf(clear_active_griddle_hold_seconds, 0.01), 0.0, 1.0)
	_set_clear_hint("清空鏊面 %d%%" % roundi(progress * 100.0))
	if progress < 1.0:
		return
	_clear_hold_active = false
	_clear_hold_elapsed = 0.0
	_set_clear_hint("已清空鏊面")
	set_process(false)
	active_griddle_clear_requested.emit()


func _set_clear_hint(value: String) -> void:
	if _clear_hint != null:
		_clear_hint.text = value
		_clear_hint.visible = true


func _show_idle_hint() -> void:
	_set_clear_hint("拖入报废\n长按清空鏊面")


func _on_mouse_exited() -> void:
	_cancel_clear_hold()
	if _clear_hint != null:
		_clear_hint.visible = false


func _cancel_clear_hold() -> void:
	if not _clear_hold_active:
		return
	_clear_hold_active = false
	_clear_hold_elapsed = 0.0
	_set_clear_hint("拖入报废\n长按清空鏊面")
	set_process(false)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var payload := Dictionary(data)
	var kind := StringName(payload.get("kind", &""))
	if kind == &"staged_product":
		return true
	return disposition == "waste" and kind == &"product_source" and bool(Dictionary(payload.get("source_ref", {})).get("discardable", false))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var payload := Dictionary(data)
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		disposition_completed.emit({"success": false, "reason": &"no_game_session"})
		return
	if StringName(payload.get("kind", &"")) == &"product_source":
		if not session.has_method("discard_product_source"):
			disposition_completed.emit({"success": false, "reason": &"discard_source_unavailable"})
			return
		var source_ref := Dictionary(payload.get("source_ref", {}))
		var result := Dictionary(session.call("discard_product_source", source_ref))
		disposition_completed.emit(result)
		if bool(result.get("success", false)):
			product_source_discarded.emit(source_ref)
		return
	if not session.has_method("remove_staged_product"):
		disposition_completed.emit({"success": false, "reason": &"staged_disposition_unavailable"})
		return
	var result: Dictionary = session.call(
		"remove_staged_product",
		StringName(payload.get("order_id", &"")),
		int(payload.get("item_index", -1)),
		StringName(disposition),
	)
	disposition_completed.emit(result)
