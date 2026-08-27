class_name OrderCardBackground
extends TextureRect

const CARD_FILL := Color("f8e3ae")
const CARD_BORDER := Color("87501f")
const HEADER_FILL := Color("dfa040")
const CONTENT_FILL := Color("fff4d6")
const CONTENT_BORDER := Color("c87b35")
const FOOTER_FILL := Color("efc979")

var _blocks: Array[Dictionary] = []


func set_card_layout(blocks: Array[Dictionary]) -> void:
	_blocks = blocks.duplicate(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_box(Rect2(Vector2.ZERO, size), CARD_FILL, CARD_BORDER, 7.0, 2)
	# The outer shell owns the rounded top corners; the header intentionally
	# meets it flush so its baseline stays perfectly straight.
	draw_rect(Rect2(2.0, 2.0, size.x - 4.0, 26.0), HEADER_FILL)
	draw_line(Vector2(1.0, 28.0), Vector2(size.x - 1.0, 28.0), CARD_BORDER, 1.3, true)
	for block in _blocks:
		var top := float(block.get("top", 0.0))
		var height := float(block.get("height", 0.0))
		if height > 0.0:
			_draw_box(Rect2(6.0, top, size.x - 12.0, height), CONTENT_FILL, CONTENT_BORDER, 4.0, 1)
	var footer_top := size.y - 24.0
	draw_rect(Rect2(2.0, footer_top, size.x - 4.0, 15.0), FOOTER_FILL)
	draw_rect(Rect2(7.0, size.y - 9.0, size.x - 14.0, 2.0), FOOTER_FILL)
	draw_line(Vector2(1.0, footer_top), Vector2(size.x - 1.0, footer_top), CARD_BORDER, 1.2, true)


func _draw_box(rect: Rect2, fill: Color, border: Color, radius: float, border_width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(roundi(radius))
	draw_style_box(style, rect)
