extends SceneTree

const EPSILON := 0.0001

var _failures := PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_distance_sampler_chunk_independence()
	_test_timed_sampler_frame_independence()
	_test_pour_frame_independence()
	_test_scraper_frame_independence()
	_test_scraper_mass_and_solidification()
	_test_scraper_uniformity_speed_and_edge_loss()
	_test_scraper_visibly_expands_coverage()
	_test_spiral_reaches_playable_coverage()
	_test_repeated_scraping_records_damage()
	_test_edge_operations_remain_valid()
	_finish()


func _test_distance_sampler_chunk_independence() -> void:
	var single := StrokeSampler.new(2.0)
	var segmented := StrokeSampler.new(2.0)
	var single_samples := single.begin(Vector2(0, 10))
	single_samples.append_array(single.sample_to(Vector2(100, 10)))
	var segmented_samples := segmented.begin(Vector2(0, 10))
	for x in range(7, 101, 7):
		segmented_samples.append_array(segmented.sample_to(Vector2(mini(x, 100), 10)))
	if segmented_samples[-1].x < 99.999:
		segmented_samples.append_array(segmented.sample_to(Vector2(100, 10)))
	_check(_points_are_close(single_samples, segmented_samples), "distance sampler is independent of input segment count")
	var largest_gap := 0.0
	for index in range(1, segmented_samples.size()):
		largest_gap = maxf(largest_gap, segmented_samples[index - 1].distance_to(segmented_samples[index]))
	_check(largest_gap <= 2.001, "fast pointer movement cannot leave gaps larger than sample spacing")


func _test_timed_sampler_frame_independence() -> void:
	var baseline := _timed_path_samples(30)
	for fps in [60, 120]:
		var candidate := _timed_path_samples(fps)
		_check(_points_are_close(baseline, candidate, 0.001), "timed pour samples match at 30 and %d FPS" % fps)
	_check(absf(float(baseline.size()) - 120.0) <= 1.0, "one-second pour produces approximately 120 fixed-time samples")


func _test_pour_frame_independence() -> void:
	var baseline := _simulate_pour(30)
	for fps in [60, 120]:
		var candidate := _simulate_pour(fps)
		_check(_max_field_difference(baseline.thickness, candidate.thickness) < 0.0005, "pour thickness is stable at 30 and %d FPS" % fps)
		_check(_max_field_difference(baseline.coverage, candidate.coverage) < EPSILON, "pour coverage is stable at 30 and %d FPS" % fps)


func _test_scraper_frame_independence() -> void:
	var baseline := _simulate_scrape(30)
	for fps in [60, 120]:
		var candidate := _simulate_scrape(fps)
		_check(_max_field_difference(baseline.thickness, candidate.thickness) < 0.001, "scraper thickness is stable at 30 and %d FPS" % fps)
		_check(_max_field_difference(baseline.damage, candidate.damage) < 0.001, "scraper damage is stable at 30 and %d FPS" % fps)


func _test_scraper_mass_and_solidification() -> void:
	var wet := PancakeModel.new(128)
	var dry := PancakeModel.new(128)
	for model in [wet, dry]:
		model.add_batter(Vector2(64, 64), 0.8, 20.0)
	var mass_before := wet.total_thickness()
	var wet_result := wet.apply_scraper_sample(Vector2(64, 64), Vector2.RIGHT, 45.0)
	var mass_after := wet.total_thickness()
	_check(absf(mass_after - mass_before) / maxf(mass_before, 0.001) < 0.001, "scraper conserves batter mass away from pan edge")
	dry.advance_solidification(8.0)
	var dry_result := dry.apply_scraper_sample(Vector2(64, 64), Vector2.RIGHT, 45.0)
	_check(float(dry_result.moved_mass) < float(wet_result.moved_mass), "solidified batter resists scraper movement")


func _test_scraper_uniformity_speed_and_edge_loss() -> void:
	var flatten_parameters := PancakeSimulationParameters.new()
	flatten_parameters.scraper_push_distance = 0.0
	var flatten_model := PancakeModel.new(64, flatten_parameters)
	flatten_model.add_batter(Vector2(32, 32), 1.0, 14.0)
	flatten_model.add_batter(Vector2(28, 32), 0.8, 6.0)
	var variance_before := _covered_variance(flatten_model.thickness, flatten_model.coverage)
	flatten_model.apply_scraper_sample(Vector2(32, 32), Vector2.RIGHT, 40.0)
	var variance_after := _covered_variance(flatten_model.thickness, flatten_model.coverage)
	_check(variance_after < variance_before, "scraper locally reduces covered thickness variance")

	var slow := PancakeModel.new(64)
	var fast := PancakeModel.new(64)
	for model in [slow, fast]:
		model.add_batter(Vector2(32, 32), 0.8, 18.0)
	var slow_result := slow.apply_scraper_sample(Vector2(32, 32), Vector2.RIGHT, 35.0)
	var fast_result := fast.apply_scraper_sample(Vector2(32, 32), Vector2.RIGHT, 190.0)
	_check(float(fast_result.moved_mass) < float(slow_result.moved_mass), "fast circular spreading has reduced spreading effectiveness")
	_check(float(slow.calculate_summary().mean_thickness) < float(fast.calculate_summary().mean_thickness), "slower circular spreading leaves a thinner pancake than fast circling")

	var edge := PancakeModel.new(64)
	edge.add_batter(Vector2(56, 32), 0.9, 9.0)
	var edge_mass_before := edge.total_thickness()
	edge.apply_scraper_sample(Vector2(58, 32), Vector2.RIGHT, 80.0)
	_check(edge.total_thickness() < edge_mass_before, "scraping beyond pan edge loses batter as flying edge")


