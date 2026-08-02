extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var workstation := main.get_node("Workstation") as Workstation
	workstation.set_process(false)
	var capture_directory := ProjectSettings.globalize_path("res://tmp/validation")
	DirAccess.make_dir_recursive_absolute(capture_directory)
	var order_path := capture_directory.path_join("p1_order_latest.png")
	if root.get_texture().get_image().save_png(order_path) != OK:
		_fail("Failed to save P1 order capture")
		return

	_fill_egg_spread_preview(workstation)
	workstation.p1_session.phase = P1Session.Phase.FIRST_SIDE
	workstation.p1_session.changed.emit()
	workstation.pancake_surface.force_texture_upload()
	await process_frame
	await process_frame
	var egg_spread_path := capture_directory.path_join("p1_egg_spread_latest.png")
	if root.get_texture().get_image().save_png(egg_spread_path) != OK:
		_fail("Failed to save P1 egg-spread capture")
		return

	workstation.reset_pancake()
	_fill_complete_product(workstation)
	workstation.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	workstation.p1_session.changed.emit()
	workstation.pancake_surface.force_texture_upload()
	await process_frame
	await process_frame
	var production_path := capture_directory.path_join("p1_production_latest.png")
	if root.get_texture().get_image().save_png(production_path) != OK:
		_fail("Failed to save P1 production capture")
		return

	workstation.p1_session.begin_folding()
	workstation.fold_model.begin_drag(Vector2(12, 64))
	workstation.fold_model.release_drag(Vector2(70, 64))
	workstation.fold_model.begin_drag(Vector2(116, 64))
	workstation.fold_model.release_drag(Vector2(58, 64))
	workstation.bag_button.pressed.emit()
	workstation.step_action_button.pressed.emit()
	await process_frame
	await process_frame
	var result_path := capture_directory.path_join("p1_result_latest.png")
	if root.get_texture().get_image().save_png(result_path) != OK:
		_fail("Failed to save P1 result capture")
		return

	var frame_msec := PackedFloat32Array()
	var previous_frame_usec := Time.get_ticks_usec()
	for frame in 120:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		frame_msec.append(float(now_usec - previous_frame_usec) / 1000.0)
		previous_frame_usec = now_usec
	frame_msec.sort()
	var p95 := frame_msec[mini(floori(float(frame_msec.size()) * 0.95), frame_msec.size() - 1)]
	if p95 > 25.0:
		_fail("P1 rendered vertical slice missed 60 FPS target: p95 %.2f ms" % p95)
		return
	print("Mobile P1 vertical-slice smoke-check PASS (render p95 %.2f ms)" % p95)
	print("Validation captures: %s, %s, %s, %s" % [order_path, egg_spread_path, production_path, result_path])
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _fill_complete_product(workstation: Workstation) -> void:
	var model := workstation.pancake_model
	for y in model.grid_size:
		for x in model.grid_size:
			if not model.is_inside_pan(Vector2(x, y), 0.84):
				continue
			var index := y * model.grid_size + x
			model.coverage[index] = 1.0
			model.thickness[index] = 0.42
			model.wetness[index] = 0.12
			model.doneness[index] = 0.64
			model.back_doneness[index] = 0.64
			model.sauce_concentration[index] = 0.35
	var center := Vector2(model.grid_size - 1, model.grid_size - 1) * 0.5
	var radii := Vector2(float(model.grid_size) * 0.5, float(model.grid_size) * 0.5 * model.parameters.pan_height_ratio)
	for index in model.cell_count:
		if model.coverage[index] <= 0.0:
			continue
		var position := Vector2(index % model.grid_size, index / model.grid_size)
		if ((position - center) / radii).length() <= 0.74:
			model.egg_white[index] = 0.08
			model.egg_yolk[index] = 0.03
			model.egg_doneness[index] = 0.72
	model.egg_state = PancakeModel.EggState.SPREADING
	model.yolk_broken = true
	model.is_flipped = true
	model.revision += 1
	model.changed.emit()
	workstation.pour_used = true
	workstation.ingredient_model.place(IngredientModel.EGG, Vector2(64, 62), 0.0, model)
	workstation.ingredient_model.place(IngredientModel.BAOCUI, Vector2(61, 55), 0.08, model)
	workstation.ingredient_model.place(IngredientModel.SCALLION, Vector2(69, 70), -0.12, model)


func _fill_egg_spread_preview(workstation: Workstation) -> void:
	var model := workstation.pancake_model
	var center := Vector2(model.grid_size - 1, model.grid_size - 1) * 0.5
	for index in model.cell_count:
		var position := Vector2(index % model.grid_size, index / model.grid_size)
		if not model.is_inside_pan(position, 0.84):
			continue
		model.coverage[index] = 1.0
		model.thickness[index] = 0.42
		model.wetness[index] = 0.18
		model.doneness[index] = 0.36
	model.crack_egg(center)
	for ring in 10:
		var radius := 6.0 + float(ring) * 4.2
		for step in 56:
			var angle := TAU * float(step) / 56.0
			var radial := Vector2(cos(angle), sin(angle) * model.parameters.pan_height_ratio)
			model.apply_egg_spreader_sample(center + radial * radius, Vector2.from_angle(angle), 70.0)
	for index in model.cell_count:
		if model.egg_white[index] + model.egg_yolk[index] >= model.parameters.egg_coverage_minimum:
			model.egg_doneness[index] = 0.28
	model.revision += 1
	model.changed.emit()
	workstation.pour_used = true
	workstation.ingredient_model.place(IngredientModel.EGG, center, 0.0, model)
	workstation.tool_controller.select_tool(ToolController.Tool.SCRAPER)
	workstation.pancake_surface.pointer_local_position = Vector2(430, 300)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
