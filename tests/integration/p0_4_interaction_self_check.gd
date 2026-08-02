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
	workstation.pancake_model.add_batter(Vector2(64, 64), 2.0, 42.0)

	_check(workstation.sauce_brush_button != null and workstation.sauce_refill_button != null, "workstation scene owns stable brush and hold-to-dip controls")
	_check(workstation.get_node_or_null("SafeArea/RightRack/BlotterButton") == null, "removed blotter is absent from the scene")
	_check(is_zero_approx(float(workstation.sauce_tool_state.load)), "brush starts empty in the player interaction path")

	workstation.sauce_refill_button.button_down.emit()
	for frame in 30:
		workstation._process(1.0 / 60.0)
	workstation.sauce_refill_button.button_up.emit()
	var short_dip_load := float(workstation.sauce_tool_state.load)
	_check(absf(short_dip_load - 0.25) <= 0.01, "half-second hold dips approximately one quarter of the brush capacity")
	workstation.sauce_refill_button.button_down.emit()
	for frame in 120:
		workstation._process(1.0 / 60.0)
	workstation.sauce_refill_button.button_up.emit()
	_check(is_equal_approx(float(workstation.sauce_tool_state.load), workstation.parameters.sauce_brush_capacity), "long hold stops at the full-brush cap")

	workstation.sauce_brush_button.pressed.emit()
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SAUCE_BRUSH, "sauce brush button selects the brush tool")
	var load_before := float(workstation.sauce_tool_state.load)
	_brush_path(workstation, surface, [Vector2(205, 250), Vector2(395, 250), Vector2(395, 350), Vector2(205, 350)])
	var sauce_after_first_stroke := workstation.pancake_model.total_sauce()
	_check(sauce_after_first_stroke > 0.0, "brush path deposits sauce through the workstation interaction path")
	_check(float(workstation.sauce_tool_state.load) < load_before, "painted area consumes the dipped amount")
	_check(workstation.sauce_status_label.text.contains("酱料评分"), "workstation displays the model-backed sauce score")

	var center_cell := workstation.pancake_model.index_of(Vector2i(64, 64))
	var concentration_after_first := workstation.pancake_model.sauce_concentration[center_cell]
	workstation.sauce_refill_button.button_down.emit()
	for frame in 120:
		workstation._process(1.0 / 60.0)
	workstation.sauce_refill_button.button_up.emit()
	var same_press_layers := _brush_out_and_back(workstation, surface, Vector2(205, 300), Vector2(395, 300), center_cell)
	_check(same_press_layers[0] > concentration_after_first, "the first pass adds a concentration layer")
	_check(same_press_layers[1] > same_press_layers[0], "returning over the same area without releasing adds another concentration layer")

	workstation.set_heatmap_field(PancakeModel.FIELD_SAUCE_CONCENTRATION)
	var material := surface.pancake_visual.material as ShaderMaterial
	_check(surface.heatmap_field == PancakeModel.FIELD_SAUCE_CONCENTRATION and int(material.get_shader_parameter(&"view_mode")) == 6, "sauce debug view reads the shared renderer data")
	workstation.set_heatmap_field(PancakeHeatmap.VIEW_APPEARANCE)

	_cancel_surface(surface, Vector2(330, 300))
	_check(workstation.tool_controller.current_tool == ToolController.Tool.NONE, "right mouse returns the sauce brush")
	workstation.reset_pancake()
	_check(is_zero_approx(workstation.pancake_model.total_sauce()), "reset clears sauce concentration")
	_check(is_zero_approx(float(workstation.sauce_tool_state.load)), "reset restores an empty brush")

	main.queue_free()
	await process_frame
	await process_frame
	_finish()


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
