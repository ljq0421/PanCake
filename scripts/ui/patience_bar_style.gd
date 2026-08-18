class_name PatienceBarStyle
extends RefCounted

const GREEN_THRESHOLD := 0.60
const YELLOW_THRESHOLD := 0.30
const TRACK_COLOR := Color("59686a")
const FILL_COLORS := [
	Color("6eaa78"),
	Color("e9b44f"),
	Color("dc5a3e"),
]


static func apply(progress_bar: ProgressBar, patience_ratio: float, current_tier: int) -> int:
	var next_tier := tier_for_ratio(patience_ratio)
	if next_tier == current_tier:
		return next_tier
	progress_bar.add_theme_stylebox_override(&"background", _style_box(TRACK_COLOR))
	progress_bar.add_theme_stylebox_override(&"fill", _style_box(FILL_COLORS[next_tier]))
	return next_tier


static func tier_for_ratio(patience_ratio: float) -> int:
	var ratio := clampf(patience_ratio, 0.0, 1.0)
	if ratio > GREEN_THRESHOLD:
		return 0
	if ratio > YELLOW_THRESHOLD:
		return 1
	return 2


static func _style_box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style
