class_name ModalOutsideInputShield
extends Control

@export var excluded_control_path: NodePath


func _has_point(point: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	var excluded := get_node_or_null(excluded_control_path) as Control
	if excluded == null or not excluded.visible:
		return true
	var canvas_point := get_global_transform_with_canvas() * point
	return not excluded.get_global_rect().has_point(canvas_point)
