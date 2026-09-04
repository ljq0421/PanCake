class_name CartoonEggCrackEffect
extends Control

## Programmatic cartoon feedback for cracking an egg onto the pancake. It uses
## no retired bitmap assets, and leaves a readable intact egg at the landing
## point until the player starts spreading it.

const NORMAL_DURATION := 0.28
const REDUCED_MOTION_DURATION := 0.16
const NORMAL_DROP_HEIGHT := 66.0
const REDUCED_DROP_HEIGHT := 16.0
const OUTLINE_COLOR := Color("6f351d")
const SHELL_COLOR := Color("fff1ca")
const SHELL_SHADE_COLOR := Color("e8c482")
const WHITE_COLOR := Color(1.0, 0.96, 0.78, 0.82)
const YOLK_COLOR := Color("f5a623")
const YOLK_HIGHLIGHT_COLOR := Color(1.0, 0.80, 0.30, 0.90)

var model: PancakeModel
var _progress := 1.0
var _active := false
var _target := Vector2.ZERO
var _landed_positions: Array[Vector2] = []
var _motion_tween: Tween


func configure(value: PancakeModel) -> void:
	model = value
	set_process(true)


func play_at(local_position: Vector2) -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_target = local_position
	_landed_positions.append(local_position)
	if _landed_positions.size() > 2:
		_landed_positions.pop_front()
	_progress = 0.0
	_active = true
	visible = true
	queue_redraw()
	var reduced_motion := (
		DisplayServer.has_method(&"accessibility_should_reduce_motion")
		and bool(DisplayServer.call(&"accessibility_should_reduce_motion"))
	)
	var duration := REDUCED_MOTION_DURATION if reduced_motion else NORMAL_DURATION
	_motion_tween = create_tween()
	_motion_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_method(_set_progress, 0.0, 1.0, duration)
	_motion_tween.finished.connect(_finish_motion)


func clear() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null
	_active = false
	_progress = 1.0
	_landed_positions.clear()
	visible = false
	queue_redraw()


func is_playing() -> bool:
	return _active


func _process(_delta: float) -> void:
	if model == null:
		return
	if not model.has_egg() or model.egg_state != PancakeModel.EggState.CRACKED or not model.egg_is_on_visible_side():
		if visible or not _landed_positions.is_empty():
			clear()


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _finish_motion() -> void:
	_motion_tween = null
	_active = false
	_progress = 1.0
	queue_redraw()


func _draw() -> void:
	if _landed_positions.is_empty():
		return
	var settled_count := _landed_positions.size() - 1 if _active else _landed_positions.size()
	for index in range(settled_count):
		_draw_intact_egg(_landed_positions[index], 1.0)
	if not _active:
		return
	var reduced_motion := (
		DisplayServer.has_method(&"accessibility_should_reduce_motion")
		and bool(DisplayServer.call(&"accessibility_should_reduce_motion"))
	)
	var drop_height := REDUCED_DROP_HEIGHT if reduced_motion else NORMAL_DROP_HEIGHT
	var shell_origin := _target - Vector2(0.0, drop_height)
	var open_progress := smoothstep(0.02, 0.42, _progress)
	_draw_shell_half(shell_origin, -1.0, open_progress)
	_draw_shell_half(shell_origin, 1.0, open_progress)
	var fall_progress := smoothstep(0.14, 0.76, _progress)
	var falling_position := shell_origin.lerp(_target, fall_progress)
	var falling_alpha := 1.0 - smoothstep(0.68, 0.86, _progress)
	if falling_alpha > 0.01:
		_draw_intact_egg(falling_position, falling_alpha, lerpf(0.72, 0.92, fall_progress))
	var landing_alpha := smoothstep(0.64, 0.88, _progress)
	if landing_alpha > 0.01:
		_draw_intact_egg(_target, landing_alpha)
	var splash_alpha := 1.0 - smoothstep(0.72, 1.0, _progress)
	if splash_alpha > 0.01:
		_draw_ellipse_outline(_target + Vector2(0.0, 7.0), Vector2(28.0, 10.0) * lerpf(0.72, 1.20, _progress), Color(1.0, 0.88, 0.48, splash_alpha * 0.72), 3.0)


func _draw_intact_egg(center: Vector2, alpha: float, scale_factor: float = 1.0) -> void:
	var shadow_color := Color(OUTLINE_COLOR, alpha * 0.52)
	_draw_filled_ellipse(center + Vector2(0.0, 3.0), Vector2(29.0, 19.0) * scale_factor, shadow_color)
	_draw_filled_ellipse(center, Vector2(28.0, 18.0) * scale_factor, Color(WHITE_COLOR, alpha * WHITE_COLOR.a))
	_draw_ellipse_outline(center, Vector2(28.0, 18.0) * scale_factor, Color(1.0, 0.91, 0.67, alpha * 0.88), 2.0)
	draw_circle(center + Vector2(3.0, -1.0) * scale_factor, 10.0 * scale_factor, Color(YOLK_COLOR, alpha))
	draw_circle(center + Vector2(0.5, -4.0) * scale_factor, 3.2 * scale_factor, Color(YOLK_HIGHLIGHT_COLOR, alpha * YOLK_HIGHLIGHT_COLOR.a))


func _draw_shell_half(origin: Vector2, direction: float, open_progress: float) -> void:
	var offset := Vector2(direction * lerpf(5.0, 16.0, open_progress), lerpf(0.0, -4.0, open_progress))
	var rotation := direction * lerpf(0.04, 0.44, open_progress)
	draw_set_transform(origin + offset, rotation, Vector2.ONE)
	var points := PackedVector2Array([
		Vector2(0.0, -12.0),
		Vector2(direction * 15.0, -9.0),
		Vector2(direction * 19.0, 1.0),
		Vector2(direction * 13.0, 11.0),
		Vector2(direction * 4.0, 8.0),
		Vector2(0.0, 2.0),
	])
	draw_colored_polygon(points, SHELL_COLOR)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, OUTLINE_COLOR, 2.2, true)
	draw_line(Vector2.ZERO, Vector2(direction * 12.0, 6.0), SHELL_SHADE_COLOR, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_filled_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(center, radii), color)


func _draw_ellipse_outline(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := _ellipse_points(center, radii)
	points.append(points[0])
	draw_polyline(points, color, width, true)


func _ellipse_points(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in 32:
		var angle := TAU * float(step) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
