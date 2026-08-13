class_name OrderItemDropButton
extends Button

signal product_source_dropped(item_index: int, source_ref: Dictionary)

@export_range(0, 2, 1) var item_index := 0


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if disabled or not data is Dictionary:
		return false
	var payload := Dictionary(data)
	return StringName(payload.get("kind", &"")) == &"product_source" and not Dictionary(payload.get("source_ref", {})).is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	product_source_dropped.emit(item_index, Dictionary(Dictionary(data).get("source_ref", {})).duplicate(true))
