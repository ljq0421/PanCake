extends SceneTree

const CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")
const MODEL := preload("res://scripts/gameplay/noodle_bowl_model.gd")
const SCORER := preload("res://scripts/gameplay/noodle_scorer.gd")
const GESTURE := preload("res://scripts/gameplay/noodle_gesture_surface.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(CATALOG.thickness_for_speed(400.0) == &"thick", "slow strokes create thick noodles")
	_check(CATALOG.thickness_for_speed(700.0) == &"standard", "middle-speed strokes create standard noodles")
	_check(CATALOG.thickness_for_speed(1000.0) == &"thin", "fast strokes create thin noodles")
	var clear_recipe := CATALOG.recipe(CATALOG.RECIPE_CLEAR)
	var tomato_recipe := CATALOG.recipe(CATALOG.RECIPE_TOMATO)
	var zhajiang_recipe := CATALOG.recipe(CATALOG.RECIPE_ZHAJIANG)
	_check(int(clear_recipe.get("sell_price", 0)) == 10 and StringName(clear_recipe.get("profile_id", &"")) == &"standard", "clear-broth menu definition uses the standard profile and ten-coin quote")
	_check(int(tomato_recipe.get("sell_price", 0)) == 16 and StringName(tomato_recipe.get("profile_id", &"")) == &"thin" and CATALOG.stock(CATALOG.STOCK_TOMATO) == {"label": "番茄鸡蛋浇头", "unit_cost": 2, "capacity": 6}, "tomato-egg menu definition uses thin noodles and six-unit paid stock")
	_check(int(zhajiang_recipe.get("sell_price", 0)) == 22 and StringName(zhajiang_recipe.get("profile_id", &"")) == &"thick" and float(zhajiang_recipe.get("drain_min", 0.0)) == 1.2 and CATALOG.stock(CATALOG.STOCK_ZHAJIANG).get("unit_cost", 0) == 3, "zhajiang menu definition uses thick noodles, long drain and three-coin stock")
	_check(CATALOG.cook_window(&"thin") == Vector2(2.0, 5.0) and CATALOG.cook_window(&"standard") == Vector2(3.0, 7.0) and CATALOG.cook_window(&"thick") == Vector2(4.0, 9.0), "thin, standard and thick batches use their authored cooking windows")
	_check(CATALOG.cook_window(&"standard", true) == Vector2(3.0, 7.8), "stable basket extends the best-window upper bound by 0.8 seconds")
	var trajectory_lengths: Array[float] = []
	for sample_count in [30, 60, 120]:
		var points := PackedVector2Array()
		for index in range(sample_count + 1):
			points.append(Vector2(120.0, 340.0).lerp(Vector2(820.0, 285.0), float(index) / float(sample_count)))
		trajectory_lengths.append(GESTURE._path_distance(points))
	_check(trajectory_lengths.max() - trajectory_lengths.min() <= 0.01, "30/60/120 FPS samples preserve the same straight-stroke distance")
	var recorded_scores: Array[float] = []
	for sample_count in [30, 60, 120]:
		recorded_scores.append(_recorded_input_score(sample_count))
	var score_spread: float = float(recorded_scores.max()) - float(recorded_scores.min())
	_check(score_spread <= maxf(recorded_scores.max() * 0.05, 0.01), "the same recorded input stays within five percent total score at 30/60/120 FPS")
	var model: RefCounted = MODEL.new()
	_check(bool(model.call("begin", CATALOG.RECIPE_CLEAR).get("success", false)), "clear-broth bowl starts")
	_check(not bool(model.call("record_stroke", 80.0, 0.1).get("success", true)), "short stroke is rejected")
	for index in 6:
		model.call("advance", 0.5)
		_check(bool(model.call("record_stroke", 140.0, 0.2).get("success", false)), "standard stroke %d is accepted" % index)
	model.call("advance", 3.0)
	_check(bool(model.call("lift_basket").get("success", false)), "six batches can be lifted")
	model.call("advance", 0.6)
	model.call("transfer_to_bowl")
	model.call("set_broth", &"broth.clear")
	model.call("add_topping", &"topping.scallion")
	var score := Dictionary(SCORER.evaluate(model.call("snapshot")))
	var cooked_batches := Array(Dictionary(model.call("snapshot")).get("batches", []))
	_check(float(Dictionary(cooked_batches.front()).get("cook_seconds", 0.0)) > float(Dictionary(cooked_batches.back()).get("cook_seconds", 0.0)), "each shaved batch keeps an independent cooking duration")
	_check(float(score.get("portion_score", 0.0)) == 100.0, "six strokes produce a full portion")
	_check(float(score.get("profile_score", 0.0)) == 100.0, "standard strokes match clear-broth profile")
	_check(float(score.get("recipe_score", 0.0)) == 100.0, "correct broth, topping and drain satisfy recipe")
	var uneven_snapshot := Dictionary(model.call("snapshot")).duplicate(true)
	var uneven_batches := Array(uneven_snapshot.get("batches", [])).duplicate(true)
	for index in range(uneven_batches.size()):
		var uneven_batch := Dictionary(uneven_batches[index]).duplicate(true)
		uneven_batch["distance"] = 90.0 if index % 2 == 0 else 300.0
		uneven_batches[index] = uneven_batch
	uneven_snapshot["batches"] = uneven_batches
	var uneven_score := Dictionary(SCORER.evaluate(uneven_snapshot))
	_check(float(uneven_score.get("blade_score", 100.0)) < float(score.get("blade_score", 0.0)), "inconsistent swipe lengths lower knife-work uniformity")
	var wrong_recipe := uneven_snapshot.duplicate(true)
	wrong_recipe["broth_id"] = &"broth.tomato"
	wrong_recipe["drain_seconds"] = 3.0
	_check(float(Dictionary(SCORER.evaluate(wrong_recipe)).get("recipe_score", 100.0)) < 100.0, "wrong broth and drain timing lower recipe correctness without blocking service")
	var restored: RefCounted = MODEL.new(model.call("snapshot"))
	_check(Dictionary(restored.call("snapshot")) == Dictionary(model.call("snapshot")), "noodle production snapshot restores exactly")
	_finish()


func _recorded_input_score(sample_count: int) -> float:
	var points := PackedVector2Array()
	for index in range(sample_count + 1):
		points.append(Vector2(120.0, 340.0).lerp(Vector2(820.0, 285.0), float(index) / float(sample_count)))
	var distance := GESTURE._path_distance(points)
	var model: RefCounted = MODEL.new()
	model.call("begin", CATALOG.RECIPE_CLEAR)
	for _index in 6:
		model.call("advance", 0.5)
		model.call("record_stroke", distance, distance / 700.0)
	model.call("advance", 3.0)
	model.call("lift_basket")
	model.call("advance", 0.6)
	model.call("transfer_to_bowl")
	model.call("set_broth", &"broth.clear")
	model.call("add_topping", &"topping.scallion")
	return float(Dictionary(SCORER.evaluate(model.call("snapshot"))).get("overall_score", 0.0))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NOODLE_SHOP_CORE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("NOODLE_SHOP_CORE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
