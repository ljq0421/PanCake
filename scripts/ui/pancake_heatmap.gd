class_name PancakeHeatmap
extends Control

signal pointer_started(local_position: Vector2)
signal pointer_ended(local_position: Vector2)
signal cancel_requested

const TRACE_LIMIT := 160
const VIEW_APPEARANCE: StringName = &"appearance"
const VIEW_MODES := {
	VIEW_APPEARANCE: 0,
	PancakeModel.FIELD_COVERAGE: 1,
	PancakeModel.FIELD_THICKNESS: 2,
	PancakeModel.FIELD_WETNESS: 3,
	PancakeModel.FIELD_DONENESS: 4,
	PancakeModel.FIELD_DAMAGE: 5,
	PancakeModel.FIELD_SAUCE_CONCENTRATION: 6,
	PancakeModel.FIELD_EGG_WHITE: 7,
}

@export_range(1.0, 60.0, 1.0) var heatmap_update_hz: float = 12.0
@export_range(32, 512, 1) var render_texture_size: int = 128

@onready var pancake_visual: TextureRect = %PancakeVisual

var model: PancakeModel
var heatmap_field: StringName = VIEW_APPEARANCE
var mouse_grid_cell := Vector2i(-1, -1)
var pointer_local_position := Vector2.ZERO
var pointer_pressed := false
var cursor_radius_pixels: float = 8.0
var cursor_is_t_spreader := false
var spreader_radial_angle := 0.0
var spreader_motion_valid := false
@export var draw_spreader_fallback := true
var _dirty := true
var _elapsed := 0.0
var _field_texture: ImageTexture
var _damage_texture: ImageTexture
var _sauce_texture: ImageTexture
var _chili_sauce_texture: ImageTexture
var _egg_texture: ImageTexture
var _last_field_image: Image
var _last_damage_image: Image
var _last_sauce_image: Image
var _last_chili_sauce_image: Image
var _last_egg_image: Image
var _trace_points := PackedVector2Array()
var _allocated_texture_size := 0
var _upload_count := 0
var _last_uploaded_revision := -1
var _source_indices := PackedInt32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents = true
	if pancake_visual.material != null:
		pancake_visual.material = pancake_visual.material.duplicate()
	_apply_view_mode()
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _dirty and _elapsed >= 1.0 / maxf(heatmap_update_hz, 1.0):
		_elapsed = 0.0
		_rebuild_heatmap_texture()


func set_model(value: PancakeModel) -> void:
	if model != null and model.changed.is_connected(_on_model_changed):
		model.changed.disconnect(_on_model_changed)
	model = value
	if model != null:
		model.changed.connect(_on_model_changed)
	_source_indices.clear()
	_dirty = true
	_rebuild_heatmap_texture()


func set_heatmap_field(field_name: StringName) -> void:
	if not VIEW_MODES.has(field_name):
		return
	heatmap_field = field_name
	_apply_view_mode()
	queue_redraw()


func force_texture_upload() -> void:
	_rebuild_heatmap_texture()


func set_fold_visual_state(
	left_progress: float,
	right_progress: float,
	package_hidden: bool = false
) -> void:
	if not is_instance_valid(pancake_visual):
		return
	var shader_material := pancake_visual.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter(&"fold_left_progress", clampf(left_progress, 0.0, 1.0))
	shader_material.set_shader_parameter(&"fold_right_progress", clampf(right_progress, 0.0, 1.0))
	shader_material.set_shader_parameter(&"package_hidden", 1.0 if package_hidden else 0.0)
	if model != null:
		shader_material.set_shader_parameter(&"fold_left_line_ratio", model.parameters.fold_left_line_ratio)
		shader_material.set_shader_parameter(&"fold_right_line_ratio", model.parameters.fold_right_line_ratio)


func get_renderer_diagnostics() -> Dictionary:
	return {
		"texture_size": _allocated_texture_size,
		"update_hz": heatmap_update_hz,
		"upload_count": _upload_count,
		"last_uploaded_revision": _last_uploaded_revision,
		"field_texture": _field_texture,
		"damage_texture": _damage_texture,
		"sauce_texture": _sauce_texture,
		"chili_sauce_texture": _chili_sauce_texture,
		"egg_texture": _egg_texture,
		"field_image": _last_field_image,
		"damage_image": _last_damage_image,
		"sauce_image": _last_sauce_image,
		"chili_sauce_image": _last_chili_sauce_image,
		"egg_image": _last_egg_image,
	}


func _on_model_changed() -> void:
	_dirty = true


