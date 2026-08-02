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
	var model := workstation.pancake_model
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
		model.advance_solidification(workstation.parameters.simulation_step_seconds)
	var solidification_usec := Time.get_ticks_usec() - solidification_started

	var texture_iterations := 8
	var texture_started := Time.get_ticks_usec()
	for index in texture_iterations:
		workstation.pancake_surface.call("_rebuild_heatmap_texture")
	var texture_usec := Time.get_ticks_usec() - texture_started

	var effort_model := PancakeModel.new(workstation.parameters.grid_size, workstation.parameters)
	var effort_center := Vector2(effort_model.grid_size, effort_model.grid_size) * 0.5
	for sample_index in 120:
		effort_model.add_batter(
			effort_center,
			workstation.parameters.batter_flow_rate / 120.0,
			workstation.parameters.pour_radius
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
		var sampler := StrokeSampler.new(workstation.parameters.scraper_sample_spacing)
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

	main.queue_free()
	await process_frame
	await process_frame
	quit(0)
