extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const PANCAKE_SCORER_SCRIPT := preload("res://scripts/gameplay/pancake_scorer.gd")


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
	var before_revision := workstation.pancake_model.revision

	workstation.ladle_button.pressed.emit()
	await create_timer(0.15).timeout
	var capture_directory := ProjectSettings.globalize_path("res://tmp/validation")
	DirAccess.make_dir_recursive_absolute(capture_directory)
	var before_scrape_path := capture_directory.path_join("p0_2_before_scrape.png")
	var before_scrape_error := root.get_texture().get_image().save_png(before_scrape_path)
	if before_scrape_error != OK:
		push_error("Failed to save pre-scrape capture: %s" % error_string(before_scrape_error))
		quit(1)
		return
	var coverage_before_scrape := float(workstation.pancake_model.calculate_summary().coverage_ratio)

	workstation.tool_controller.select_tool(ToolController.Tool.SCRAPER)
	surface.pointer_pressed = true
	var pan_center := Vector2(300, 300)
	surface.pointer_local_position = pan_center + Vector2(24, 0)
	surface.pointer_started.emit(surface.pointer_local_position)
	for frame in range(1, 241):
		var progress := float(frame) / 240.0
		var angle := progress * TAU * 2.6
		var radius := lerpf(24.0, 155.0, progress)
		surface.pointer_local_position = pan_center + Vector2(cos(angle) * radius, sin(angle) * radius * workstation.parameters.pan_height_ratio)
		workstation._process(1.0 / 60.0)
	surface.pointer_pressed = false
	surface.pointer_ended.emit(surface.pointer_local_position)
	workstation.warning_tone.call("trigger", false)
	await create_timer(0.2).timeout
	var production_path := capture_directory.path_join("p0_art_production_latest.png")
	var production_error := root.get_texture().get_image().save_png(production_path)
	if production_error != OK:
		push_error("Failed to save production validation capture: %s" % error_string(production_error))
		quit(1)
		return

	workstation.sauce_refill_button.button_down.emit()
	for frame in 120:
		workstation._process(1.0 / 60.0)
	workstation.sauce_refill_button.button_up.emit()
	workstation.tool_controller.select_tool(ToolController.Tool.SAUCE_BRUSH)
	var sauce_path := [Vector2(205, 240), Vector2(395, 240), Vector2(395, 360), Vector2(205, 360)]
	surface.pointer_pressed = true
	surface.pointer_local_position = sauce_path[0]
	surface.pointer_started.emit(surface.pointer_local_position)
	for point_index in range(1, sauce_path.size()):
		var segment_start: Vector2 = sauce_path[point_index - 1]
		var segment_finish: Vector2 = sauce_path[point_index]
		for frame in range(1, 61):
			surface.pointer_local_position = segment_start.lerp(segment_finish, float(frame) / 60.0)
			workstation._process(1.0 / 60.0)
	surface.pointer_pressed = false
	surface.pointer_ended.emit(surface.pointer_local_position)
	await create_timer(0.2).timeout
	var sauce_evaluation: Dictionary = PANCAKE_SCORER_SCRIPT.evaluate_sauce(workstation.pancake_model)
	var diagnostics := workstation.pancake_surface.get_renderer_diagnostics()
	var texture := diagnostics.field_texture as ImageTexture
	var damage_texture := diagnostics.damage_texture as ImageTexture
	var sauce_texture := diagnostics.sauce_texture as ImageTexture
	var material := workstation.pancake_surface.pancake_visual.material as ShaderMaterial
	var texture_is_current := not bool(workstation.pancake_surface.get("_dirty"))
	var coverage_after_scrape := float(workstation.pancake_model.calculate_summary().coverage_ratio)
	if workstation.pancake_model.revision <= before_revision or workstation.pancake_model.total_thickness() <= 0.0 or workstation.pancake_model.total_sauce() <= 0.0 or texture == null or damage_texture == null or sauce_texture == null or material == null or not texture_is_current or not workstation.pour_used or surface.heatmap_field != PancakeHeatmap.VIEW_APPEARANCE or coverage_after_scrape < 0.85:
		push_error("Mobile P0.4 appearance smoke-check FAIL: coverage %.2f%% -> %.2f%%, required >= 85.0%%; revision %d; mass %.1f; sauce %.1f; texture current %s" % [
			coverage_before_scrape * 100.0,
			coverage_after_scrape * 100.0,
			workstation.pancake_model.revision,
			workstation.pancake_model.total_thickness(),
			workstation.pancake_model.total_sauce(),
			texture_is_current,
		])
		quit(1)
		return

	var stable_field_rid := texture.get_rid()
	var stable_damage_rid := damage_texture.get_rid()
	var stable_sauce_rid := sauce_texture.get_rid()
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var upload_started := Time.get_ticks_usec()
	for iteration in 240:
		workstation.pancake_surface.force_texture_upload()
	var upload_usec := Time.get_ticks_usec() - upload_started
	var memory_after := Performance.get_monitor(Performance.MEMORY_STATIC)
	var stress_diagnostics := workstation.pancake_surface.get_renderer_diagnostics()
	if (stress_diagnostics.field_texture as ImageTexture).get_rid() != stable_field_rid or (stress_diagnostics.damage_texture as ImageTexture).get_rid() != stable_damage_rid or (stress_diagnostics.sauce_texture as ImageTexture).get_rid() != stable_sauce_rid:
		push_error("Mobile P0.4 texture reuse smoke-check FAIL")
		quit(1)
		return

	var frame_msec := PackedFloat32Array()
	var previous_frame_usec := Time.get_ticks_usec()
	for frame in 180:
		if frame % 3 == 0:
			workstation.pancake_model.advance_solidification(workstation.parameters.simulation_step_seconds)
		await process_frame
		var now_usec := Time.get_ticks_usec()
		frame_msec.append(float(now_usec - previous_frame_usec) / 1000.0)
		previous_frame_usec = now_usec
	frame_msec.sort()
	var average_frame_msec := 0.0
	for value in frame_msec:
		average_frame_msec += value
	average_frame_msec /= maxf(float(frame_msec.size()), 1.0)
	var p95_frame_msec := frame_msec[mini(floori(float(frame_msec.size()) * 0.95), frame_msec.size() - 1)]
	if p95_frame_msec > 25.0:
		push_error("Mobile P0.4 rendered workload missed 60 FPS stability target: p95 %.2f ms" % p95_frame_msec)
		quit(1)
		return
	var capture := root.get_texture().get_image()
	var capture_path := capture_directory.path_join("p0_4_latest.png")
	var capture_error := capture.save_png(capture_path)
	if capture_error != OK:
		push_error("Failed to save P0.4 validation capture: %s" % error_string(capture_error))
		quit(1)
		return

	workstation.set_heatmap_field(PancakeModel.FIELD_SAUCE_CONCENTRATION)
	await process_frame
	await process_frame
	var sauce_capture_path := capture_directory.path_join("p0_4_sauce_debug.png")
	var sauce_capture_error := root.get_texture().get_image().save_png(sauce_capture_path)
	if sauce_capture_error != OK:
		push_error("Failed to save P0.4 sauce-debug capture: %s" % error_string(sauce_capture_error))
		quit(1)
		return
	workstation.set_heatmap_field(PancakeHeatmap.VIEW_APPEARANCE)
	var sauce_mass_before_probe := workstation.pancake_model.total_sauce()
	_apply_material_state_probe(workstation.pancake_model)
	workstation.pancake_surface.force_texture_upload()
	await process_frame
	await process_frame
	var state_capture_path := capture_directory.path_join("p0_3_material_states.png")
	var state_capture_error := root.get_texture().get_image().save_png(state_capture_path)
	if state_capture_error != OK:
		push_error("Failed to save P0.3 material-state capture: %s" % error_string(state_capture_error))
		quit(1)
		return
	print("Mobile P0.4 sauce-render smoke-check PASS (%dx%d, revision %d, %.1f batter mass, %.1f sauce, sauce score %.1f, coverage %.1f%% -> %.1f%%)" % [
		texture.get_width(),
		texture.get_height(),
		workstation.pancake_model.revision,
		workstation.pancake_model.total_thickness(),
		sauce_mass_before_probe,
		float(sauce_evaluation.score),
		coverage_before_scrape * 100.0,
		coverage_after_scrape * 100.0,
	])
	print("240 upload stress: %.3f ms/upload, static memory delta %.1f KiB, texture RIDs reused" % [float(upload_usec) / 1000.0 / 240.0, (memory_after - memory_before) / 1024.0])
	print("180 rendered frames: average %.2f ms, p95 %.2f ms" % [average_frame_msec, p95_frame_msec])
	print("Validation captures: %s, %s, %s, %s" % [production_path, capture_path, sauce_capture_path, state_capture_path])
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _apply_material_state_probe(model: PancakeModel) -> void:
	var doneness := model.doneness.duplicate()
	var wetness := model.wetness.duplicate()
	var sauce := model.sauce_concentration.duplicate()
	sauce.fill(0.0)
	var minimum_x := model.grid_size
	var maximum_x := 0
	for y in model.grid_size:
		for x in model.grid_size:
			if model.coverage[y * model.grid_size + x] > 0.0:
				minimum_x = mini(minimum_x, x)
				maximum_x = maxi(maximum_x, x)
	var covered_width := maxf(float(maximum_x - minimum_x + 1), 1.0)
	for y in model.grid_size:
		for x in model.grid_size:
			var index := y * model.grid_size + x
			if model.coverage[index] <= 0.0:
				continue
			var covered_fraction := float(x - minimum_x) / covered_width
			if covered_fraction < 1.0 / 3.0:
				doneness[index] = 0.05
				wetness[index] = 0.90
			elif covered_fraction < 2.0 / 3.0:
				doneness[index] = 0.58
				wetness[index] = 0.35
			else:
				doneness[index] = 0.96
				wetness[index] = 0.05
	model.doneness = doneness
	model.wetness = wetness
	model.sauce_concentration = sauce
	model.revision += 1
	model.changed.emit()
