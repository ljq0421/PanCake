extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_session := root.get_node_or_null("GameSession")
	if game_session != null:
		game_session.call("begin_new_game")
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
	workstation.pancake_model.sauce_concentration.fill(0.0)
	workstation.sauce_tool_states[OrderService.SAUCE_SWEET].add(0.46)
	workstation.sauce_tool_states[OrderService.SAUCE_CHILI].add(0.28)
	workstation._refresh_sauce_load_display()
	workstation.pancake_surface.force_texture_upload()
	await process_frame
	await process_frame
	var sauce_blob_path := capture_directory.path_join("p1_sauce_blob_latest.png")
	if root.get_texture().get_image().save_png(sauce_blob_path) != OK:
		_fail("Failed to save P1 sauce-blob capture")
		return
	for state in workstation.sauce_tool_states.values():
		state.reset()
	workstation._refresh_sauce_load_display()
	workstation.pancake_model.sauce_concentration.fill(0.35)
	workstation.pancake_model.revision += 1
	workstation.pancake_model.changed.emit()
	workstation.pancake_surface.force_texture_upload()
	await process_frame
	await process_frame
	var production_path := capture_directory.path_join("p1_production_latest.png")
	var production_image := root.get_texture().get_image()
	if production_image.save_png(production_path) != OK:
		_fail("Failed to save P1 production capture")
		return
	var exposed_surface_position := workstation.pancake_surface.get_global_transform_with_canvas() * Vector2(
		workstation.pancake_surface.size.x * 0.84,
		workstation.pancake_surface.size.y * 0.50,
	)
	var exposed_pixel := Vector2i(roundi(exposed_surface_position.x), roundi(exposed_surface_position.y))
	exposed_pixel.x = clampi(exposed_pixel.x, 0, production_image.get_width() - 1)
	exposed_pixel.y = clampi(exposed_pixel.y, 0, production_image.get_height() - 1)
	var exposed_before_fold := production_image.get_pixelv(exposed_pixel)

	workstation.p1_session.begin_folding()
	workstation.fold_model.begin_drag(Vector2(12, 64))
	workstation.fold_model.update_drag(Vector2(58, 64))
	await process_frame
	await process_frame
	var fold_progress_path := capture_directory.path_join("p1_fold_in_progress_latest.png")
	var fold_progress_image := root.get_texture().get_image()
	if fold_progress_image.save_png(fold_progress_path) != OK:
		_fail("Failed to save P1 in-progress fold capture")
		return
	var exposed_during_fold := fold_progress_image.get_pixelv(exposed_pixel)
	if _maximum_rgb_channel_delta(exposed_before_fold, exposed_during_fold) > 0.045:
		_fail("An uncovered sauce pixel changed color while the opposite flap was moving")
		return
	var moving_fold_diagnostics: Dictionary = workstation.fold_overlay.get_renderer_diagnostics()
	if int(moving_fold_diagnostics.get("sauce_front_strip_count", 0)) <= 0:
		_fail("Moving fold capture did not render sauce on its visible interior strips")
		return
	workstation.fold_model.release_drag(Vector2(70, 64))
	await create_timer(0.78).timeout
	var single_fold_path := capture_directory.path_join("p1_single_fold_latest.png")
	var single_fold_image := root.get_texture().get_image()
	if single_fold_image.save_png(single_fold_path) != OK:
		_fail("Failed to save P1 single-fold capture")
		return
	var exposed_after_single_fold := single_fold_image.get_pixelv(exposed_pixel)
	if _maximum_rgb_channel_delta(exposed_before_fold, exposed_after_single_fold) > 0.045:
		_fail("An uncovered sauce pixel changed color after the opposite flap landed")
		return
	workstation.fold_model.begin_drag(Vector2(116, 64))
	workstation.fold_model.release_drag(Vector2(58, 64))
	await create_timer(0.78).timeout
	var folded_path := capture_directory.path_join("p1_folded_latest.png")
	if root.get_texture().get_image().save_png(folded_path) != OK:
		_fail("Failed to save P1 folded-product capture")
		return
	workstation.bag_button.pressed.emit()
	await create_timer(0.32).timeout
	var paper_bag_path := capture_directory.path_join("p1_paper_bag_latest.png")
	if root.get_texture().get_image().save_png(paper_bag_path) != OK:
		_fail("Failed to save P1 paper-bag capture")
		return
	workstation.serve_product_button.pressed.emit()
	await create_timer(0.55).timeout
	var accepting_path := capture_directory.path_join("p1_customer_accepting_bag_latest.png")
	if root.get_texture().get_image().save_png(accepting_path) != OK:
		_fail("Failed to save P1 customer-accepting capture")
		return
	await create_timer(0.58).timeout
	var paying_path := capture_directory.path_join("p1_customer_paying_latest.png")
	if root.get_texture().get_image().save_png(paying_path) != OK:
		_fail("Failed to save P1 customer-paying capture")
		return
	var payment_deadline_msec := Time.get_ticks_msec() + 2000
	while workstation._payment_animation_active and Time.get_ticks_msec() < payment_deadline_msec:
		await process_frame
	if workstation._payment_animation_active:
		_fail("Customer payment animation did not settle before capture")
		return
	await process_frame
	var result_path := capture_directory.path_join("p1_result_latest.png")
	if root.get_texture().get_image().save_png(result_path) != OK:
		_fail("Failed to save P1 result capture")
		return
	workstation.end_business_day()
	await process_frame
	await process_frame
	var daily_bill_path := capture_directory.path_join("p1_daily_bill_latest.png")
	if root.get_texture().get_image().save_png(daily_bill_path) != OK:
		_fail("Failed to save P1 daily-bill capture")
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
	print("Validation captures: %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s" % [order_path, egg_spread_path, sauce_blob_path, production_path, fold_progress_path, single_fold_path, folded_path, accepting_path, paying_path, result_path, daily_bill_path])
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


func _maximum_rgb_channel_delta(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
