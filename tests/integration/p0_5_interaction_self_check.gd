extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")

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
	_check(
		workstation.fold_overlay.get_fold_source_span(FOLD_MODEL_SCRIPT.REGION_LEFT, 0.5).is_empty()
		and workstation.fold_overlay.get_fold_arc_profile(FOLD_MODEL_SCRIPT.REGION_LEFT, 0.5).is_empty(),
		"an empty pancake model produces no invented fold silhouette or arc"
	)
	_fill_uniform_pancake(workstation.pancake_model)
	var regular_span: PackedVector2Array = workstation.fold_overlay.get_fold_source_span(FOLD_MODEL_SCRIPT.REGION_LEFT, 0.55)
	_sculpt_irregular_left_edge(workstation.pancake_model)
	var notched_span: PackedVector2Array = workstation.fold_overlay.get_fold_source_span(FOLD_MODEL_SCRIPT.REGION_LEFT, 0.55)
	_check(
		regular_span.size() == 2
		and notched_span.size() == 2
		and notched_span[0].y > regular_span[0].y + 16.0
		and is_equal_approx(notched_span[1].y, regular_span[1].y),
		"fold source silhouette follows an actual missing upper edge instead of restoring a circular arc"
	)
	_fill_uniform_pancake(workstation.pancake_model)

	_check(workstation.fold_button != null and workstation.fold_overlay != null, "workstation scene owns stable fold controls and overlay")
	_check(workstation.fold_overlay.pancake_front_texture != null and workstation.fold_overlay.pancake_back_texture != null, "fold overlay textures both the pancake top and revealed underside")
	_check(
		workstation.fold_overlay.paper_bag_package_texture != null
		and workstation.fold_overlay.reinforced_sleeve_package_texture != null
		and workstation.fold_overlay.serving_tray_package_texture != null,
		"fold overlay owns dedicated paper-bag, reinforced-sleeve, and tray artwork"
	)
	_check(workstation.paper_sleeve_button != null and workstation.tray_button != null, "workstation scene owns both rescue choices")
	workstation.fold_button.pressed.emit()
	_check(workstation.tool_controller.current_tool == ToolController.Tool.FOLD, "fold button selects the continuous fold tool")
	_check(bool(workstation.fold_overlay.guides_visible), "fold tool exposes visible fold lines and edge handles")

	_press_surface(surface, _scaled_surface_point(surface, Vector2(110, 300)))
	_move_surface(surface, _scaled_surface_point(surface, Vector2(180, 300)))
	workstation._process(1.0 / 60.0)
	_check(float(workstation.fold_model.drag_progress) > 0.0 and workstation.fold_model.completed_fold_count() == 0, "mouse movement deforms the flap before release")
	var arc_profile: PackedVector2Array = workstation.fold_overlay.get_fold_arc_profile(FOLD_MODEL_SCRIPT.REGION_LEFT, 0.55)
	_check(arc_profile.size() > 20 and _maximum_profile_bend(arc_profile) > 8.0, "dragged flap uses a tessellated curved profile instead of one flat reflected plane")
	_move_surface(surface, _scaled_surface_point(surface, Vector2(300, 300)))
	workstation._process(1.0 / 60.0)
	_release_surface(surface, _scaled_surface_point(surface, Vector2(300, 300)))
	_check(workstation.fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT), "dragging the left edge over its line commits the left fold")
	_check(
		is_inf(float(workstation.fold_overlay.call("left_fold_clip_max_x"))),
		"the completed left flap remains whole until the right flap reaches its tail"
	)
	_check(workstation.fold_overlay.is_fold_animation_active(), "committing a fold starts the visible completion and soft-settle animation")
	await create_timer(0.65).timeout
	_check(not workstation.fold_overlay.is_fold_animation_active(), "fold completion animation settles back to a stable rendered state")
	var surface_material := workstation.pancake_surface.pancake_visual.material as ShaderMaterial
	_check(is_equal_approx(float(surface_material.get_shader_parameter(&"fold_left_progress")), 1.0), "committed left fold makes the original pancake region transparent instead of painting a fake griddle color")
	_check(workstation.scraper_button.disabled and workstation.sauce_brush_button.disabled, "starting a fold locks earlier preparation tools")

	_press_surface(surface, _scaled_surface_point(surface, Vector2(490, 300)))
	_move_surface(surface, _scaled_surface_point(surface, Vector2(390, 300)))
	workstation._process(1.0 / 60.0)
	var moving_right_edge := float(workstation.fold_overlay.call("right_fold_outer_edge_x", float(workstation.fold_model.drag_progress)))
	var landed_right_edge := float(workstation.fold_overlay.call("right_fold_outer_edge_x", 1.0))
	_check(
		is_equal_approx(
			float(workstation.fold_overlay.call("left_fold_clip_max_x")),
			moving_right_edge
		),
		"the moving right flap clips the left tail at its current outer edge"
	)
	_check(moving_right_edge > landed_right_edge + 1.0, "the left-tail clip advances progressively as the right flap folds inward")
	_move_surface(surface, _scaled_surface_point(surface, Vector2(300, 300)))
	workstation._process(1.0 / 60.0)
	_release_surface(surface, _scaled_surface_point(surface, Vector2(300, 300)))
	_check(workstation.fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT), "dragging the right edge over its line commits the right fold")
	await create_timer(0.65).timeout
	_check(
		is_equal_approx(
			float(workstation.fold_overlay.call("left_fold_clip_max_x")),
			landed_right_edge
		),
		"after the right fold lands, the left tail is clipped at the final right outer edge"
	)
	_check(not workstation.paper_sleeve_button.disabled and not workstation.tray_button.disabled, "completed non-severe folds expose both safe completion choices")
	workstation.paper_sleeve_button.pressed.emit()
	_check(workstation.fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_SLEEVE, "paper sleeve completes the real workstation path")
	_check(
		workstation.fold_overlay.current_package_texture().resource_path.ends_with("reinforced_paper_sleeve_package_v1.png"),
		"reinforced sleeve state renders its dedicated finished-product artwork"
	)
	_check(is_equal_approx(float(surface_material.get_shader_parameter(&"package_hidden")), 1.0), "completed packaging hides the old folded pancake below the serving artwork")

	workstation.reset_pancake()
	_fill_uniform_pancake(workstation.pancake_model)
	_set_hole(workstation.pancake_model, Vector2i(25, 64))
	workstation.fold_button.pressed.emit()
	_drag_surface(workstation, surface, _scaled_surface_point(surface, Vector2(110, 300)), _scaled_surface_point(surface, Vector2(300, 300)))
	_check(workstation.fold_model.maximum_severity() == 2, "a hole in the dragged region creates a severe workstation fold failure")
	_check(workstation.paper_sleeve_button.disabled and not workstation.tray_button.disabled, "severe failure disables sleeve but immediately enables tray")
	workstation.tray_button.pressed.emit()
	_check(workstation.fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_TRAY, "tray rescues a severe failure without a dead end")
	_check(
		workstation.fold_overlay.current_package_texture().resource_path.ends_with("serving_tray_package_v1.png"),
		"tray rescue state renders its dedicated finished-product artwork"
	)
	workstation.reset_pancake()
	_check(is_zero_approx(float(surface_material.get_shader_parameter(&"fold_left_progress"))) and is_zero_approx(float(surface_material.get_shader_parameter(&"fold_right_progress"))), "reset restores the complete pancake surface mask")
	_check(is_zero_approx(float(surface_material.get_shader_parameter(&"package_hidden"))), "reset restores the unpackaged pancake surface")
	_check(workstation.fold_model.completed_fold_count() == 0 and workstation.tool_controller.current_tool == ToolController.Tool.NONE, "R/reset clears folding, packaging, pointer, and tool state")

	main.queue_free()
	await process_frame
	await process_frame
	_finish()


