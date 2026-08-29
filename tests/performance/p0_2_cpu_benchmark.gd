extends SceneTree

const GRIDDLE_SCENE := preload("res://scenes/gameplay/compact_griddle_unit.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var unit := GRIDDLE_SCENE.instantiate() as CompactGriddleUnit
	if unit == null:
		push_error("P0.2 benchmark could not instantiate CompactGriddleUnit")
		quit(1)
		return
	root.add_child(unit)
	await process_frame
	await process_frame
	unit.set_process(false)
	var model: PancakeModel = unit.pancake_model
	if model == null or unit.pancake_surface == null:
		push_error("P0.2 benchmark requires a live pancake model and heatmap surface")
		unit.queue_free()
		quit(1)
		return
	model.add_batter(Vector2(model.grid_size, model.grid_size) * 0.5, 3.0, 24.0)

	var scraper_iterations := 40
	var scraper_started := Time.get_ticks_usec()
	for index in scraper_iterations:
		var direction := Vector2.RIGHT if index % 2 == 0 else Vector2.LEFT
		model.apply_scraper_sample(Vector2(model.grid_size, model.grid_size) * 0.5, direction, 45.0)
	var scraper_usec := Time.get_ticks_usec() - scraper_started

	var solidification_iterations := 20
	var solidification_started := Time.get_ticks_usec()
	for index in solidification_iterations:
		model.advance_solidification(model.parameters.simulation_step_seconds)
	var solidification_usec := Time.get_ticks_usec() - solidification_started

	var texture_iterations := 8
	var texture_started := Time.get_ticks_usec()
	for index in texture_iterations:
		unit.pancake_surface.force_texture_upload()
	var texture_usec := Time.get_ticks_usec() - texture_started

	var effort_model := PancakeModel.new(model.parameters.grid_size, model.parameters)
	var effort_center := Vector2(effort_model.grid_size, effort_model.grid_size) * 0.5
	for sample_index in 120:
		effort_model.add_batter(
			effort_center,
			model.parameters.batter_flow_rate / 120.0,
			model.parameters.pour_radius
		)
	var coverage_before := float(effort_model.calculate_summary().coverage_ratio)
	var endpoints := [
		Vector2(effort_model.grid_size - 10, effort_center.y),
		Vector2(10, effort_center.y),
		Vector2(effort_center.x, 10),
		Vector2(effort_center.x, effort_model.grid_size - 10),
	]
	var coverage_by_pass := PackedFloat32Array()
	var gesture_usec := PackedInt64Array()
	var samples_by_pass := PackedInt32Array()
	for endpoint in endpoints:
		var sampler := StrokeSampler.new(model.parameters.scraper_sample_spacing)
		var previous := effort_center
		sampler.begin(previous)
		var samples := sampler.sample_to(endpoint)
		var gesture_started := Time.get_ticks_usec()
		for sample in samples:
			effort_model.apply_scraper_sample(sample, sample - previous, 45.0)
			previous = sample
		gesture_usec.append(Time.get_ticks_usec() - gesture_started)
		samples_by_pass.append(samples.size())
		coverage_by_pass.append(float(effort_model.calculate_summary().coverage_ratio))
	var coverage_after_two_passes := coverage_by_pass[1]
	var coverage_after_four_passes := float(effort_model.calculate_summary().coverage_ratio)

	print("P0.2 CPU BENCHMARK grid=%d" % model.grid_size)
	print("scraper average: %.3f ms/sample (%d samples)" % [float(scraper_usec) / 1000.0 / scraper_iterations, scraper_iterations])
	print("solidification average: %.3f ms/step (%d steps)" % [float(solidification_usec) / 1000.0 / solidification_iterations, solidification_iterations])
	print("dynamic field upload average: %.3f ms/upload (%d uploads)" % [float(texture_usec) / 1000.0 / texture_iterations, texture_iterations])
	print("two broad scraper passes: coverage %.1f%% -> %.1f%%" % [coverage_before * 100.0, coverage_after_two_passes * 100.0])
	print("first two gesture CPU totals: %.3f ms/%d samples, %.3f ms/%d samples" % [
		float(gesture_usec[0]) / 1000.0,
		samples_by_pass[0],
		float(gesture_usec[1]) / 1000.0,
		samples_by_pass[1],
	])
	print("four-pass diagnostic coverage: %.1f%%" % (coverage_after_four_passes * 100.0))
	print("coverage after each pass: %.1f%%, %.1f%%, %.1f%%, %.1f%%" % [
		coverage_by_pass[0] * 100.0,
		coverage_by_pass[1] * 100.0,
		coverage_by_pass[2] * 100.0,
		coverage_by_pass[3] * 100.0,
	])

	unit.queue_free()
	await process_frame
	await process_frame
	quit(0)
