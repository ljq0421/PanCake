class_name ProductDragSource
extends TextureButton

const HOLD_PROGRESS_RING_SCRIPT := preload("res://scripts/ui/hold_progress_ring.gd")

signal short_clicked(source_ref: Dictionary)
signal drag_started(source_ref: Dictionary)
signal drag_ended(source_ref: Dictionary, successful: bool)
signal hold_requested(source_ref: Dictionary)
signal hold_advanced(source_ref: Dictionary, delta: float)
signal hold_released(source_ref: Dictionary)
signal hover_changed(source_ref: Dictionary, hovering: bool)

## Keep the drag threshold low enough that a deliberate drag starts immediately,
## without turning a normal click into a drag.
@export var drag_threshold_pixels := 4.0
@export var hold_enabled := false
@export var hold_threshold_seconds := 0.1
@export var native_drag_enabled := true
@export var cancel_pending_on_mouse_exit := true
@export var drag_cancel_tolerance_pixels := 8.0
## Visual used under the pointer during native dragging. This remains separate
## from texture_normal because some sources deliberately use an invisible
## texture solely as a reliable hit target.
@export var drag_preview_texture: Texture2D
## The preview's canvas size. Ingredient sources set this to the same rendered
## size used on the pancake so the item neither shrinks nor grows mid-drag.
@export var drag_preview_size := Vector2(72.0, 72.0)
## Visual-only offset for the native drag preview, relative to the pointer.
## This lets a source remain visible without moving the actual drop position.
@export var drag_preview_offset := Vector2.ZERO
## Text shown in a native UI preview when the product deliberately has no art
## asset yet. This keeps placeholder-only products recognizable while dragging.
@export var drag_preview_text := ""

var _source_ref: Dictionary = {}
var _press_position := Vector2.ZERO
var _pressed_for_drag := false
var _drag_available := false
var _holding := false
var _hold_elapsed := 0.0
var _native_drag_in_progress := false
var _drop_forward_target: Control
var _hold_progress_ring: HoldProgressRing
var _hover_rest_modulate := Color.WHITE
var _hovered := false
var _base_drag_threshold_pixels := 4.0
var _effective_cancel_tolerance_pixels := 8.0
var _result_feedback_tween: Tween
var _selection_outline: Panel
## Optional alpha-tested layers that define the clickable silhouette.  A source
## without these layers keeps the regular rectangular hit area.
var _alpha_hit_regions: Array[Dictionary] = []
var _alpha_hit_images: Dictionary = {}


func _ready() -> void:
	_base_drag_threshold_pixels = maxf(drag_threshold_pixels, 1.0)
	_effective_cancel_tolerance_pixels = maxf(drag_cancel_tolerance_pixels, 0.0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_create_hold_progress_ring()
	_create_selection_outline()
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_settings"):
		_apply_interaction_settings(Dictionary(session.call("get_settings")))
		var settings_signal := Signal(session, &"settings_changed")
		if not settings_signal.is_connected(_apply_interaction_settings):
			settings_signal.connect(_apply_interaction_settings)
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
	_refresh_cursor()
	if not available:
		_set_hold_progress_visible(false)


func set_drag_available(value: bool) -> void:
	_drag_available = value
	_refresh_cursor()


func set_hold_progress(progress_ratio: float) -> void:
	if _hold_progress_ring == null:
		return
	_hold_progress_ring.set_progress_ratio(progress_ratio)
	_set_hold_progress_visible(_pressed_for_drag or _holding)


func play_result_feedback(success: bool) -> void:
	if _result_feedback_tween != null and _result_feedback_tween.is_valid():
		_result_feedback_tween.kill()
	var rest_color := _hover_rest_modulate * Color(1.06, 1.04, 0.94, 1.0) if _hovered else _hover_rest_modulate
	var feedback_color := Color(0.72, 1.0, 0.72, rest_color.a) if success else Color(1.0, 0.48, 0.44, rest_color.a)
	_result_feedback_tween = create_tween()
	_result_feedback_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_result_feedback_tween.tween_property(self, "self_modulate", feedback_color, 0.06)
	_result_feedback_tween.tween_property(self, "self_modulate", rest_color, 0.08)


func set_selection_highlight(value: bool) -> void:
	if _selection_outline != null:
		_selection_outline.visible = value


func set_drag_preview_texture(value: Texture2D) -> void:
	drag_preview_texture = value


func set_drag_preview_text(value: String) -> void:
	drag_preview_text = value


func set_drag_preview_size(value: Vector2) -> void:
	drag_preview_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))


