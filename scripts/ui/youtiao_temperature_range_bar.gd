class_name YoutiaoTemperatureRangeBar
extends Control

var _state: StringName = &"idle"
var _progress := 0.0
var _quality := 100.0


func apply_snapshot(snapshot: Dictionary, enabled: bool) -> void:
	visible = enabled
	_state = StringName(snapshot.get("state", &"idle"))
	_quality = clampf(float(snapshot.get("quality", 100.0)), 0.0, 100.0)
	var tier := clampi(int(snapshot.get("tier", 0)), 0, 2)
	var duration: float = [12.0, 9.0, 9.0][tier]
	var cooking := maxf(float(snapshot.get("cooking_elapsed_seconds", 0.0)), 0.0)
	var completed := maxf(float(snapshot.get("completed_elapsed_seconds", 0.0)), 0.0)
	match _state:
		&"loaded":
			_progress = 0.08
		&"frying":
			_progress = lerpf(0.08, 0.58, clampf(cooking / maxf(duration, 0.001), 0.0, 1.0))
		&"ready_safe", &"draining", &"ready_to_collect":
			_progress = 0.64
		&"overcooking":
			_progress = lerpf(0.70, 0.94, clampf(completed / 15.0, 0.0, 1.0))
		&"burnt":
			_progress = 0.98
		_:
			_progress = 0.03
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var bar := Rect2(1.0, 3.0, maxf(size.x - 2.0, 1.0), maxf(size.y - 6.0, 1.0))
	draw_style_box(_segment_style(Color("6eaa78")), Rect2(bar.position, Vector2(bar.size.x * 0.38, bar.size.y)))
	draw_style_box(_segment_style(Color("e9b44f")), Rect2(bar.position + Vector2(bar.size.x * 0.38, 0.0), Vector2(bar.size.x * 0.30, bar.size.y)))
	draw_style_box(_segment_style(Color("dc5a3e")), Rect2(bar.position + Vector2(bar.size.x * 0.68, 0.0), Vector2(bar.size.x * 0.32, bar.size.y)))
	var marker_x := bar.position.x + bar.size.x * clampf(_progress, 0.0, 1.0)
	var marker_color := Color("5a2d16") if _state != &"burnt" else Color("2b160f")
	draw_circle(Vector2(marker_x, size.y * 0.5), 4.0, Color("fff2cf"))
	draw_circle(Vector2(marker_x, size.y * 0.5), 2.2, marker_color)


static func _segment_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
