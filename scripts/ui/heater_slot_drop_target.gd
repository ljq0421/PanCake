class_name HeaterSlotDropTarget
extends Control

signal load_completed(result: Dictionary)

@export var slot_index := 0


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or StringName(Dictionary(data).get("kind", &"")) != &"product_source":
		return false
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	return StringName(source_ref.get("source_kind", &"")) == &"inventory"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("load_f3_drink"):
		load_completed.emit({"success": false, "reason": &"no_game_session"})
		return
	var result: Dictionary = session.call("load_f3_drink", slot_index, StringName(source_ref.get("product_id", &"")))
	load_completed.emit(result)

