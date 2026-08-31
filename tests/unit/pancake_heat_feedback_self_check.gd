extends SceneTree

const PANCAKE_SCORER_SCRIPT := preload("res://scripts/gameplay/pancake_scorer.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_shared_heat_boundaries()
	_test_local_heat_variation_is_explained()
	_finish()


func _test_shared_heat_boundaries() -> void:
	_check(
		not PANCAKE_SCORER_SCRIPT.heat_is_suitable_metrics({"mean_front_doneness": 0.249, "mean_back_doneness": 0.50})
		and PANCAKE_SCORER_SCRIPT.heat_is_suitable_metrics({"mean_front_doneness": 0.25, "mean_back_doneness": 0.749})
		and not PANCAKE_SCORER_SCRIPT.heat_is_suitable_metrics({"mean_front_doneness": 0.75, "mean_back_doneness": 0.50}),
		"shared heat contract treats 0.25 as suitable and 0.75 as charred"
	)


func _test_local_heat_variation_is_explained() -> void:
	var model := PancakeModel.new(32)
	model.add_batter(Vector2(16, 16), 2.0, 13.0)
	var hot_cell := false
	for index in model.cell_count:
		if model.coverage[index] <= 0.0:
			continue
		# Both sides average inside the suitable band, but each side has large local
		# variation. This reproduces the previously unexplained low heat score.
		var doneness := 0.92 if hot_cell else 0.36
		model.doneness[index] = doneness
		model.back_doneness[index] = doneness
		model.egg_white[index] = model.parameters.egg_coverage_minimum * 2.0
		hot_cell = not hot_cell
	model.yolk_broken = true
	model.flip(false)
	var ingredients := IngredientModel.new()
	var order := {"ingredients": [], "sauces": [], "time_limit": 72.0}
	var completed := Dictionary(PANCAKE_SCORER_SCRIPT.evaluate_order(
		model,
		ingredients,
		PancakeFoldModel.new(model, ingredients),
		order,
		20.0,
		1.0
	))
	var completed_tags := PackedStringArray(completed.get("tags", []))
	_check(
		float(Dictionary(completed.get("dimensions", {})).get("heat", 100.0)) < 60.0
		and completed_tags.has("火候不均")
		and str(completed.get("feedback", "")).contains("火候不够均匀"),
		"low local heat score with suitable side averages reports uneven heat"
	)
	var stored := Dictionary(PANCAKE_SCORER_SCRIPT.evaluate_stored_product(
		{"serving_score_basis": completed.get("serving_score_basis", {})},
		order,
		20.0,
		1.0
	))
	_check(
		PackedStringArray(stored.get("tags", [])).has("火候不均")
		and str(stored.get("feedback", "")).contains("火候不够均匀"),
		"stored-product customer review preserves the uneven-heat explanation"
	)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("Pancake heat feedback self-check PASS")
		quit(0)
	else:
		print("Pancake heat feedback self-check FAIL (%d)" % _failures.size())
		quit(1)
