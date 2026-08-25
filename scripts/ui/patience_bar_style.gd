class_name PatienceBarStyle
extends RefCounted

const GREEN_THRESHOLD := 0.60
const YELLOW_THRESHOLD := 0.30
const FILL_COLORS := [
	Color("6eaa78"),
	Color("e9b44f"),
	Color("dc5a3e"),
]


static func apply(progress_bar: ProgressBar, patience_ratio: float, current_tier: int) -> int:
	var next_tier := tier_for_ratio(patience_ratio)
	if next_tier == current_tier:
		return next_tier
	# The order-card bitmap owns the decorative track. Keep this control transparent
	# so it paints only the changing fill inside that track.
	progress_bar.add_theme_stylebox_override(&"background", _transparent_style_box())
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
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


static func _transparent_style_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	return style
