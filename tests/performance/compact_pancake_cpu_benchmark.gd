extends SceneTree

const GRIDDLE_SCENE := preload("res://scenes/gameplay/compact_griddle_unit.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var unit := GRIDDLE_SCENE.instantiate() as CompactGriddleUnit
	root.add_child(unit)
	await process_frame
	unit.set_process(false)
	var model := unit.pancake_model
	model.add_batter(Vector2(model.grid_size, model.grid_size) * 0.5, 4.0, 14.0)
	var spread_iterations := 24
	var spread_started := Time.get_ticks_usec()
	for iteration in spread_iterations:
		unit.call("_apply_radial_batter_sweep", Vector2(48.0, 32.0), Vector2.RIGHT, 90.0)
	var spread_usec := Time.get_ticks_usec() - spread_started
	model.reset()
	model.add_batter(Vector2(model.grid_size, model.grid_size) * 0.5, 4.0, 14.0)
	var burst_start := Vector2(48.0, 32.0)
	var burst_end := Vector2(32.0, 48.0)
	unit._scrape_sampler.begin(burst_start)
	unit._previous_scrape_sample = burst_start
	unit._last_process_grid_position = burst_start
	unit._spreader_max_radius = unit.call("_pan_polar_offset", burst_start).length()
	unit._spreader_smoothed_angle = unit.call("_pan_polar_offset", burst_end).angle()
	unit._spreader_angle_initialized = true
	unit.pancake_surface.pointer_local_position = (burst_end + Vector2(0.5, 0.5)) / float(model.grid_size) * unit.pancake_surface.size
	var burst_raw_sample_count := floori(burst_start.distance_to(burst_end) / unit._scrape_sampler.spacing)
	var burst_started := Time.get_ticks_usec()
	unit.call("_process_manual_spread", 1.0 / 60.0)
	var burst_usec := Time.get_ticks_usec() - burst_started
	var spiral_result := _benchmark_spiral(unit, 180)
	var upload_iterations := 30
	var upload_started := Time.get_ticks_usec()
	for iteration in upload_iterations:
		unit.pancake_surface.force_texture_upload()
	var upload_usec := Time.get_ticks_usec() - upload_started
	print("COMPACT_PANCAKE_CPU_BENCHMARK")
	print("radial spread average: %.3f ms (%d samples)" % [float(spread_usec) / 1000.0 / spread_iterations, spread_iterations])
	print("long-frame spread burst: %.3f ms (%d raw path samples)" % [float(burst_usec) / 1000.0, burst_raw_sample_count])
	print("three-second spiral average/max: %.3f/%.3f ms; coverage %.1f%%" % [float(spiral_result.average_usec) / 1000.0, float(spiral_result.max_usec) / 1000.0, float(spiral_result.coverage_ratio) * 100.0])
	print("idle-ingredient upload average: %.3f ms (%d uploads)" % [float(upload_usec) / 1000.0 / upload_iterations, upload_iterations])
	unit.queue_free()
	await process_frame
	quit(0)


func _benchmark_spiral(unit: CompactGriddleUnit, frame_count: int) -> Dictionary:
	var model := unit.pancake_model
	model.reset()
	var pan_center := Vector2.ONE * (float(model.grid_size) - 1.0) * 0.5
	model.add_batter(pan_center, 4.0, 14.0)
	var start := pan_center + Vector2(14.0, 0.0)
	unit._scrape_sampler.begin(start)
	unit._previous_scrape_sample = start
	unit._last_process_grid_position = start
	unit._spreader_max_radius = 14.0
	unit._spreader_direction_grace_remaining = 0
	unit._spreader_speed_initialized = false
	var total_usec := 0
	var max_usec := 0
	for frame_index in range(1, frame_count + 1):
		var progress := float(frame_index) / float(frame_count)
		var angle := TAU * 2.6 * progress
		var radius := lerpf(14.0, 30.0, progress)
		var polar_offset := Vector2.from_angle(angle) * radius
		var point := pan_center + Vector2(polar_offset.x, polar_offset.y * model.parameters.pan_height_ratio)
		unit._spreader_smoothed_angle = angle
		unit._spreader_angle_initialized = true
		unit.pancake_surface.pointer_local_position = (point + Vector2(0.5, 0.5)) / float(model.grid_size) * unit.pancake_surface.size
		var frame_started := Time.get_ticks_usec()
		unit.call("_process_manual_spread", 1.0 / 60.0)
		var frame_usec := Time.get_ticks_usec() - frame_started
		total_usec += frame_usec
		max_usec = maxi(max_usec, frame_usec)
	return {
		"average_usec": float(total_usec) / float(frame_count),
		"max_usec": max_usec,
		"coverage_ratio": float(model.calculate_summary().coverage_ratio),
	}
