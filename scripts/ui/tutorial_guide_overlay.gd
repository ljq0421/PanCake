class_name TutorialGuideOverlay
extends Control

const EDGE_INSET := 10.0
const TARGET_PADDING := 8.0
const BUBBLE_GAP := 22.0
const BUBBLE_MIN_WIDTH := 260.0
const BUBBLE_MAX_WIDTH := 380.0
const BUBBLE_MIN_HEIGHT := 64.0
const ARROW_SIZE := Vector2(28.0, 28.0)

@onready var guide_arrow: Control = $GuideArrow
@onready var target_highlight: Panel = $TargetHighlight
@onready var guide_bubble: PanelContainer = $GuideBubble
@onready var guide_label: Label = $GuideBubble/GuideLabel

var _target: Control
var _pulse_time := 0.0
var _reduce_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reduce_motion = DisplayServer.has_method(&"accessibility_should_reduce_motion") \
		and bool(DisplayServer.call(&"accessibility_should_reduce_motion"))
	_hide_guide()


func show_guide(target: Control, message: String) -> void:
	if target == null or not target.is_visible_in_tree():
		_hide_guide()
		return
	_target = target
	guide_label.text = message
	_pulse_time = 0.0
	visible = true
	_layout_for_target()


func hide_guide() -> void:
	_target = null
	_hide_guide()


func _process(delta: float) -> void:
	if not visible or _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		_hide_guide()
		return
	_pulse_time += maxf(delta, 0.0)
	_layout_for_target()
	if _reduce_motion:
		guide_arrow.scale = Vector2.ONE
		target_highlight.modulate.a = 1.0
		return
	var pulse_wave := sin(_pulse_time * 3.2)
	guide_arrow.scale = Vector2.ONE * (1.0 + pulse_wave * 0.04)
	target_highlight.modulate.a = 0.90 + pulse_wave * 0.10


func _layout_for_target() -> void:
	# Both controls live in the same canvas. Their global rectangles therefore
	# have the same coordinate origin even when the viewport is stretched. Using
	# their difference avoids applying a canvas transform twice.
	var target_global_rect := _target.get_global_rect()
	var overlay_global_rect := get_global_rect()
	var local_rect := Rect2(
		target_global_rect.position - overlay_global_rect.position,
		target_global_rect.size,
	).grow(TARGET_PADDING)
	var bounds := Rect2(Vector2.ZERO, size)
	local_rect.position.x = clampf(local_rect.position.x, EDGE_INSET, maxf(bounds.size.x - local_rect.size.x - EDGE_INSET, EDGE_INSET))
	local_rect.position.y = clampf(local_rect.position.y, EDGE_INSET, maxf(bounds.size.y - local_rect.size.y - EDGE_INSET, EDGE_INSET))
	target_highlight.position = local_rect.position
	target_highlight.size = local_rect.size
	var bubble_size := _bubble_size(bounds.size)
	var bubble_position := Vector2.ZERO
	var arrow_center := Vector2.ZERO
	var arrow_direction := Vector2.LEFT
	var space_right := bounds.size.x - EDGE_INSET - local_rect.end.x - BUBBLE_GAP
	var space_left := local_rect.position.x - EDGE_INSET - BUBBLE_GAP
	var space_below := bounds.size.y - EDGE_INSET - local_rect.end.y - BUBBLE_GAP
	var space_above := local_rect.position.y - EDGE_INSET - BUBBLE_GAP
	if space_right >= bubble_size.x:
		bubble_position = Vector2(local_rect.end.x + BUBBLE_GAP, local_rect.get_center().y - bubble_size.y * 0.5)
		arrow_center = Vector2(local_rect.end.x + BUBBLE_GAP * 0.5, local_rect.get_center().y)
		arrow_direction = Vector2.LEFT
	elif space_left >= bubble_size.x:
		bubble_position = Vector2(local_rect.position.x - BUBBLE_GAP - bubble_size.x, local_rect.get_center().y - bubble_size.y * 0.5)
		arrow_center = Vector2(local_rect.position.x - BUBBLE_GAP * 0.5, local_rect.get_center().y)
		arrow_direction = Vector2.RIGHT
	elif space_below >= bubble_size.y or space_below >= space_above:
		bubble_position = Vector2(local_rect.get_center().x - bubble_size.x * 0.5, local_rect.end.y + BUBBLE_GAP)
		arrow_center = Vector2(local_rect.get_center().x, local_rect.end.y + BUBBLE_GAP * 0.5)
		arrow_direction = Vector2.UP
	else:
		bubble_position = Vector2(local_rect.get_center().x - bubble_size.x * 0.5, local_rect.position.y - BUBBLE_GAP - bubble_size.y)
		arrow_center = Vector2(local_rect.get_center().x, local_rect.position.y - BUBBLE_GAP * 0.5)
		arrow_direction = Vector2.DOWN
	bubble_position.x = clampf(bubble_position.x, EDGE_INSET, maxf(bounds.size.x - bubble_size.x - EDGE_INSET, EDGE_INSET))
	bubble_position.y = clampf(bubble_position.y, EDGE_INSET, maxf(bounds.size.y - bubble_size.y - EDGE_INSET, EDGE_INSET))
	guide_bubble.position = bubble_position
	guide_bubble.size = bubble_size
	guide_arrow.size = ARROW_SIZE
	guide_arrow.pivot_offset = ARROW_SIZE * 0.5
	guide_arrow.position = arrow_center - ARROW_SIZE * 0.5
	guide_arrow.call(&"set_direction", arrow_direction)


func _bubble_size(bounds_size: Vector2) -> Vector2:
	var maximum_width := maxf(minf(BUBBLE_MAX_WIDTH, bounds_size.x - EDGE_INSET * 2.0), 120.0)
	var minimum_width := minf(BUBBLE_MIN_WIDTH, maximum_width)
	var font := guide_label.get_theme_font(&"font")
	var font_size := guide_label.get_theme_font_size(&"font_size")
	var natural_width := font.get_string_size(guide_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + 32.0
	var width := clampf(natural_width, minimum_width, maximum_width)
	var text_width := maxf(width - 32.0, 80.0)
	var text_size := font.get_multiline_string_size(guide_label.text, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size)
	var height := maxf(BUBBLE_MIN_HEIGHT, text_size.y + 20.0)
	return Vector2(width, minf(height, maxf(bounds_size.y - EDGE_INSET * 2.0, BUBBLE_MIN_HEIGHT)))


func _hide_guide() -> void:
	visible = false
	guide_arrow.scale = Vector2.ONE
	target_highlight.modulate.a = 1.0