func _gui_input(event: InputEvent) -> void:
	if model == null:
		return
	if event is InputEventMouseMotion:
		pointer_local_position = event.position
		mouse_grid_cell = PancakeSpace.local_to_grid(event.position, size, model.grid_size)
		if pointer_pressed and PancakeSpace.is_inside_pan(event.position, size, model.parameters.pan_height_ratio):
			_append_trace(event.position)
		queue_redraw()
	elif event is InputEventMouseButton:
		pointer_local_position = event.position
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and PancakeSpace.is_inside_pan(event.position, size, model.parameters.pan_height_ratio):
			pointer_pressed = true
			mouse_grid_cell = PancakeSpace.local_to_grid(event.position, size, model.grid_size)
			_append_trace(event.position)
			pointer_started.emit(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			pointer_pressed = false
			pointer_ended.emit(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			pointer_pressed = false
			cancel_requested.emit()
			accept_event()


func _append_trace(point: Vector2) -> void:
	_trace_points.append(point)
	if _trace_points.size() > TRACE_LIMIT:
		_trace_points.remove_at(0)


func clear_trace() -> void:
	_trace_points.clear()
	queue_redraw()


func _rebuild_heatmap_texture() -> void:
	if model == null or not is_instance_valid(pancake_visual):
		return
	var texture_size := clampi(render_texture_size, 32, 512)
	_ensure_source_indices(texture_size)
	var pixel_count := texture_size * texture_size
	var field_pixels := PackedByteArray()
	var damage_pixels := PackedByteArray()
	var sauce_pixels := PackedByteArray()
	var chili_sauce_pixels := PackedByteArray()
	var egg_pixels := PackedByteArray()
	field_pixels.resize(pixel_count * 4)
	damage_pixels.resize(pixel_count)
	sauce_pixels.resize(pixel_count)
	chili_sauce_pixels.resize(pixel_count)
	egg_pixels.resize(pixel_count * 4)
	var inverse_maximum_thickness := 1.0 / maxf(model.parameters.maximum_thickness, 0.001)
	var inverse_maximum_sauce := 1.0 / maxf(model.parameters.sauce_maximum_concentration, 0.001)
	var inverse_maximum_egg := 1.0 / maxf(model.parameters.egg_maximum_concentration, 0.001)
	var egg_visible := model.yolk_broken and not model.is_flipped
	for target_index in pixel_count:
		var source_index := _source_indices[target_index]
		var coverage_byte := roundi(clampf(model.coverage[source_index], 0.0, 1.0) * 255.0)
		var thickness_byte := roundi(clampf(model.thickness[source_index] * inverse_maximum_thickness, 0.0, 1.0) * 255.0)
		var wetness_byte := roundi(clampf(model.wetness[source_index], 0.0, 1.0) * 255.0)
		var doneness_byte := roundi(clampf(model.visible_doneness_at(source_index), 0.0, 1.0) * 255.0)
		field_pixels.encode_u32(target_index * 4, coverage_byte | (thickness_byte << 8) | (wetness_byte << 16) | (doneness_byte << 24))
		damage_pixels[target_index] = roundi(clampf(model.damage[source_index], 0.0, 1.0) * 255.0)
		sauce_pixels[target_index] = roundi(clampf(model.sauce_concentration[source_index] * inverse_maximum_sauce, 0.0, 1.0) * 255.0)
		chili_sauce_pixels[target_index] = roundi(clampf(model.chili_sauce_concentration[source_index] * inverse_maximum_sauce, 0.0, 1.0) * 255.0)
		var egg_white_byte := 0
		var egg_yolk_byte := 0
		var egg_doneness_byte := 0
		var egg_alpha_byte := 0
		if egg_visible:
			egg_white_byte = roundi(clampf(model.egg_white[source_index] * inverse_maximum_egg, 0.0, 1.0) * 255.0)
			egg_yolk_byte = roundi(clampf(model.egg_yolk[source_index] * inverse_maximum_egg, 0.0, 1.0) * 255.0)
			egg_doneness_byte = roundi(clampf(model.egg_doneness[source_index], 0.0, 1.0) * 255.0)
			egg_alpha_byte = roundi(clampf((model.egg_white[source_index] + model.egg_yolk[source_index]) * inverse_maximum_egg, 0.0, 1.0) * 255.0)
		egg_pixels.encode_u32(target_index * 4, egg_white_byte | (egg_yolk_byte << 8) | (egg_doneness_byte << 16) | (egg_alpha_byte << 24))
	var field_image := Image.create_from_data(texture_size, texture_size, false, Image.FORMAT_RGBA8, field_pixels)
	var damage_image := Image.create_from_data(texture_size, texture_size, false, Image.FORMAT_R8, damage_pixels)
	var sauce_image := Image.create_from_data(texture_size, texture_size, false, Image.FORMAT_R8, sauce_pixels)
	var chili_sauce_image := Image.create_from_data(texture_size, texture_size, false, Image.FORMAT_R8, chili_sauce_pixels)
	var egg_image := Image.create_from_data(texture_size, texture_size, false, Image.FORMAT_RGBA8, egg_pixels)
	_last_field_image = field_image
	_last_damage_image = damage_image
	_last_sauce_image = sauce_image
	_last_chili_sauce_image = chili_sauce_image
	_last_egg_image = egg_image
	if _field_texture == null or _damage_texture == null or _sauce_texture == null or _chili_sauce_texture == null or _egg_texture == null or _allocated_texture_size != texture_size:
		_field_texture = ImageTexture.create_from_image(field_image)
		_damage_texture = ImageTexture.create_from_image(damage_image)
		_sauce_texture = ImageTexture.create_from_image(sauce_image)
		_chili_sauce_texture = ImageTexture.create_from_image(chili_sauce_image)
		_egg_texture = ImageTexture.create_from_image(egg_image)
		_allocated_texture_size = texture_size
	else:
		_field_texture.update(field_image)
		_damage_texture.update(damage_image)
		_sauce_texture.update(sauce_image)
		_chili_sauce_texture.update(chili_sauce_image)
		_egg_texture.update(egg_image)
	pancake_visual.texture = _field_texture
	var shader_material := pancake_visual.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(&"field_texture", _field_texture)
		shader_material.set_shader_parameter(&"damage_texture", _damage_texture)
		shader_material.set_shader_parameter(&"sauce_texture", _sauce_texture)
		shader_material.set_shader_parameter(&"chili_sauce_field", _chili_sauce_texture)
		shader_material.set_shader_parameter(&"egg_texture", _egg_texture)
		shader_material.set_shader_parameter(&"field_texel_size", Vector2.ONE / float(texture_size))
		shader_material.set_shader_parameter(&"pan_height_ratio", model.parameters.pan_height_ratio)
		shader_material.set_shader_parameter(&"view_mode", int(VIEW_MODES.get(heatmap_field, 0)))
	_dirty = false
	_upload_count += 1
	_last_uploaded_revision = model.revision
	queue_redraw()


func _ensure_source_indices(texture_size: int) -> void:
	var pixel_count := texture_size * texture_size
	if _source_indices.size() == pixel_count and _allocated_texture_size == texture_size:
		return
	_source_indices.resize(pixel_count)
	for y in texture_size:
		var source_y := mini(floori((float(y) + 0.5) / float(texture_size) * model.grid_size), model.grid_size - 1)
		for x in texture_size:
			var source_x := mini(floori((float(x) + 0.5) / float(texture_size) * model.grid_size), model.grid_size - 1)
			_source_indices[y * texture_size + x] = source_y * model.grid_size + source_x


func _apply_view_mode() -> void:
	if not is_instance_valid(pancake_visual):
		return
	var shader_material := pancake_visual.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(&"view_mode", int(VIEW_MODES.get(heatmap_field, 0)))


func _draw() -> void:
	if heatmap_field != VIEW_APPEARANCE:
		var grid_step := size.x / 8.0
		for index in range(1, 8):
			var position := grid_step * index
			draw_line(Vector2(position, 0), Vector2(position, size.y), Color(1, 1, 1, 0.10), 1.0)
			draw_line(Vector2(0, position), Vector2(size.x, position), Color(1, 1, 1, 0.10), 1.0)
	if _trace_points.size() > 1:
		draw_polyline(_trace_points, Color(0.96, 0.96, 1.0, 0.76), 3.0, true)
	if mouse_grid_cell.x >= 0 and model != null:
		var local_position := PancakeSpace.grid_to_local(mouse_grid_cell, size, model.grid_size)
		if cursor_is_t_spreader and draw_spreader_fallback:
			_draw_t_spreader(local_position)
		else:
			draw_circle(local_position, cursor_radius_pixels, Color.WHITE, false, 2.0)
	var center := size * 0.5
	var radii := Vector2(size.x * 0.5 - 2.0, size.y * 0.5 * model.parameters.pan_height_ratio - 2.0)
	var outline := PackedVector2Array()
	for step in 65:
		var angle := TAU * float(step) / 64.0
		outline.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(outline, Color(0.16, 0.11, 0.08, 0.95), 8.0, true)


func _draw_t_spreader(position: Vector2) -> void:
	var radial := Vector2(cos(spreader_radial_angle), sin(spreader_radial_angle))
	var tangent := radial.orthogonal()
	var bar_half_length := cursor_radius_pixels
	var stem_length := cursor_radius_pixels * 0.72
	var color := Color(0.48, 0.96, 0.92, 0.98) if spreader_motion_valid else Color(1.0, 0.78, 0.32, 0.92)
	draw_line(position - tangent * bar_half_length, position + tangent * bar_half_length, color, 8.0, true)
	draw_line(position, position - radial * stem_length, color, 8.0, true)
	draw_circle(position, 6.0, Color(0.16, 0.09, 0.05, 0.98))
