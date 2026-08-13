class_name StagedProductDropTarget
extends Control

signal disposition_completed(result: Dictionary)

@export_enum("return_stock", "waste") var disposition := "waste"


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
		disposition_completed.emit(Dictionary(session.call("discard_product_source", Dictionary(payload.get("source_ref", {})))))
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
