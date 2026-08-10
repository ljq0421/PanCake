class_name TrayCustomerDropTarget
extends Control

signal tray_dropped(order_id: StringName)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and StringName(Dictionary(data).get("kind", &"")) == &"order_tray"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	tray_dropped.emit(StringName(Dictionary(data).get("order_id", &"")))