func _scaled_surface_point(surface: Control, old_point: Vector2) -> Vector2:
	return Vector2(old_point.x * surface.size.x / 600.0, old_point.y * surface.size.y / 600.0)


func _fill_uniform_pancake(model: PancakeModel) -> void:
	var center := Vector2(model.grid_size - 1, model.grid_size - 1) * 0.5
	for y in model.grid_size:
		for x in model.grid_size:
			if not model.is_inside_pan(Vector2(x, y), 0.86):
				continue
			var index := y * model.grid_size + x
			model.coverage[index] = 1.0
			model.thickness[index] = 0.55
			model.wetness[index] = 0.25
			model.doneness[index] = 0.55
	model.revision += 1
	model.changed.emit()


func _set_hole(model: PancakeModel, cell: Vector2i) -> void:
	var index := model.index_of(cell)
	model.coverage[index] = 0.0
	model.thickness[index] = 0.0
	model.damage[index] = 1.0
	model.revision += 1
	model.changed.emit()


func _sculpt_irregular_left_edge(model: PancakeModel) -> void:
	for x in range(22, 34):
		var distance_from_center := absf(float(x) - 27.5) / 5.5
		var trim_cells := 4 + roundi((1.0 - distance_from_center) * 6.0)
		var removed := 0
		for y in model.grid_size:
			var index := y * model.grid_size + x
			if model.coverage[index] <= 0.0:
				continue
			model.coverage[index] = 0.0
			model.thickness[index] = 0.0
			model.wetness[index] = 0.0
			removed += 1
			if removed >= trim_cells:
				break
	model.revision += 1
	model.changed.emit()


func _drag_surface(workstation: Workstation, surface: PancakeHeatmap, start: Vector2, finish: Vector2) -> void:
	_press_surface(surface, start)
	_move_surface(surface, finish)
	workstation._process(1.0 / 60.0)
	_release_surface(surface, finish)


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


func _maximum_profile_bend(profile: PackedVector2Array) -> float:
	if profile.size() < 3:
		return 0.0
	var chord_start := profile[0]
	var chord_end := profile[profile.size() - 1]
	var chord := chord_end - chord_start
	var chord_length := chord.length()
	if chord_length <= 0.001:
		return 0.0
	var maximum := 0.0
	for point in profile:
		var distance := absf(chord.cross(point - chord_start)) / chord_length
		maximum = maxf(maximum, distance)
	return maximum


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("P0.5 interaction self-check PASS")
		quit(0)
	else:
		print("P0.5 interaction self-check FAIL (%d)" % _failures.size())
		quit(1)