func _test_scraper_visibly_expands_coverage() -> void:
	var model := PancakeModel.new(64)
	model.add_batter(Vector2(27, 32), 2.0, 8.0)
	var coverage_before := float(model.calculate_summary().coverage_ratio)
	var sampler := StrokeSampler.new(2.0)
	var previous := Vector2(24, 32)
	sampler.begin(previous)
	for sample in sampler.sample_to(Vector2(42, 32)):
		model.apply_scraper_sample(sample, sample - previous, 45.0)
		previous = sample
	var coverage_after := float(model.calculate_summary().coverage_ratio)
	_check(coverage_after > coverage_before * 1.20, "one clear scraper pass visibly expands covered area")


func _test_spiral_reaches_playable_coverage() -> void:
	var parameters := PancakeSimulationParameters.new()
	var model := PancakeModel.new(parameters.grid_size, parameters)
	var center := Vector2(model.grid_size, model.grid_size) * 0.5
	model.add_batter(center, parameters.automatic_pour_amount, parameters.automatic_pour_radius)
	var sampler := StrokeSampler.new(parameters.scraper_sample_spacing)
	var start := center + Vector2(5.0, 0.0)
	sampler.begin(start)
	for frame in range(1, 241):
		var progress := float(frame) / 240.0
		var angle := progress * TAU * 2.6
		var radius := lerpf(5.0, float(model.grid_size) * 0.42, progress)
		var point := center + Vector2(cos(angle) * radius, sin(angle) * radius * parameters.pan_height_ratio)
		for sample in sampler.sample_to(point):
			var normalized_offset := Vector2(sample.x - center.x, (sample.y - center.y) / parameters.pan_height_ratio)
			var outward_direction := Vector2(normalized_offset.x, normalized_offset.y * parameters.pan_height_ratio).normalized()
			model.apply_scraper_sample(sample, outward_direction, 45.0)
	var coverage_after := float(model.calculate_summary().coverage_ratio)
	_check(coverage_after >= 0.90, "one center-outward spiral reaches at least 90 percent of the usable griddle area (actual %.1f percent)" % (coverage_after * 100.0))


func _test_repeated_scraping_records_damage() -> void:
	var model := PancakeModel.new(64)
	model.add_batter(Vector2(32, 32), 0.14, 14.0)
	var peak_damage := 0.0
	var holes := 0
	for pass_index in 80:
		var direction := Vector2.RIGHT if pass_index % 2 == 0 else Vector2.LEFT
		var result := model.apply_scraper_sample(Vector2(32, 32), direction, 95.0)
		peak_damage = maxf(peak_damage, float(result.peak_damage))
		holes += int(result.new_holes)
	_check(peak_damage > 0.0, "repeated scraping of a thin region records permanent damage")
	_check(holes > 0 or peak_damage >= 0.65, "repeated scraping reaches visible pre-hole warning or creates holes")


func _test_edge_operations_remain_valid() -> void:
	var model := PancakeModel.new(64)
	model.add_batter(Vector2(2, 32), 1.0, 12.0)
	model.apply_scraper_sample(Vector2(3, 32), Vector2.LEFT, 140.0)
	_check(model.validate().is_empty(), "pour and scraper writes near pan edge remain finite and in bounds")


func _timed_path_samples(fps: int) -> PackedVector2Array:
	var sampler := TimedStrokeSampler.new(1.0 / 120.0)
	var start := Vector2(10, 32)
	var finish := Vector2(54, 32)
	sampler.begin(start)
	var samples := PackedVector2Array()
	for frame in range(1, fps + 1):
		var position := start.lerp(finish, float(frame) / float(fps))
		samples.append_array(sampler.sample_to(position, 1.0 / float(fps)))
	return samples


func _simulate_pour(fps: int) -> Dictionary:
	var model := PancakeModel.new(64)
	for sample in _timed_path_samples(fps):
		model.add_batter(sample, 1.0 / 120.0, 6.0)
	return model.snapshot()


func _simulate_scrape(fps: int) -> Dictionary:
	var model := PancakeModel.new(64)
	model.add_batter(Vector2(32, 32), 0.9, 25.0)
	var sampler := StrokeSampler.new(1.5)
	var start := Vector2(14, 32)
	var finish := Vector2(50, 32)
	var previous := start
	sampler.begin(start)
	for frame in range(1, fps + 1):
		var position := start.lerp(finish, float(frame) / float(fps))
		for sample in sampler.sample_to(position):
			model.apply_scraper_sample(sample, sample - previous, 36.0)
			previous = sample
	return model.snapshot()


func _points_are_close(first: PackedVector2Array, second: PackedVector2Array, tolerance: float = EPSILON) -> bool:
	if first.size() != second.size():
		return false
	for index in first.size():
		if first[index].distance_to(second[index]) > tolerance:
			return false
	return true


func _max_field_difference(first: PackedFloat32Array, second: PackedFloat32Array) -> float:
	if first.size() != second.size():
		return INF
	var difference := 0.0
	for index in first.size():
		difference = maxf(difference, absf(first[index] - second[index]))
	return difference


func _covered_variance(values: PackedFloat32Array, coverage: PackedFloat32Array) -> float:
	var mean := 0.0
	var count := 0
	for index in values.size():
		if coverage[index] > 0.0:
			mean += values[index]
			count += 1
	if count == 0:
		return 0.0
	mean /= float(count)
	var variance := 0.0
	for index in values.size():
		if coverage[index] > 0.0:
			var difference := values[index] - mean
			variance += difference * difference
	return variance / float(count)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("P0.2 simulation self-check PASS")
		quit(0)
	else:
		print("P0.2 simulation self-check FAIL (%d)" % _failures.size())
		quit(1)
