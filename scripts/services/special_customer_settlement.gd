class_name SpecialCustomerSettlement
extends RefCounted

const SPECIALS := preload("res://scripts/data/special_customer_catalog.gd")


## Applies only the special-customer delta.  Ordinary order economics remain
## owned by GameSessionStore and are passed in as the compatibility baseline.
static func calculate(
	order: Dictionary,
	order_success: bool,
	grades: PackedStringArray,
	base_coins: int,
	normal_reputation_delta: int,
	item_results: Array = []
) -> Dictionary:
	var special_id := StringName(order.get("special_customer_id", Dictionary(order.get("metadata", {})).get("special_customer_id", &"")))
	var result := {
		"special_customer_id": special_id,
		"earned_coins": maxi(base_coins, 0),
		"reputation_delta": normal_reputation_delta,
		"perfect_bonus_coins": 0,
		"perfect_achieved": false,
		"outcome": &"ordinary",
	}
	if not SPECIALS.is_special_id(special_id):
		return result
	var perfect_quote := maxi(int(order.get("perfect_quote_coins", Dictionary(order.get("metadata", {})).get("perfect_quote_coins", base_coins))), maxi(base_coins, 0))
	match special_id:
		SPECIALS.GLUTTON:
			if order_success:
				_apply_perfect_quote(result, perfect_quote)
				result["outcome"] = &"three_portions_completed"
			else:
				result["outcome"] = &"failed"
		SPECIALS.STUDENT:
			if order_success:
				result["reputation_delta"] = normal_reputation_delta + 2
				result["outcome"] = &"budget_meal_completed"
			else:
				result["outcome"] = &"failed"
		SPECIALS.SPICY_FAN:
			var spice_target_met := order_success and _spice_target_met(item_results)
			if spice_target_met:
				_apply_perfect_quote(result, perfect_quote)
				result["outcome"] = &"spice_target_met"
			else:
				result["outcome"] = &"spice_target_missed" if order_success else &"failed"
		SPECIALS.BLOGGER:
			if order_success and _all_grade(grades, &"A"):
				_apply_perfect_quote(result, perfect_quote)
				result["reputation_delta"] = 8
				result["outcome"] = &"all_a"
			elif order_success and not _contains_grade(grades, &"C") and not _contains_grade(grades, &"waste"):
				result["outcome"] = &"contains_b"
			else:
				result["reputation_delta"] = -4
				result["outcome"] = &"negative_review"
	return result


static func failure_reputation_delta(order: Dictionary, fallback: int = -2) -> int:
	var special_id := StringName(order.get("special_customer_id", Dictionary(order.get("metadata", {})).get("special_customer_id", &"")))
	return -4 if special_id == SPECIALS.BLOGGER else fallback


static func adjusted_grades(order: Dictionary, grades: PackedStringArray, item_results: Array) -> PackedStringArray:
	var adjusted := grades.duplicate()
	var special_id := StringName(order.get("special_customer_id", Dictionary(order.get("metadata", {})).get("special_customer_id", &"")))
	if special_id != SPECIALS.SPICY_FAN or _spice_target_met(item_results):
		return adjusted
	var target_score := _lowest_spice_target_score(item_results)
	var cap := &"B" if target_score >= 65.0 else &"C"
	for index in range(adjusted.size()):
		var grade := StringName(adjusted[index])
		if _grade_rank(grade) < _grade_rank(cap):
			adjusted[index] = str(cap)
	return adjusted


static func _apply_perfect_quote(result: Dictionary, perfect_quote: int) -> void:
	var base_coins := maxi(int(result.get("earned_coins", 0)), 0)
	result["earned_coins"] = perfect_quote
	result["perfect_bonus_coins"] = maxi(perfect_quote - base_coins, 0)
	result["perfect_achieved"] = true


static func _spice_target_met(item_results: Array) -> bool:
	var found_chili_product := false
	for item_result_variant in item_results:
		var item_result := Dictionary(item_result_variant)
		for product_variant in Array(item_result.get("products", [])):
			var product := Dictionary(product_variant)
			if StringName(product.get("product_id", &"")) != &"product.pancake.custom":
				continue
			found_chili_product = true
			var basis := Dictionary(product.get("serving_score_basis", {}))
			var profiles := Dictionary(basis.get("sauce_profiles", {}))
			var chili_profiles := Dictionary(profiles.get("red_chili", profiles.get("stock.pancake.sauce.red_chili", {})))
			var target := Dictionary(chili_profiles.get("1.35", {}))
			if target.is_empty():
				var special_evaluation := Dictionary(product.get("special_evaluation", {}))
				if not bool(special_evaluation.get("spice_target_met", false)):
					return false
				continue
			if float(target.get("score", 0.0)) < 82.0 or float(target.get("coverage_ratio", 0.0)) < 0.75 or float(target.get("uniformity", 0.0)) < 0.65:
				return false
	return found_chili_product


static func _lowest_spice_target_score(item_results: Array) -> float:
	var lowest := 100.0
	var found := false
	for item_result_variant in item_results:
		for product_variant in Array(Dictionary(item_result_variant).get("products", [])):
			var product := Dictionary(product_variant)
			if StringName(product.get("product_id", &"")) != &"product.pancake.custom":
				continue
			var profiles := Dictionary(Dictionary(product.get("serving_score_basis", {})).get("sauce_profiles", {}))
			var chili_profiles := Dictionary(profiles.get("red_chili", profiles.get("stock.pancake.sauce.red_chili", {})))
			var target := Dictionary(chili_profiles.get("1.35", {}))
			var score := float(target.get("score", Dictionary(product.get("special_evaluation", {})).get("chili_score", 0.0)))
			lowest = minf(lowest, score)
			found = true
	return lowest if found else 0.0


static func _grade_rank(grade: StringName) -> int:
	return {&"A": 0, &"B": 1, &"C": 2, &"waste": 3}.get(grade, 3)


static func _all_grade(grades: PackedStringArray, target: StringName) -> bool:
	if grades.is_empty():
		return false
	for grade in grades:
		if StringName(grade) != target:
			return false
	return true


static func _contains_grade(grades: PackedStringArray, target: StringName) -> bool:
	for grade in grades:
		if StringName(grade) == target:
			return true
	return false
