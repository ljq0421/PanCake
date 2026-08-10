class_name SteamerLayerDropTarget
extends Control

signal layer_feedback(result: Dictionary)

@export var layer_index := 0


func _ready() -> void:
	var start_button := get_node_or_null("StartButton") as Button
	if start_button != null:
		start_button.pressed.connect(_start_layer)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and StringName(Dictionary(data).get("kind", &"")) == &"product_source" and StringName(Dictionary(Dictionary(data).get("source_ref", {})).get("source_kind", &"")) == &"steamer_input"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("load_f4_steamer_layer", layer_index, StringName(source_ref.get("recipe_id", &"")), 1) if session != null else {"success": false, "reason": &"no_game_session"}
	layer_feedback.emit(result)


func _start_layer() -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("perform_f4_steamer_action", layer_index, &"start") if session != null else {"success": false, "reason": &"no_game_session"}
	layer_feedback.emit(result)

