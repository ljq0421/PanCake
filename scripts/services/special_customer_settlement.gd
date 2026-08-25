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


static func adjusted_grades(_order: Dictionary, grades: PackedStringArray, _item_results: Array) -> PackedStringArray:
	return grades.duplicate()


static func _apply_perfect_quote(result: Dictionary, perfect_quote: int) -> void:
	var base_coins := maxi(int(result.get("earned_coins", 0)), 0)
	result["earned_coins"] = perfect_quote
	result["perfect_bonus_coins"] = maxi(perfect_quote - base_coins, 0)
	result["perfect_achieved"] = true


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
