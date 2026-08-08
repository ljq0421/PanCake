class_name FiveAreaProgressionService
extends RefCounted

## Owns five-area progression state only.  It does not inspect scene nodes,
## manipulate stock quantities, or write save files; GameSessionStore becomes
## the persistence coordinator in phase 4.

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const INSTALL_SLOT := &"install"
const CONTENT_SLOT := &"content"

var coins := 0
var reputation := 0
var current_day := 1
var day_open := true
var unlocked_area_ids: Dictionary = {&"area.pancake": true}
var device_tiers: Dictionary = {&"device.pancake_griddle": 0}
var unlocked_recipe_ids: Dictionary = {&"recipe.pancake.base": true}
var unlocked_product_ids: Dictionary = {&"product.pancake.custom": true}
var unlocked_stock_ids: Dictionary = {
	&"stock.pancake.batter": true,
	&"stock.pancake.egg": true,
	&"stock.pancake.baocui": true,
	&"stock.pancake.scallion": true,
	&"stock.pancake.sauce.sweet_flour": true,
}
var unlocked_automation_ids: Dictionary = {}
var owned_assist_ids: Dictionary = {}
var owned_growth_ids: Dictionary = {}
var stock_capacity := 6
var area_mastery: Dictionary = {}
var area_mastery_details: Dictionary = {}
var applied_mastery_settlement_ids: Dictionary = {}
var pending_install_purchase: StringName = &""
var pending_content_purchase: StringName = &""
## Tutorial state uses stable region/device IDs and is never inferred from UI.
var tutorial_completed_area_ids: Dictionary = {}
var tutorial_queue_area_ids: Array[StringName] = [&"area.pancake"]
var tutorial_queue_device_ids: Array[StringName] = []
var tutorial_active_kind: StringName = &"area"
var tutorial_active_id: StringName = &"area.pancake"
var tutorial_failure_count_by_id: Dictionary = {}


