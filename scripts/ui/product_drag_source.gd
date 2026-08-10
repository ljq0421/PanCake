class_name ProductDragSource
extends TextureButton

signal short_clicked(source_ref: Dictionary)
signal drag_started(source_ref: Dictionary)

@export var drag_threshold_pixels := 10.0

var _source_ref: Dictionary = {}
var _press_position := Vector2.ZERO
var _pressed_for_drag := false


func configure(source_ref: Dictionary, product_texture: Texture2D, available: bool, hint: String = "") -> void:
	_source_ref = source_ref.duplicate(true)
	texture_normal = product_texture
	texture_disabled = product_texture
	disabled = not available
	tooltip_text = hint
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_FORBIDDEN


func source_ref() -> Dictionary:
	return _source_ref.duplicate(true)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed_for_drag = true
			_press_position = event.position
		else:
			if _pressed_for_drag and event.position.distance_to(_press_position) <= drag_threshold_pixels:
				short_clicked.emit(_source_ref.duplicate(true))
			_pressed_for_drag = false
	elif event is InputEventMouseMotion and _pressed_for_drag and event.position.distance_to(_press_position) > drag_threshold_pixels:
		_pressed_for_drag = false
		var preview := TextureRect.new()
		preview.texture = texture_normal
		preview.custom_minimum_size = Vector2(72.0, 72.0)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
		drag_started.emit(_source_ref.duplicate(true))
		force_drag({"kind": &"product_source", "source_ref": _source_ref.duplicate(true)}, preview)
		accept_event()
