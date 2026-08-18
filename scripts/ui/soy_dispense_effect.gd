class_name SoyDispenseEffect
extends Control

## A lightweight overlay for the direct soy dispenser.  The cup artwork remains
## the source of truth; this only supplies the live liquid and stream while the
## player is holding the spout.

## These positions are measured from the permanent dispenser art, so the flow
## begins at the bottom opening of the tap rather than beside its handle.
const CUP_CENTER_X := 141.0
const CUP_RIM_Y := 327.0
const CUP_BOTTOM_Y := 379.0
const NOZZLE_TIP := Vector2(141.0, 316.0)
const STREAM_WIDTH := 5.0

var _dispensing := false
var _fill_ratio := 0.0
var _liquid_color := Color("f6ddb0")
var _flow_time := 0.0
var _reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reduced_motion = _should_reduce_motion()
	visible = false


func set_dispense_state(dispensing: bool, fill_ratio: float, liquid_color: Color) -> void:
	_set_cup_state(dispensing, fill_ratio, liquid_color)


func set_filled_cup(fill_ratio: float, liquid_color: Color) -> void:
	_set_cup_state(false, fill_ratio, liquid_color)


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
	if not _dispensing or _reduced_motion:
		return
	_flow_time += maxf(delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	if _dispensing:
		_draw_stream()
	_draw_cup_fill()


func _draw_stream() -> void:
	# The flow is deliberately restrained: the actual fill progress is the
	# primary feedback, while this small highlight keeps the source legible.
	var sway := 0.0 if _reduced_motion else sin(_flow_time * 18.0) * 0.8
	var stream_end := Vector2(CUP_CENTER_X + sway, CUP_RIM_Y + 4.0)
	var stream_color := _liquid_color.lightened(0.05)
	draw_line(NOZZLE_TIP, stream_end, stream_color, STREAM_WIDTH, true)
	draw_line(NOZZLE_TIP + Vector2(-1.2, 0.0), stream_end + Vector2(-1.2, 0.0), Color(1.0, 0.97, 0.83, 0.72), 1.2, true)
	draw_circle(stream_end, STREAM_WIDTH * 0.56, stream_color)


func _draw_cup_fill() -> void:
	if _fill_ratio <= 0.0:
		return
	# The opaque cup has no separate interior layer.  This tapered fill shape
	# stays within its bowl silhouette and becomes wider as the liquid rises.
	var fill_height := (CUP_BOTTOM_Y - CUP_RIM_Y) * _fill_ratio
	var surface_y := CUP_BOTTOM_Y - fill_height
	var surface_half_width := lerpf(13.0, 20.0, _fill_ratio)
	var lower_half_width := 14.0
	var wave := 0.0 if _reduced_motion else sin(_flow_time * 14.0) * 0.8
	var body_points := PackedVector2Array([
		Vector2(CUP_CENTER_X - lower_half_width, CUP_BOTTOM_Y),
		Vector2(CUP_CENTER_X + lower_half_width, CUP_BOTTOM_Y),
		Vector2(CUP_CENTER_X + surface_half_width, surface_y),
		Vector2(CUP_CENTER_X, surface_y + wave),
		Vector2(CUP_CENTER_X - surface_half_width, surface_y),
	])
	draw_colored_polygon(body_points, Color(_liquid_color, 0.79))
	var surface_points := PackedVector2Array()
	for index in range(9):
		var progress := float(index) / 8.0
		var x := lerpf(CUP_CENTER_X - surface_half_width, CUP_CENTER_X + surface_half_width, progress)
		var crest := sin(progress * PI) * 2.0
		surface_points.append(Vector2(x, surface_y - crest + wave))
	draw_polyline(surface_points, _liquid_color.lightened(0.18), 1.4, true)


func _should_reduce_motion() -> bool:
	# Godot 4.7 exposes the platform preference when the OS supports it.  The
	# guarded call keeps the scene compatible with older export templates too.
	return DisplayServer.has_method(&"accessibility_should_reduce_motion") \
		and bool(DisplayServer.call(&"accessibility_should_reduce_motion"))
