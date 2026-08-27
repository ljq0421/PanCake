class_name TutorialGuideArrow
extends Control

const FILL_COLOR := Color("f4a92e")
const OUTLINE_COLOR := Color("6d310b")
const SHADOW_COLOR := Color(0.24, 0.10, 0.02, 0.28)

var _direction := Vector2.DOWN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	_direction = direction.normalized()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var tangent := Vector2(-_direction.y, _direction.x)
	var tip := center + _direction * 9.0
	var base_center := center - _direction * 7.0
	var points := PackedVector2Array([
		base_center + tangent * 7.5,
		tip,
		base_center - tangent * 7.5,
	])
	var shadow_points := PackedVector2Array()
	for point in points:
		shadow_points.append(point + Vector2(0.0, 2.0))
	draw_colored_polygon(shadow_points, SHADOW_COLOR)
	draw_colored_polygon(points, FILL_COLOR)
	var outline := PackedVector2Array([points[0], points[1], points[2], points[0]])
	draw_polyline(outline, OUTLINE_COLOR, 2.5, true)
