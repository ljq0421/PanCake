class_name SoyDispenseEffect
extends Control

## A lightweight overlay for the direct soy dispenser.  The cup artwork remains
## the source of truth; this only supplies the live liquid and stream while the
## player is holding the spout.

## These positions are measured from the permanent dispenser art, so the flow
## begins at the bottom opening of the tap rather than beside its handle.
const DEFAULT_CUP_CENTER_X := 151.5
const DEFAULT_CUP_RIM_Y := 333.0
const DEFAULT_CUP_BOTTOM_Y := 399.0
const DEFAULT_NOZZLE_TIP := Vector2(150.0, 308.0)
const STREAM_WIDTH := 6.0
const CUP_SIDE_SAMPLES := 12
const SURFACE_SAMPLES := 18
const SUGAR_PARTICLE_COUNT := 7
const SUGAR_ANIMATION_SECONDS := 0.28

var _dispensing := false
var _fill_ratio := 0.0
var _liquid_color := Color("f6ddb0")
var _flow_time := 0.0
var _reduced_motion := false
var _cup_center_x := DEFAULT_CUP_CENTER_X
var _cup_rim_y := DEFAULT_CUP_RIM_Y
var _cup_bottom_y := DEFAULT_CUP_BOTTOM_Y
var _nozzle_tip := DEFAULT_NOZZLE_TIP
var _cup_top_half_width := 26.0
var _cup_bottom_half_width := 18.0
var _sugar_animation_time := -1.0
var _sugar_source := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reduced_motion = _should_reduce_motion()
	visible = false


func set_dispense_state(dispensing: bool, fill_ratio: float, liquid_color: Color) -> void:
	_set_cup_state(dispensing, fill_ratio, liquid_color)


func set_filled_cup(fill_ratio: float, liquid_color: Color) -> void:
	_set_cup_state(false, fill_ratio, liquid_color)


func play_sugar_add(source: Vector2) -> void:
	# A short ingredient trail makes the otherwise instant sweetness change
	# spatially legible: the sugar leaves the jar and lands on this cup.
	_sugar_source = source
	_sugar_animation_time = 0.0
	queue_redraw()


func is_overflowing() -> bool:
	return _dispensing and _fill_ratio >= 0.999


func configure_geometry(cup_rect: Rect2, nozzle_tip: Vector2) -> void:
	# The collectible cup changed size with the plastic artwork.  Derive all
	# liquid bounds from its actual rect so the stream and fill cannot drift.
	_cup_center_x = cup_rect.get_center().x
	_cup_rim_y = cup_rect.position.y + cup_rect.size.y * 0.16
	_cup_bottom_y = cup_rect.position.y + cup_rect.size.y * 0.86
	_nozzle_tip = nozzle_tip
	_cup_top_half_width = cup_rect.size.x * 0.28
	_cup_bottom_half_width = cup_rect.size.x * 0.19
	queue_redraw()


func _set_cup_state(dispensing: bool, fill_ratio: float, liquid_color: Color) -> void:
	var next_ratio := clampf(fill_ratio, 0.0, 1.0)
	var changed := _dispensing != dispensing \
		or not is_equal_approx(_fill_ratio, next_ratio) \
		or _liquid_color != liquid_color
	_dispensing = dispensing
	_fill_ratio = next_ratio
	_liquid_color = liquid_color
	visible = _dispensing or _fill_ratio > 0.0
	if changed:
		queue_redraw()


func _process(delta: float) -> void:
	var should_redraw := false
	if _dispensing and not _reduced_motion:
		_flow_time += maxf(delta, 0.0)
		should_redraw = true
	if _sugar_animation_time >= 0.0:
		_sugar_animation_time += maxf(delta, 0.0)
		if _sugar_animation_time >= SUGAR_ANIMATION_SECONDS:
			_sugar_animation_time = -1.0
		should_redraw = true
	if not should_redraw:
		return
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	if _dispensing:
		_draw_stream()
	_draw_cup_fill()
	if is_overflowing():
		_draw_overflow()
	if _sugar_animation_time >= 0.0:
		_draw_sugar_add()


func _draw_stream() -> void:
	# The flow is deliberately restrained: the actual fill progress is the
	# primary feedback, while this small highlight keeps the source legible.
	var sway := 0.0 if _reduced_motion else sin(_flow_time * 18.0) * 0.8
	# The stream meets the live surface rather than ending at the rim.  This
	# keeps it visually continuous even at the beginning of a fill.
	var stream_end := Vector2(_cup_center_x + sway, _surface_y() + 0.6)
	var stream_color := _liquid_color.lightened(0.05)
	draw_line(_nozzle_tip, stream_end, stream_color, STREAM_WIDTH, true)
	draw_line(_nozzle_tip + Vector2(-1.3, 0.0), stream_end + Vector2(-1.3, 0.0), Color(1.0, 0.97, 0.83, 0.78), 1.4, true)
	draw_circle(stream_end, STREAM_WIDTH * 0.56, stream_color)


