class_name FiveAreaPlayableOrderGenerator
extends RefCounted

## Pure deterministic candidate generation for all five formal areas.
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PANCAKE_GENERATOR := preload("res://scripts/services/five_area_pancake_order_generator.gd")

const PLAYABLE_AREA_IDS: Array[StringName] = [
	&"area.pancake",
	&"area.packaged_drink",
	&"area.youtiao",
	&"area.fresh_soy_milk",
	&"area.steamer",
]
const BASE_PATIENCE_SECONDS := {
	&"area.pancake": 72.0,
	&"area.packaged_drink": 24.0,
	&"area.youtiao": 36.0,
	&"area.fresh_soy_milk": 32.0,
	&"area.steamer": 44.0,
}
const TUTORIAL_PRODUCT_IDS := {
	&"area.packaged_drink": &"product.packaged_drink.milk",
	&"area.youtiao": &"product.youtiao.plain",
	&"area.fresh_soy_milk": &"product.fresh_soy_milk.yellow_bean",
	&"area.steamer": &"product.steamer.mantou",
}


static func generate(
	progression: Dictionary,
	inventory: Dictionary,
	seed: int,
	sequence: int,
	current_day: int,
	tutorial_generated_day: int
) -> Dictionary:
	var tutorial := Dictionary(progression.get("tutorial", {}))
	var tutorial_kind := StringName(tutorial.get("active_kind", &""))
	var tutorial_id := StringName(tutorial.get("active_id", &""))
	var tutorial_area_id := tutorial_id if tutorial_kind == &"area" else &""
	if PLAYABLE_AREA_IDS.has(tutorial_area_id) and tutorial_generated_day != current_day:
		var teaching := _teaching_candidate(tutorial_area_id, progression, inventory)
		if not bool(teaching.get("success", false)):
			return teaching
		teaching["tutorial_generated_day"] = current_day
		return teaching
	if tutorial_kind == &"device" and tutorial_id == &"device.packaged_drink_heater" and tutorial_generated_day != current_day:
		var heater_teaching := _heater_teaching_candidate(progression)
		if not bool(heater_teaching.get("success", false)):
			return heater_teaching
		heater_teaching["tutorial_generated_day"] = current_day
		return heater_teaching

	var eligible_areas: Array[StringName] = []
	var completed_tutorials := _id_set(tutorial.get("completed_area_ids", []))
	var unlocked_areas := _id_set(progression.get("unlocked_area_ids", []))
	for area_id in PLAYABLE_AREA_IDS:
		if not unlocked_areas.has(area_id) or not completed_tutorials.has(area_id):
			continue
		if not _eligible_product_ids(area_id, progression).is_empty():
			eligible_areas.append(area_id)
	if eligible_areas.is_empty():
		return {"success": false, "reason": &"no_eligible_playable_order"}

	var item_count := _complexity_item_count(progression, eligible_areas.size(), seed, sequence)
	var remaining_areas := eligible_areas.duplicate()
	var selected_candidates: Array[Dictionary] = []
	for item_index in range(item_count):
		var area_id := _weighted_area(remaining_areas, progression, seed + item_index * 7919, sequence)
		remaining_areas.erase(area_id)
		var candidate: Dictionary
		if area_id == &"area.pancake":
			candidate = _pancake_candidate(progression, {}, seed + item_index * 104729, sequence, false)
		else:
			var product_ids := _eligible_product_ids(area_id, progression)
			var product_id := _weighted_product(product_ids, seed + item_index * 104729, sequence)
			candidate = _product_candidate(area_id, product_id, progression, seed + item_index * 104729, sequence, false)
		if not bool(candidate.get("success", false)):
			return candidate
		selected_candidates.append(candidate)
	return _combine_candidates(selected_candidates)


