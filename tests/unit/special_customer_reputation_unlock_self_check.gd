extends SceneTree

const SPECIALS := preload("res://scripts/data/special_customer_catalog.gd")
const GENERATOR := preload("res://scripts/services/five_area_playable_order_generator.gd")
const SETTLEMENT := preload("res://scripts/services/special_customer_settlement.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_reputation_thresholds()
	_check_existing_area_requirements()
	_check_generator_gate()
	_check_ordinary_income_is_unchanged()
	_finish()


func _check_reputation_thresholds() -> void:
	var progression := _fully_unlocked_progression()
	progression["reputation"] = 19
	_check(SPECIALS.eligible_ids(progression).is_empty(), "no special customer is eligible below 20 global reputation")
	progression["reputation"] = 20
	_check(SPECIALS.eligible_ids(progression) == [SPECIALS.STUDENT], "student unlocks exactly at 20 global reputation")
	progression["reputation"] = 84
	_check(SPECIALS.eligible_ids(progression) == [SPECIALS.STUDENT], "glutton remains locked below 85 global reputation")
	progression["reputation"] = 85
	var at_85 := SPECIALS.eligible_ids(progression)
	_check(at_85.has(SPECIALS.STUDENT) and at_85.has(SPECIALS.GLUTTON) and not at_85.has(SPECIALS.BLOGGER), "glutton unlocks exactly at 85 global reputation")
	progression["reputation"] = 219
	_check(not SPECIALS.eligible_ids(progression).has(SPECIALS.BLOGGER), "blogger remains locked below 220 global reputation")
	progression["reputation"] = 220
	_check(SPECIALS.eligible_ids(progression).size() == 3 and SPECIALS.eligible_ids(progression).has(SPECIALS.BLOGGER), "all three special customers are eligible at 220 global reputation")

	var at_19 := SPECIALS.reputation_unlock_overview(19)
	var at_20 := SPECIALS.reputation_unlock_overview(20)
	var at_220 := SPECIALS.reputation_unlock_overview(220)
	_check(int(at_19.get("unlocked_count", -1)) == 0 and StringName(at_19.get("next_special_customer_id", &"")) == SPECIALS.STUDENT and int(at_19.get("remaining_reputation", -1)) == 1, "overview exposes the next student milestone and remaining reputation")
	_check(int(at_20.get("unlocked_count", -1)) == 1 and StringName(at_20.get("next_special_customer_id", &"")) == SPECIALS.GLUTTON and int(at_20.get("next_min_global_reputation", -1)) == 85, "overview advances to the glutton milestone after the student unlock")
	_check(bool(at_220.get("all_unlocked", false)) and int(at_220.get("unlocked_count", -1)) == 3 and int(at_220.get("remaining_reputation", -1)) == 0, "overview reports completion after the blogger milestone")


func _check_existing_area_requirements() -> void:
	var progression := _fully_unlocked_progression()
	progression["reputation"] = 220
	progression["tutorial"]["completed_area_ids"] = [&"area.pancake"]
	_check(SPECIALS.eligible_ids(progression) == [SPECIALS.STUDENT], "reputation supplements rather than removes the existing area tutorial requirements")


func _check_generator_gate() -> void:
	var unlocked := _fully_unlocked_progression()
	unlocked["reputation"] = 20
	var special_sequence := -1
	for sequence in range(1, 500):
		var candidate := Dictionary(GENERATOR.generate(unlocked, {}, 81473, sequence, 9, 0, {
			"special_state": SPECIALS.default_state(9),
			"queue_has_special_customer": false,
		}))
		if StringName(Dictionary(candidate.get("metadata", {})).get("special_customer_id", &"")) == SPECIALS.STUDENT:
			special_sequence = sequence
			break
	_check(special_sequence > 0, "special-order generation reaches the student after its reputation milestone")
	if special_sequence <= 0:
		return
	var locked := unlocked.duplicate(true)
	locked["reputation"] = 19
	var locked_candidate := Dictionary(GENERATOR.generate(locked, {}, 81473, special_sequence, 9, 0, {
		"special_state": SPECIALS.default_state(9),
		"queue_has_special_customer": false,
	}))
	_check(StringName(Dictionary(locked_candidate.get("metadata", {})).get("special_customer_id", &"")).is_empty(), "the same deterministic roll stays ordinary below the reputation milestone")


func _check_ordinary_income_is_unchanged() -> void:
	var ordinary := SETTLEMENT.calculate({}, true, PackedStringArray(["A"]), 11, 4)
	_check(int(ordinary.get("earned_coins", -1)) == 11 and int(ordinary.get("reputation_delta", -1)) == 4 and StringName(ordinary.get("outcome", &"")) == &"ordinary", "global reputation does not multiply ordinary order income")


func _fully_unlocked_progression() -> Dictionary:
	return {
		"unlocked_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"],
		"unlocked_recipe_ids": [&"recipe.pancake.base", &"recipe.youtiao.plain", &"recipe.fresh_soy_milk.yellow_bean"],
		"unlocked_product_ids": [&"product.pancake.custom", &"product.youtiao.plain", &"product.fresh_soy_milk.yellow_bean"],
		"unlocked_stock_ids": [&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour", &"stock.youtiao.plain_dough", &"stock.fresh_soy_milk.yellow_bean"],
		"tutorial": {"completed_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "active_kind": &"", "active_id": &""},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SPECIAL_CUSTOMER_REPUTATION_UNLOCK_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("SPECIAL_CUSTOMER_REPUTATION_UNLOCK_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