func _draw_cup_fill() -> void:
	if _fill_ratio <= 0.0:
		return
	# Trace the tapered plastic cup with several points instead of a four-corner
	# polygon.  The full cup therefore keeps a rounded profile and has no square
	# liquid corners.
	var surface_y := _surface_y()
	var wave := 0.0 if _reduced_motion else sin(_flow_time * 14.0) * 0.8
	var fill_color := Color(_liquid_color, 0.90)
	# Rendering a stack of convex tapered strips avoids the renderer's
	# triangulation failure for a dynamically changing concave polygon.
	for index in range(CUP_SIDE_SAMPLES):
		var top_progress := float(index) / CUP_SIDE_SAMPLES
		var bottom_progress := float(index + 1) / CUP_SIDE_SAMPLES
		var y_top := lerpf(surface_y, _cup_bottom_y, top_progress)
		var y_bottom := lerpf(surface_y, _cup_bottom_y, bottom_progress)
		var top_half_width := _cup_half_width_at(y_top)
		var bottom_half_width := _cup_half_width_at(y_bottom)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_cup_center_x - top_half_width, y_top),
			Vector2(_cup_center_x + top_half_width, y_top),
			Vector2(_cup_center_x + bottom_half_width, y_bottom),
			Vector2(_cup_center_x - bottom_half_width, y_bottom),
		]), fill_color)
	var surface_points := _surface_points(surface_y, wave)
	draw_polyline(surface_points, _liquid_color.lightened(0.18), 1.4, true)


func _draw_overflow() -> void:
	# Once the liquid reaches the rim, a small rounded lip and two drips show
	# that the player is still holding the nozzle.  It never changes cup state.
	var phase := 0.0 if _reduced_motion else _flow_time * 12.0
	var surface_y := _surface_y()
	var rim_half_width := _cup_half_width_at(surface_y)
	var spill_side := 1.0 if sin(phase) >= 0.0 else -1.0
	var rim_x := _cup_center_x + rim_half_width * spill_side
	var lip_x := rim_x + 5.0 * spill_side
	var spill_color := Color(_liquid_color, 0.92)
	var drip_length := 9.0 if _reduced_motion else 9.0 + absf(sin(phase * 0.72)) * 8.0
	draw_circle(Vector2(lip_x, surface_y + 1.6), 4.4, spill_color)
	draw_line(Vector2(lip_x, surface_y + 3.0), Vector2(lip_x, surface_y + drip_length), spill_color, 3.6, true)
	draw_circle(Vector2(lip_x, surface_y + drip_length), 2.0, spill_color)
	# Keep a second small bead on the opposite rim so the overflow reads as a
	# full cup, rather than a disconnected side splash.
	draw_circle(Vector2(_cup_center_x - rim_half_width * spill_side, surface_y + 1.4), 2.4, Color(_liquid_color, 0.74))


func _draw_sugar_add() -> void:
	var duration := SUGAR_ANIMATION_SECONDS
	var progress := clampf(_sugar_animation_time / duration, 0.0, 1.0)
	var target := Vector2(_cup_center_x, _surface_y() + 3.0)
	if _reduced_motion:
		# Preserve the feedback without travelling particles when motion is
		# reduced: a brief cluster at the liquid surface is enough.
		for index in range(4):
			var x := target.x + (float(index) - 1.5) * 3.0
			draw_circle(Vector2(x, target.y - 2.0), 2.8, Color("fff2be"))
		return
	for index in range(SUGAR_PARTICLE_COUNT):
		var stagger := float(index) * 0.07
		var particle_progress := clampf((progress - stagger) / (1.0 - stagger), 0.0, 1.0)
		if particle_progress <= 0.0:
			continue
		var start := _sugar_source + Vector2((float(index % 3) - 1.0) * 3.0, 0.0)
		var end := target + Vector2((float(index) - 3.0) * 1.55, 0.0)
		var control := start.lerp(end, 0.5) + Vector2(0.0, -18.0)
		var position := _quadratic_bezier(start, control, end, particle_progress)
		var alpha := 1.0 - maxf(0.0, (particle_progress - 0.8) / 0.2) * 0.35
		draw_circle(position, 3.0, Color(1.0, 0.91, 0.58, alpha))


static func _quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return inverse * inverse * start + 2.0 * inverse * progress * control + progress * progress * end


func _surface_y() -> float:
	return _cup_bottom_y - (_cup_bottom_y - _cup_rim_y) * maxf(_fill_ratio, 0.03)


func _cup_half_width_at(y: float) -> float:
	var down_cup := inverse_lerp(_cup_rim_y, _cup_bottom_y, y)
	return lerpf(_cup_top_half_width, _cup_bottom_half_width, clampf(down_cup, 0.0, 1.0))


func _surface_points(surface_y: float, wave: float) -> PackedVector2Array:
	var half_width := _cup_half_width_at(surface_y)
	var points := PackedVector2Array()
	for index in range(SURFACE_SAMPLES + 1):
		var progress := float(index) / SURFACE_SAMPLES
		var x := lerpf(_cup_center_x - half_width, _cup_center_x + half_width, progress)
		# A shallow ellipse-like arc preserves a rounded liquid edge at 100%.
		var arc := sin(progress * PI) * 2.0
		points.append(Vector2(x, surface_y - arc + wave))
	return points


func _should_reduce_motion() -> bool:
	# Godot 4.7 exposes the platform preference when the OS supports it.  The
	# guarded call keeps the scene compatible with older export templates too.
	return DisplayServer.has_method(&"accessibility_should_reduce_motion") \
		and bool(DisplayServer.call(&"accessibility_should_reduce_motion"))
