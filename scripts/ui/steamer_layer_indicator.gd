class_name SteamerLayerIndicator
extends Control

var state: StringName = &"empty"
var progress_value := 0.0


func set_visual(next_state: StringName, next_progress: float) -> void:
	state = next_state
	progress_value = clampf(next_progress, 0.0, 100.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(minf(size.x, size.y) * 0.5 - 3.0, 1.0)
	var color := _state_color()
	draw_arc(center, radius, 0.0, TAU, 32, Color(0.12, 0.10, 0.08, 0.72), 3.0, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress_value / 100.0, 32, color, 3.0, true)
	draw_circle(Vector2(size.x - 4.5, 4.5), 4.0, Color(0.08, 0.07, 0.06, 0.85))
	draw_circle(Vector2(size.x - 4.5, 4.5), 2.7, color)


func _state_color() -> Color:
	match state:
		&"steaming":
			return Color("8ed6eb")
		&"ready_safe":
			return Color("8bd17c")
		&"overcooking":
			return Color("ff9f43")
	return Color("79736d")
