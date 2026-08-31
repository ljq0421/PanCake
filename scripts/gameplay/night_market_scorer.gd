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
			item_results.append({
				"item_id": required_id,
				"score": 0.0,
				"missing": true,
				"diagnostic": "%s：缺少餐品，按订单补齐后再出餐。" % CATALOG.item_label(required_id),
			})
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
	var diagnostics := PackedStringArray()
	for result in item_results:
		var diagnostic := str(result.get("diagnostic", ""))
		if not diagnostic.is_empty():
			diagnostics.append(diagnostic)
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
		"diagnostics": diagnostics,
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
		"diagnostic": _grill_diagnostic(
			StringName(plated.get("item_id", &"")), front, back, target_min, target_max,
			actual_zone, ideal_zone, StringName(plated.get("seasoning_id", &"")),
			StringName(definition.get("seasoning_id", &"")), float(plated.get("total_seconds", 0.0)),
			float(definition.get("ideal_seconds", 14.0)), doneness, balance, zone_score, seasoning_score, time_score,
		),
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
		"diagnostic": _fryer_diagnostic(
			StringName(plated.get("item_id", &"")), float(plated.get("cook_seconds", 0.0)),
			float(plated.get("average_temperature", 0.0)), float(plated.get("drain_seconds", 0.0)),
			StringName(plated.get("seasoning_id", &"")), StringName(definition.get("seasoning_id", &"")),
			float(plated.get("total_seconds", 0.0)), definition, cook_score, temp_score, drain_score,
			seasoning_score, time_score,
		),
	}


static func _grill_diagnostic(
	item_id: StringName,
	front: float,
	back: float,
	target_min: float,
	target_max: float,
	actual_zone: StringName,
	ideal_zone: StringName,
	actual_seasoning: StringName,
	ideal_seasoning: StringName,
	total_seconds: float,
	ideal_seconds: float,
	doneness_score: float,
	balance_score: float,
	zone_score: float,
	seasoning_score: float,
	time_score: float,
) -> String:
	var label := CATALOG.item_label(item_id)
	var candidates: Array[Dictionary] = [
		{"score": doneness_score, "text": _grill_doneness_diagnostic(label, front, back, target_min, target_max)},
		{"score": balance_score, "text": "%s：两面受热不均，中途翻面并让两面时长接近。" % label},
		{"score": zone_score, "text": "%s：火区不合适，下次使用%s。" % [label, _zone_label(ideal_zone)]},
		{"score": seasoning_score, "text": "%s：调味不符，应撒%s。" % [label, CATALOG.seasoning_label(ideal_seasoning)]},
		{"score": time_score, "text": _grill_timing_diagnostic(label, total_seconds, ideal_seconds)},
	]
	return _lowest_diagnostic(candidates, "%s：火候、翻面和调味都到位。" % label)


static func _fryer_diagnostic(
	item_id: StringName,
	cook_seconds: float,
	average_temperature: float,
	drain_seconds: float,
	actual_seasoning: StringName,
	ideal_seasoning: StringName,
	total_seconds: float,
	definition: Dictionary,
	cook_score: float,
	temperature_score: float,
	drain_score: float,
	seasoning_score: float,
	time_score: float,
) -> String:
	var label := CATALOG.item_label(item_id)
	var candidates: Array[Dictionary] = [
		{"score": cook_score, "text": _fryer_cook_diagnostic(label, cook_seconds, float(definition.get("cook_min", 4.0)), float(definition.get("cook_max", 7.0)))},
		{"score": temperature_score, "text": _fryer_temperature_diagnostic(label, average_temperature, float(definition.get("temp_min", 165.0)), float(definition.get("temp_max", 185.0)))},
		{"score": drain_score, "text": _fryer_drain_diagnostic(label, drain_seconds, float(definition.get("drain_min", 0.8)), float(definition.get("drain_max", 1.8)))},
		{"score": seasoning_score, "text": "%s：调味不符，应撒%s。" % [label, CATALOG.seasoning_label(ideal_seasoning)]},
		{"score": time_score, "text": _fryer_timing_diagnostic(label, total_seconds, float(definition.get("ideal_seconds", 7.0)))},
	]
	return _lowest_diagnostic(candidates, "%s：油温、炸制和沥油都到位。" % label)


static func _lowest_diagnostic(candidates: Array[Dictionary], success_text: String) -> String:
	var lowest_score := 101.0
	var diagnostic := success_text
	for candidate in candidates:
		var score := float(candidate.get("score", 100.0))
		if score < lowest_score:
			lowest_score = score
			diagnostic = str(candidate.get("text", success_text))
	return success_text if lowest_score >= 90.0 else diagnostic


static func _grill_doneness_diagnostic(label: String, front: float, back: float, minimum: float, maximum: float) -> String:
	var front_state := _heat_state(front, minimum, maximum)
	var back_state := _heat_state(back, minimum, maximum)
	if front_state == "偏生" and back_state == "偏生":
		return "%s：两面偏生，应延长烤制。" % label
	if front_state == "过火" and back_state == "过火":
		return "%s：两面过火，应提前起串。" % label
	return "%s：正面%s、反面%s，应更早翻面并让两面均匀。" % [label, front_state, back_state]


static func _heat_state(value: float, minimum: float, maximum: float) -> String:
	if value < minimum:
		return "偏生"
	if value > maximum:
		return "过火"
	return "正好"


static func _grill_timing_diagnostic(label: String, total_seconds: float, ideal_seconds: float) -> String:
	return "%s：起串偏早，观察两面金黄后再装盘。" % label if total_seconds < ideal_seconds else "%s：在火上停留过久，达到金黄就及时起串。" % label


static func _fryer_cook_diagnostic(label: String, value: float, minimum: float, maximum: float) -> String:
	return "%s：炸制偏短，颜色金黄后再提篮。" % label if value < minimum else "%s：炸制过久，应提前提篮。" % label


static func _fryer_temperature_diagnostic(label: String, value: float, minimum: float, maximum: float) -> String:
	if value < minimum:
		return "%s：油温偏低，升温后再下篮。" % label
	if value > maximum:
		return "%s：油温偏高，降低火力再炸。" % label
	return "%s：油温波动较大，尽量保持在适宜区间。" % label


static func _fryer_drain_diagnostic(label: String, value: float, minimum: float, maximum: float) -> String:
	return "%s：沥油不足，提篮后等到滴油变缓再装盘。" % label if value < minimum else "%s：沥油过久，滴油变缓后应及时装盘。" % label


static func _fryer_timing_diagnostic(label: String, total_seconds: float, ideal_seconds: float) -> String:
	return "%s：整体节奏偏快，按上色与滴油状态再装盘。" % label if total_seconds < ideal_seconds else "%s：整体节奏偏慢，达到目标状态后及时装盘。" % label


static func _zone_label(zone_id: StringName) -> String:
	return {
		CATALOG.ZONE_LOW: "小火区",
		CATALOG.ZONE_MEDIUM: "中火区",
		CATALOG.ZONE_HIGH: "旺火区",
	}.get(zone_id, "合适火区")


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
