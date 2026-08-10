class_name StagedProductDropTarget
extends Control

signal disposition_completed(result: Dictionary)

@export_enum("return_stock", "waste") var disposition := "waste"


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and StringName(Dictionary(data).get("kind", &"")) == &"staged_product"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var payload := Dictionary(data)
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("remove_staged_product"):
		disposition_completed.emit({"success": false, "reason": &"no_game_session"})
		return
	var result: Dictionary = session.call(
		"remove_staged_product",
		StringName(payload.get("order_id", &"")),
		int(payload.get("item_index", -1)),
		StringName(disposition),
	)
	disposition_completed.emit(result)

