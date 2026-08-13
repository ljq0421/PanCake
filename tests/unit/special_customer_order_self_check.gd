extends SceneTree

const GENERATOR := preload("res://scripts/services/five_area_playable_order_generator.gd")
const SPECIALS := preload("res://scripts/data/special_customer_catalog.gd")
const ECONOMICS := preload("res://scripts/services/special_customer_settlement.gd")
const ORDERS := preload("res://scripts/services/five_area_order_service.gd")
const SCORER := preload("res://scripts/gameplay/pancake_scorer.gd")
const PANCAKE_MODEL := preload("res://scripts/simulation/pancake_model.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := _fully_playable_progression()
	_check_unlocks(progression)
	_check_probability_and_state(progression)
	_check_priority_suppression(progression)
	_check_special_order_shapes(progression)
	_check_settlement_rules()
	_check_order_round_trip()
	_check_formal_settlement_transaction()
	_check_spice_target_scoring()
	_finish()


func _check_unlocks(full: Dictionary) -> void:
	var student_only := full.duplicate(true)
	student_only["tutorial"]["completed_area_ids"] = [&"area.pancake"]
	student_only["unlocked_stock_ids"].erase(&"stock.pancake.sauce.red_chili")
	_check(SPECIALS.eligible_ids(student_only) == [SPECIALS.STUDENT], "pancake tutorial unlocks only the student special before chili")
	student_only["unlocked_stock_ids"].append(&"stock.pancake.sauce.red_chili")
	_check(SPECIALS.eligible_ids(student_only).has(SPECIALS.SPICY_FAN), "red chili stock unlocks the spicy special")
	var through_youtiao := full.duplicate(true)
	through_youtiao["tutorial"]["completed_area_ids"] = [&"area.pancake", &"area.youtiao"]
	_check(SPECIALS.eligible_ids(through_youtiao).has(SPECIALS.GLUTTON) and not SPECIALS.eligible_ids(through_youtiao).has(SPECIALS.BLOGGER), "youtiao tutorial unlocks glutton before the three-area blogger")
	_check(SPECIALS.eligible_ids(full).has(SPECIALS.BLOGGER), "three completed area tutorials unlock the blogger")


func _check_probability_and_state(progression: Dictionary) -> void:
	var special_count := 0
	for sequence in range(1, 5001):
		var generated := Dictionary(GENERATOR.generate(progression, {}, 81473, sequence, 9, 0, {
			"special_state": SPECIALS.default_state(9),
			"queue_has_special_customer": false,
		}))
		special_count += int(_special_id(generated) != &"")
	var ratio := float(special_count) / 5000.0
	_check(absf(ratio - 0.20) <= 0.02, "unconstrained deterministic sampling stays near 20 percent")
	var first := GENERATOR.generate(progression, {}, 81473, 37, 9, 0, {"special_state": SPECIALS.default_state(9)})
	var repeated := GENERATOR.generate(progression, {}, 81473, 37, 9, 0, {"special_state": SPECIALS.default_state(9)})
	_check(first == repeated, "special generation is reproducible for a fixed seed and state")

	var state := SPECIALS.default_state(9)
	var generated_sequences := PackedInt32Array()
	var generated_ids := PackedStringArray()
	for sequence in range(1, 301):
		var candidate := Dictionary(GENERATOR.generate(progression, {}, 123456, sequence, 9, 0, {
			"special_state": state,
			"queue_has_special_customer": false,
		}))
		state = Dictionary(candidate.get("special_state", state)).duplicate(true)
		var special_id := _special_id(candidate)
		if special_id.is_empty():
			continue
		generated_sequences.append(sequence)
		generated_ids.append(str(special_id))
	_check(generated_sequences.size() == 3, "daily state caps special customers at three")
	for index in range(1, generated_sequences.size()):
		_check(generated_sequences[index] - generated_sequences[index - 1] >= 3, "special customers have two ordinary generated positions between them")
		_check(generated_ids[index] != generated_ids[index - 1], "eligible special types do not repeat consecutively")

	var batch_seen := false
	for first_sequence in range(1, 80):
		var batch := Dictionary(GENERATOR.generate_queue_candidates(progression, {}, 9981, first_sequence, 6, 9, 0, {}, {
			"special_state": SPECIALS.default_state(9),
			"queue_has_special_customer": false,
		}))
		var batch_specials := 0
		for candidate_variant in Array(batch.get("candidates", [])):
			batch_specials += int(not _special_id(Dictionary(candidate_variant)).is_empty())
		_check(batch_specials <= 1, "one generated open queue never contains two special customers")
		batch_seen = batch_seen or batch_specials == 1
	_check(batch_seen, "batch sampling reaches a special customer while enforcing the queue cap")

	var queue_blocked := GENERATOR.generate(progression, {}, 81473, 37, 9, 0, {
		"special_state": SPECIALS.default_state(9),
		"queue_has_special_customer": true,
	})
	_check(_special_id(queue_blocked).is_empty(), "an existing queued special suppresses another special")


func _check_priority_suppression(progression: Dictionary) -> void:
	var tutorial_progression := progression.duplicate(true)
	tutorial_progression["tutorial"] = {
		"completed_area_ids": [&"area.pancake"],
		"active_kind": &"area",
		"active_id": &"area.youtiao",
	}
	var tutorial_batch := Dictionary(GENERATOR.generate_queue_candidates(tutorial_progression, {}, 8, 1, 4, 4, 0, {}, {
		"special_state": SPECIALS.default_state(4),
	}))
	_check(Array(tutorial_batch.get("candidates", [])).all(func(candidate): return _special_id(Dictionary(candidate)).is_empty()), "tutorial context completely suppresses special generation")
	var promotion := {"kind": &"product", "target_id": &"product.youtiao.plain", "next_index": 0}
	var promotion_batch := Dictionary(GENERATOR.generate_queue_candidates(progression, {}, 8, 1, 6, 9, 9, promotion, {
		"special_state": SPECIALS.default_state(9),
	}))
	_check(Array(promotion_batch.get("candidates", [])).all(func(candidate): return _special_id(Dictionary(candidate)).is_empty()), "three-order promotion context completely suppresses special generation")


func _check_special_order_shapes(progression: Dictionary) -> void:
	var areas: Array[StringName] = [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"]
	var student := Dictionary(GENERATOR._special_candidate(SPECIALS.STUDENT, areas, progression, 7, 2))
	var student_item := Dictionary(Array(student.get("items", []))[0])
	_check(StringName(student_item.get("pancake_template_id", &"")) == &"order.pancake.classic" and float(Dictionary(student.get("metadata", {})).get("patience_seconds", 0.0)) == 90.0, "student orders the fixed lowest-price classic meal with 90 seconds")

	var spicy := Dictionary(GENERATOR._special_candidate(SPECIALS.SPICY_FAN, areas, progression, 7, 2))
	var spicy_item := Dictionary(Array(spicy.get("items", []))[0])
	_check(Array(spicy_item.get("sauce_ids", [])) == [&"stock.pancake.sauce.red_chili"] and is_equal_approx(float(spicy_item.get("sauce_intensity_multiplier", 0.0)), 1.35) and float(Dictionary(spicy.get("metadata", {})).get("patience_seconds", 0.0)) == 80.0, "spicy special is chili-only and carries the 1.35 target")

	var glutton := Dictionary(GENERATOR._special_candidate(SPECIALS.GLUTTON, areas, progression, 7, 2))
	var glutton_quantity := 0
	var glutton_areas := {}
	for item_variant in Array(glutton.get("items", [])):
		var item := Dictionary(item_variant)
		glutton_quantity += int(item.get("quantity", 1))
		glutton_areas[StringName(item.get("area_id", &""))] = true
	var glutton_metadata := Dictionary(glutton.get("metadata", {}))
	_check(glutton_quantity == 3 and glutton_areas.size() >= 2 and float(glutton_metadata.get("patience_seconds", 0.0)) == 150.0 and int(glutton_metadata.get("perfect_quote_coins", 0)) == roundi(float(glutton_metadata.get("base_coins", 0)) * 1.20), "glutton requests three portions from at least two product classes with the 20 percent quote")

	var blogger_counts := {}
	for sequence in range(1, 80):
		var blogger := Dictionary(GENERATOR._special_candidate(SPECIALS.BLOGGER, areas, progression, 19, sequence))
		blogger_counts[Array(blogger.get("items", [])).size()] = true
		var item_areas := {}
		for item_variant in Array(blogger.get("items", [])):
			item_areas[StringName(Dictionary(item_variant).get("area_id", &""))] = true
		_check(item_areas.size() == Array(blogger.get("items", [])).size(), "blogger items always use distinct product classes")
	_check(blogger_counts.has(2) and blogger_counts.has(3), "blogger deterministic sampling reaches both two- and three-class orders")


func _check_settlement_rules() -> void:
	var student := ECONOMICS.calculate({"special_customer_id": SPECIALS.STUDENT}, true, PackedStringArray(["A"]), 3, 4)
	_check(int(student.get("earned_coins", 0)) == 3 and int(student.get("reputation_delta", 0)) == 6, "student keeps base payment and adds two reputation")
	var glutton := ECONOMICS.calculate({"special_customer_id": SPECIALS.GLUTTON, "perfect_quote_coins": 18}, true, PackedStringArray(["A", "B"]), 15, 3)
	_check(int(glutton.get("earned_coins", 0)) == 18 and int(glutton.get("perfect_bonus_coins", 0)) == 3, "glutton successful completion pays the 20 percent quote")

	var spicy_order := {"special_customer_id": SPECIALS.SPICY_FAN, "perfect_quote_coins": 11}
	var met_product := {"product_id": &"product.pancake.custom", "serving_score_basis": {"sauce_profiles": {"red_chili": {"1.35": {"score": 90.0, "coverage_ratio": 0.95, "uniformity": 0.82}}}}}
	var missed_product := {"product_id": &"product.pancake.custom", "serving_score_basis": {"sauce_profiles": {"red_chili": {"1.35": {"score": 70.0, "coverage_ratio": 0.95, "uniformity": 0.50}}}}}
	var spicy_met := ECONOMICS.calculate(spicy_order, true, PackedStringArray(["A"]), 8, 4, [{"products": [met_product]}])
	var spicy_missed := ECONOMICS.calculate(spicy_order, true, PackedStringArray(["B"]), 8, 3, [{"products": [missed_product]}])
	_check(int(spicy_met.get("earned_coins", 0)) == 11 and bool(spicy_met.get("perfect_achieved", false)), "spicy target and uniformity award the 35 percent quote")
	_check(int(spicy_missed.get("earned_coins", 0)) == 8 and not bool(spicy_missed.get("perfect_achieved", false)), "under-target spicy delivery remains deliverable for base payment")
	_check(ECONOMICS.adjusted_grades(spicy_order, PackedStringArray(["A"]), [{"products": [missed_product]}]) == PackedStringArray(["B"]), "under-target spice caps the delivered product rating")

	var blogger_order := {"special_customer_id": SPECIALS.BLOGGER, "perfect_quote_coins": 30}
	var blogger_a := ECONOMICS.calculate(blogger_order, true, PackedStringArray(["A", "A"]), 20, 4)
	var blogger_b := ECONOMICS.calculate(blogger_order, true, PackedStringArray(["A", "B"]), 20, 3)
	var blogger_c := ECONOMICS.calculate(blogger_order, true, PackedStringArray(["A", "C"]), 20, 1)
	var blogger_failed := ECONOMICS.calculate(blogger_order, false, PackedStringArray(["C"]), 0, -2)
	_check(int(blogger_a.get("earned_coins", 0)) == 30 and int(blogger_a.get("reputation_delta", 0)) == 8, "all-A blogger result pays 50 percent bonus and totals eight reputation")
	_check(int(blogger_b.get("earned_coins", 0)) == 20 and int(blogger_b.get("reputation_delta", 0)) == 3, "B blogger result uses ordinary settlement")
	_check(int(blogger_c.get("reputation_delta", 0)) == -4 and int(blogger_failed.get("reputation_delta", 0)) == -4, "C, mismatch, and failed blogger results apply the negative review")


func _check_order_round_trip() -> void:
	var service := ORDERS.new()
	var opened := Dictionary(service.open_order([{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 3}], {
		"customer_id": &"customer_special_glutton",
		"special_customer_id": SPECIALS.GLUTTON,
		"special_title": "超能吃大胃王",
		"special_rule_text": "共3份",
		"customer_line": "三份",
		"base_coins": 15,
		"perfect_quote_coins": 18,
	}))
	var order := Dictionary(opened.get("order", {}))
	var restored := ORDERS.new(service.snapshot())
	var restored_order := Dictionary(restored.order_by_id(StringName(order.get("order_id", &""))))
	_check(StringName(order.get("customer_id", &"")) == &"customer_special_glutton" and StringName(restored_order.get("customer_id", &"")) == &"customer_special_glutton", "special role ID survives formal-order snapshot restore without entering ordinary rotation")
	_check(int(restored_order.get("perfect_quote_coins", 0)) == 18 and str(restored_order.get("special_title", "")) == "超能吃大胃王", "optional special order fields survive snapshot restore")
	_check(ORDERS.customer_id_for_sequence(1) == &"customer_01" and ORDERS.customer_id_for_sequence(21) == &"customer_01", "ordinary twenty-customer rotation remains unchanged")


func _check_formal_settlement_transaction() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for formal special settlement")
	if session == null:
		return
	session.call("begin_new_game")
	var opened := Dictionary(session.call("open_formal_order", [{
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 3,
		"temperature_mode": &"room_temperature",
		"ingredient_ids": [],
		"sauce_ids": [],
		"heat_preference": &"golden",
	}], {
		"customer_id": &"customer_special_glutton",
		"special_customer_id": SPECIALS.GLUTTON,
		"special_title": "超能吃大胃王",
		"base_coins": 15,
		"perfect_quote_coins": 18,
	}))
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	for product_index in 3:
		session.call("attach_formal_order_product", order_id, 0, {
			"product_instance_id": StringName("special.transaction.%d" % product_index),
			"area_id": &"area.pancake",
			"product_id": &"product.pancake.custom",
			"temperature_mode": &"room_temperature",
			"ingredient_ids": [],
			"sauce_ids": [],
			"heat_preference": &"golden",
			"grade": &"A",
			"score": 95.0,
		})
	var settled := Dictionary(session.call("settle_f3_order", order_id))
	var reputation_after := int(Dictionary(session.call("five_area_progression_snapshot")).get("reputation", 0))
	var payments := Array(session.call("pending_order_payments"))
	var repeated := Dictionary(session.call("settle_f3_order", order_id))
	_check(bool(settled.get("success", false)) and int(settled.get("earned_coins", 0)) == 18 and int(settled.get("perfect_bonus_coins", 0)) == 3, "formal special settlement uses the perfect quote exactly once")
	_check(payments.size() == 1 and int(Dictionary(payments[0]).get("amount", 0)) == 18 and int(Dictionary(payments[0]).get("perfect_bonus_coins", 0)) == 3, "pending payment stores special and perfect-bonus amounts")
	_check(bool(repeated.get("already_settled", false)) and Array(session.call("pending_order_payments")).size() == 1 and int(Dictionary(session.call("five_area_progression_snapshot")).get("reputation", 0)) == reputation_after, "repeated settlement is idempotent for coins and reputation")
	_check(int(Dictionary(session.call("today_bill")).get("revenue", 0)) == 18, "business ledger and bill receive the special coin amount")
	session.call("_write_save")
	session.call("_load_save")
	_check(Array(session.call("pending_order_payments")).size() == 1 and int(Dictionary(Array(session.call("pending_order_payments"))[0]).get("amount", 0)) == 18, "pending special payment survives save reload")


func _check_spice_target_scoring() -> void:
	var model := PANCAKE_MODEL.new(16)
	for index in model.cell_count:
		model.coverage[index] = 1.0
		model.chili_sauce_concentration[index] = model.parameters.sauce_target_concentration * 1.35
	var standard := Dictionary(SCORER.evaluate_sauce_type(model, &"red_chili", 1.0))
	var boosted := Dictionary(SCORER.evaluate_sauce_type(model, &"red_chili", 1.35))
	_check(is_equal_approx(float(boosted.get("target_concentration", 0.0)), model.parameters.sauce_target_concentration * 1.35) and float(boosted.get("uniformity", 0.0)) > float(standard.get("uniformity", 0.0)), "chili score is recomputed around the real 1.35 concentration target")


func _fully_playable_progression() -> Dictionary:
	return {
		"unlocked_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"],
		"device_tiers": {&"device.pancake_griddle": 2, &"device.youtiao_fryer": 2, &"device.fresh_soy_milk_machine": 2},
		"unlocked_recipe_ids": [&"recipe.pancake.base", &"recipe.youtiao.plain", &"recipe.fresh_soy_milk.yellow_bean"],
		"unlocked_product_ids": [&"product.pancake.custom", &"product.youtiao.plain", &"product.fresh_soy_milk.yellow_bean"],
		"unlocked_stock_ids": [&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.red_chili", &"stock.youtiao.plain_dough", &"stock.fresh_soy_milk.yellow_bean"],
		"tutorial": {"completed_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "active_kind": &"", "active_id": &""},
	}


func _special_id(candidate: Dictionary) -> StringName:
	return StringName(Dictionary(candidate.get("metadata", {})).get("special_customer_id", &""))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SPECIAL_CUSTOMER_ORDER_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("SPECIAL_CUSTOMER_ORDER_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
