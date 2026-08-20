class_name ProductDragSource
extends TextureButton

signal short_clicked(source_ref: Dictionary)
signal drag_started(source_ref: Dictionary)
signal drag_ended(source_ref: Dictionary, successful: bool)
signal hold_requested(source_ref: Dictionary)
signal hold_advanced(source_ref: Dictionary, delta: float)
signal hold_released(source_ref: Dictionary)

@export var drag_threshold_pixels := 10.0
@export var hold_enabled := false
@export var hold_threshold_seconds := 0.1
@export var native_drag_enabled := true
@export var cancel_pending_on_mouse_exit := true

var _source_ref: Dictionary = {}
var _press_position := Vector2.ZERO
var _pressed_for_drag := false
var _drag_available := false
var _holding := false
var _hold_elapsed := 0.0
var _native_drag_in_progress := false


func _ready() -> void:
	mouse_exited.connect(_on_mouse_exited)
	set_process(false)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _native_drag_in_progress:
		return
	_native_drag_in_progress = false
	var viewport := get_viewport()
	var successful := viewport != null and viewport.gui_is_drag_successful()
	drag_ended.emit(_source_ref.duplicate(true), successful)


func configure(source_ref: Dictionary, product_texture: Texture2D, available: bool, hint: String = "") -> void:
	_source_ref = source_ref.duplicate(true)
	texture_normal = product_texture
	texture_disabled = product_texture
	disabled = not available
	_drag_available = available
	tooltip_text = hint
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_FORBIDDEN


func set_drag_available(value: bool) -> void:
	_drag_available = value


func _process(delta: float) -> void:
	advance_gesture(delta)


func source_ref() -> Dictionary:
	return _source_ref.duplicate(true)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_gesture(event.global_position)
		else:
			end_gesture()
	elif event is InputEventMouseMotion and _pressed_for_drag:
		update_gesture(event.global_position)


func begin_gesture(viewport_position: Vector2) -> void:
	if disabled:
		return
	_pressed_for_drag = true
	_holding = false
	_press_position = viewport_position
	_hold_elapsed = 0.0
	set_process(hold_enabled)


func update_gesture(viewport_position: Vector2, perform_native_drag: bool = true) -> void:
	if not _pressed_for_drag or viewport_position.distance_to(_press_position) <= drag_threshold_pixels:
		return
	# Movement is the stronger intent.  A player may pause longer than the hold
	# threshold before beginning a drag, so an accepted hold must not permanently
	# trap an available product in restock mode.
	if _holding:
		if not _drag_available:
			return
		_holding = false
		hold_released.emit(_source_ref.duplicate(true))
	_pressed_for_drag = false
	set_process(false)
	if _drag_available:
		drag_started.emit(_source_ref.duplicate(true))
		if not perform_native_drag or not native_drag_enabled:
			return
		_native_drag_in_progress = true
		var preview := TextureRect.new()
		preview.texture = texture_normal
		# Drag previews must stay above decorative drop targets (for example, the
		# black-sesame tray), otherwise the product appears to slip underneath it.
		preview.z_index = z_index + 1
		preview.custom_minimum_size = Vector2(72.0, 72.0)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
		force_drag({"kind": &"product_source", "source_ref": _source_ref.duplicate(true)}, preview)


func advance_gesture(delta: float) -> void:
	if _holding:
		hold_advanced.emit(_source_ref.duplicate(true), maxf(delta, 0.0))
		return
	if not hold_enabled or not _pressed_for_drag:
		return
	_hold_elapsed += maxf(delta, 0.0)
	if _hold_elapsed + 0.000001 < hold_threshold_seconds:
		return
	set_process(false)
	hold_requested.emit(_source_ref.duplicate(true))


func accept_hold() -> void:
	if not _pressed_for_drag:
		return
	_holding = true
	set_process(true)


func reject_hold() -> void:
	_reset_gesture()


func end_gesture() -> void:
	var was_holding := _holding
	var was_pending := _pressed_for_drag and not _holding
	_reset_gesture()
	if was_holding:
		hold_released.emit(_source_ref.duplicate(true))
	elif was_pending:
		short_clicked.emit(_source_ref.duplicate(true))


func is_hold_active() -> bool:
	return _holding


func _on_mouse_exited() -> void:
	# Leaving a hold-enabled drink lane cancels restocking as authored. Ordinary
	# product sources, however, must remain pending long enough for the outgoing
	# motion event to start their native drag.
	if hold_enabled and (_holding or (_pressed_for_drag and cancel_pending_on_mouse_exit)):
		end_gesture()


func _reset_gesture() -> void:
	_pressed_for_drag = false
	_holding = false
	_hold_elapsed = 0.0
	set_process(false)
