extends SceneTree

const GENERATOR := preload("res://scripts/services/five_area_playable_order_generator.gd")
const ORDER_SERVICE := preload("res://scripts/services/five_area_order_service.gd")
const PROGRESSION_SERVICE := preload("res://scripts/services/five_area_progression_service.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := _fully_playable_progression()
	var empty_inventory := _inventory(0)
	var first: Dictionary = GENERATOR.generate(progression, empty_inventory, 24680, 7, 8, 0)
	var repeated: Dictionary = GENERATOR.generate(progression, empty_inventory, 24680, 7, 8, 0)
	_check(first == repeated, "fixed seed and sequence generate an identical playable order")
	_check(bool(first.get("success", false)) and Array(first.get("items", [])).size() >= 1 and Array(first.get("items", [])).size() <= 3, "full-table generation produces one to three items")
	_check(_is_supported_area(_area_id(first)), "normal generation uses a supported five-area product")
	_check(bool(first.get("success", false)), "normal generation ignores zero physical stock")

	var seen := {}
	var heated_count := 0
	var sampled_only_supported := true
	var complexity_counts := {1: 0, 2: 0, 3: 0}
	for sequence in range(1, 401):
		var generated: Dictionary = GENERATOR.generate(progression, empty_inventory, 24680, sequence, 8, 0)
		var generated_items := Array(generated.get("items", []))
		complexity_counts[generated_items.size()] = int(complexity_counts.get(generated_items.size(), 0)) + 1
		for generated_item in generated_items:
			var generated_area_id := StringName(Dictionary(generated_item).get("area_id", &""))
			seen[generated_area_id] = true
			sampled_only_supported = sampled_only_supported and _is_supported_area(generated_area_id)
		var area_id := _area_id(generated)
		var item := _item(generated)
		if area_id == &"area.packaged_drink" and StringName(item.get("temperature_mode", &"")) == &"heated":
			heated_count += 1
	_check(seen.has(&"area.pancake") and seen.has(&"area.packaged_drink") and seen.has(&"area.youtiao") and seen.has(&"area.fresh_soy_milk") and seen.has(&"area.steamer"), "deterministic weighted sampling can reach all five playable areas")
	_check(sampled_only_supported, "sampled normal orders stay inside the playable area allowlist")
	_check(int(complexity_counts[1]) > int(complexity_counts[2]) and int(complexity_counts[2]) > int(complexity_counts[3]) and int(complexity_counts[3]) > 0, "deterministic full-table sampling follows the 72/20/8 ordering")
	_check(heated_count > 0, "completed drink training enables deterministic heated-drink orders")
	var cabinet_only_progression := progression.duplicate(true)
	cabinet_only_progression["device_tiers"] = {&"device.pancake_griddle": 1, &"device.youtiao_fryer": 0, &"device.fresh_soy_milk_machine": 1, &"device.steamer": 1}
	cabinet_only_progression["tutorial"] = Dictionary(progression.get("tutorial", {})).duplicate(true)
	Dictionary(cabinet_only_progression["tutorial"])["completed_device_ids"] = []
	var cabinet_only_has_heated := false
	for sequence in range(1, 301):
		for candidate_item in Array(GENERATOR.generate(cabinet_only_progression, empty_inventory, 86420, sequence, 8, 0).get("items", [])):
			var item := Dictionary(candidate_item)
			cabinet_only_has_heated = cabinet_only_has_heated or (StringName(item.get("area_id", &"")) == &"area.packaged_drink" and StringName(item.get("temperature_mode", &"")) == &"heated")
	_check(not cabinet_only_has_heated, "cabinet ownership alone generates only room-temperature packaged drinks")

	var teaching_progression := progression.duplicate(true)
	teaching_progression["tutorial"] = {
		"completed_area_ids": [&"area.pancake"],
		"active_kind": &"area",
		"active_id": &"area.packaged_drink",
	}
	var teaching: Dictionary = GENERATOR.generate(teaching_progression, empty_inventory, 9, 1, 3, 0)
	_check(bool(teaching.get("success", false)) and Array(teaching.get("required_stock_ids", [])).has("stock.packaged_drink.milk"), "drink teaching appears at zero stock while retaining its real milk requirement")
	var stocked_inventory := _inventory(0)
	stocked_inventory["stock.packaged_drink.milk"] = 1
	var stocked_teaching: Dictionary = GENERATOR.generate(teaching_progression, stocked_inventory, 9, 1, 3, 0)
	_check(_area_id(teaching) == &"area.packaged_drink" and StringName(_item(teaching).get("temperature_mode", &"")) == &"room_temperature", "starter drink teaching is a room-temperature single item")
	_check(Array(stocked_teaching.get("items", [])).size() == 1 and _item(stocked_teaching) == _item(teaching), "restocking does not replace or expand the authored drink teaching item")
	_check(bool(Dictionary(teaching.get("metadata", {})).get("tutorial_no_countdown", false)) and is_equal_approx(float(Dictionary(teaching.get("metadata", {})).get("patience_seconds", 0.0)), 24.0), "drink teaching is explicitly unlimited instead of receiving a hidden countdown")
	var heater_teaching_progression := progression.duplicate(true)
	heater_teaching_progression["tutorial"] = {
		"completed_area_ids": [&"area.pancake", &"area.packaged_drink"],
		"completed_device_ids": [],
		"active_kind": &"device",
		"active_id": &"device.packaged_drink_heater",
	}
	var heater_teaching := GENERATOR.generate(heater_teaching_progression, empty_inventory, 9, 1, 4, 0)
	_check(
		bool(heater_teaching.get("success", false))
		and StringName(_item(heater_teaching).get("product_id", &"")) == &"product.packaged_drink.milk"
		and StringName(_item(heater_teaching).get("temperature_mode", &"")) == &"heated"
		and StringName(Dictionary(heater_teaching.get("metadata", {})).get("tutorial_kind", &"")) == &"device"
		and StringName(Dictionary(heater_teaching.get("metadata", {})).get("tutorial_id", &"")) == &"device.packaged_drink_heater",
		"heater tutorial is one unlimited heated-milk teaching order with generic tutorial identity"
	)
	var promotion_cases := [
		{"kind": &"area", "id": &"area.pancake", "product_id": &"product.pancake.custom"},
		{"kind": &"area", "id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk"},
		{"kind": &"area", "id": &"area.youtiao", "product_id": &"product.youtiao.plain"},
		{"kind": &"area", "id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean"},
		{"kind": &"area", "id": &"area.steamer", "product_id": &"product.steamer.mantou"},
		{"kind": &"device", "id": &"device.packaged_drink_heater", "product_id": &"product.packaged_drink.milk", "temperature_mode": &"heated"},
	]
	for promotion_case in promotion_cases:
		var promoted_progression := progression.duplicate(true)
		var completed_area_ids: Array = Array(Dictionary(progression.get("tutorial", {})).get("completed_area_ids", [])).duplicate()
		if StringName(promotion_case.get("kind", &"")) == &"area":
			completed_area_ids.erase(StringName(promotion_case.get("id", &"")))
		promoted_progression["tutorial"] = {
			"completed_area_ids": completed_area_ids,
			"completed_device_ids": [] if StringName(promotion_case.get("kind", &"")) == &"device" else [&"device.packaged_drink_heater"],
			"active_kind": promotion_case.get("kind", &""),
			"active_id": promotion_case.get("id", &""),
		}
		var promoted_batch := Dictionary(GENERATOR.generate_queue_candidates(promoted_progression, empty_inventory, 95173, 31, 4, 12, 0))
		var promoted_repeat := Dictionary(GENERATOR.generate_queue_candidates(promoted_progression, empty_inventory, 95173, 31, 4, 12, 0))
		var promoted_candidates := Array(promoted_batch.get("candidates", []))
		var promotion_valid := promoted_candidates.size() == 4 and promoted_batch == promoted_repeat
		for exposure_offset in range(1, mini(promoted_candidates.size(), 4)):
			var exposure := Dictionary(promoted_candidates[exposure_offset])
			var metadata := Dictionary(exposure.get("metadata", {}))
			promotion_valid = promotion_valid and _candidate_has_product(exposure, StringName(promotion_case.get("product_id", &"")), StringName(promotion_case.get("temperature_mode", &"")))
			promotion_valid = promotion_valid and int(metadata.get("promotion_index", 0)) == exposure_offset
		_check(promotion_valid, "%s tutorial is followed by three deterministic orders containing its new output" % promotion_case.get("id", &""))

	var promotion_window := Dictionary(GENERATOR.generate_queue_candidates(
		progression, empty_inventory, 13579, 70, 4, 8, 0,
		{"tutorial_kind": &"area", "tutorial_id": &"area.youtiao", "next_index": 0}
	))
	var promotion_window_candidates := Array(promotion_window.get("candidates", []))
	var window_boundary_valid := promotion_window_candidates.size() == 4
	for index in range(mini(promotion_window_candidates.size(), 3)):
		window_boundary_valid = window_boundary_valid and int(Dictionary(Dictionary(promotion_window_candidates[index]).get("metadata", {})).get("promotion_index", 0)) == index + 1
	if promotion_window_candidates.size() >= 4:
		window_boundary_valid = window_boundary_valid and not Dictionary(Dictionary(promotion_window_candidates[3]).get("metadata", {})).has("promotion_index")
	_check(window_boundary_valid, "the fourth order after a promotion context returns to ordinary generation")
	var content_promotion_cases := [
		{"kind": &"product", "id": &"product.packaged_drink.walnut", "recipe_id": &"recipe.packaged_drink.walnut", "stock_id": &"stock.packaged_drink.walnut", "expected_product": &"product.packaged_drink.walnut"},
		{"kind": &"product", "id": &"product.youtiao.oil_cake", "recipe_id": &"recipe.youtiao.oil_cake", "stock_id": &"stock.youtiao.oil_cake_dough", "expected_product": &"product.youtiao.oil_cake"},
		{"kind": &"pancake_stock", "id": &"stock.pancake.meat_floss", "expected_product": &"product.pancake.custom"},
	]
	for promotion_case in content_promotion_cases:
		var content_progression := progression.duplicate(true)
		var unlocked_recipes := Array(content_progression.get("unlocked_recipe_ids", [])).duplicate()
		var unlocked_products := Array(content_progression.get("unlocked_product_ids", [])).duplicate()
		var unlocked_stocks := Array(content_progression.get("unlocked_stock_ids", [])).duplicate()
		if promotion_case.has("recipe_id"):
			unlocked_recipes.append(promotion_case["recipe_id"])
			unlocked_products.append(promotion_case["expected_product"])
			unlocked_stocks.append(promotion_case["stock_id"])
		else:
			unlocked_stocks.append(promotion_case["id"])
		content_progression["unlocked_recipe_ids"] = unlocked_recipes
		content_progression["unlocked_product_ids"] = unlocked_products
		content_progression["unlocked_stock_ids"] = unlocked_stocks
		var content_batch := Dictionary(GENERATOR.generate_queue_candidates(
			content_progression, empty_inventory, 97531, 81, 4, 8, 0,
			{"kind": promotion_case["kind"], "target_id": promotion_case["id"], "source_growth_id": &"growth.test.content", "next_index": 0}
		))
		var content_candidates := Array(content_batch.get("candidates", []))
		var content_valid := content_candidates.size() == 4
		for index in range(mini(content_candidates.size(), 3)):
			var candidate := Dictionary(content_candidates[index])
			var metadata := Dictionary(candidate.get("metadata", {}))
			content_valid = content_valid and _candidate_has_product(candidate, promotion_case["expected_product"])
			content_valid = content_valid and int(metadata.get("promotion_index", 0)) == index + 1
			if StringName(promotion_case["kind"]) == &"pancake_stock":
				content_valid = content_valid and Array(_item(candidate).get("ingredient_ids", [])).has(promotion_case["id"])
		if content_candidates.size() >= 4:
			content_valid = content_valid and not Dictionary(Dictionary(content_candidates[3]).get("metadata", {})).has("promotion_index")
		_check(content_valid, "%s appears in exactly the next three promoted orders before normal weighting resumes" % promotion_case["id"])

	var tutorial_plus_content_progression := progression.duplicate(true)
	tutorial_plus_content_progression["tutorial"] = {
		"completed_area_ids": [&"area.pancake"],
		"completed_device_ids": [],
		"active_kind": &"area",
		"active_id": &"area.packaged_drink",
	}
	var tutorial_recipes := Array(tutorial_plus_content_progression.get("unlocked_recipe_ids", [])).duplicate()
	var tutorial_products := Array(tutorial_plus_content_progression.get("unlocked_product_ids", [])).duplicate()
	var tutorial_stocks := Array(tutorial_plus_content_progression.get("unlocked_stock_ids", [])).duplicate()
	tutorial_recipes.append(&"recipe.packaged_drink.walnut")
	tutorial_products.append(&"product.packaged_drink.walnut")
	tutorial_stocks.append(&"stock.packaged_drink.walnut")
	tutorial_plus_content_progression["unlocked_recipe_ids"] = tutorial_recipes
	tutorial_plus_content_progression["unlocked_product_ids"] = tutorial_products
	tutorial_plus_content_progression["unlocked_stock_ids"] = tutorial_stocks
	var tutorial_plus_content := Array(Dictionary(GENERATOR.generate_queue_candidates(
		tutorial_plus_content_progression, empty_inventory, 24681, 91, 4, 9, 0,
		{"kind": &"product", "target_id": &"product.packaged_drink.walnut", "source_growth_id": &"growth.recipe.packaged_drink.walnut", "next_index": 0}
	)).get("candidates", []))
	var tutorial_priority_valid := tutorial_plus_content.size() == 4 and StringName(Dictionary(Dictionary(tutorial_plus_content[0]).get("metadata", {})).get("tutorial_id", &"")) == &"area.packaged_drink"
	for index in range(1, mini(tutorial_plus_content.size(), 4)):
		tutorial_priority_valid = tutorial_priority_valid and _candidate_has_product(Dictionary(tutorial_plus_content[index]), &"product.packaged_drink.walnut")
	_check(tutorial_priority_valid, "an exclusive area tutorial stays first while the independent new-content promotion occupies the next three orders")
	var found_non_pancake_companion := false
	for sequence in range(1, 301):
		var exposure_batch := Dictionary(GENERATOR.generate_queue_candidates(
			progression, empty_inventory, 86421, sequence, 3, 8, 0,
			{"tutorial_kind": &"area", "tutorial_id": &"area.youtiao", "next_index": 0}
		))
		for exposure_variant in Array(exposure_batch.get("candidates", [])):
			for exposure_item_variant in Array(Dictionary(exposure_variant).get("items", [])):
				var exposure_area := StringName(Dictionary(exposure_item_variant).get("area_id", &""))
				if exposure_area not in [&"area.youtiao", &"area.pancake"]:
					found_non_pancake_companion = true
					break
			if found_non_pancake_companion:
				break
		if found_non_pancake_companion:
			break
	_check(found_non_pancake_companion, "promotion double orders can pair the new output with a taught non-pancake product")
	var teaching_products := {
		&"area.pancake": &"product.pancake.custom",
		&"area.packaged_drink": &"product.packaged_drink.milk",
		&"area.youtiao": &"product.youtiao.plain",
		&"area.fresh_soy_milk": &"product.fresh_soy_milk.yellow_bean",
		&"area.steamer": &"product.steamer.mantou",
	}
	for teaching_area_id in teaching_products:
		var area_progression := progression.duplicate(true)
		area_progression["tutorial"] = {"completed_area_ids": [], "active_kind": &"area", "active_id": teaching_area_id}
		var area_teaching := Dictionary(GENERATOR.generate(area_progression, empty_inventory, 9, 1, 3, 0))
		_check(bool(area_teaching.get("success", false)) and Array(area_teaching.get("items", [])).size() == 1 and _area_id(area_teaching) == teaching_area_id and StringName(_item(area_teaching).get("product_id", &"")) == teaching_products[teaching_area_id], "%s zero-stock teaching remains a single authored product" % teaching_area_id)
		var same_day := Dictionary(GENERATOR.generate(area_progression, empty_inventory, 9, 2, 3, 3))
		_check(StringName(Dictionary(same_day.get("metadata", {})).get("teaching_area_id", &"")).is_empty(), "%s teaching cannot be generated twice on the same day" % teaching_area_id)

	var service: RefCounted = ORDER_SERVICE.new()
	var opened: Dictionary = service.call("ensure_queue", 1, teaching)
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	var refusal_preview: Dictionary = service.call("preview_refusal", order_id)
	_check(int(refusal_preview.get("reputation_delta", 0)) == -1, "unstarted refusal previews the smaller reputation loss")
	service.call("mark_production_started", order_id, &"device.packaged_drink_heater.slot.0")
	refusal_preview = service.call("preview_refusal", order_id)
	_check(int(refusal_preview.get("reputation_delta", 0)) == -2, "started production upgrades refusal to the wrong-order loss")
	var refused: Dictionary = service.call("refuse_order", order_id)
	var refused_retry: Dictionary = service.call("refuse_order", order_id)
	_check(StringName(refused.get("terminal_state", &"")) == &"refused" and bool(refused_retry.get("already_settled", false)), "refusal reaches one idempotent terminal result")

	service = ORDER_SERVICE.new()
	opened = service.call("ensure_queue", 1, teaching)
	service.call("advance_patience", 10.0)
	var restored: RefCounted = ORDER_SERVICE.new(service.call("snapshot"))
	var restored_order: Dictionary = restored.call("current_order")
	_check(is_equal_approx(float(restored_order.get("remaining_patience_seconds", 0.0)), 24.0), "tutorial patience remains unchanged across snapshot restore")
	var expired: Dictionary = restored.call("advance_patience", 30.0)
	_check(not expired.has("terminal_state") and not bool(expired.get("changed", true)), "tutorial patience never reaches an expired terminal state")
	service = ORDER_SERVICE.new()
	var queue_candidates: Array = Array(GENERATOR.generate_queue_candidates(progression, empty_inventory, 24680, 21, 4, 8, 0).get("candidates", []))
	var queued: Dictionary = service.call("ensure_queue", 4, queue_candidates)
	_check(bool(queued.get("success", false)) and Array(queued.get("queue", [])).size() == 4 and Array(service.call("active_orders")).size() == 3 and Array(service.call("waiting_orders")).size() == 1, "four-order queue exposes three active customers and one hidden candidate")
	var active_before: Array = Array(service.call("active_orders"))
	var waiting_before: Dictionary = Dictionary(Array(service.call("waiting_orders"))[0])
	service.call("advance_time", 3.0)
	var active_after: Array = Array(service.call("active_orders"))
	var waiting_after: Dictionary = Dictionary(Array(service.call("waiting_orders"))[0])
	var all_active_advanced := active_before.size() == active_after.size()
	for index in range(active_before.size()):
		all_active_advanced = all_active_advanced and is_equal_approx(float(Dictionary(active_before[index]).get("remaining_patience_seconds", 0.0)) - 3.0, float(Dictionary(active_after[index]).get("remaining_patience_seconds", 0.0)))
	_check(all_active_advanced, "all three active playable orders consume patience together")
	_check(is_equal_approx(float(waiting_before.get("remaining_patience_seconds", 0.0)), float(waiting_after.get("remaining_patience_seconds", 0.0))), "hidden candidate does not consume patience")

	var progression_service: RefCounted = PROGRESSION_SERVICE.new()
	var first_failure: Dictionary = progression_service.call("record_tutorial_failure", &"area", &"area.pancake")
	var second_failure: Dictionary = progression_service.call("record_tutorial_failure", &"area", &"area.pancake")
	_check(int(first_failure.get("failure_count", 0)) == 1 and not bool(first_failure.get("tutorial_ended", false)), "the first teaching failure keeps the tutorial queued")
	_check(bool(second_failure.get("tutorial_ended", false)) and Array(Dictionary(progression_service.call("tutorial_snapshot")).get("completed_area_ids", [])).has("area.pancake"), "two consecutive teaching failures end training without a mastery award")

	_finish()


func _fully_playable_progression() -> Dictionary:
	return {
		"unlocked_area_ids": [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"],
		"unlocked_recipe_ids": [
			&"recipe.pancake.base", &"recipe.packaged_drink.milk", &"recipe.youtiao.plain",
			&"recipe.fresh_soy_milk.yellow_bean", &"recipe.steamer.mantou",
		],
		"unlocked_product_ids": [
			&"product.pancake.custom", &"product.packaged_drink.milk", &"product.youtiao.plain",
			&"product.fresh_soy_milk.yellow_bean", &"product.steamer.mantou",
		],
		"unlocked_stock_ids": [
			&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour",
			&"stock.packaged_drink.milk", &"stock.youtiao.plain_dough", &"stock.fresh_soy_milk.yellow_bean", &"stock.steamer.mantou",
		],
		"device_tiers": {
			&"device.pancake_griddle": 1, &"device.packaged_drink_heater": 0, &"device.youtiao_fryer": 0,
			&"device.fresh_soy_milk_machine": 1, &"device.steamer": 1,
		},
		"area_mastery_details": {
			&"area.packaged_drink": {"correct_temperature": 8},
			&"area.youtiao": {"qualified": 8},
		},
		"tutorial": {
			"completed_area_ids": [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"],
			"completed_device_ids": [&"device.packaged_drink_heater"],
			"active_kind": &"",
			"active_id": &"",
		},
	}


func _inventory(value: int) -> Dictionary:
	var result := {}
	for stock_id in [
		"stock.pancake.batter", "stock.pancake.egg", "stock.pancake.baocui", "stock.pancake.scallion", "stock.pancake.sauce.sweet_flour",
		"stock.packaged_drink.milk", "stock.youtiao.plain_dough", "stock.fresh_soy_milk.yellow_bean", "stock.steamer.mantou",
	]:
		result[stock_id] = value
	return result


func _item(result: Dictionary) -> Dictionary:
	var items: Array = Array(result.get("items", []))
	return {} if items.is_empty() else Dictionary(items[0])


func _area_id(result: Dictionary) -> StringName:
	return StringName(_item(result).get("area_id", &""))


func _candidate_has_product(candidate: Dictionary, product_id: StringName, temperature_mode: StringName = &"") -> bool:
	for item_variant in Array(candidate.get("items", [])):
		var item := Dictionary(item_variant)
		if StringName(item.get("product_id", &"")) != product_id:
			continue
		if temperature_mode.is_empty() or StringName(item.get("temperature_mode", &"")) == temperature_mode:
			return true
	return false


func _is_supported_area(area_id: StringName) -> bool:
	return GENERATOR.PLAYABLE_AREA_IDS.has(area_id)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_PLAYABLE_ORDER_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