func set_drag_preview_offset(value: Vector2) -> void:
	drag_preview_offset = value


func set_drop_forward_target(target: Control) -> void:
	_drop_forward_target = target


func is_native_drag_active() -> bool:
	return _native_drag_in_progress


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if _drop_forward_target == null or not is_instance_valid(_drop_forward_target):
		return false
	return bool(_drop_forward_target.call("_can_drop_data", _forwarded_target_position(at_position), data))


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _drop_forward_target == null or not is_instance_valid(_drop_forward_target):
		return
	_drop_forward_target.call("_drop_data", _forwarded_target_position(at_position), data)


func _forwarded_target_position(local_position: Vector2) -> Vector2:
	var canvas_position := get_global_transform_with_canvas() * local_position
	return _drop_forward_target.get_global_transform_with_canvas().affine_inverse() * canvas_position


func set_alpha_hit_regions(regions: Array[Dictionary]) -> void:
	_alpha_hit_regions.clear()
	for region in regions:
		var texture := region.get("texture") as Texture2D
		var rect := region.get("rect", Rect2()) as Rect2
		if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var texture_id := texture.get_instance_id()
		var image := _alpha_hit_images.get(texture_id) as Image
		if image == null:
			image = texture.get_image()
			_alpha_hit_images[texture_id] = image
		if image == null or image.is_empty():
			continue
		_alpha_hit_regions.append({"image": image, "rect": rect})


func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	if _alpha_hit_regions.is_empty():
		return true
	for region in _alpha_hit_regions:
		var rect := region["rect"] as Rect2
		if not rect.has_point(point):
			continue
		var image := region["image"] as Image
		var pixel_x := clampi(floori((point.x - rect.position.x) / rect.size.x * float(image.get_width())), 0, image.get_width() - 1)
		var pixel_y := clampi(floori((point.y - rect.position.y) / rect.size.y * float(image.get_height())), 0, image.get_height() - 1)
		if image.get_pixel(pixel_x, pixel_y).a > 0.0:
			return true
	return false


func _process(delta: float) -> void:
	if (_pressed_for_drag or _holding) and cancel_pending_on_mouse_exit:
		var viewport := get_viewport()
		var local_pointer := get_global_transform_with_canvas().affine_inverse() * viewport.get_mouse_position() if viewport != null else Vector2.ZERO
		if viewport != null and not Rect2(Vector2.ZERO, size).grow(_effective_cancel_tolerance_pixels).has_point(local_pointer):
			_cancel_gesture_from_exit()
			return
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
	if _hold_progress_ring != null:
		_hold_progress_ring.set_progress_ratio(0.0)
	_set_hold_progress_visible(false)
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
		# A drag-start handler may reserve the backing inventory. If that
		# transaction fails, it disables dragging before native drag data is
		# created so a stale source can never produce a phantom portion.
		if not _drag_available:
			return
		if not perform_native_drag or not native_drag_enabled:
			return
		_native_drag_in_progress = true
		var preview := _new_drag_preview()
		force_drag({"kind": &"product_source", "source_ref": _source_ref.duplicate(true)}, preview)


