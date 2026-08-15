class_name TutorialGuideOverlay
extends Control

@onready var guide_arrow: Label = $GuideArrow
@onready var guide_bubble: PanelContainer = $GuideBubble
@onready var guide_label: Label = $GuideBubble/GuideLabel

var _target: Control
var _pulse_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_guide()


func show_guide(target: Control, message: String) -> void:
	if target == null or not target.is_visible_in_tree():
		_hide_guide()
		return
	_target = target
	guide_label.text = message
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
	var pulse := 1.0 + sin(_pulse_time * 5.0) * 0.08
	guide_arrow.scale = Vector2.ONE * pulse


func _layout_for_target() -> void:
	var global_rect := _target.get_global_rect()
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var top_left := inverse * global_rect.position
	var bottom_right := inverse * global_rect.end
	var local_rect := Rect2(top_left, bottom_right - top_left).grow(8.0)
	var bounds := Rect2(Vector2.ZERO, size)
	local_rect.position.x = clampf(local_rect.position.x, 4.0, maxf(bounds.size.x - local_rect.size.x - 4.0, 4.0))
	local_rect.position.y = clampf(local_rect.position.y, 4.0, maxf(bounds.size.y - local_rect.size.y - 4.0, 4.0))
	guide_arrow.pivot_offset = guide_arrow.size * 0.5
	guide_arrow.position = Vector2(local_rect.get_center().x - 18.0, maxf(local_rect.position.y - 42.0, 4.0))
	var bubble_size := Vector2(330.0, 68.0)
	var bubble_position := Vector2(local_rect.end.x + 14.0, local_rect.get_center().y - bubble_size.y * 0.5)
	if bubble_position.x + bubble_size.x > bounds.size.x - 8.0:
		bubble_position.x = local_rect.position.x - bubble_size.x - 14.0
	bubble_position.x = clampf(bubble_position.x, 8.0, maxf(bounds.size.x - bubble_size.x - 8.0, 8.0))
	bubble_position.y = clampf(bubble_position.y, 8.0, maxf(bounds.size.y - bubble_size.y - 8.0, 8.0))
	guide_bubble.position = bubble_position
	guide_bubble.size = bubble_size


func _hide_guide() -> void:
	visible = false
