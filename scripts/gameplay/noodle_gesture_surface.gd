class_name NoodleGestureSurface
extends Control

signal stroke_completed(distance: float, duration: float)

const DOUGH_RECT := Rect2(105.0, 225.0, 390.0, 235.0)
const POT_CENTER := Vector2(820.0, 285.0)
const POT_RADIUS := Vector2(215.0, 155.0)

var production_snapshot: Dictionary = {}
var _dragging := false
var _started_usec := 0
var _points := PackedVector2Array()
var _steam_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	queue_redraw()


func _process(delta: float) -> void:
	_steam_time += maxf(delta, 0.0)
	queue_redraw()


func set_production_snapshot(value: Dictionary) -> void:
	production_snapshot = value.duplicate(true)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if DOUGH_RECT.has_point(event.position):
				_dragging = true
				_started_usec = Time.get_ticks_usec()
				_points = PackedVector2Array([event.position])
				accept_event()
		else:
			if not _dragging:
				return
			_points.append(event.position)
			var duration := maxf(float(Time.get_ticks_usec() - _started_usec) / 1000000.0, 0.001)
			var distance := _path_distance(_points)
			var ended_in_pot := _inside_pot(event.position)
			_dragging = false
			if ended_in_pot:
				stroke_completed.emit(distance, duration)
			_points.clear()
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_points.append(event.position)
		if _points.size() > 40:
			_points.remove_at(1)
		queue_redraw()
		accept_event()


func _draw() -> void:
	_draw_tile_wall()
	_draw_counter()
	_draw_dough()
	_draw_pot()
	_draw_batches()
	_draw_steam()
	if _points.size() >= 2:
		draw_polyline(_points, Color(1.0, 0.82, 0.42, 0.95), 8.0, true)
		draw_circle(_points[_points.size() - 1], 11.0, Color(1.0, 0.94, 0.68, 1.0))


func _draw_tile_wall() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#183b42"))
	for x in range(0, ceili(size.x), 64):
		draw_line(Vector2(x, 0), Vector2(x, 165), Color(0.23, 0.42, 0.44, 0.45), 2.0)
	for y in range(0, 166, 42):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.23, 0.42, 0.44, 0.45), 2.0)


func _draw_counter() -> void:
	draw_rect(Rect2(0, 165, size.x, size.y - 165), Color("#8e4d32"))
	draw_rect(Rect2(0, 175, size.x, size.y - 185), Color("#b86b43"))
	for y in range(210, ceili(size.y), 55):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.29, 0.12, 0.07, 0.22), 3.0)


func _draw_dough() -> void:
	draw_style_box(_rounded_box(Color("#6f3425"), Color("#e5b05f"), 5.0, 24.0), DOUGH_RECT)
	var dough := Rect2(DOUGH_RECT.position + Vector2(42, 38), DOUGH_RECT.size - Vector2(84, 76))
	draw_style_box(_rounded_box(Color("#f4dba0"), Color("#fff0bf"), 3.0, 52.0), dough)
	for index in 5:
		var y := dough.position.y + 30.0 + index * 25.0
		draw_arc(Vector2(dough.end.x - 25.0, y), 34.0, PI * 0.74, PI * 1.25, 16, Color(0.75, 0.52, 0.28, 0.65), 4.0)
	draw_string(ThemeDB.fallback_font, DOUGH_RECT.position + Vector2(100, -18), "从面团划向锅口", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#fff0c2"))


func _draw_pot() -> void:
	draw_set_transform(POT_CENTER, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, POT_RADIUS.x + 22.0, Color("#322c2b"))
	draw_circle(Vector2.ZERO, POT_RADIUS.x + 11.0, Color("#d8b56e"))
	draw_circle(Vector2.ZERO, POT_RADIUS.x - 2.0, Color("#365e66"))
	draw_circle(Vector2.ZERO, POT_RADIUS.x - 15.0, Color("#73b5b8"))
	for index in 7:
		var phase := _steam_time * 1.8 + float(index)
		var p := Vector2(cos(phase * 1.7) * 135.0, sin(phase * 1.2) * 80.0)
		draw_circle(p, 6.0 + fmod(float(index) * 2.0, 7.0), Color(0.86, 0.97, 0.94, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, POT_CENTER + Vector2(-78, -228), "沸水面篮", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#fff0c2"))


func _draw_batches() -> void:
	var batches := Array(production_snapshot.get("batches", []))
	for index in range(batches.size()):
		var batch := Dictionary(batches[index])
		var thickness := StringName(batch.get("thickness_id", &"standard"))
		var width := 4.0 if thickness == &"thin" else 7.0 if thickness == &"standard" else 11.0
		var angle := -1.9 + float(index) * 0.56
		var origin := POT_CENTER + Vector2(cos(angle) * 95.0, sin(angle) * 62.0)
		var points := PackedVector2Array()
		for point_index in 8:
			points.append(origin + Vector2(point_index * 12.0 - 42.0, sin(float(point_index) * 1.4 + angle) * 17.0))
		draw_polyline(points, Color("#f4d88d"), width, true)


func _draw_steam() -> void:
	for index in 4:
		var phase := fmod(_steam_time * 0.28 + float(index) * 0.24, 1.0)
		var center := POT_CENTER + Vector2(-105.0 + index * 70.0 + sin(_steam_time + index) * 12.0, -125.0 - phase * 115.0)
		draw_arc(center, 22.0 + phase * 15.0, -PI * 0.1, PI * 1.1, 20, Color(0.92, 0.98, 0.94, 0.48 * (1.0 - phase)), 7.0)


func _inside_pot(point: Vector2) -> bool:
	var normalized := (point - POT_CENTER) / POT_RADIUS
	return normalized.length_squared() <= 1.0


static func _path_distance(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	return total


static func _rounded_box(fill: Color, border: Color, border_width: float, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(roundi(border_width))
	box.set_corner_radius_all(roundi(radius))
	return box

