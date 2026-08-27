class_name CookingStageBar
extends Control

const STAGE_INACTIVE := &"inactive"
const STAGE_YELLOW := &"yellow"
const STAGE_GREEN := &"green"
const STAGE_RED := &"red"

const TRACK_COLOR := Color(0.075, 0.14, 0.15, 1.0)
const TRACK_BORDER_COLOR := Color(0.045, 0.09, 0.10, 1.0)
const INACTIVE_COLOR := Color(0.18, 0.24, 0.25, 1.0)
const YELLOW_COLOR := Color("e9b44f")
const GREEN_COLOR := Color("6eaa78")
const RED_COLOR := Color("dc5a3e")
const MARKER_COLOR := Color(0.96, 0.88, 0.76, 1.0)

var progress := 0.0
var yellow_end := 0.40
var green_end := 0.60
var active := false
var stage_override: StringName = &""
var status_text := ""


func configure(
	next_progress: float,
	next_yellow_end: float,
	next_green_end: float,
	next_active: bool,
	next_stage_override: StringName = &"",
	next_status_text: String = ""
) -> void:
	progress = clampf(next_progress, 0.0, 1.0)
	yellow_end = clampf(next_yellow_end, 0.02, 0.96)
	green_end = clampf(next_green_end, yellow_end + 0.02, 0.98)
	active = next_active
	stage_override = next_stage_override if next_stage_override in [STAGE_YELLOW, STAGE_GREEN, STAGE_RED] else &""
	status_text = next_status_text
	tooltip_text = status_text
	queue_redraw()


func current_stage() -> StringName:
	if not active:
		return STAGE_INACTIVE
	if not stage_override.is_empty():
		return stage_override
	if progress < yellow_end:
		return STAGE_YELLOW
	if progress <= green_end:
		return STAGE_GREEN
	return STAGE_RED


func current_stage_color() -> Color:
	return _color_for_stage(current_stage())


func _draw() -> void:
	var bar := Rect2(2.0, 3.0, maxf(size.x - 4.0, 1.0), maxf(size.y - 6.0, 1.0))
	draw_style_box(_rounded_style(TRACK_COLOR, 6), bar)
	if not active:
		draw_style_box(_rounded_style(INACTIVE_COLOR, 5), bar.grow(-2.0))
		draw_style_box(_outline_style(TRACK_BORDER_COLOR, 6, 1), bar)
		return

	var yellow_width := bar.size.x * yellow_end
	var green_width := bar.size.x * (green_end - yellow_end)
	var red_width := maxf(bar.size.x - yellow_width - green_width, 0.0)
	var yellow_rect := Rect2(bar.position, Vector2(yellow_width, bar.size.y))
	var green_rect := Rect2(bar.position + Vector2(yellow_width, 0.0), Vector2(green_width, bar.size.y))
	var red_rect := Rect2(green_rect.end.x, bar.position.y, red_width, bar.size.y)
	draw_style_box(_segment_style(YELLOW_COLOR, true, false), yellow_rect)
	draw_rect(green_rect, GREEN_COLOR)
	draw_style_box(_segment_style(RED_COLOR, false, true), red_rect)

	var stage_rect := yellow_rect
	match current_stage():
		STAGE_GREEN:
			stage_rect = green_rect
		STAGE_RED:
			stage_rect = red_rect
	draw_rect(stage_rect.grow(-1.0), MARKER_COLOR, false, 2.0, true)
	draw_style_box(_outline_style(TRACK_BORDER_COLOR, 6, 2), bar)

	var marker_x := clampf(bar.position.x + bar.size.x * progress, bar.position.x + 2.0, bar.end.x - 2.0)
	draw_line(Vector2(marker_x, bar.position.y - 1.0), Vector2(marker_x, bar.end.y + 1.0), MARKER_COLOR, 3.0, true)
	draw_circle(Vector2(marker_x, bar.position.y - 1.0), 3.5, MARKER_COLOR)


static func _color_for_stage(stage: StringName) -> Color:
	match stage:
		STAGE_YELLOW:
			return YELLOW_COLOR
		STAGE_GREEN:
			return GREEN_COLOR
		STAGE_RED:
			return RED_COLOR
	return INACTIVE_COLOR


static func _rounded_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


static func _outline_style(color: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := _rounded_style(Color.TRANSPARENT, radius)
	style.border_color = color
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	return style


static func _segment_style(color: Color, rounded_left: bool, rounded_right: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	if rounded_left:
		style.corner_radius_top_left = 5
		style.corner_radius_bottom_left = 5
	if rounded_right:
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_right = 5
	return style
