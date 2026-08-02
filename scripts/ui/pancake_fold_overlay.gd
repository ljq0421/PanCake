class_name PancakeFoldOverlay
extends Control

const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")

var fold_model: RefCounted
var guides_visible := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_fold_model(value: RefCounted) -> void:
	if fold_model != null and fold_model.changed.is_connected(_on_fold_changed):
		fold_model.changed.disconnect(_on_fold_changed)
	fold_model = value
	if fold_model != null:
		fold_model.changed.connect(_on_fold_changed)
	queue_redraw()


func set_guides_visible(value: bool) -> void:
	guides_visible = value
	queue_redraw()


func _on_fold_changed() -> void:
	queue_redraw()


func _draw() -> void:
	if fold_model == null or fold_model.pancake_model == null:
		return
	if guides_visible and fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_NONE:
		_draw_guides()
	_draw_region(FOLD_MODEL_SCRIPT.REGION_LEFT)
	_draw_region(FOLD_MODEL_SCRIPT.REGION_RIGHT)
	if fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE:
		_draw_package()


func _draw_guides() -> void:
	var left_x: float = size.x * float(fold_model.pancake_model.parameters.fold_left_line_ratio)
	var right_x: float = size.x * float(fold_model.pancake_model.parameters.fold_right_line_ratio)
	var geometry := _pancake_geometry()
	var left_span := _guide_span(left_x, geometry)
	var right_span := _guide_span(right_x, geometry)
	var guide_color := Color(0.98, 0.91, 0.42, 0.90)
	_draw_dashed_line(Vector2(left_x, left_span.x), Vector2(left_x, left_span.y), guide_color)
	_draw_dashed_line(Vector2(right_x, right_span.x), Vector2(right_x, right_span.y), guide_color)
	var center: Vector2 = geometry.center
	var radii: Vector2 = geometry.radii
	if not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT):
		draw_arc(center - Vector2(radii.x * 0.92, 0.0), size.x * 0.040, -1.2, 1.2, 20, Color(0.45, 0.94, 0.94, 0.95), 5.0, true)
	if not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT):
		draw_arc(center + Vector2(radii.x * 0.92, 0.0), size.x * 0.040, PI - 1.2, PI + 1.2, 20, Color(0.45, 0.94, 0.94, 0.95), 5.0, true)


func _draw_region(region: StringName) -> void:
	var folded: bool = fold_model.is_region_folded(region)
	var active: bool = fold_model.active_region == region
	if not folded and not active:
		return
	var progress: float = 1.0 if folded else float(fold_model.drag_progress)
	var source_polygon := _segment_polygon(region)
	if progress > 0.01:
		draw_colored_polygon(source_polygon, Color(0.055, 0.060, 0.066, 0.98))
	var flap_polygon := _transform_polygon(source_polygon, region, progress)
	var result: Dictionary = fold_model.get_region_result(region)
	var severity := int(result.get("severity", 0)) if folded else 0
	var flap_color := Color(0.93, 0.62, 0.23, 0.96)
	if severity == 1:
		flap_color = Color(0.80, 0.39, 0.12, 0.98)
	elif severity >= 2:
		flap_color = Color(0.55, 0.16, 0.10, 0.98)
	draw_colored_polygon(flap_polygon, flap_color)
	draw_polyline(_closed(flap_polygon), Color(0.18, 0.09, 0.045, 0.98), 6.0, true)
	if folded and severity > 0:
		_draw_cracks(flap_polygon, severity)