func _init(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		load_snapshot(snapshot)


func owns_area(area_id: StringName) -> bool:
	return bool(unlocked_area_ids.get(area_id, false))


func owns_growth(growth_id: StringName) -> bool:
	return bool(owned_growth_ids.get(growth_id, false))


func owns_recipe(recipe_id: StringName) -> bool:
	return bool(unlocked_recipe_ids.get(recipe_id, false))


func owns_product(product_id: StringName) -> bool:
	return bool(unlocked_product_ids.get(product_id, false))


func owns_stock(stock_id: StringName) -> bool:
	return bool(unlocked_stock_ids.get(stock_id, false))


func owns_automation(automation_id: StringName) -> bool:
	return bool(unlocked_automation_ids.get(automation_id, false))


func owns_assist(assist_id: StringName) -> bool:
	return bool(owned_assist_ids.get(assist_id, false))


func device_tier(device_id: StringName) -> int:
	return int(device_tiers.get(device_id, 0))


func mastery_value(area_id: StringName) -> int:
	var details := mastery_snapshot(area_id)
	if area_id == &"area.packaged_drink":
		return int(details.get("correct_temperature", 0))
	return int(details.get("qualified", area_mastery.get(area_id, 0)))


func mastery_snapshot(area_id: StringName) -> Dictionary:
	var details: Dictionary = Dictionary(area_mastery_details.get(area_id, {})).duplicate(true)
	if not details.has("qualified"):
		details["qualified"] = int(area_mastery.get(area_id, 0))
	if not details.has("a_grade"):
		details["a_grade"] = 0
	if not details.has("correct_temperature"):
		details["correct_temperature"] = int(area_mastery.get(area_id, 0)) if area_id == &"area.packaged_drink" else 0
	if not details.has("correct_streak_current"):
		details["correct_streak_current"] = 0
	if not details.has("correct_streak_best"):
		details["correct_streak_best"] = 0
	return details


func specialization_level(area_id: StringName) -> StringName:
	if not tutorial_completed_area_ids.has(area_id):
		return &"unrated"
	var definition := CATALOG.mastery_definition(area_id)
	if definition.is_empty():
		return &"unrated"
	var details := mastery_snapshot(area_id)
	var qualified_key := StringName(definition.get("qualified_key", &"qualified"))
	var a_grade_key := StringName(definition.get("a_grade_key", &"a_grade"))
	var qualified := int(details.get(qualified_key, 0))
	var a_grade := int(details.get(a_grade_key, 0))
	for level in [&"gold", &"silver", &"bronze"]:
		var threshold := Dictionary(definition.get(level, {}))
		if qualified >= int(threshold.get("qualified", 0)) and a_grade >= int(threshold.get("a_grade", 0)):
			return level
	return &"unrated"


func specialization_snapshot() -> Dictionary:
	var result := {}
	for area_id in CATALOG.AREA_IDS:
		result[str(area_id)] = specialization_level(area_id)
	return result


func set_day_open(value: bool) -> void:
	day_open = value


func purchase_status(growth_id: StringName) -> Dictionary:
	return _evaluate_purchase(growth_id)


func purchase(growth_id: StringName) -> Dictionary:
	var evaluation := _evaluate_purchase(growth_id)
	if not bool(evaluation.get("can_purchase", false)):
		return {"success": false, "reason": evaluation.get("reason", &"purchase_unavailable"), "status": evaluation}
	var slot: StringName = evaluation.get("purchase_slot", &"")
	coins -= int(evaluation.get("price", 0))
	_set_pending(slot, growth_id)
	return {
		"success": true,
		"growth_id": growth_id,
		"purchase_slot": slot,
		"charged_coins": int(evaluation.get("price", 0)),
		"activates_on_day": current_day + 1,
	}


func growth_recommendations(limit_total: int = 3) -> Dictionary:
	var safe_limit := maxi(limit_total, 0)
	var relevant: Array[Dictionary] = []
	var next_area_id := _next_locked_area_id()
	var catalog_ids: Array[StringName] = CATALOG.growth_ids()
	for catalog_index in catalog_ids.size():
		var growth_id := catalog_ids[catalog_index]
		var definition := CATALOG.growth_definition(growth_id)
		if not _is_recommendation_relevant(definition, next_area_id):
			continue
		var status := _evaluate_purchase(growth_id)
		if bool(status.get("already_owned", false)):
			continue
		status["catalog_index"] = catalog_index
		status["required_area_index"] = CATALOG.UNLOCK_AREA_IDS.find(StringName(definition.get("requires_area_id", &"")))
		status["structural_block_count"] = _structural_block_count(status)
		status["requirement_gap"] = _requirement_gap(status)
		relevant.append(status)
	relevant.sort_custom(_sort_recommendations)

	var primary_install: Dictionary = {}
	var primary_content: Dictionary = {}
	var next_area_unlock: Dictionary = {}
	for status in relevant:
		var definition := CATALOG.growth_definition(StringName(status.get("growth_id", &"")))
		var kind := StringName(definition.get("kind", &""))
		if primary_install.is_empty() and status.get("purchase_slot", &"") == INSTALL_SLOT and kind != &"area_unlock":
			primary_install = status
		if primary_content.is_empty() and status.get("purchase_slot", &"") == CONTENT_SLOT:
			primary_content = status
		if next_area_unlock.is_empty() and kind == &"area_unlock" and StringName(definition.get("area_id", &"")) == next_area_id:
			next_area_unlock = status

	var recommended: Array[Dictionary] = []
	_append_unique_recommendation(recommended, primary_install, safe_limit)
	_append_unique_recommendation(recommended, primary_content, safe_limit)
	_append_unique_recommendation(recommended, next_area_unlock, safe_limit)
	for status in relevant:
		_append_unique_recommendation(recommended, status, safe_limit)
		if recommended.size() >= safe_limit:
			break

	var install: Array[Dictionary] = []
	var content: Array[Dictionary] = []
	var nearest_locked: Array[Dictionary] = []
	for status in recommended:
		if status.get("purchase_slot", &"") == INSTALL_SLOT:
			install.append(status)
		else:
			content.append(status)
		if not bool(status.get("can_purchase", false)):
			nearest_locked.append(status)
	return {
		"recommended": recommended,
		"install": install,
		"content": content,
		"nearest_locked": nearest_locked,
	}


func record_area_result(area_id: StringName, result: Dictionary) -> Dictionary:
	if not owns_area(area_id):
		return {"success": false, "reason": &"area_locked"}
	var settlement_id := StringName(result.get("settlement_id", &""))
	if not settlement_id.is_empty() and applied_mastery_settlement_ids.has(settlement_id):
		return {"success": true, "changed": false, "reason": &"already_recorded", "area_id": area_id, "mastery": mastery_value(area_id), "details": mastery_snapshot(area_id)}
	var details := mastery_snapshot(area_id)
	var grade := str(result.get("grade", ""))
	var gained := 0
	if area_id == &"area.packaged_drink":
		var correct := bool(result.get("correct_temperature", false))
		if correct:
			gained = 1
			details["correct_temperature"] = int(details.get("correct_temperature", 0)) + 1
			details["correct_streak_current"] = int(details.get("correct_streak_current", 0)) + 1
			details["correct_streak_best"] = maxi(int(details.get("correct_streak_best", 0)), int(details.get("correct_streak_current", 0)))
		else:
			details["correct_streak_current"] = 0
		details["qualified"] = int(details.get("correct_temperature", 0))
	else:
		gained = 1 if grade == "A" or grade == "B" else 0
		if gained > 0:
			details["qualified"] = int(details.get("qualified", 0)) + 1
		if grade == "A":
			details["a_grade"] = int(details.get("a_grade", 0)) + 1
	area_mastery_details[area_id] = details
	area_mastery[area_id] = int(details.get("correct_temperature", 0)) if area_id == &"area.packaged_drink" else int(details.get("qualified", 0))
	if not settlement_id.is_empty():
		applied_mastery_settlement_ids[settlement_id] = true
	return {"success": true, "changed": true, "area_id": area_id, "mastery_gained": gained, "mastery": mastery_value(area_id), "details": details.duplicate(true)}


func tutorial_snapshot() -> Dictionary:
	return {
		"completed_area_ids": _snapshot_id_set(tutorial_completed_area_ids),
		"queue_area_ids": tutorial_queue_area_ids.duplicate(),
		"queue_device_ids": tutorial_queue_device_ids.duplicate(),
		"active_kind": tutorial_active_kind,
		"active_id": tutorial_active_id,
		"failure_count_by_id": tutorial_failure_count_by_id.duplicate(true),
	}


func complete_tutorial(kind: StringName, tutorial_id: StringName) -> Dictionary:
	if tutorial_active_kind != kind or tutorial_active_id != tutorial_id:
		return {"success": false, "reason": &"tutorial_not_active"}
	if kind == &"area":
		tutorial_completed_area_ids[tutorial_id] = true
		tutorial_queue_area_ids.erase(tutorial_id)
	elif kind == &"device":
		tutorial_queue_device_ids.erase(tutorial_id)
	else:
		return {"success": false, "reason": &"tutorial_kind_invalid"}
	tutorial_active_kind = &""
	tutorial_active_id = &""
	tutorial_failure_count_by_id.erase(tutorial_id)
	tutorial_failure_count_by_id.erase(str(tutorial_id))
	return {"success": true, "kind": kind, "tutorial_id": tutorial_id}


func record_tutorial_failure(kind: StringName, tutorial_id: StringName) -> Dictionary:
	if tutorial_active_kind != kind or tutorial_active_id != tutorial_id:
		return {"success": false, "reason": &"tutorial_not_active"}
	var failures := int(tutorial_failure_count_by_id.get(tutorial_id, tutorial_failure_count_by_id.get(str(tutorial_id), 0))) + 1
	tutorial_failure_count_by_id[tutorial_id] = failures
	var ended := failures >= 2
	if ended:
		_end_tutorial_without_mastery(kind, tutorial_id)
	return {"success": true, "kind": kind, "tutorial_id": tutorial_id, "failure_count": failures, "tutorial_ended": ended}


func skip_tutorial(kind: StringName, tutorial_id: StringName) -> Dictionary:
	if tutorial_active_kind != kind or tutorial_active_id != tutorial_id:
		return {"success": false, "reason": &"tutorial_not_active"}
	_end_tutorial_without_mastery(kind, tutorial_id)
	return {"success": true, "kind": kind, "tutorial_id": tutorial_id, "tutorial_ended": true, "skipped": true}


func _end_tutorial_without_mastery(kind: StringName, tutorial_id: StringName) -> void:
	if kind == &"area":
		tutorial_completed_area_ids[tutorial_id] = true
		tutorial_queue_area_ids.erase(tutorial_id)
	elif kind == &"device":
		tutorial_queue_device_ids.erase(tutorial_id)
	tutorial_active_kind = &""
	tutorial_active_id = &""


func advance_tutorial_for_new_business_day() -> Dictionary:
	if not tutorial_active_id.is_empty():
		return {"success": true, "active_kind": tutorial_active_kind, "active_id": tutorial_active_id}
	if not tutorial_queue_area_ids.is_empty():
		tutorial_active_kind = &"area"
		tutorial_active_id = tutorial_queue_area_ids.front()
	elif not tutorial_queue_device_ids.is_empty():
		tutorial_active_kind = &"device"
		tutorial_active_id = tutorial_queue_device_ids.front()
	return {"success": true, "active_kind": tutorial_active_kind, "active_id": tutorial_active_id}


func begin_next_business_day() -> Dictionary:
	if day_open:
		return {"success": false, "reason": &"business_day_open"}
	var rollback_snapshot := snapshot()
	var activated: Array[StringName] = []
	for slot in [INSTALL_SLOT, CONTENT_SLOT]:
		var growth_id := _pending_for(slot)
		if growth_id.is_empty():
			continue
		var definition := CATALOG.growth_definition(growth_id)
		if definition.is_empty() or definition.get("purchase_slot", &"") != slot:
			load_snapshot(rollback_snapshot)
			return {"success": false, "reason": &"activation_rollback", "failed_growth_id": growth_id, "activated_growth_ids": []}
		_apply_growth(growth_id, definition)
		activated.append(growth_id)
	pending_install_purchase = &""
	pending_content_purchase = &""
	current_day += 1
	day_open = true
	return {"success": true, "activated_growth_ids": activated, "current_day": current_day}


func snapshot() -> Dictionary:
	return {
		"coins": coins,
		"reputation": reputation,
		"current_day": current_day,
		"day_open": day_open,
		"unlocked_area_ids": _snapshot_id_set(unlocked_area_ids),
		"device_tiers": device_tiers.duplicate(true),
		"unlocked_recipe_ids": _snapshot_id_set(unlocked_recipe_ids),
		"unlocked_product_ids": _snapshot_id_set(unlocked_product_ids),
		"unlocked_stock_ids": _snapshot_id_set(unlocked_stock_ids),
		"unlocked_automation_ids": _snapshot_id_set(unlocked_automation_ids),
		"owned_assist_ids": _snapshot_id_set(owned_assist_ids),
		"owned_growth_ids": _snapshot_id_set(owned_growth_ids),
		"stock_capacity": stock_capacity,
		"area_mastery": area_mastery.duplicate(true),
		"area_mastery_details": area_mastery_details.duplicate(true),
		"specialization": specialization_snapshot(),
		"applied_mastery_settlement_ids": _snapshot_id_set(applied_mastery_settlement_ids),
		"pending_install_purchase": str(pending_install_purchase),
		"pending_content_purchase": str(pending_content_purchase),
		"tutorial": tutorial_snapshot(),
	}


func load_snapshot(value: Dictionary) -> void:
	coins = maxi(int(value.get("coins", 0)), 0)
	reputation = maxi(int(value.get("reputation", 0)), 0)
	current_day = maxi(int(value.get("current_day", 1)), 1)
	day_open = bool(value.get("day_open", true))
	unlocked_area_ids = _load_id_set(value.get("unlocked_area_ids", [&"area.pancake"]))
	if unlocked_area_ids.is_empty():
		unlocked_area_ids[&"area.pancake"] = true
	device_tiers = Dictionary(value.get("device_tiers", {&"device.pancake_griddle": 0})).duplicate(true)
	unlocked_recipe_ids = _load_id_set(value.get("unlocked_recipe_ids", [&"recipe.pancake.base"]))
	unlocked_product_ids = _load_id_set(value.get("unlocked_product_ids", [&"product.pancake.custom"]))
	unlocked_stock_ids = _load_id_set(value.get("unlocked_stock_ids", []))
	unlocked_automation_ids = _load_id_set(value.get("unlocked_automation_ids", []))
	owned_assist_ids = _load_id_set(value.get("owned_assist_ids", []))
	owned_growth_ids = _load_id_set(value.get("owned_growth_ids", []))
	stock_capacity = clampi(int(value.get("stock_capacity", 6)), 6, 14)
	area_mastery = Dictionary(value.get("area_mastery", {})).duplicate(true)
	area_mastery_details = Dictionary(value.get("area_mastery_details", {})).duplicate(true)
	applied_mastery_settlement_ids = _load_id_set(value.get("applied_mastery_settlement_ids", []))
	pending_install_purchase = StringName(value.get("pending_install_purchase", ""))
	pending_content_purchase = StringName(value.get("pending_content_purchase", ""))
	var tutorial: Dictionary = Dictionary(value.get("tutorial", {}))
	tutorial_completed_area_ids = _load_id_set(tutorial.get("completed_area_ids", []))
	tutorial_queue_area_ids = _load_id_array(tutorial.get("queue_area_ids", [&"area.pancake"]))
	tutorial_queue_device_ids = _load_id_array(tutorial.get("queue_device_ids", []))
	tutorial_active_kind = StringName(tutorial.get("active_kind", &"area"))
	tutorial_active_id = StringName(tutorial.get("active_id", &"area.pancake"))
	tutorial_failure_count_by_id = Dictionary(tutorial.get("failure_count_by_id", {})).duplicate(true)


func _evaluate_purchase(growth_id: StringName) -> Dictionary:
	var definition := CATALOG.growth_definition(growth_id)
	if definition.is_empty():
		return {"growth_id": growth_id, "can_purchase": false, "reason": &"unknown_growth", "missing_requirements": [{"reason": &"unknown_growth"}]}
	var slot: StringName = definition.get("purchase_slot", &"")
	var required_area: StringName = definition.get("requires_area_id", &"")
	var min_day := int(definition.get("min_day", 1))
	var min_reputation := int(definition.get("min_reputation", 0))
	var price := int(definition.get("price", 0))
	var status := {
		"growth_id": growth_id,
		"purchase_slot": slot,
		"kind": StringName(definition.get("kind", &"")),
		"price": price,
		"min_day": min_day,
		"current_day": current_day,
		"min_reputation": min_reputation,
		"current_reputation": reputation,
		"required_area_id": required_area,
		"target_area_id": StringName(definition.get("area_id", &"")),
		"already_owned": false,
		"can_purchase": false,
		"reason": &"",
		"missing_requirements": [],
	}
	if owns_growth(growth_id):
		status["already_owned"] = true
		status["reason"] = &"already_owned"
		return status
	var missing_requirements: Array[Dictionary] = []
	var pending := _pending_for(slot)
	if not pending.is_empty():
		missing_requirements.append({"reason": &"purchase_slot_occupied", "pending_growth_id": pending})
	if not required_area.is_empty() and not owns_area(required_area):
		missing_requirements.append({"reason": &"area_locked", "required_area_id": required_area})
	for required_growth_variant in Array(definition.get("requires_growth_ids", [])):
		var required_growth_id := StringName(required_growth_variant)
		if not owns_growth(required_growth_id):
			missing_requirements.append({"reason": &"growth_requirement", "required_growth_id": required_growth_id})
	if current_day < min_day:
		missing_requirements.append({"reason": &"day_requirement", "min_day": min_day, "current_day": current_day})
	if reputation < min_reputation:
		missing_requirements.append({"reason": &"reputation_requirement", "min_reputation": min_reputation, "current_reputation": reputation})
	var tutorial_area_id := StringName(definition.get("requires_tutorial_area_id", &""))
	if not tutorial_area_id.is_empty() and not tutorial_completed_area_ids.has(tutorial_area_id):
		missing_requirements.append({"reason": &"tutorial_requirement", "required_tutorial_area_id": tutorial_area_id, "requires_tutorial_area_id": tutorial_area_id})
	if bool(definition.get("requires_all_areas", false)):
		for area_id in CATALOG.UNLOCK_AREA_IDS:
			if not owns_area(area_id):
				missing_requirements.append({"reason": &"all_areas_requirement", "required_area_id": area_id})
				break
	var mastery_requirements: Dictionary = Dictionary(definition.get("requires_mastery", {}))
	for mastery_area_variant in mastery_requirements:
		var mastery_area_id := StringName(mastery_area_variant)
		var current_mastery := mastery_snapshot(mastery_area_id)
		var required_values: Dictionary = Dictionary(mastery_requirements[mastery_area_variant])
		for metric_variant in required_values:
			var metric := str(metric_variant)
			var required_value := int(required_values[metric_variant])
			var current_value := int(current_mastery.get(metric, 0))
			if current_value < required_value:
				missing_requirements.append({"reason": &"mastery_requirement", "mastery_area_id": mastery_area_id, "mastery_metric": StringName(metric), "current_mastery": current_value, "required_mastery": required_value})
	if coins < price:
		missing_requirements.append({"reason": &"insufficient_coins", "price": price, "current_coins": coins})
	status["missing_requirements"] = missing_requirements
	if missing_requirements.is_empty():
		status["can_purchase"] = true
		return status
	var primary_requirement: Dictionary = missing_requirements.front()
	status["reason"] = primary_requirement.get("reason", &"purchase_unavailable")
	for key in primary_requirement:
		if key != "reason":
			status[key] = primary_requirement[key]
	return status


func _apply_growth(growth_id: StringName, definition: Dictionary) -> void:
	owned_growth_ids[growth_id] = true
	var area_id: StringName = definition.get("area_id", &"")
	if not area_id.is_empty():
		unlocked_area_ids[area_id] = true
		if not tutorial_completed_area_ids.has(area_id) and not tutorial_queue_area_ids.has(area_id):
			tutorial_queue_area_ids.append(area_id)
	var device_id: StringName = definition.get("device_id", &"")
	if not device_id.is_empty():
		device_tiers[device_id] = maxi(device_tier(device_id), int(definition.get("target_tier", 1)))
		if definition.get("kind", &"") == &"device_tier" and not tutorial_queue_device_ids.has(device_id):
			tutorial_queue_device_ids.append(device_id)
	for recipe_id in definition.get("unlock_recipe_ids", []):
		unlocked_recipe_ids[recipe_id] = true
	for product_id in definition.get("unlock_product_ids", []):
		unlocked_product_ids[product_id] = true
	for stock_id in definition.get("unlock_stock_ids", []):
		unlocked_stock_ids[stock_id] = true
	var automation_id: StringName = definition.get("automation_id", &"")
	if not automation_id.is_empty():
		unlocked_automation_ids[automation_id] = true
	var assist_id: StringName = definition.get("assist_id", &"")
	if not assist_id.is_empty():
		owned_assist_ids[assist_id] = true
	if definition.get("kind", &"") == &"stock_capacity":
		stock_capacity = maxi(stock_capacity, int(definition.get("target_capacity", 6)))


func _pending_for(slot: StringName) -> StringName:
	return pending_install_purchase if slot == INSTALL_SLOT else pending_content_purchase


func _set_pending(slot: StringName, growth_id: StringName) -> void:
	if slot == INSTALL_SLOT:
		pending_install_purchase = growth_id
	else:
		pending_content_purchase = growth_id


func _snapshot_id_set(source: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for value in source:
		if bool(source[value]):
			result.append(str(value))
	return result


func _load_id_set(source: Variant) -> Dictionary:
	var result := {}
	for value in Array(source):
		result[StringName(value)] = true
	return result


func _load_id_array(source: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_id in Array(source):
		var id := StringName(raw_id)
		if not id.is_empty() and not result.has(id):
			result.append(id)
	return result


func _next_locked_area_id() -> StringName:
	for area_id in CATALOG.UNLOCK_AREA_IDS:
		if not owns_area(area_id):
			return area_id
	return &""


func _all_areas_owned() -> bool:
	return _next_locked_area_id().is_empty()


func _is_recommendation_relevant(definition: Dictionary, next_area_id: StringName) -> bool:
	if definition.is_empty():
		return false
	var required_area_id := StringName(definition.get("requires_area_id", &""))
	if required_area_id.is_empty() or not owns_area(required_area_id):
		return false
	var kind := StringName(definition.get("kind", &""))
	if kind == &"area_unlock":
		var target_area_id := StringName(definition.get("area_id", &""))
		return not next_area_id.is_empty() and target_area_id == next_area_id and not owns_area(target_area_id)
	if bool(definition.get("requires_all_areas", false)) and not _all_areas_owned():
		return false
	return true


static func _append_unique_recommendation(target: Array[Dictionary], status: Dictionary, limit_total: int) -> void:
	if status.is_empty() or target.size() >= limit_total:
		return
	var growth_id := StringName(status.get("growth_id", &""))
	for existing in target:
		if StringName(existing.get("growth_id", &"")) == growth_id:
			return
	target.append(status)


static func _structural_block_count(status: Dictionary) -> int:
	var count := 0
	for requirement_variant in Array(status.get("missing_requirements", [])):
		var requirement := Dictionary(requirement_variant)
		if StringName(requirement.get("reason", &"")) in [&"area_locked", &"growth_requirement", &"all_areas_requirement"]:
			count += 1
	return count


static func _requirement_gap(status: Dictionary) -> int:
	var gap := 0
	for requirement_variant in Array(status.get("missing_requirements", [])):
		var requirement := Dictionary(requirement_variant)
		match StringName(requirement.get("reason", &"")):
			&"day_requirement":
				gap += maxi(int(requirement.get("min_day", 1)) - int(requirement.get("current_day", 1)), 0)
			&"reputation_requirement":
				gap += maxi(int(requirement.get("min_reputation", 0)) - int(requirement.get("current_reputation", 0)), 0)
			&"mastery_requirement":
				gap += maxi(int(requirement.get("required_mastery", 0)) - int(requirement.get("current_mastery", 0)), 0)
	return gap


static func _sort_recommendations(left: Dictionary, right: Dictionary) -> bool:
	var left_rank := 0 if bool(left.get("can_purchase", false)) else 1
	var right_rank := 0 if bool(right.get("can_purchase", false)) else 1
	if left_rank != right_rank:
		return left_rank < right_rank
	var left_structural := int(left.get("structural_block_count", 0))
	var right_structural := int(right.get("structural_block_count", 0))
	if left_structural != right_structural:
		return left_structural < right_structural
	var left_day := int(left.get("min_day", 1))
	var right_day := int(right.get("min_day", 1))
	if left_day != right_day:
		return left_day < right_day
	var left_gap := int(left.get("requirement_gap", 0))
	var right_gap := int(right.get("requirement_gap", 0))
	if left_gap != right_gap:
		return left_gap < right_gap
	var left_area := int(left.get("required_area_index", -1))
	var right_area := int(right.get("required_area_index", -1))
	if left_area != right_area:
		return left_area < right_area
	var left_price := int(left.get("price", 0))
	var right_price := int(right.get("price", 0))
	if left_price != right_price:
		return left_price < right_price
	var left_catalog := int(left.get("catalog_index", 0))
	var right_catalog := int(right.get("catalog_index", 0))
	if left_catalog != right_catalog:
		return left_catalog < right_catalog
	return str(left.get("growth_id", "")) < str(right.get("growth_id", ""))
