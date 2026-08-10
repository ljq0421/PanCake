class_name FiveAreaProgressionService
extends RefCounted

## Owns five-area progression state only.  It does not inspect scene nodes,
## manipulate stock quantities, or write save files; GameSessionStore becomes
## the persistence coordinator in phase 4.

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const INSTALL_SLOT := &"install"
const CONTENT_SLOT := &"content"
const DAY_END_GROWTH_CARD_COUNT := 3

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
	return _effective_purchase_status(growth_id)


func purchase(growth_id: StringName) -> Dictionary:
	var evaluation := _effective_purchase_status(growth_id)
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
	var raw_recommendations := _raw_growth_window(maxi(safe_limit, DAY_END_GROWTH_CARD_COUNT))
	var coin_guarantee_growth_id := _day_end_coin_guarantee_growth_id(raw_recommendations)
	var recommended: Array[Dictionary] = []
	for index in mini(safe_limit, raw_recommendations.size()):
		var status: Dictionary = raw_recommendations[index].duplicate(true)
		if StringName(status.get("growth_id", &"")) == coin_guarantee_growth_id:
			status = _apply_coin_guarantee(status)
		recommended.append(status)

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


func _effective_purchase_status(growth_id: StringName) -> Dictionary:
	var status := _evaluate_purchase(growth_id)
	var coin_guarantee_growth_id := _day_end_coin_guarantee_growth_id(_raw_growth_window(DAY_END_GROWTH_CARD_COUNT))
	if growth_id == coin_guarantee_growth_id:
		return _apply_coin_guarantee(status)
	return status


func _raw_growth_window(limit_total: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var safe_limit := maxi(limit_total, 0)
	for route_index in CATALOG.FIXED_GROWTH_ROUTE.size():
		if result.size() >= safe_limit:
			break
		var growth_id: StringName = CATALOG.FIXED_GROWTH_ROUTE[route_index]
		var status := _evaluate_purchase(growth_id)
		if bool(status.get("already_owned", false)):
			continue
		status["route_index"] = route_index
		result.append(status)
	return result


func _day_end_coin_guarantee_growth_id(raw_recommendations: Array[Dictionary]) -> StringName:
	if day_open or raw_recommendations.is_empty():
		return &""
	var canonical_count := mini(DAY_END_GROWTH_CARD_COUNT, raw_recommendations.size())
	for index in canonical_count:
		if _status_has_coin_path(raw_recommendations[index]):
			return &""
	var frontier: Dictionary = raw_recommendations.front()
	if bool(frontier.get("pending_activation", false)):
		return &""
	var purchase_slot := StringName(frontier.get("purchase_slot", &""))
	if purchase_slot not in [INSTALL_SLOT, CONTENT_SLOT] or not _pending_for(purchase_slot).is_empty():
		return &""
	return StringName(frontier.get("growth_id", &""))


func _status_has_coin_path(status: Dictionary) -> bool:
	if bool(status.get("can_purchase", false)):
		return true
	var missing_requirements: Array = Array(status.get("missing_requirements", []))
	if missing_requirements.is_empty():
		return false
	for requirement_variant in missing_requirements:
		var requirement := Dictionary(requirement_variant)
		if StringName(requirement.get("reason", &"")) != &"insufficient_coins":
			return false
	return true


func _apply_coin_guarantee(status: Dictionary) -> Dictionary:
	var effective := status.duplicate(true)
	effective["coin_guarantee"] = true
	var preserved_requirements: Array[Dictionary] = []
	for requirement_variant in Array(status.get("missing_requirements", [])):
		var requirement := Dictionary(requirement_variant).duplicate(true)
		var reason := StringName(requirement.get("reason", &""))
		if reason in [&"insufficient_coins", &"purchase_slot_occupied", &"unknown_growth"]:
			preserved_requirements.append(requirement)
	effective["missing_requirements"] = preserved_requirements
	if preserved_requirements.is_empty():
		effective["can_purchase"] = true
		effective["reason"] = &""
		return effective
	effective["can_purchase"] = false
	var primary_requirement: Dictionary = preserved_requirements.front()
	effective["reason"] = primary_requirement.get("reason", &"purchase_unavailable")
	for key in primary_requirement:
		if key != "reason":
			effective[key] = primary_requirement[key]
	return effective


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
	_reconcile_packaged_drink_tutorial()
	if not tutorial_active_id.is_empty():
		return {"success": true, "active_kind": tutorial_active_kind, "active_id": tutorial_active_id}
	if not tutorial_queue_area_ids.is_empty():
		tutorial_active_kind = &"area"
		tutorial_active_id = tutorial_queue_area_ids.front()
	elif not tutorial_queue_device_ids.is_empty():
		tutorial_active_kind = &"device"
		tutorial_active_id = tutorial_queue_device_ids.front()
	return {"success": true, "active_kind": tutorial_active_kind, "active_id": tutorial_active_id}


func _reconcile_packaged_drink_tutorial() -> void:
	# Older development saves can already own the cabinet without retaining the
	# tutorial queue entry. Recreate only this unfinished area tutorial and let
	# the normal queue ordering activate it at the next business-day boundary.
	var area_id := &"area.packaged_drink"
	if not owns_area(area_id) or tutorial_completed_area_ids.has(area_id):
		return
	if tutorial_active_kind == &"area" and tutorial_active_id == area_id:
		return
	if not tutorial_queue_area_ids.has(area_id):
		tutorial_queue_area_ids.append(area_id)


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
		push_error("Growth configuration is missing: %s" % growth_id)
		return {"growth_id": growth_id, "can_purchase": false, "reason": &"unknown_growth", "missing_requirements": [{"reason": &"unknown_growth", "growth_id": growth_id}]}
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
		"pending_activation": false,
		"coin_guarantee": false,
		"can_purchase": false,
		"current_coins": coins,
		"reason": &"",
		"missing_requirements": [],
	}
	if owns_growth(growth_id):
		status["already_owned"] = true
		status["reason"] = &"already_owned"
		return status
	var missing_requirements: Array[Dictionary] = []
	var pending := _pending_for(slot)
	if pending == growth_id:
		status["pending_activation"] = true
		status["reason"] = &"pending_activation"
		return status
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
		var current_area_count := 0
		for area_id in CATALOG.UNLOCK_AREA_IDS:
			if owns_area(area_id):
				current_area_count += 1
		for area_id in CATALOG.UNLOCK_AREA_IDS:
			if not owns_area(area_id):
				missing_requirements.append({"reason": &"all_areas_requirement", "required_area_id": area_id, "current_area_count": current_area_count, "required_area_count": CATALOG.UNLOCK_AREA_IDS.size()})
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