func _segment_polygon(region: StringName) -> PackedVector2Array:
	var geometry := _pancake_geometry()
	var center: Vector2 = geometry.center
	var radii: Vector2 = geometry.radii
	var line_ratio: float = fold_model.pancake_model.parameters.fold_left_line_ratio if region == FOLD_MODEL_SCRIPT.REGION_LEFT else fold_model.pancake_model.parameters.fold_right_line_ratio
	var line_x := size.x * line_ratio
	var dx := clampf((line_x - center.x) / maxf(radii.x, 0.001), -0.999, 0.999)
	var base_angle := acos(dx)
	var points := PackedVector2Array()
	var steps := 18
	if region == FOLD_MODEL_SCRIPT.REGION_LEFT:
		var top_angle := TAU - base_angle
		for step in range(steps + 1):
			var angle := lerpf(top_angle, base_angle, float(step) / float(steps))
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	else:
		var top_angle := TAU - base_angle
		for step in range(steps + 1):
			var angle := lerpf(top_angle, TAU + base_angle, float(step) / float(steps))
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _pancake_geometry() -> Dictionary:
	var model = fold_model.pancake_model
	var minimum := Vector2i(model.grid_size, model.grid_size)
	var maximum := Vector2i(-1, -1)
	for y in model.grid_size:
		for x in model.grid_size:
			var index: int = y * int(model.grid_size) + x
			if model.coverage[index] <= 0.0 and model.damage[index] < model.parameters.hole_damage_threshold:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x:
		return {
			"center": size * 0.5,
			"radii": Vector2(size.x * 0.36, size.y * 0.36 * model.parameters.pan_height_ratio),
		}
	var grid_extent := Vector2(maximum - minimum + Vector2i.ONE)
	var center_grid := Vector2(minimum + maximum) * 0.5 + Vector2(0.5, 0.5)
	var center_local := Vector2(center_grid.x / float(model.grid_size) * size.x, center_grid.y / float(model.grid_size) * size.y)
	var radii_local := Vector2(
		grid_extent.x / float(model.grid_size) * size.x,
		grid_extent.y / float(model.grid_size) * size.y
	) * 0.5
	return {"center": center_local, "radii": radii_local}


func _transform_polygon(source: PackedVector2Array, region: StringName, progress: float) -> PackedVector2Array:
	var line_ratio: float = fold_model.pancake_model.parameters.fold_left_line_ratio if region == FOLD_MODEL_SCRIPT.REGION_LEFT else fold_model.pancake_model.parameters.fold_right_line_ratio
	var line_x := size.x * line_ratio
	var squash := 1.0 - sin(progress * PI) * 0.18
	var fold_center: Vector2 = _pancake_geometry().center
	var transformed := PackedVector2Array()
	for point in source:
		var reflected_x := 2.0 * line_x - point.x
		var moved_x := lerpf(point.x, reflected_x, progress)
		var moved_y := fold_center.y + (point.y - fold_center.y) * squash
		transformed.append(Vector2(moved_x, moved_y))
	return transformed


func _guide_span(line_x: float, geometry: Dictionary) -> Vector2:
	var center: Vector2 = geometry.center
	var radii: Vector2 = geometry.radii
	var normalized_x := clampf((line_x - center.x) / maxf(radii.x, 0.001), -1.0, 1.0)
	var half_height := radii.y * sqrt(maxf(1.0 - normalized_x * normalized_x, 0.0))
	return Vector2(center.y - half_height, center.y + half_height)


func _draw_cracks(polygon: PackedVector2Array, severity: int) -> void:
	if polygon.is_empty():
		return
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	var crack_color := Color(0.12, 0.035, 0.025, 0.98)
	var center := bounds.get_center()
	draw_polyline(PackedVector2Array([
		Vector2(bounds.position.x + bounds.size.x * 0.18, center.y - 38.0),
		Vector2(center.x - 12.0, center.y - 10.0),
		Vector2(center.x + 8.0, center.y + 16.0),
		Vector2(bounds.end.x - bounds.size.x * 0.16, center.y + 42.0),
	]), crack_color, 5.0, true)
	if severity >= 2:
		draw_polyline(PackedVector2Array([
			Vector2(center.x - 24.0, bounds.position.y + bounds.size.y * 0.22),
			Vector2(center.x + 14.0, center.y - 4.0),
			Vector2(center.x - 18.0, bounds.end.y - bounds.size.y * 0.20),
		]), crack_color, 7.0, true)


func _draw_package() -> void:
	var color := Color(0.86, 0.76, 0.55, 0.88) if fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_SLEEVE else Color(0.72, 0.74, 0.76, 0.88)
	var rect := Rect2(size.x * 0.31, size.y * 0.18, size.x * 0.38, size.y * 0.64)
	draw_rect(rect, color, true)
	draw_rect(rect, Color(0.20, 0.17, 0.13, 0.95), false, 8.0)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var length := from.distance_to(to)
	var direction := from.direction_to(to)
	var cursor := 0.0
	while cursor < length:
		var segment_end := minf(cursor + 14.0, length)
		draw_line(from + direction * cursor, from + direction * segment_end, color, 4.0, true)
		cursor += 25.0


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
