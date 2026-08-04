extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var workstation := main.get_node("Workstation") as Workstation
	workstation.set_process(false)
	var surface := workstation.pancake_surface
	_prepare_sauce_phase(workstation)

	_check(workstation.sauce_brush_button != null and workstation.sauce_refill_button != null, "workstation scene owns stable brush and hold-to-squeeze controls")
	_check(workstation.sauce_blob_overlay != null, "workstation scene owns a stable visible sauce-blob overlay")
	_check(workstation.get_node_or_null("SafeArea/RightRack/BlotterButton") == null, "removed blotter is absent from the scene")
	_check(is_zero_approx(float(workstation.sauce_tool_state.load)), "pancake starts without an unspread sauce blob")

	workstation.sauce_refill_button.button_down.emit()
	for frame in 30:
		workstation._process(1.0 / 60.0)
	workstation.sauce_refill_button.button_up.emit()
	var short_squeeze_load := float(workstation.sauce_tool_state.load)
	var expected_short_squeeze := workstation.parameters.sauce_squeeze_initial_amount + workstation.parameters.sauce_squeeze_rate * 0.5
	_check(absf(short_squeeze_load - expected_short_squeeze) <= 0.01, "click plus half-second hold creates a proportional sauce blob on the pancake")
	_check(workstation.sauce_blob_overlay.visible, "squeezed sauce has immediate visible pancake feedback")
	workstation.sauce_refill_button.button_down.emit()
	for frame in 120:
		workstation._process(1.0 / 60.0)
	workstation.sauce_refill_button.button_up.emit()
	_check(is_equal_approx(float(workstation.sauce_tool_state.load), workstation.parameters.sauce_brush_capacity), "long hold stops at the maximum sauce-blob amount")
	var sweet_load := float(workstation.sauce_tool_state.load)
	workstation.chili_sauce_refill_button.button_down.emit()
	for frame in 30:
		workstation._process(1.0 / 60.0)
	workstation.chili_sauce_refill_button.button_up.emit()
	_check(float(workstation.sauce_tool_state.load) > 0.0, "chili bottle creates an independent chili sauce blob")
	workstation.sauce_refill_button.button_down.emit()
	workstation.sauce_refill_button.button_up.emit()
	_check(is_equal_approx(float(workstation.sauce_tool_state.load), sweet_load), "switching sauce bottles preserves the other unspread sauce amount")

	workstation.sauce_brush_button.pressed.emit()
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SAUCE_BRUSH, "sauce brush button selects the brush tool")
	var load_before := float(workstation.sauce_tool_state.load)
	var surface_center := surface.size * 0.5
	var brush_half_width := surface.size.x * 0.32
	var brush_half_height := surface.size.y * 0.16
	_brush_path(workstation, surface, [
		surface_center + Vector2(-brush_half_width, -brush_half_height),
		surface_center + Vector2(brush_half_width, -brush_half_height),
		surface_center + Vector2(brush_half_width, brush_half_height),
		surface_center + Vector2(-brush_half_width, brush_half_height),
	])
	var sauce_after_first_stroke := workstation.pancake_model.total_sauce()
	_check(sauce_after_first_stroke > 0.0, "brush path deposits sauce through the workstation interaction path")
	_check(float(workstation.sauce_tool_state.load) < load_before, "painted area consumes the visible sauce blob")
	_check(workstation.sauce_status_label.text.contains("酱料评分"), "workstation displays the model-backed sauce score")

	var center_cell := workstation.pancake_model.index_of(Vector2i(64, 64))
	var concentration_after_first := workstation.pancake_model.sauce_concentration[center_cell]
	workstation.sauce_refill_button.button_down.emit()
	for frame in 120:
		workstation._process(1.0 / 60.0)
	workstation.sauce_refill_button.button_up.emit()
	var same_press_layers := _brush_out_and_back(
		workstation,
		surface,
		surface_center - Vector2(surface.size.x * 0.2, 0.0),
		surface_center + Vector2(surface.size.x * 0.2, 0.0),
		center_cell
	)
	_check(same_press_layers[0] > concentration_after_first, "the first pass adds a concentration layer")
	_check(same_press_layers[1] > same_press_layers[0], "returning over the same area without releasing adds another concentration layer")

	workstation.set_heatmap_field(PancakeModel.FIELD_SAUCE_CONCENTRATION)
	var material := surface.pancake_visual.material as ShaderMaterial
	_check(surface.heatmap_field == PancakeModel.FIELD_SAUCE_CONCENTRATION and int(material.get_shader_parameter(&"view_mode")) == 6, "sauce debug view reads the shared renderer data")
	workstation.set_heatmap_field(PancakeHeatmap.VIEW_APPEARANCE)

	_cancel_surface(surface, surface_center)
	_check(workstation.tool_controller.current_tool == ToolController.Tool.NONE, "right mouse returns the sauce brush")
	workstation.reset_pancake()
	_check(is_zero_approx(workstation.pancake_model.total_sauce()), "reset clears sauce concentration")
	_check(is_zero_approx(float(workstation.sauce_tool_state.load)) and not workstation.sauce_blob_overlay.visible, "reset removes all unspread sauce blobs")

	main.queue_free()
	await process_frame
	await process_frame
	_finish()


