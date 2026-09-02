class_name OrderCardBackground
extends TextureRect

const CARD_FILL := Color("f8e3ae")
const CARD_BORDER := Color("87501f")
const HEADER_FILL := Color("dfa040")
const CONTENT_FILL := Color("fff4d6")
const CONTENT_BORDER := Color("c87b35")
const FOOTER_FILL := Color("efc979")
const FOCUSED_BORDER := Color("ffc34a")

@export_range(0.5, 3.0, 0.1) var scale_factor := 1.0

var _blocks: Array[Dictionary] = []
var _focused := false


func set_card_layout(blocks: Array[Dictionary]) -> void:
	_blocks = blocks.duplicate(true)
	queue_redraw()


func set_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var outer_border := FOCUSED_BORDER if _focused else CARD_BORDER
	var outer_width := roundi((4.0 if _focused else 2.0) * scale_factor)
	_draw_box(Rect2(Vector2.ZERO, size), CARD_FILL, outer_border, 7.0 * scale_factor, outer_width)
	if _focused:
		draw_rect(Rect2(8.0 * scale_factor, 7.0 * scale_factor, 42.0 * scale_factor, 4.0 * scale_factor), FOCUSED_BORDER)
	# The outer shell owns the rounded top corners; the header intentionally
	# meets it flush so its baseline stays perfectly straight.
	draw_rect(Rect2(2.0 * scale_factor, 2.0 * scale_factor, size.x - 4.0 * scale_factor, 26.0 * scale_factor), HEADER_FILL)
	draw_line(Vector2(1.0 * scale_factor, 28.0 * scale_factor), Vector2(size.x - 1.0 * scale_factor, 28.0 * scale_factor), CARD_BORDER, 1.3 * scale_factor, true)
	for block in _blocks:
		var top := float(block.get("top", 0.0))
		var height := float(block.get("height", 0.0))
		if height > 0.0:
			_draw_box(Rect2(6.0 * scale_factor, top, size.x - 12.0 * scale_factor, height), CONTENT_FILL, CONTENT_BORDER, 4.0 * scale_factor, roundi(scale_factor))
	var footer_top := size.y - 24.0 * scale_factor
	draw_rect(Rect2(2.0 * scale_factor, footer_top, size.x - 4.0 * scale_factor, 15.0 * scale_factor), FOOTER_FILL)
	draw_rect(Rect2(7.0 * scale_factor, size.y - 9.0 * scale_factor, size.x - 14.0 * scale_factor, 2.0 * scale_factor), FOOTER_FILL)
	draw_line(Vector2(1.0 * scale_factor, footer_top), Vector2(size.x - 1.0 * scale_factor, footer_top), CARD_BORDER, 1.2 * scale_factor, true)


func _draw_box(rect: Rect2, fill: Color, border: Color, radius: float, border_width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(roundi(radius))
	draw_style_box(style, rect)
