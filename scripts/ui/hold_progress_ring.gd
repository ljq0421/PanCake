class_name HoldProgressRing
extends Control

const TRACK_COLOR := Color(0.08, 0.12, 0.12, 0.88)
const PROGRESS_COLOR := Color(1.0, 0.82, 0.30, 1.0)
const TEXT_COLOR := Color(1.0, 0.98, 0.88, 1.0)
const OUTLINE_COLOR := Color(0.03, 0.02, 0.01, 0.92)

var progress_ratio := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_progress_ratio(value: float) -> void:
	progress_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(minf(size.x, size.y) * 0.5 - 7.0, 4.0)
	draw_circle(center, radius + 5.0, Color(0.015, 0.035, 0.035, 0.88))
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, 48, TRACK_COLOR, 7.0, true)
	if progress_ratio > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress_ratio, 48, PROGRESS_COLOR, 7.0, true)
	var percent_text := "%d%%" % roundi(progress_ratio * 100.0)
	var font := ThemeDB.fallback_font
	var font_size := 24
	var text_size := font.get_string_size(percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string_outline(font, baseline, percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 3, OUTLINE_COLOR)
	draw_string(font, baseline, percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, TEXT_COLOR)