func _prepare_sauce_phase(workstation: Workstation) -> void:
	var model := workstation.pancake_model
	for y in model.grid_size:
		for x in model.grid_size:
			if not model.is_inside_pan(Vector2(x, y), 0.84):
				continue
			var index := y * model.grid_size + x
			model.coverage[index] = 1.0
			model.thickness[index] = 0.42
			model.wetness[index] = 0.20
	_check(bool(workstation.p1_session.confirm_spread(model).success), "sauce fixture reaches first-side cooking through the guarded flow")
	var center := Vector2(model.grid_size - 1, model.grid_size - 1) * 0.5
	workstation.ingredient_model.place(IngredientModel.EGG, center, 0.0, model)
	_seed_even_egg(model)
	model.doneness.fill(0.62)
	_check(bool(workstation.p1_session.request_flip(model, workstation.ingredient_model).success), "sauce fixture flips directly into the sauce phase through the guarded flow")
	workstation._refresh_p1_ui()


func _seed_even_egg(model: PancakeModel) -> void:
	var center := Vector2(model.grid_size - 1, model.grid_size - 1) * 0.5
	var radii := Vector2(float(model.grid_size) * 0.5, float(model.grid_size) * 0.5 * model.parameters.pan_height_ratio)
	for index in model.cell_count:
		if model.coverage[index] <= 0.0:
			continue
		var position := Vector2(index % model.grid_size, index / model.grid_size)
		if ((position - center) / radii).length() > 0.74:
			continue
		model.egg_white[index] = 0.08
		model.egg_yolk[index] = 0.03
	model.egg_state = PancakeModel.EggState.SPREADING
	model.yolk_broken = true


func _brush_path(workstation: Workstation, surface: PancakeHeatmap, points: Array[Vector2]) -> void:
	_press_surface(surface, points[0])
	for point_index in range(1, points.size()):
		var start := points[point_index - 1]
		var finish := points[point_index]
		for frame in range(1, 61):
			var position := start.lerp(finish, float(frame) / 60.0)
			_move_surface(surface, position)
			workstation._process(1.0 / 60.0)
	_release_surface(surface, points[-1])


func _brush_out_and_back(workstation: Workstation, surface: PancakeHeatmap, start: Vector2, finish: Vector2, center_cell: int) -> PackedFloat32Array:
	_press_surface(surface, start)
	for frame in range(1, 61):
		_move_surface(surface, start.lerp(finish, float(frame) / 60.0))
		workstation._process(1.0 / 60.0)
	var after_forward := workstation.pancake_model.sauce_concentration[center_cell]
	for frame in range(1, 61):
		_move_surface(surface, finish.lerp(start, float(frame) / 60.0))
		workstation._process(1.0 / 60.0)
	var after_return := workstation.pancake_model.sauce_concentration[center_cell]
	_release_surface(surface, start)
	return PackedFloat32Array([after_forward, after_return])


func _press_surface(surface: PancakeHeatmap, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	surface._gui_input(event)


func _move_surface(surface: PancakeHeatmap, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	surface._gui_input(event)


func _release_surface(surface: PancakeHeatmap, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	surface._gui_input(event)


func _cancel_surface(surface: PancakeHeatmap, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = position
	surface._gui_input(event)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("P0.4 interaction self-check PASS")
		quit(0)
	else:
		print("P0.4 interaction self-check FAIL (%d)" % _failures.size())
		quit(1)
