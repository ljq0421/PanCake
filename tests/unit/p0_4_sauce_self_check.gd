extends SceneTree

const SAUCE_TOOL_STATE_SCRIPT := preload("res://scripts/gameplay/sauce_tool_state.gd")
const PANCAKE_SCORER_SCRIPT := preload("res://scripts/gameplay/pancake_scorer.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_sauce_field_lifecycle()
	_test_hold_to_dip_capacity()
	_test_sauce_frame_independence()
	_test_reentry_adds_layers_without_requiring_release()
	_test_wide_brush_covers_pancake_quickly()
	_test_scorer_distinguishes_sauce_results()
	_test_customer_review_sauce_score_contract()
	_finish()


func _test_sauce_field_lifecycle() -> void:
	var model := PancakeModel.new(32)
	_check(model.sauce_concentration.size() == 1024, "sauce concentration allocates with the logic grid")
	model.add_batter(Vector2(16, 16), 1.0, 10.0)
	var stroke_id := model.begin_sauce_stroke()
	model.apply_sauce_sample(Vector2(16, 16), 0.35, 6.0, stroke_id)
	_check(model.total_sauce() > 0.0, "sauce sample writes one layer onto covered pancake cells")
	var snapshot := model.snapshot()
	_check(snapshot.has("sauce_concentration"), "snapshot exposes sauce concentration")
	model.reset()
	_check(is_zero_approx(model.total_sauce()), "reset clears sauce concentration")


func _test_hold_to_dip_capacity() -> void:
	var state: RefCounted = SAUCE_TOOL_STATE_SCRIPT.new(1.0)
	_check(is_zero_approx(float(state.load)), "sauce brush starts empty")
	state.add(0.25)
	_check(is_equal_approx(float(state.load_ratio()), 0.25), "short dipping adds a proportional partial load")
	state.add(2.0)
	_check(is_equal_approx(float(state.load), 1.0), "dipping stops at the brush capacity")
	state.consume(0.4)
	_check(is_equal_approx(float(state.load), 0.6), "painting consumes the held sauce amount")


func _test_sauce_frame_independence() -> void:
	var baseline := _simulate_timed_brush(30)
	for fps in [60, 120]:
		var candidate := _simulate_timed_brush(fps)
		_check(_max_difference(baseline, candidate) < 0.0005, "sauce stroke is stable at 30 and %d FPS" % fps)


func _test_reentry_adds_layers_without_requiring_release() -> void:
	var model := _covered_model(64)
	var center_index := model.index_of(Vector2i(32, 32))
	var first_stroke := model.begin_sauce_stroke()
	model.apply_sauce_sample(Vector2(32, 32), 0.35, 16.0, first_stroke)
	var first_layer := model.sauce_concentration[center_index]
	model.apply_sauce_sample(Vector2(32, 32), 0.35, 16.0, first_stroke)
	_check(is_equal_approx(model.sauce_concentration[center_index], first_layer), "stationary sampling overlap does not create hidden extra layers")
	model.apply_sauce_sample(Vector2(4, 4), 0.35, 16.0, first_stroke)
	model.apply_sauce_sample(Vector2(32, 32), 0.35, 16.0, first_stroke)
	_check(model.sauce_concentration[center_index] > first_layer * 1.9, "returning over the same area while still pressed adds a second layer")
	var after_same_press_return := model.sauce_concentration[center_index]
	var second_stroke := model.begin_sauce_stroke()
	model.apply_sauce_sample(Vector2(32, 32), 0.35, 16.0, second_stroke)
	_check(is_equal_approx(model.sauce_concentration[center_index], after_same_press_return), "a third sauce serving is capped after two portions")


func _test_wide_brush_covers_pancake_quickly() -> void:
	var model := _covered_model(64)
	var stroke_id := model.begin_sauce_stroke()
	var sampler := StrokeSampler.new(6.0)
	var path := [Vector2(6, 19), Vector2(58, 19), Vector2(58, 32), Vector2(6, 32), Vector2(6, 45), Vector2(58, 45)]
	var painted_cells := 0
	sampler.begin(path[0])
	var first_result := model.apply_sauce_sample(path[0], 0.35, 16.0, stroke_id)
	painted_cells += int(first_result.newly_layered_cells)
	for endpoint in path.slice(1):
		for sample in sampler.sample_to(endpoint):
			var result := model.apply_sauce_sample(sample, 0.35, 16.0, stroke_id)
			painted_cells += int(result.newly_layered_cells)
	var covered_cells := model.covered_cell_count()
	_check(float(painted_cells) / maxf(float(covered_cells), 1.0) >= 0.95, "one wide zigzag stroke covers at least 95% of a typical pancake")
	_check(parameters_are_simplified(model.parameters), "wide brush parameters require only a few broad passes")


func _test_scorer_distinguishes_sauce_results() -> void:
	var uniform := _covered_model(64)
	uniform.sauce_concentration = _filled_sauce(uniform, uniform.parameters.sauce_target_concentration, false)
	var uniform_result: Dictionary = PANCAKE_SCORER_SCRIPT.evaluate_sauce(uniform)
	_check(float(uniform_result.score) >= 99.0 and (uniform_result.tags as PackedStringArray).has("酱料均匀"), "one uniform layer receives the uniform sauce result")

	var missing := _covered_model(64)
	missing.sauce_concentration = _filled_sauce(missing, missing.parameters.sauce_target_concentration, true)
	var missing_result: Dictionary = PANCAKE_SCORER_SCRIPT.evaluate_sauce(missing)
	_check((missing_result.tags as PackedStringArray).has("局部缺酱"), "partial coverage receives the missing-sauce result")

	var excessive := _covered_model(64)
	excessive.sauce_concentration = _filled_sauce(excessive, excessive.parameters.sauce_excess_threshold + 0.25, false)
	var excessive_result: Dictionary = PANCAKE_SCORER_SCRIPT.evaluate_sauce(excessive)
	_check((excessive_result.tags as PackedStringArray).has("酱料过量"), "repeated layers above the threshold receive the excessive-sauce result")


func _test_customer_review_sauce_score_contract() -> void:
	var plain_order := {"heat_preference": &"golden", "ingredients": [], "sauces": [], "time_limit": 72.0}
	var plain_model := _covered_model(32)
	plain_model.doneness.fill(0.50)
	plain_model.back_doneness.fill(0.50)
	var plain_ingredients := IngredientModel.new()
	var plain_result := Dictionary(PANCAKE_SCORER_SCRIPT.evaluate_order(plain_model, plain_ingredients, PancakeFoldModel.new(plain_model, plain_ingredients), plain_order, 20.0, 1.0))
	var plain_review := Dictionary(PANCAKE_SCORER_SCRIPT.evaluate_stored_product({"serving_score_basis": plain_result.get("serving_score_basis", {})}, plain_order, 20.0, 1.0))
	_check(is_equal_approx(float(Dictionary(plain_result.get("dimensions", {})).get("sauce", 0.0)), 100.0) and is_equal_approx(float(Dictionary(plain_review.get("dimensions", {})).get("sauce", 0.0)), 100.0), "orders without sauce receive a 100 sauce score in both completion and customer review")

	var automatic_order := {"heat_preference": &"golden", "ingredients": [], "sauces": [OrderService.SAUCE_SWEET], "time_limit": 72.0}
	var automatic_model := _covered_model(32)
	automatic_model.doneness.fill(0.50)
	automatic_model.back_doneness.fill(0.50)
	automatic_model.sauce_concentration.fill(automatic_model.parameters.sauce_target_concentration)
	var automatic_ingredients := IngredientModel.new()
	var automatic_result := Dictionary(PANCAKE_SCORER_SCRIPT.evaluate_order(automatic_model, automatic_ingredients, PancakeFoldModel.new(automatic_model, automatic_ingredients), automatic_order, 20.0, 1.0, false, true))
	var automatic_review := Dictionary(PANCAKE_SCORER_SCRIPT.evaluate_stored_product({"serving_score_basis": automatic_result.get("serving_score_basis", {})}, automatic_order, 20.0, 1.0))
	_check(is_equal_approx(float(Dictionary(automatic_result.get("dimensions", {})).get("sauce", 0.0)), 100.0) and is_equal_approx(float(Dictionary(automatic_review.get("dimensions", {})).get("sauce", 0.0)), 100.0), "automatic sauce receives a 100 sauce score in both completion and customer review")


func _simulate_timed_brush(fps: int) -> PackedFloat32Array:
	var model := _covered_model(64)
	var sampler := StrokeSampler.new(6.0)
	var start := Vector2(8, 32)
	var finish := Vector2(56, 32)
	var stroke_id := model.begin_sauce_stroke()
	sampler.begin(start)
	model.apply_sauce_sample(start, 0.35, 16.0, stroke_id)
	for frame in range(1, fps + 1):
		var position := start.lerp(finish, float(frame) / float(fps))
		for sample in sampler.sample_to(position):
			model.apply_sauce_sample(sample, 0.35, 16.0, stroke_id)
	return model.sauce_concentration.duplicate()


func _covered_model(size: int) -> PancakeModel:
	var model := PancakeModel.new(size)
	model.add_batter(Vector2(size, size) * 0.5, 2.0, float(size) * 0.42)
	return model


func _filled_sauce(model: PancakeModel, concentration: float, left_half_only: bool) -> PackedFloat32Array:
	var result := model.sauce_concentration.duplicate()
	for y in model.grid_size:
		for x in model.grid_size:
			var index := y * model.grid_size + x
			if model.coverage[index] > 0.0 and (not left_half_only or x < (model.grid_size >> 1)):
				result[index] = concentration
	return result


func parameters_are_simplified(parameters: PancakeSimulationParameters) -> bool:
	return parameters.sauce_brush_radius >= 15.0 and parameters.sauce_sample_spacing >= 6.0


func _max_difference(first: PackedFloat32Array, second: PackedFloat32Array) -> float:
	var difference := 0.0
	for index in first.size():
		difference = maxf(difference, absf(first[index] - second[index]))
	return difference


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("P0.4 sauce self-check PASS")
		quit(0)
	else:
		print("P0.4 sauce self-check FAIL (%d)" % _failures.size())
		quit(1)
