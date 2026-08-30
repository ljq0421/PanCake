class_name NightMarketScorer
extends RefCounted

const CATALOG := preload("res://scripts/data/night_market_catalog.gd")


static func evaluate(production: Dictionary, order: Dictionary, ember_baffle: bool = false, thermostat: bool = false) -> Dictionary:
	var actual_items := Array(production.get("plate_items", []))
	var required_items := Array(order.get("item_ids", []))
	var used: Dictionary = {}
	var item_results: Array[Dictionary] = []
	var matched_count := 0
	for required_value in required_items:
		var required_id := StringName(required_value)
		var match_index := -1
		for index in actual_items.size():
			if used.has(index):
				continue
			if StringName(Dictionary(actual_items[index]).get("item_id", &"")) == required_id:
				match_index = index
				break
		if match_index < 0:
			item_results.append({"item_id": required_id, "score": 0.0, "missing": true})
			continue
		used[match_index] = true
		matched_count += 1
		var plated := Dictionary(actual_items[match_index])
		item_results.append(_score_item(plated, ember_baffle, thermostat))
	var item_total := 0.0
	for result in item_results:
		item_total += float(result.get("score", 0.0))
	var item_average := item_total / maxf(float(required_items.size()), 1.0)
	var extra_count := maxi(actual_items.size() - matched_count, 0)
	var recipe_score := clampf(100.0 * float(matched_count) / maxf(float(required_items.size()), 1.0) - 20.0 * extra_count, 0.0, 100.0)
	var time_limit := maxf(float(order.get("time_limit", 48.0)), 1.0)
	var elapsed := float(production.get("elapsed_seconds", 0.0))
	var time_score := 100.0 if elapsed <= time_limit else clampf(100.0 - (elapsed - time_limit) * 4.0, 0.0, 100.0)
	var overall := clampf(item_average * 0.75 + recipe_score * 0.20 + time_score * 0.05, 0.0, 100.0)
	var grade := "A" if overall >= 90.0 else "B" if overall >= 75.0 else "C" if overall >= 60.0 else "D"
	return {
		"overall_score": overall,
		"grade": grade,
		"item_score": item_average,
		"recipe_score": recipe_score,
		"time_score": time_score,
		"matched_count": matched_count,
		"extra_count": extra_count,
		"item_results": item_results,
		"feedback": _feedback_for(overall, item_results, recipe_score),
	}


static func _score_item(plated: Dictionary, ember_baffle: bool, thermostat: bool) -> Dictionary:
	var item_id := StringName(plated.get("item_id", &""))
	var definition := CATALOG.item(item_id)
	if StringName(plated.get("line", &"")) == CATALOG.LINE_GRILL:
		return _score_grill(plated, definition, ember_baffle)
	return _score_fryer(plated, definition, thermostat)


static func _score_grill(plated: Dictionary, definition: Dictionary, ember_baffle: bool) -> Dictionary:
	var target_min := float(definition.get("target_min", 45.0))
	var target_max := float(definition.get("target_max", 68.0)) + (8.0 if ember_baffle else 0.0)
	var front := float(plated.get("front_heat", 0.0))
	var back := float(plated.get("back_heat", 0.0))
	var doneness := (_window_score(front, target_min, target_max, 4.0) + _window_score(back, target_min, target_max, 4.0)) * 0.5
	var balance := clampf(100.0 - absf(front - back) * 3.0, 0.0, 100.0)
	var actual_zone := StringName(plated.get("zone_id", &"medium"))
	var ideal_zone := StringName(definition.get("ideal_zone", &"medium"))
	var zone_score := 100.0 if actual_zone == ideal_zone else 72.0
	var seasoning_score := 100.0 if StringName(plated.get("seasoning_id", &"")) == StringName(definition.get("seasoning_id", &"")) else 0.0
	var time_score := clampf(100.0 - absf(float(plated.get("total_seconds", 0.0)) - float(definition.get("ideal_seconds", 14.0))) * 5.0, 0.0, 100.0)
	var score := doneness * 0.35 + balance * 0.25 + zone_score * 0.15 + seasoning_score * 0.15 + time_score * 0.10
	if bool(plated.get("reheated", false)):
		score = minf(score, 90.0)
	return {
		"item_id": StringName(plated.get("item_id", &"")), "line": CATALOG.LINE_GRILL, "score": score,
		"doneness_score": doneness, "balance_score": balance, "zone_score": zone_score,
		"seasoning_score": seasoning_score, "time_score": time_score,
	}


static func _score_fryer(plated: Dictionary, definition: Dictionary, thermostat: bool) -> Dictionary:
	var cook_score := _window_score(float(plated.get("cook_seconds", 0.0)), float(definition.get("cook_min", 4.0)), float(definition.get("cook_max", 7.0)), 20.0)
	var bonus := 5.0 if thermostat else 0.0
	var temp_score := _window_score(float(plated.get("average_temperature", 0.0)), float(definition.get("temp_min", 165.0)) - bonus, float(definition.get("temp_max", 185.0)) + bonus, 4.0)
	temp_score = clampf(temp_score - float(plated.get("low_temp_seconds", 0.0)) * 6.0 - float(plated.get("high_temp_seconds", 0.0)) * 8.0, 0.0, 100.0)
	var drain_score := _window_score(float(plated.get("drain_seconds", 0.0)), float(definition.get("drain_min", 0.8)), float(definition.get("drain_max", 1.8)), 40.0)
	var seasoning_score := 100.0 if StringName(plated.get("seasoning_id", &"")) == StringName(definition.get("seasoning_id", &"")) else 0.0
	var time_score := clampf(100.0 - absf(float(plated.get("total_seconds", 0.0)) - float(definition.get("ideal_seconds", 7.0))) * 8.0, 0.0, 100.0)
	var score := cook_score * 0.35 + temp_score * 0.25 + drain_score * 0.20 + seasoning_score * 0.15 + time_score * 0.05
	if bool(plated.get("reimmersed", false)):
		score = minf(score, 90.0)
	return {
		"item_id": StringName(plated.get("item_id", &"")), "line": CATALOG.LINE_FRYER, "score": score,
		"doneness_score": cook_score, "temperature_score": temp_score, "drain_score": drain_score,
		"seasoning_score": seasoning_score, "time_score": time_score,
	}


static func _window_score(value: float, minimum: float, maximum: float, penalty_per_unit: float) -> float:
	if value >= minimum and value <= maximum:
		return 100.0
	var distance := minimum - value if value < minimum else value - maximum
	return clampf(100.0 - distance * penalty_per_unit, 0.0, 100.0)


static func _feedback_for(overall: float, item_results: Array[Dictionary], recipe_score: float) -> String:
	if recipe_score < 100.0:
		return "拼盘内容和订单不完全一致。"
	for result in item_results:
		if float(result.get("seasoning_score", 100.0)) < 100.0:
			return "火候已经完成，但调味和订单不一致。"
	if overall >= 90.0:
		return "两条火线配合漂亮，火候和沥油都正好。"
	if overall >= 75.0:
		return "出餐稳当，再留意翻面均匀与提篮时机。"
	if overall >= 60.0:
		return "可以递交，但一条产线的节奏明显落后。"
	return "火候或配方偏差较大，下一单先守住一个节奏。"
