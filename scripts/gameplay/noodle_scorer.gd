class_name NoodleScorer
extends RefCounted

const CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")

const WEIGHT_BLADE := 0.25
const WEIGHT_DONENESS := 0.30
const WEIGHT_PROFILE := 0.15
const WEIGHT_PORTION := 0.10
const WEIGHT_RECIPE := 0.15
const WEIGHT_TIME := 0.05

static func evaluate(snapshot: Dictionary, sharp_knife: bool = false, stable_basket: bool = false) -> Dictionary:
	var recipe := CATALOG.recipe(StringName(snapshot.get("recipe_id", &"")))
	if recipe.is_empty():
		return {"success": false, "reason": &"unknown_recipe", "overall_score": 0.0, "grade": "D"}
	var batches := Array(snapshot.get("batches", []))
	var target_profile := StringName(recipe.get("profile_id", &"standard"))
	var blade_score := _blade_uniformity_score(batches, sharp_knife)
	var doneness_score := _doneness_score(batches, stable_basket)
	doneness_score = minf(doneness_score, float(snapshot.get("undercook_repair_cap", 100.0)))
	var profile_score := _profile_score(batches, target_profile, sharp_knife)
	var portion_score := clampf(100.0 - absf(float(batches.size() - CATALOG.TARGET_BATCH_COUNT)) * 20.0, 0.0, 100.0)
	var recipe_score := _recipe_score(snapshot, recipe)
	var time_limit := maxf(float(recipe.get("time_limit", 30.0)), 1.0)
	var elapsed := maxf(float(snapshot.get("elapsed_seconds", 0.0)), 0.0)
	var time_score := 100.0 * clampf(1.0 - maxf(elapsed - time_limit * 0.55, 0.0) / (time_limit * 0.75), 0.0, 1.0)
	var overall := (
		blade_score * WEIGHT_BLADE
		+ doneness_score * WEIGHT_DONENESS
		+ profile_score * WEIGHT_PROFILE
		+ portion_score * WEIGHT_PORTION
		+ recipe_score * WEIGHT_RECIPE
		+ time_score * WEIGHT_TIME
	)
	var tags := PackedStringArray()
	if blade_score < 60.0:
		tags.append("刀工不匀")
	if doneness_score < 60.0:
		tags.append("前后熟度不一")
	if profile_score < 60.0:
		tags.append("粗细不合要求")
	if portion_score < 80.0:
		tags.append("分量有偏差")
	if recipe_score < 100.0:
		tags.append("汤底或浇头不符")
	if tags.is_empty():
		tags.append("刀工利落，熟度正好")
	return {
		"success": true,
		"overall_score": overall,
		"grade": _grade(overall),
		"blade_score": blade_score,
		"doneness_score": doneness_score,
		"profile_score": profile_score,
		"portion_score": portion_score,
		"recipe_score": recipe_score,
		"time_score": time_score,
		"tags": tags,
		"feedback": tags[0] if not tags.is_empty() else "这碗面做得不错。",
	}


static func _blade_uniformity_score(batches: Array, sharp_knife: bool) -> float:
	if batches.size() <= 1:
		return 35.0 if batches.size() == 1 else 0.0
	var speeds: Array[float] = []
	var lengths: Array[float] = []
	for value in batches:
		var batch := Dictionary(value)
		speeds.append(maxf(float(batch.get("speed", 0.0)), 0.0))
		lengths.append(maxf(float(batch.get("distance", 0.0)), 0.0))
	var speed_coefficient := _coefficient_of_variation(speeds)
	var length_coefficient := _coefficient_of_variation(lengths)
	# Stroke speed controls thickness while travelled distance controls noodle
	# length.  Both must be repeatable for the knife-work score to be high.
	var tolerance := 0.46 if sharp_knife else 0.36
	var coefficient := speed_coefficient * 0.6 + length_coefficient * 0.4
	return 100.0 * clampf(1.0 - coefficient / tolerance, 0.0, 1.0)


static func _coefficient_of_variation(values: Array[float]) -> float:
	if values.is_empty():
		return 1.0
	var mean := 0.0
	for value in values:
		mean += value
	mean /= float(values.size())
	var variance := 0.0
	for value in values:
		variance += pow(value - mean, 2.0)
	variance /= float(values.size())
	return sqrt(variance) / maxf(mean, 1.0)


static func _doneness_score(batches: Array, stable_basket: bool) -> float:
	if batches.is_empty():
		return 0.0
	var total := 0.0
	for value in batches:
		var batch := Dictionary(value)
		var profile := StringName(batch.get("thickness_id", &"standard"))
		var window := CATALOG.cook_window(profile, stable_basket)
		var cooked := maxf(float(batch.get("cook_seconds", 0.0)), 0.0)
		var score := 100.0
		if cooked < window.x:
			score = 100.0 * clampf(1.0 - (window.x - cooked) / 3.0, 0.0, 1.0)
		elif cooked > window.y:
			score = 100.0 * clampf(1.0 - (cooked - window.y) / 3.0, 0.0, 1.0)
		total += score
	return total / float(batches.size())


static func _profile_score(batches: Array, target: StringName, sharp_knife: bool) -> float:
	if batches.is_empty():
		return 0.0
	var matching := 0
	for value in batches:
		if StringName(Dictionary(value).get("thickness_id", &"standard")) == target:
			matching += 1
	var ratio := float(matching) / float(batches.size())
	if sharp_knife:
		ratio = clampf(ratio + 0.08, 0.0, 1.0)
	return ratio * 100.0


static func _recipe_score(snapshot: Dictionary, recipe: Dictionary) -> float:
	var parts := 1
	var matches := 1 if StringName(snapshot.get("broth_id", &"")) == StringName(recipe.get("broth_id", &"")) else 0
	var actual_toppings := PackedStringArray(Array(snapshot.get("topping_ids", [])).map(func(value): return str(value)))
	actual_toppings.sort()
	var expected_toppings := PackedStringArray(Array(recipe.get("topping_ids", [])).map(func(value): return str(value)))
	expected_toppings.sort()
	parts += 1
	if actual_toppings == expected_toppings:
		matches += 1
	var drain := float(snapshot.get("drain_seconds", 0.0))
	parts += 1
	if drain >= float(recipe.get("drain_min", 0.0)) and drain <= float(recipe.get("drain_max", 99.0)):
		matches += 1
	return 100.0 * float(matches) / float(parts)


static func _grade(score: float) -> String:
	if score >= 90.0:
		return "A"
	if score >= 75.0:
		return "B"
	if score >= 60.0:
		return "C"
	return "D"
