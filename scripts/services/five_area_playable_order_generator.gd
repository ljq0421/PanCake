class_name FiveAreaPlayableOrderGenerator
extends RefCounted

## Pure deterministic candidate generation for the areas that currently have
## complete production interactions. Soy-milk and steamer data intentionally do
## not enter this list until their production routes exist.
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PANCAKE_GENERATOR := preload("res://scripts/services/five_area_pancake_order_generator.gd")

const PLAYABLE_AREA_IDS: Array[StringName] = [
	&"area.pancake",
	&"area.packaged_drink",
	&"area.youtiao",
]
const BASE_PATIENCE_SECONDS := {
	&"area.pancake": 72.0,
	&"area.packaged_drink": 24.0,
	&"area.youtiao": 36.0,
}
const TUTORIAL_PRODUCT_IDS := {
	&"area.packaged_drink": &"product.packaged_drink.milk",
	&"area.youtiao": &"product.youtiao.plain",
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
	var tutorial_area_id := StringName(tutorial.get("active_id", &"")) if StringName(tutorial.get("active_kind", &"")) == &"area" else &""
	if PLAYABLE_AREA_IDS.has(tutorial_area_id) and tutorial_generated_day != current_day:
		var teaching := _teaching_candidate(tutorial_area_id, progression, inventory)
		if not bool(teaching.get("success", false)):
			return teaching
		teaching["tutorial_generated_day"] = current_day
		return teaching

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

	var area_id := _weighted_area(eligible_areas, progression, seed, sequence)
	if area_id == &"area.pancake":
		return _pancake_candidate(progression, {}, seed, sequence, false)
	var product_ids := _eligible_product_ids(area_id, progression)
	var product_id := _weighted_product(product_ids, seed, sequence)
	return _product_candidate(area_id, product_id, progression, seed, sequence, false)


static func _teaching_candidate(area_id: StringName, progression: Dictionary, inventory: Dictionary) -> Dictionary:
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
	var missing := PackedStringArray()
	for stock_id_variant in Array(candidate.get("required_stock_ids", [])):
		var stock_id := StringName(stock_id_variant)
		if int(inventory.get(str(stock_id), inventory.get(stock_id, 0))) < 1:
			missing.append(str(stock_id))
	if not missing.is_empty():
		return {
			"success": false,
			"reason": &"tutorial_restock_required",
			"teaching_area_id": area_id,
			"missing_stock_ids": missing,
		}
	return candidate


static func _pancake_candidate(progression: Dictionary, tutorial: Dictionary, seed: int, sequence: int, teaching: bool) -> Dictionary:
	var generated: Dictionary
	if teaching:
		generated = PANCAKE_GENERATOR.generate(progression, tutorial, 0)
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
	var patience := float(BASE_PATIENCE_SECONDS[&"area.pancake"]) * (1.5 if teaching else 1.0)
	legacy["time_limit"] = patience
	legacy.erase("tutorial_no_countdown")
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
			"patience_seconds": patience,
			"base_coins": maxi(int(legacy.get("payment_coins", 1)), 1),
		},
		"required_stock_ids": Array(template.get("ingredient_stock_ids", [])) + Array(template.get("sauce_stock_ids", [])) + [&"stock.pancake.batter"],
	}


static func _product_candidate(area_id: StringName, product_id: StringName, progression: Dictionary, seed: int, sequence: int, teaching: bool) -> Dictionary:
	var product := CATALOG.product_definition(product_id)
	var recipe := CATALOG.recipe_definition(StringName(product.get("recipe_id", &"")))
	if product.is_empty() or recipe.is_empty():
		return {"success": false, "reason": &"invalid_product_definition"}
	var temperature_mode := &"room_temperature"
	if area_id == &"area.packaged_drink" and not teaching and bool(product.get("can_heat", false)):
		var tutorial := Dictionary(progression.get("tutorial", {}))
		if _id_set(tutorial.get("completed_area_ids", [])).has(area_id) and _roll(seed, sequence, 79, 100) < 35:
			temperature_mode = &"heated"
	var patience := float(BASE_PATIENCE_SECONDS.get(area_id, 24.0)) * (1.5 if teaching else 1.0)
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
			"patience_seconds": patience,
			"base_coins": maxi(int(product.get("base_sell_price", 1)), 1),
		},
		"required_stock_ids": Array(recipe.get("stock_ids", [])),
	}


static func _eligible_product_ids(area_id: StringName, progression: Dictionary) -> Array[StringName]:
	if area_id == &"area.pancake":
		return [&"product.pancake.custom"] if not _eligible_pancake_templates(progression).is_empty() else []
	var unlocked_products := _id_set(progression.get("unlocked_product_ids", []))
	var unlocked_recipes := _id_set(progression.get("unlocked_recipe_ids", []))
	var unlocked_stocks := _id_set(progression.get("unlocked_stock_ids", []))
	var device_tiers := Dictionary(progression.get("device_tiers", {}))
	var area_definition := CATALOG.area_definition(area_id)
	var device_id := StringName(area_definition.get("device_id", &""))
	if device_id.is_empty() or not (device_tiers.has(device_id) or device_tiers.has(str(device_id))):
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
	var ids: Array[StringName] = []
	for template_key in CATALOG.PANCAKE_ORDER_TEMPLATES.keys():
		var template_id := StringName(template_key)
		var template := CATALOG.pancake_order_template(template_id)
		var valid := true
		for stock_id_variant in Array(template.get("ingredient_stock_ids", [])) + Array(template.get("sauce_stock_ids", [])):
			if not owned.has(StringName(stock_id_variant)):
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
