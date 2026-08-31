class_name NoodleGestureSurface
extends Control

signal stroke_completed(distance: float, duration: float)

const CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")
const DOUGH_RECT := Rect2(105.0, 225.0, 390.0, 235.0)
const POT_CENTER := Vector2(820.0, 285.0)
const POT_RADIUS := Vector2(215.0, 155.0)

@export var dough_texture: Texture2D
@export var pot_texture: Texture2D
@export var basket_texture: Texture2D
@export var batch_texture: Texture2D
@export var knife_texture: Texture2D
@export var drain_texture: Texture2D
@export var clear_bowl_texture: Texture2D
@export var tomato_bowl_texture: Texture2D
@export var zhajiang_bowl_texture: Texture2D

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
	if _has_formal_art():
		_draw_formal_worktop()
	else:
		_draw_tile_wall()
		_draw_counter()
		_draw_dough()
		_draw_pot()
		_draw_batches()
	_draw_steam()
	if _points.size() >= 2:
		draw_polyline(_points, Color(1.0, 0.82, 0.42, 0.95), 8.0, true)
		draw_circle(_points[_points.size() - 1], 11.0, Color(1.0, 0.94, 0.68, 1.0))
		if knife_texture != null:
			draw_texture_rect(knife_texture, Rect2(_points[-1] - Vector2(100, 68), Vector2(200, 133)), false)


func has_formal_art() -> bool:
	return _has_formal_art() and knife_texture != null and drain_texture != null and clear_bowl_texture != null and tomato_bowl_texture != null and zhajiang_bowl_texture != null


func qualitative_doneness() -> String:
	var batches := Array(production_snapshot.get("batches", []))
	var state := StringName(production_snapshot.get("state", &"idle"))
	if state == &"idle":
		return "等待开火"
	if state == &"bowled":
		return "已经入碗"
	if batches.is_empty():
		return "等待下锅"
	var has_under := false
	var has_ready := false
	var has_over := false
	var under_progress := 0.0
	var overrun := 0.0
	for value in batches:
		var batch := Dictionary(value)
		var window := CATALOG.cook_window(StringName(batch.get("thickness_id", &"standard")), bool(production_snapshot.get("stable_basket", false)))
		var cooked := float(batch.get("cook_seconds", 0.0))
		if cooked < window.x:
			has_under = true
			under_progress += cooked / maxf(window.x, 0.001)
		elif cooked <= window.y:
			has_ready = true
		else:
			has_over = true
			overrun += cooked - window.y
	var category_count := int(has_under) + int(has_ready) + int(has_over)
	if category_count > 1:
		return "熟度不一"
	if has_over:
		return "将要过火" if overrun / float(batches.size()) <= 1.0 else "已经过火"
	if has_ready:
		return "火候正好"
	return "刚刚下锅" if under_progress / float(batches.size()) < 0.45 else "渐渐熟了"


func _has_formal_art() -> bool:
	return dough_texture != null and pot_texture != null and basket_texture != null and batch_texture != null


func _draw_formal_worktop() -> void:
	var state := StringName(production_snapshot.get("state", &"idle"))
	draw_texture_rect(dough_texture, Rect2(-20, 110, 600, 338), false)
	draw_texture_rect(pot_texture, Rect2(480, 5, 680, 510), false)
	if state in [&"shaving", &"cooking", &"lifted"]:
		_draw_formal_batches()
		var basket_rect := Rect2(540, 20, 600, 450)
		if state == &"lifted":
			basket_rect.position += Vector2(0, -70)
		draw_texture_rect(basket_texture, basket_rect, false)
		if state == &"lifted" and drain_texture != null:
			draw_texture_rect(drain_texture, Rect2(720, 270, 145, 218), false)
	elif state == &"bowled":
		var bowl := _product_texture()
		if bowl != null:
			draw_texture_rect(bowl, Rect2(620, 90, 430, 430), false)
	_draw_doneness_badge()
	draw_string(ThemeDB.fallback_font, DOUGH_RECT.position + Vector2(74, -22), "从面团划向锅口", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#5a301d"))


func _draw_formal_batches() -> void:
	var batches := Array(production_snapshot.get("batches", []))
	var placements := [
		Vector2(700, 218), Vector2(786, 190), Vector2(870, 218),
		Vector2(730, 275), Vector2(820, 260), Vector2(900, 278),
	]
	for index in mini(batches.size(), placements.size()):
		var batch := Dictionary(batches[index])
		var thickness := StringName(batch.get("thickness_id", &"standard"))
		var scale := 0.82 if thickness == &"thin" else 1.0 if thickness == &"standard" else 1.16
		var batch_size := Vector2(118, 79) * scale
		draw_texture_rect(batch_texture, Rect2(placements[index] - batch_size * 0.5, batch_size), false)


func _draw_doneness_badge() -> void:
	var label := qualitative_doneness()
	var fill := Color("#24494a")
	var border := Color("#e8b65e")
	if label == "火候正好":
		fill = Color("#276347")
		border = Color("#96dda7")
	elif label in ["熟度不一", "将要过火"]:
		fill = Color("#75461f")
		border = Color("#ffd273")
	elif label == "已经过火":
		fill = Color("#6f2c28")
		border = Color("#ff9587")
	var rect := Rect2(662, 18, 316, 54)
	draw_style_box(_rounded_box(fill, border, 3.0, 18.0), rect)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(24, 36), "面篮状态 · %s" % label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 48, 22, Color("#fff4d6"))


func _product_texture() -> Texture2D:
	var recipe_id := StringName(production_snapshot.get("recipe_id", CATALOG.RECIPE_CLEAR))
	var product_id := StringName(CATALOG.recipe(recipe_id).get("product_id", CATALOG.PRODUCT_CLEAR))
	return {
		CATALOG.PRODUCT_CLEAR: clear_bowl_texture,
		CATALOG.PRODUCT_TOMATO: tomato_bowl_texture,
		CATALOG.PRODUCT_ZHAJIANG: zhajiang_bowl_texture,
	}.get(product_id, clear_bowl_texture)


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