static func generate_queue_candidates(
	progression: Dictionary,
	inventory: Dictionary,
	seed: int,
	first_sequence: int,
	count: int,
	current_day: int,
	tutorial_generated_day: int,
	promotion_context: Dictionary = {}
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var generated_tutorial_day := tutorial_generated_day
	var promotion_kind := StringName(promotion_context.get("kind", promotion_context.get("tutorial_kind", &"")))
	var promotion_id := StringName(promotion_context.get("target_id", promotion_context.get("tutorial_id", &"")))
	var promotion_source_growth_id := StringName(promotion_context.get("source_growth_id", &""))
	var promotion_index := clampi(int(promotion_context.get("next_index", 0)), 0, 3)
	var explicit_promotion := not promotion_id.is_empty()
	for offset in range(clampi(count, 0, 6)):
		var sequence := first_sequence + offset
		var generated: Dictionary
		# A newly active tutorial always owns the first storefront position. An
		# already queued content promotion resumes immediately behind it.
		if offset == 0 and tutorial_generated_day != current_day and _has_due_tutorial(progression):
			generated = generate(progression, inventory, seed, sequence, current_day, generated_tutorial_day)
		elif not promotion_id.is_empty() and promotion_index < 3:
			generated = _post_tutorial_exposure_candidate(
				progression,
				seed,
				sequence,
				promotion_kind,
				promotion_id,
				promotion_index + 1,
				promotion_source_growth_id,
			)
			promotion_index += 1
		else:
			generated = generate(progression, inventory, seed, sequence, current_day, generated_tutorial_day)
		if not bool(generated.get("success", false)):
			if not candidates.is_empty():
				return {
					"success": true,
					"candidates": candidates,
					"tutorial_generated_day": generated_tutorial_day,
					"deferred_reason": generated.get("reason", &"no_eligible_playable_order"),
				}
			return generated
		if int(generated.get("tutorial_generated_day", 0)) > 0:
			generated_tutorial_day = int(generated.get("tutorial_generated_day", 0))
		var metadata := Dictionary(generated.get("metadata", {}))
		var generated_tutorial_id := StringName(metadata.get("tutorial_id", &""))
		if not generated_tutorial_id.is_empty() and not explicit_promotion:
			promotion_kind = StringName(metadata.get("tutorial_kind", &"area"))
			promotion_id = generated_tutorial_id
			promotion_index = 0
		candidates.append(generated)
	return {"success": true, "candidates": candidates, "tutorial_generated_day": generated_tutorial_day}


static func _post_tutorial_exposure_candidate(
	progression: Dictionary,
	seed: int,
	sequence: int,
	tutorial_kind: StringName,
	tutorial_id: StringName,
	exposure_index: int,
	source_growth_id: StringName = &""
) -> Dictionary:
	var primary := _promotion_primary_candidate(progression, seed, sequence, tutorial_kind, tutorial_id)
	if not bool(primary.get("success", false)):
		return primary
	var candidates: Array[Dictionary] = [primary]
	var promotion_area_id := _promotion_area_id(tutorial_kind, tutorial_id)
	# Keep the ordinary 72/20/8 complexity roll, but clamp the promotion window
	# to one old companion so the newly unlocked output remains the focus.
	if _roll(seed, sequence, 113, 100) >= 72:
		var old_areas := _eligible_completed_areas(progression, promotion_area_id)
		if not old_areas.is_empty():
			var old_area_id := _weighted_area(old_areas, progression, seed + 7919, sequence)
			var companion: Dictionary
			if old_area_id == &"area.pancake":
				companion = _pancake_candidate(progression, {}, seed + 104729, sequence, false)
			else:
				var product_ids := _eligible_product_ids(old_area_id, progression)
				var product_id := _weighted_product(product_ids, seed + 104729, sequence)
				companion = _product_candidate(old_area_id, product_id, progression, seed + 104729, sequence, false)
			if bool(companion.get("success", false)):
				candidates.append(companion)
	var result := _combine_candidates(candidates)
	var metadata := Dictionary(result.get("metadata", {})).duplicate(true)
	metadata["promotion_tutorial_kind"] = tutorial_kind
	metadata["promotion_tutorial_id"] = tutorial_id
	metadata["promotion_kind"] = tutorial_kind
	metadata["promotion_target_id"] = tutorial_id
	metadata["promotion_source_growth_id"] = source_growth_id
	metadata["promotion_index"] = clampi(exposure_index, 1, 3)
	result["metadata"] = metadata
	return result


static func _promotion_primary_candidate(
	progression: Dictionary,
	seed: int,
	sequence: int,
	tutorial_kind: StringName,
	tutorial_id: StringName
) -> Dictionary:
	if tutorial_kind == &"product":
		var definition := CATALOG.product_definition(tutorial_id)
		var area_id := StringName(definition.get("area_id", &""))
		if definition.is_empty() or area_id.is_empty():
			return {"success": false, "reason": &"promotion_content_unavailable", "tutorial_id": tutorial_id}
		return _product_candidate(area_id, tutorial_id, progression, seed, sequence, false)
	if tutorial_kind == &"pancake_stock":
		return _pancake_candidate_for_stock(progression, tutorial_id, seed, sequence)
	if tutorial_kind == &"device" and tutorial_id == &"device.packaged_drink_heater":
		var heated := _product_candidate(
			&"area.packaged_drink",
			&"product.packaged_drink.milk",
			progression,
			seed,
			sequence,
			false,
		)
		var heated_items := Array(heated.get("items", [])).duplicate(true)
		if not heated_items.is_empty():
			var item := Dictionary(heated_items[0])
			item["temperature_mode"] = &"heated"
			heated_items[0] = item
			heated["items"] = heated_items
		return heated
	if tutorial_kind != &"area" or not PLAYABLE_AREA_IDS.has(tutorial_id):
		return {"success": false, "reason": &"promotion_content_unavailable", "tutorial_id": tutorial_id}
	if tutorial_id == &"area.pancake":
		return _pancake_candidate(progression, {}, seed, sequence, false)
	var product_id: StringName = TUTORIAL_PRODUCT_IDS.get(tutorial_id, &"")
	if product_id.is_empty():
		return {"success": false, "reason": &"promotion_content_unavailable", "tutorial_id": tutorial_id}
	return _product_candidate(tutorial_id, product_id, progression, seed, sequence, false)


static func _promotion_area_id(tutorial_kind: StringName, tutorial_id: StringName) -> StringName:
	if tutorial_kind == &"product":
		return StringName(CATALOG.product_definition(tutorial_id).get("area_id", &""))
	if tutorial_kind == &"pancake_stock":
		return &"area.pancake"
	if tutorial_kind == &"device" and tutorial_id == &"device.packaged_drink_heater":
		return &"area.packaged_drink"
	return tutorial_id if tutorial_kind == &"area" else &""


static func _has_due_tutorial(progression: Dictionary) -> bool:
	var tutorial := Dictionary(progression.get("tutorial", {}))
	var kind := StringName(tutorial.get("active_kind", &""))
	var tutorial_id := StringName(tutorial.get("active_id", &""))
	return (kind == &"area" and PLAYABLE_AREA_IDS.has(tutorial_id)) or (kind == &"device" and tutorial_id == &"device.packaged_drink_heater")


static func _eligible_completed_areas(progression: Dictionary, excluded_area_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var completed := _id_set(Dictionary(progression.get("tutorial", {})).get("completed_area_ids", []))
	var unlocked := _id_set(progression.get("unlocked_area_ids", []))
	for area_id in PLAYABLE_AREA_IDS:
		if area_id == excluded_area_id or not completed.has(area_id) or not unlocked.has(area_id):
			continue
		if not _eligible_product_ids(area_id, progression).is_empty():
			result.append(area_id)
	return result


static func _complexity_item_count(progression: Dictionary, eligible_count: int, seed: int, sequence: int) -> int:
	if eligible_count < 2:
		return 1
	var unlocked := _id_set(progression.get("unlocked_area_ids", []))
	var completed := _id_set(Dictionary(progression.get("tutorial", {})).get("completed_area_ids", []))
	for area_id in PLAYABLE_AREA_IDS:
		if not unlocked.has(area_id) or not completed.has(area_id):
			return 1
	var roll := _roll(seed, sequence, 113, 100)
	if roll < 72:
		return 1
	if roll < 92:
		return mini(2, eligible_count)
	return mini(3, eligible_count)


static func _combine_candidates(candidates: Array[Dictionary]) -> Dictionary:
	if candidates.size() == 1:
		return candidates[0]
	var items: Array = []
	var required_stock_ids: Array = []
	var patience_values: Array[float] = []
	var base_coins := 0
	for candidate in candidates:
		items.append_array(Array(candidate.get("items", [])))
		required_stock_ids.append_array(Array(candidate.get("required_stock_ids", [])))
		var metadata := Dictionary(candidate.get("metadata", {}))
		patience_values.append(float(metadata.get("patience_seconds", 0.0)))
		base_coins += maxi(int(metadata.get("base_coins", 1)), 1)
	patience_values.sort()
	var max_patience: float = float(patience_values.pop_back())
	var patience: float = max_patience + 10.0 * float(items.size() - 1)
	for value in patience_values:
		patience += 0.6 * value
	var multiplier := 1.15 if items.size() == 2 else 1.30
	return {
		"success": true,
		"items": items,
		"metadata": {
			"teaching_area_id": &"",
			"tutorial_kind": &"",
			"tutorial_id": &"",
			"patience_seconds": snappedf(patience, 0.1),
			"base_coins": maxi(roundi(float(base_coins) * multiplier), 1),
			"reward_multiplier": multiplier,
		},
		"required_stock_ids": required_stock_ids,
	}


static func _teaching_candidate(area_id: StringName, progression: Dictionary, _inventory: Dictionary) -> Dictionary:
	var candidate: Dictionary
	if area_id == &"area.pancake":
		candidate = _pancake_candidate(progression, Dictionary(progression.get("tutorial", {})), 0, 0, true)
	else:
		var product_id: StringName = TUTORIAL_PRODUCT_IDS.get(area_id, &"")
		if product_id.is_empty() or not _eligible_product_ids(area_id, progression).has(product_id):
			return {"success": false, "reason": &"tutorial_content_unavailable", "teaching_area_id": area_id}
		candidate = _product_candidate(area_id, product_id, progression, 0, 0, true)
	if not bool(candidate.get("success", false)):
		return candidate
	# Every area tutorial includes its own zero-stock recovery step. Never defer
	# the first teaching customer merely because the player must restock first.
	return candidate


static func _heater_teaching_candidate(progression: Dictionary) -> Dictionary:
	var product_id := &"product.packaged_drink.milk"
	if not _eligible_product_ids(&"area.packaged_drink", progression).has(product_id):
		return {"success": false, "reason": &"tutorial_content_unavailable", "tutorial_id": &"device.packaged_drink_heater"}
	var candidate := _product_candidate(&"area.packaged_drink", product_id, progression, 0, 0, true)
	if not bool(candidate.get("success", false)):
		return candidate
	var items: Array = Array(candidate.get("items", [])).duplicate(true)
	if not items.is_empty():
		var item := Dictionary(items[0])
		item["temperature_mode"] = &"heated"
		items[0] = item
	candidate["items"] = items
	var metadata := Dictionary(candidate.get("metadata", {})).duplicate(true)
	metadata["teaching_area_id"] = &"area.packaged_drink"
	metadata["tutorial_kind"] = &"device"
	metadata["tutorial_id"] = &"device.packaged_drink_heater"
	metadata["tutorial_no_countdown"] = true
	candidate["metadata"] = metadata
	return candidate


static func _pancake_candidate(progression: Dictionary, tutorial: Dictionary, seed: int, sequence: int, teaching: bool, required_template_id: StringName = &"") -> Dictionary:
	var generated: Dictionary
	if teaching:
		generated = PANCAKE_GENERATOR.generate(progression, tutorial, 0)
	elif not required_template_id.is_empty():
		generated = PANCAKE_GENERATOR.generate_for_template(progression, required_template_id)
	else:
		var eligible := _eligible_pancake_templates(progression)
		if eligible.is_empty():
			return {"success": false, "reason": &"no_eligible_pancake_order"}
		var index := _roll(seed, sequence, 31, eligible.size())
		generated = PANCAKE_GENERATOR.generate(progression, {}, index)
	if not bool(generated.get("success", false)):
		return generated
	var legacy := Dictionary(generated.get("order", {})).duplicate(true)
	var template_id := StringName(legacy.get("id", &""))
	var template := CATALOG.pancake_order_template(template_id)
	var patience := float(BASE_PATIENCE_SECONDS[&"area.pancake"])
	legacy["time_limit"] = patience
	legacy["tutorial_no_countdown"] = teaching
	if teaching:
		legacy["tutorial_guide"] = "新手指引：按顺序完成这张基础煎饼；教学单不限时。"
	return {
		"success": true,
		"items": [{
			"area_id": &"area.pancake",
			"product_id": &"product.pancake.custom",
			"quantity": 1,
			"temperature_mode": &"room_temperature",
			"pancake_template_id": template_id,
			"ingredient_ids": Array(template.get("ingredient_stock_ids", [])),
			"sauce_ids": Array(template.get("sauce_stock_ids", [])),
			"heat_preference": StringName(template.get("heat_preference", &"golden")),
		}],
		"metadata": {
			"legacy_order": legacy,
			"teaching_area_id": &"area.pancake" if teaching else &"",
			"tutorial_kind": &"area" if teaching else &"",
			"tutorial_id": &"area.pancake" if teaching else &"",
			"tutorial_no_countdown": teaching,
			"patience_seconds": patience,
			"base_coins": maxi(int(legacy.get("payment_coins", 1)), 1),
		},
		"required_stock_ids": Array(template.get("ingredient_stock_ids", [])) + Array(template.get("sauce_stock_ids", [])) + [&"stock.pancake.batter"],
	}


static func _pancake_candidate_for_stock(progression: Dictionary, stock_id: StringName, seed: int, sequence: int) -> Dictionary:
	var eligible := _eligible_pancake_templates(progression)
	var matching: Array[StringName] = []
	for template_id in eligible:
		var template := CATALOG.pancake_order_template(template_id)
		var required := Array(template.get("ingredient_stock_ids", [])) + Array(template.get("sauce_stock_ids", []))
		if required.has(stock_id) or required.has(str(stock_id)):
			matching.append(template_id)
	if matching.is_empty():
		return {"success": false, "reason": &"promotion_content_unavailable", "stock_id": stock_id}
	var selected := matching[_roll(seed, sequence, 31, matching.size())]
	return _pancake_candidate(progression, {}, seed, sequence, false, selected)


static func _product_candidate(area_id: StringName, product_id: StringName, progression: Dictionary, seed: int, sequence: int, teaching: bool) -> Dictionary:
	var product := CATALOG.product_definition(product_id)
	var recipe := CATALOG.recipe_definition(StringName(product.get("recipe_id", &"")))
	if product.is_empty() or recipe.is_empty():
		return {"success": false, "reason": &"invalid_product_definition"}
	var temperature_mode := &"room_temperature"
	if area_id == &"area.packaged_drink" and not teaching and bool(product.get("can_heat", false)):
		var tutorial := Dictionary(progression.get("tutorial", {}))
		var completed_devices := _id_set(tutorial.get("completed_device_ids", []))
		var device_tiers := Dictionary(progression.get("device_tiers", {}))
		var heater_owned := device_tiers.has(&"device.packaged_drink_heater") or device_tiers.has("device.packaged_drink_heater")
		if heater_owned and completed_devices.has(&"device.packaged_drink_heater") and _roll(seed, sequence, 79, 100) < 35:
			temperature_mode = &"heated"
	var patience := float(BASE_PATIENCE_SECONDS.get(area_id, 24.0))
	return {
		"success": true,
		"items": [{
			"area_id": area_id,
			"product_id": product_id,
			"quantity": 1,
			"temperature_mode": temperature_mode,
			"pancake_template_id": &"",
			"ingredient_ids": PackedStringArray(),
			"sauce_ids": PackedStringArray(),
		}],
		"metadata": {
			"teaching_area_id": area_id if teaching else &"",
			"tutorial_kind": &"area" if teaching else &"",
			"tutorial_id": area_id if teaching else &"",
			"tutorial_no_countdown": teaching,
			"patience_seconds": patience,
			"base_coins": maxi(int(product.get("base_sell_price", 1)), 1),
		},
		"required_stock_ids": Array(recipe.get("stock_ids", [])),
	}


static func _eligible_product_ids(area_id: StringName, progression: Dictionary) -> Array[StringName]:
	if area_id == &"area.pancake":
		var pancake_product_ids: Array[StringName] = []
		if not _eligible_pancake_templates(progression).is_empty():
			pancake_product_ids.append(&"product.pancake.custom")
		return pancake_product_ids
	var unlocked_products := _id_set(progression.get("unlocked_product_ids", []))
	var unlocked_recipes := _id_set(progression.get("unlocked_recipe_ids", []))
	var unlocked_stocks := _id_set(progression.get("unlocked_stock_ids", []))
	var device_tiers := Dictionary(progression.get("device_tiers", {}))
	var area_definition := CATALOG.area_definition(area_id)
	var device_id := StringName(area_definition.get("device_id", &""))
	if area_id != &"area.packaged_drink" and (device_id.is_empty() or not (device_tiers.has(device_id) or device_tiers.has(str(device_id)))):
		return []
	var ids: Array[StringName] = []
	for product_key in CATALOG.PRODUCT_DEFINITIONS.keys():
		var product_id := StringName(product_key)
		var product := CATALOG.product_definition(product_id)
		if StringName(product.get("area_id", &"")) != area_id or not unlocked_products.has(product_id):
			continue
		var recipe_id := StringName(product.get("recipe_id", &""))
		var recipe := CATALOG.recipe_definition(recipe_id)
		if recipe.is_empty() or not unlocked_recipes.has(recipe_id):
			continue
		var all_stock_unlocked := true
		for stock_id_variant in Array(recipe.get("stock_ids", [])):
			if not unlocked_stocks.has(StringName(stock_id_variant)):
				all_stock_unlocked = false
				break
		if all_stock_unlocked:
			ids.append(product_id)
	ids.sort()
	return ids


static func _eligible_pancake_templates(progression: Dictionary) -> Array[StringName]:
	var owned := _id_set(progression.get("unlocked_stock_ids", []))
	var owned_recipes := _id_set(progression.get("unlocked_recipe_ids", []))
	var ids: Array[StringName] = []
	for template_key in CATALOG.PANCAKE_ORDER_TEMPLATES.keys():
		var template_id := StringName(template_key)
		var template := CATALOG.pancake_order_template(template_id)
		var valid := true
		for recipe_id_variant in Array(template.get("requires_recipe_ids", [])):
			if not owned_recipes.has(StringName(recipe_id_variant)):
				valid = false
				break
		if not valid:
			continue
		for stock_id_variant in Array(template.get("ingredient_stock_ids", [])) + Array(template.get("sauce_stock_ids", [])):
			var stock_id := StringName(stock_id_variant)
			if StringName(CATALOG.stock_definition(stock_id).get("category", &"")) == &"prepared_add_on":
				continue
			if not owned.has(stock_id):
				valid = false
				break
		if valid:
			ids.append(template_id)
	ids.sort()
	return ids


static func _weighted_area(area_ids: Array[StringName], progression: Dictionary, seed: int, sequence: int) -> StringName:
	var weighted: Array[Dictionary] = []
	var total := 0
	var mastery_by_area := Dictionary(progression.get("area_mastery_details", {}))
	for area_id in area_ids:
		var weight := 100
		if area_id != &"area.pancake":
			var details := Dictionary(mastery_by_area.get(area_id, mastery_by_area.get(str(area_id), {})))
			var qualified := int(details.get("correct_temperature", 0)) if area_id == &"area.packaged_drink" else int(details.get("qualified", 0))
			weight = 15 if qualified < 3 else (25 if qualified < 8 else 35)
		total += weight
		weighted.append({"area_id": area_id, "limit": total})
	var roll := _roll(seed, sequence, 17, total)
	for entry in weighted:
		if roll < int(entry.get("limit", 0)):
			return StringName(entry.get("area_id", &"area.pancake"))
	return area_ids.front()


static func _weighted_product(product_ids: Array[StringName], seed: int, sequence: int) -> StringName:
	var total := 0
	var limits: Array[Dictionary] = []
	for product_id in product_ids:
		total += maxi(int(CATALOG.product_definition(product_id).get("order_weight", 100)), 1)
		limits.append({"product_id": product_id, "limit": total})
	var roll := _roll(seed, sequence, 43, total)
	for entry in limits:
		if roll < int(entry.get("limit", 0)):
			return StringName(entry.get("product_id", &""))
	return product_ids.front()


static func _roll(seed: int, sequence: int, salt: int, upper_bound: int) -> int:
	if upper_bound <= 1:
		return 0
	var value := int(seed) & 0x7fffffff
	value = int((value * 1103515245 + 12345 + sequence * 2654435761 + salt * 1013904223) & 0x7fffffff)
	return posmod(value, upper_bound)


static func _id_set(values: Variant) -> Dictionary:
	var result := {}
	for value in Array(values):
		result[StringName(value)] = true
	return result