func _new_drag_preview() -> Control:
	var preview_texture := drag_preview_texture if drag_preview_texture != null else texture_normal
	if preview_texture != null:
		var texture_preview := TextureRect.new()
		texture_preview.texture = preview_texture
		texture_preview.offset_transform_enabled = drag_preview_offset != Vector2.ZERO
		texture_preview.offset_transform_visual_only = true
		texture_preview.offset_transform_position = drag_preview_offset
		texture_preview.custom_minimum_size = drag_preview_size
		texture_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
		texture_preview.z_index = z_index + 1
		return texture_preview
	var text_preview := Panel.new()
	text_preview.custom_minimum_size = drag_preview_size
	text_preview.size = drag_preview_size
	text_preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	text_preview.z_index = z_index + 1
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e86b28")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#fff0b6")
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	text_preview.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.text = drag_preview_text if not drag_preview_text.is_empty() else tooltip_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#fff7ce"))
	label.add_theme_color_override("font_outline_color", Color("#722506"))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_preview.add_child(label)
	return text_preview


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
	set_hold_progress(0.0)
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
	if _hovered:
		_hovered = false
		self_modulate = _hover_rest_modulate
		hover_changed.emit(_source_ref.duplicate(true), false)
	# The process loop applies the configured tolerance.  A zero-tolerance hold
	# cancels immediately without turning the exit into a short click.
	if hold_enabled and (_holding or _pressed_for_drag) and cancel_pending_on_mouse_exit and _effective_cancel_tolerance_pixels <= 0.0:
		_cancel_gesture_from_exit()


func _reset_gesture() -> void:
	_pressed_for_drag = false
	_holding = false
	_hold_elapsed = 0.0
	_set_hold_progress_visible(false)
	set_process(false)


func _on_mouse_entered() -> void:
	if disabled:
		return
	_hovered = true
	_hover_rest_modulate = self_modulate
	# This high-frequency affordance is intentionally instantaneous; motion here
	# would make repeated ingredient selection feel slower.
	self_modulate = _hover_rest_modulate * Color(1.06, 1.04, 0.94, 1.0)
	hover_changed.emit(_source_ref.duplicate(true), true)


func _cancel_gesture_from_exit() -> void:
	var was_holding := _holding
	_reset_gesture()
	if was_holding:
		hold_released.emit(_source_ref.duplicate(true))


func _create_hold_progress_ring() -> void:
	_hold_progress_ring = HOLD_PROGRESS_RING_SCRIPT.new()
	_hold_progress_ring.name = "HoldProgress"
	_hold_progress_ring.z_index = 200
	_hold_progress_ring.set_anchors_preset(Control.PRESET_CENTER)
	_hold_progress_ring.position = Vector2(-38.0, -38.0)
	_hold_progress_ring.size = Vector2(76.0, 76.0)
	_hold_progress_ring.visible = false
	add_child(_hold_progress_ring)


func _create_selection_outline() -> void:
	_selection_outline = Panel.new()
	_selection_outline.name = "SelectionOutline"
	_selection_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	_selection_outline.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.76, 0.18, 0.12)
	style.border_color = Color("ffe17a")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.expand_margin_left = 3.0
	style.expand_margin_top = 3.0
	style.expand_margin_right = 3.0
	style.expand_margin_bottom = 3.0
	_selection_outline.add_theme_stylebox_override("panel", style)
	_selection_outline.visible = false
	add_child(_selection_outline)


func _set_hold_progress_visible(value: bool) -> void:
	if _hold_progress_ring != null:
		_hold_progress_ring.visible = value and hold_enabled


func _refresh_cursor() -> void:
	if disabled:
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	elif native_drag_enabled and _drag_available:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _apply_interaction_settings(settings: Dictionary) -> void:
	var sensitivity := clampf(float(settings.get("drag_sensitivity", 100.0)), 50.0, 150.0)
	var normalized := (sensitivity - 50.0) / 100.0
	drag_threshold_pixels = _base_drag_threshold_pixels * lerpf(1.5, 0.5, normalized)
	_effective_cancel_tolerance_pixels = lerpf(4.0, 12.0, normalized)
