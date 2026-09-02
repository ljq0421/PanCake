class_name WorkbenchZoneBackdrop
extends Control

const ZONE_ORDER: Array[StringName] = [
	&"area.youtiao",
	&"area.pancake",
	&"area.ingredients",
	&"area.drinks",
]
const ZONE_RECTS := {
	&"area.youtiao": Rect2(28.0, 646.0, 438.0, 414.0),
	&"area.pancake": Rect2(482.0, 646.0, 466.0, 414.0),
	&"area.ingredients": Rect2(964.0, 646.0, 606.0, 414.0),
	&"area.drinks": Rect2(1586.0, 646.0, 306.0, 414.0),
}
const ZONE_LABELS := {
	&"area.youtiao": "炸制区",
	&"area.pancake": "鏊台区",
	&"area.ingredients": "配料与出餐区",
	&"area.drinks": "饮品区",
}
const TABLE_VANISH_X := 960.0
const FAR_EDGE_SCALE := 0.88

var _active_zone_id: StringName = &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_active_area(area_id: StringName) -> void:
	var zone_id := _zone_for_area(area_id)
	if _active_zone_id == zone_id:
		return
	_active_zone_id = zone_id
	queue_redraw()


func active_zone_id() -> StringName:
	return _active_zone_id


func zone_rect(zone_id: StringName) -> Rect2:
	return Rect2(ZONE_RECTS.get(zone_id, Rect2()))


func zone_polygon(zone_id: StringName) -> PackedVector2Array:
	var rect := zone_rect(zone_id)
	if rect.size == Vector2.ZERO:
		return PackedVector2Array()
	var bottom_left := rect.position + Vector2(0.0, rect.size.y)
	var bottom_right := rect.end
	var top_left_x := TABLE_VANISH_X + (rect.position.x - TABLE_VANISH_X) * FAR_EDGE_SCALE
	var top_right_x := TABLE_VANISH_X + (rect.end.x - TABLE_VANISH_X) * FAR_EDGE_SCALE
	return PackedVector2Array([
		Vector2(top_left_x, rect.position.y),
		Vector2(top_right_x, rect.position.y),
		bottom_right,
		bottom_left,
	])


func _draw() -> void:
	for zone_id in ZONE_ORDER:
		var points := zone_polygon(zone_id)
		if points.size() != 4:
			continue
		var active := zone_id == _active_zone_id
		var background := Color(0.075, 0.115, 0.105, 0.11 if not active else 0.17)
		var border := Color(0.76, 0.62, 0.37, 0.28 if not active else 0.92)
		draw_colored_polygon(points, background)
		var outline := PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
		draw_polyline(outline, border, 2.0 if not active else 4.0, true)
		var marker_color := Color(0.74, 0.59, 0.33, 0.34 if not active else 0.96)
		var marker_start := points[0].lerp(points[1], 0.05) + Vector2(0.0, 16.0)
		var marker_end := points[0].lerp(points[1], 0.16 if not active else 0.25) + Vector2(0.0, 16.0)
		draw_line(marker_start, marker_end, marker_color, 4.0, true)


static func _zone_for_area(area_id: StringName) -> StringName:
	match area_id:
		&"area.youtiao":
			return &"area.youtiao"
		&"area.pancake":
			return &"area.pancake"
		&"area.fresh_soy_milk", &"area.packaged_drink":
			return &"area.drinks"
		_:
			return &""
