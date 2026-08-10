extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const CHANNEL_TOLERANCE := 1.5 / 255.0

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate() as Workstation
	root.add_child(workstation)
	await process_frame
	workstation.set_process(false)
	var surface := workstation.pancake_surface
	surface.set_process(false)
	var model := workstation.pancake_model
	var material := surface.pancake_visual.material as ShaderMaterial

	_check(surface.pancake_visual != null, "scene owns a stable PancakeVisual node")
	_check(material != null and material.shader != null, "PancakeVisual owns the P0.3 shader material")
	var raw_texture := material.get_shader_parameter(&"raw_texture") as Texture2D
	var cooked_texture := material.get_shader_parameter(&"cooked_texture") as Texture2D
	var charred_texture := material.get_shader_parameter(&"charred_texture") as Texture2D
	var edge_texture := material.get_shader_parameter(&"edge_texture") as Texture2D
	var egg_surface_texture := material.get_shader_parameter(&"egg_surface_texture") as Texture2D
	var sweet_sauce_material_texture := material.get_shader_parameter(&"sweet_sauce_texture") as Texture2D
	var chili_sauce_material_texture := material.get_shader_parameter(&"chili_sauce_texture") as Texture2D
	_check(raw_texture != null and raw_texture.resource_path == "res://resources/art/workstation/textures/pancake_raw_texture_v1.png", "shader uses the approved raw pancake texture candidate")
	_check(cooked_texture != null and cooked_texture.resource_path == "res://resources/art/workstation/textures/pancake_cooked_texture_v1.png", "shader uses the approved cooked pancake texture candidate")
	_check(charred_texture != null and charred_texture.resource_path == "res://resources/art/workstation/textures/pancake_charred_texture_v1.png", "shader uses the confirmed charred pancake texture candidate")
	_check(edge_texture != null and edge_texture.resource_path == "res://resources/art/workstation/textures/pancake_edge_texture_v1.png", "shader uses the approved pancake edge texture candidate")
	_check(egg_surface_texture != null and egg_surface_texture.resource_path == "res://resources/art/workstation/textures/egg_spread_material_v1.png", "spread egg uses the dedicated hand-drawn material texture")
	_check(is_equal_approx(float(material.get_shader_parameter(&"pan_height_ratio")), model.parameters.pan_height_ratio), "shader mask uses the shared griddle aspect ratio")

	var center := Vector2i(model.grid_size / 2, model.grid_size / 2)
	var center_index := model.index_of(center)
	model.coverage = _with_value(model.coverage, center_index, 0.75)
	model.thickness = _with_value(model.thickness, center_index, model.parameters.maximum_thickness * 0.50)
	model.wetness = _with_value(model.wetness, center_index, 0.25)
	model.doneness = _with_value(model.doneness, center_index, 0.80)
	model.damage = _with_value(model.damage, center_index, 0.60)
	model.sauce_concentration = _with_value(model.sauce_concentration, center_index, model.parameters.sauce_maximum_concentration * 0.40)
	model.chili_sauce_concentration = _with_value(model.chili_sauce_concentration, center_index, model.parameters.sauce_maximum_concentration * 0.55)
	model.egg_white = _with_value(model.egg_white, center_index, model.parameters.egg_maximum_concentration * 0.35)
	model.egg_yolk = _with_value(model.egg_yolk, center_index, model.parameters.egg_maximum_concentration * 0.20)
	model.egg_doneness = _with_value(model.egg_doneness, center_index, 0.45)
	model.egg_state = PancakeModel.EggState.SPREADING
	model.yolk_broken = true
	model.revision += 1
	surface.force_texture_upload()
	await process_frame

	var diagnostics := surface.get_renderer_diagnostics()
	var field_texture := diagnostics.field_texture as ImageTexture
	var damage_texture := diagnostics.damage_texture as ImageTexture
	var sauce_texture := diagnostics.sauce_texture as ImageTexture
	var egg_texture := diagnostics.egg_texture as ImageTexture
	_check(field_texture != null and damage_texture != null and sauce_texture != null and egg_texture != null, "renderer owns reusable pancake, damage, sauce and egg data textures")
	_check(field_texture.get_width() == model.parameters.render_texture_size, "field texture uses configured render size")
	_check(damage_texture.get_width() == model.parameters.render_texture_size, "damage texture uses configured render size")
	_check(sauce_texture.get_width() == model.parameters.render_texture_size, "sauce texture uses configured render size")
	_check(egg_texture.get_width() == model.parameters.render_texture_size, "egg texture uses configured render size")
	var field_pixel := (diagnostics.field_image as Image).get_pixel(center.x, center.y)
	var damage_pixel := (diagnostics.damage_image as Image).get_pixel(center.x, center.y)
	var sauce_pixel := (diagnostics.sauce_image as Image).get_pixel(center.x, center.y)
	var fold_sweet_pixel := (diagnostics.fold_sweet_sauce_image as Image).get_pixel(center.x, center.y)
	var fold_chili_pixel := (diagnostics.fold_chili_sauce_image as Image).get_pixel(center.x, center.y)
	var egg_pixel := (diagnostics.egg_image as Image).get_pixel(center.x, center.y)
	var resized_sweet_material := sweet_sauce_material_texture.get_image()
	var resized_chili_material := chili_sauce_material_texture.get_image()
	resized_sweet_material.resize(model.parameters.render_texture_size, model.parameters.render_texture_size, Image.INTERPOLATE_BILINEAR)
	resized_chili_material.resize(model.parameters.render_texture_size, model.parameters.render_texture_size, Image.INTERPOLATE_BILINEAR)
	var expected_sweet_rgb := resized_sweet_material.get_pixel(center.x, center.y)
	var expected_chili_rgb := resized_chili_material.get_pixel(center.x, center.y)
	var expected_sweet_alpha := smoothstep(0.015, 0.32, 0.40) * 0.82
	var expected_chili_alpha := smoothstep(0.015, 0.32, 0.55) * 0.80
	_check(absf(field_pixel.r - 0.75) <= CHANNEL_TOLERANCE, "coverage maps to the field texture red channel")
	_check(absf(field_pixel.g - 0.50) <= CHANNEL_TOLERANCE, "normalized thickness maps to the field texture green channel")
	_check(absf(field_pixel.b - 0.25) <= CHANNEL_TOLERANCE, "wetness maps to the field texture blue channel")
	_check(absf(field_pixel.a - 0.80) <= CHANNEL_TOLERANCE, "doneness maps to the field texture alpha channel")
	_check(absf(damage_pixel.r - 0.60) <= CHANNEL_TOLERANCE, "damage maps to the R8 damage texture")
	_check((diagnostics.damage_image as Image).get_format() == Image.FORMAT_R8, "damage upload uses a compact single-channel texture")
	_check(absf(sauce_pixel.r - 0.40) <= CHANNEL_TOLERANCE, "sauce concentration maps to the R8 sauce texture")
	_check((diagnostics.sauce_image as Image).get_format() == Image.FORMAT_R8, "sauce upload uses a compact single-channel texture")
	_check(_rgb_matches(fold_sweet_pixel, expected_sweet_rgb) and absf(fold_sweet_pixel.a - expected_sweet_alpha) <= CHANNEL_TOLERANCE, "folded sweet sauce keeps the surface material RGB and shader opacity curve")
	_check(_rgb_matches(fold_chili_pixel, expected_chili_rgb) and absf(fold_chili_pixel.a - expected_chili_alpha) <= CHANNEL_TOLERANCE, "folded chili sauce keeps the surface material RGB and shader opacity curve")
	_check(material.shader.code.contains("stationary_sauce_visibility") and not material.shader.code.contains("sauce) * filling_visibility"), "stationary sauce remains unchanged until real fold geometry occludes it")
	_check(absf(egg_pixel.r - 0.35) <= CHANNEL_TOLERANCE and absf(egg_pixel.g - 0.20) <= CHANNEL_TOLERANCE, "egg white and yolk map to independent texture channels")
	_check(absf(egg_pixel.b - 0.45) <= CHANNEL_TOLERANCE, "egg doneness maps to the egg texture blue channel")

	var initial_upload_count := int(diagnostics.upload_count)
	surface.set("_elapsed", 0.0)
	model.changed.emit()
	surface._process(0.49 / surface.heatmap_update_hz)
	_check(int(surface.get_renderer_diagnostics().upload_count) == initial_upload_count, "renderer does not upload before the configured interval")
	surface._process(0.52 / surface.heatmap_update_hz)
	_check(int(surface.get_renderer_diagnostics().upload_count) == initial_upload_count + 1, "renderer uploads after the configured interval")

	var stable_field_rid := field_texture.get_rid()
	var stable_damage_rid := damage_texture.get_rid()
	var stable_sauce_rid := sauce_texture.get_rid()
	var stable_egg_rid := egg_texture.get_rid()
	for iteration in 120:
		model.wetness = _with_value(model.wetness, center_index, float(iteration % 101) / 100.0)
		model.revision += 1
		surface.force_texture_upload()
	var after_stress := surface.get_renderer_diagnostics()
	_check((after_stress.field_texture as ImageTexture).get_rid() == stable_field_rid, "steady field uploads reuse one GPU texture")
	_check((after_stress.damage_texture as ImageTexture).get_rid() == stable_damage_rid, "steady damage uploads reuse one GPU texture")
	_check((after_stress.sauce_texture as ImageTexture).get_rid() == stable_sauce_rid, "steady sauce uploads reuse one GPU texture")
	_check((after_stress.egg_texture as ImageTexture).get_rid() == stable_egg_rid, "steady egg uploads reuse one GPU texture")
	_check(int(after_stress.last_uploaded_revision) == model.revision, "renderer records the current model revision")

	surface.set_heatmap_field(PancakeModel.FIELD_THICKNESS)
	_check(int(material.get_shader_parameter(&"view_mode")) == 2, "debug view switches the same shader to thickness data")
	surface.set_heatmap_field(PancakeHeatmap.VIEW_APPEARANCE)
	_check(int(material.get_shader_parameter(&"view_mode")) == 0, "appearance view restores shader composition")

	surface.render_texture_size = 64
	surface.force_texture_upload()
	_check(int(surface.get_renderer_diagnostics().texture_size) == 64, "render texture size is runtime-configurable")

	workstation.queue_free()
	await process_frame
	await process_frame
	_finish()


func _with_value(values: PackedFloat32Array, index: int, value: float) -> PackedFloat32Array:
	var result := values.duplicate()
	result[index] = value
	return result


func _rgb_matches(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) <= CHANNEL_TOLERANCE and absf(actual.g - expected.g) <= CHANNEL_TOLERANCE and absf(actual.b - expected.b) <= CHANNEL_TOLERANCE


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("P0.3 renderer self-check PASS")
		quit(0)
	else:
		print("P0.3 renderer self-check FAIL (%d)" % _failures.size())
		quit(1)
