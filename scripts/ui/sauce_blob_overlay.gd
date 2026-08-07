class_name SauceBlobOverlay
extends Control

const SWEET_COLOR := Color(0.30, 0.095, 0.025, 0.96)
const SWEET_HIGHLIGHT := Color(0.55, 0.20, 0.055, 0.72)
const CHILI_COLOR := Color(0.76, 0.075, 0.025, 0.96)
const CHILI_HIGHLIGHT := Color(1.0, 0.22, 0.055, 0.72)

var sweet_ratio := 0.0
var chili_ratio := 0.0
var left_fold_progress := 0.0
var right_fold_progress := 0.0


func set_amounts(next_sweet_ratio: float, next_chili_ratio: float) -> void:
	sweet_ratio = clampf(next_sweet_ratio, 0.0, 1.0)
	chili_ratio = clampf(next_chili_ratio, 0.0, 1.0)
	_refresh_visibility()
	queue_redraw()


func set_fold_progress(next_left_progress: float, next_right_progress: float) -> void:
	left_fold_progress = clampf(next_left_progress, 0.0, 1.0)
	right_fold_progress = clampf(next_right_progress, 0.0, 1.0)
	_refresh_visibility()
	queue_redraw()


func _refresh_visibility() -> void:
	var has_blob := sweet_ratio > 0.001 or chili_ratio > 0.001
	var fillings_enclosed := left_fold_progress >= 0.999 and right_fold_progress >= 0.999
	visible = has_blob and not fillings_enclosed


func _draw() -> void:
	_draw_blob(size * 0.5 + Vector2(-34.0, 8.0), sweet_ratio, SWEET_COLOR, SWEET_HIGHLIGHT, 0.35)
	_draw_blob(size * 0.5 + Vector2(34.0, -8.0), chili_ratio, CHILI_COLOR, CHILI_HIGHLIGHT, 1.75)


func _draw_blob(center: Vector2, ratio: float, base_color: Color, highlight_color: Color, phase: float) -> void:
	if ratio <= 0.001:
		return
	var radius := lerpf(10.0, 54.0, sqrt(ratio))
	var points := PackedVector2Array()
	for point_index in 24:
		var angle := TAU * float(point_index) / 24.0
		var wobble := 1.0 + sin(angle * 3.0 + phase) * 0.08 + cos(angle * 5.0 - phase) * 0.045
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * wobble)
	draw_colored_polygon(points, base_color)
	draw_circle(center + Vector2(-radius * 0.18, -radius * 0.22), radius * 0.34, highlight_color)
