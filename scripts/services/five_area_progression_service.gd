class_name FiveAreaProgressionService
extends RefCounted

## Owns five-area progression state only.  It does not inspect scene nodes,
## manipulate stock quantities, or write save files; GameSessionStore becomes
## the persistence coordinator in phase 4.

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

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
	&"stock.pancake.sauce.sweet_flour": true,
}
var unlocked_automation_ids: Dictionary = {}
var owned_assist_ids: Dictionary = {}
var owned_growth_ids: Dictionary = {}
var stock_capacity := 6
var area_mastery: Dictionary = {}
var area_mastery_details: Dictionary = {}
var applied_mastery_settlement_ids: Dictionary = {}
## Ordered day-end transaction. Every queued item is charged immediately and
## activates together when the next business day opens.
var pending_growth_ids: Array[StringName] = []
## Tutorial state uses stable region/device IDs and is never inferred from UI.
var tutorial_completed_area_ids: Dictionary = {}
var tutorial_completed_device_ids: Dictionary = {}
var tutorial_queue_area_ids: Array[StringName] = [&"area.pancake"]
var tutorial_queue_device_ids: Array[StringName] = []
var tutorial_active_kind: StringName = &"area"
var tutorial_active_id: StringName = &"area.pancake"
var tutorial_failure_count_by_id: Dictionary = {}
## Action progress and final outcomes are deliberately separate.  Completing a
## gesture can advance the guide, but only a correct delivery records
## `completed`; an explicit opt-out records `skipped`.
var tutorial_action_ids_by_id: Dictionary = {}
var tutorial_order_validation_by_id: Dictionary = {}
var tutorial_final_outcome_by_id: Dictionary = {}


func _init(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		load_snapshot(snapshot)


func owns_area(area_id: StringName) -> bool:
	return bool(unlocked_area_ids.get(area_id, false))


func owns_device(device_id: StringName) -> bool:
	return device_tiers.has(device_id) or device_tiers.has(str(device_id))


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
	return int(details.get("qualified", area_mastery.get(area_id, 0)))


func mastery_snapshot(area_id: StringName) -> Dictionary:
	var details: Dictionary = Dictionary(area_mastery_details.get(area_id, {})).duplicate(true)
	if not details.has("qualified"):
		details["qualified"] = int(area_mastery.get(area_id, 0))
	if not details.has("a_grade"):
		details["a_grade"] = 0
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
	coins -= int(evaluation.get("price", 0))
	pending_growth_ids.append(growth_id)
	return {
		"success": true,
		"growth_id": growth_id,
		"charged_coins": int(evaluation.get("price", 0)),
		"activates_on_day": current_day + 1,
		"pending_growth_ids": pending_growth_ids.duplicate(),
	}


func growth_overview() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for display_index in CATALOG.GROWTH_DISPLAY_ORDER.size():
		var growth_id: StringName = CATALOG.GROWTH_DISPLAY_ORDER[display_index]
		var status := _evaluate_purchase(growth_id)
		status["display_index"] = display_index
		status["anchor_id"] = StringName(CATALOG.growth_definition(growth_id).get("anchor_id", &""))
		result.append(status)
	return result


## Retained as a non-limiting compatibility entry point for non-workshop UI.
func growth_recommendations(_limit_total: int = 0) -> Dictionary:
	var overview := growth_overview()
	return {"recommended": overview, "install": overview, "content": overview, "nearest_locked": overview.filter(func(item: Dictionary) -> bool: return not bool(item.get("can_purchase", false)))}

func record_area_result(area_id: StringName, result: Dictionary) -> Dictionary:
	if not owns_area(area_id):
		return {"success": false, "reason": &"area_locked"}
	var settlement_id := StringName(result.get("settlement_id", &""))
	if not settlement_id.is_empty() and applied_mastery_settlement_ids.has(settlement_id):
		return {"success": true, "changed": false, "reason": &"already_recorded", "area_id": area_id, "mastery": mastery_value(area_id), "details": mastery_snapshot(area_id)}
	var details := mastery_snapshot(area_id)
	var grade := str(result.get("grade", ""))
	var gained := 1 if grade == "A" or grade == "B" else 0
	if gained > 0:
		details["qualified"] = int(details.get("qualified", 0)) + 1
	if grade == "A":
		details["a_grade"] = int(details.get("a_grade", 0)) + 1
	area_mastery_details[area_id] = details
	area_mastery[area_id] = int(details.get("qualified", 0))
	if not settlement_id.is_empty():
		applied_mastery_settlement_ids[settlement_id] = true
	return {"success": true, "changed": true, "area_id": area_id, "mastery_gained": gained, "mastery": mastery_value(area_id), "details": details.duplicate(true)}


func tutorial_snapshot() -> Dictionary:
	return {
		"completed_area_ids": _snapshot_id_set(tutorial_completed_area_ids),
		# Retain the legacy keys for readers of older snapshots, but tutorials are
		# now exclusively area-scoped.
		"completed_device_ids": PackedStringArray(),
		"queue_area_ids": tutorial_queue_area_ids.duplicate(),
		"queue_device_ids": PackedStringArray(),
		"active_kind": tutorial_active_kind,
		"active_id": tutorial_active_id,
		"failure_count_by_id": tutorial_failure_count_by_id.duplicate(true),
		"action_ids_by_id": tutorial_action_ids_by_id.duplicate(true),
		"order_validation_by_id": tutorial_order_validation_by_id.duplicate(true),
		"final_outcome_by_id": tutorial_final_outcome_by_id.duplicate(true),
	}


func record_tutorial_action(kind: StringName, tutorial_id: StringName, action_id: StringName) -> Dictionary:
	if kind != &"area":
		return {"success": false, "reason": &"tutorial_kind_invalid"}
	if tutorial_active_kind != kind or tutorial_active_id != tutorial_id:
		return {"success": false, "reason": &"tutorial_not_active"}
	if action_id.is_empty():
		return {"success": false, "reason": &"tutorial_action_invalid"}
	var key := str(tutorial_id)
	var actions := PackedStringArray(tutorial_action_ids_by_id.get(key, PackedStringArray()))
	if not actions.has(str(action_id)):
		actions.append(str(action_id))
	tutorial_action_ids_by_id[key] = actions
	return {
		"success": true,
		"kind": kind,
		"tutorial_id": tutorial_id,
		"action_id": action_id,
		"final_outcome": &"pending",
		"actions": actions.duplicate(),
	}


func record_tutorial_order_validation(kind: StringName, tutorial_id: StringName, correct: bool, mismatch_reasons: Array = []) -> Dictionary:
	if kind != &"area":
		return {"success": false, "reason": &"tutorial_kind_invalid"}
	if tutorial_active_kind != kind or tutorial_active_id != tutorial_id:
		return {"success": false, "reason": &"tutorial_not_active"}
	var value := {
		"result": &"correct" if correct else &"incorrect",
		"mismatch_reasons": PackedStringArray(mismatch_reasons),
	}
	tutorial_order_validation_by_id[str(tutorial_id)] = value
	return {
		"success": true,
		"kind": kind,
		"tutorial_id": tutorial_id,
		"order_validation": value.duplicate(true),
		"final_outcome": &"pending",
	}


func complete_tutorial(kind: StringName, tutorial_id: StringName) -> Dictionary:
	if kind != &"area":
		return {"success": false, "reason": &"tutorial_kind_invalid"}
	if tutorial_active_kind != kind or tutorial_active_id != tutorial_id:
		return {"success": false, "reason": &"tutorial_not_active"}
	tutorial_completed_area_ids[tutorial_id] = true
	tutorial_queue_area_ids.erase(tutorial_id)
	tutorial_active_kind = &""
	tutorial_active_id = &""
	tutorial_failure_count_by_id.erase(tutorial_id)
	tutorial_failure_count_by_id.erase(str(tutorial_id))
	tutorial_final_outcome_by_id[str(tutorial_id)] = &"completed"
	return {"success": true, "kind": kind, "tutorial_id": tutorial_id, "final_outcome": &"completed"}


func record_tutorial_failure(kind: StringName, tutorial_id: StringName) -> Dictionary:
	if kind != &"area":
		return {"success": false, "reason": &"tutorial_kind_invalid"}
	if tutorial_active_kind != kind or tutorial_active_id != tutorial_id:
		return {"success": false, "reason": &"tutorial_not_active"}
	var failures := int(tutorial_failure_count_by_id.get(tutorial_id, tutorial_failure_count_by_id.get(str(tutorial_id), 0))) + 1
	tutorial_failure_count_by_id[tutorial_id] = failures
	return {"success": true, "kind": kind, "tutorial_id": tutorial_id, "failure_count": failures, "tutorial_ended": false, "final_outcome": &"pending"}


func skip_tutorial(kind: StringName, tutorial_id: StringName) -> Dictionary:
	if kind != &"area":
		return {"success": false, "reason": &"tutorial_kind_invalid"}
	if tutorial_active_kind != kind or tutorial_active_id != tutorial_id:
		return {"success": false, "reason": &"tutorial_not_active"}
	_end_tutorial_without_mastery(kind, tutorial_id)
	tutorial_final_outcome_by_id[str(tutorial_id)] = &"skipped"
	return {"success": true, "kind": kind, "tutorial_id": tutorial_id, "tutorial_ended": true, "skipped": true, "final_outcome": &"skipped"}


func _end_tutorial_without_mastery(kind: StringName, tutorial_id: StringName) -> void:
	if kind == &"area":
		tutorial_completed_area_ids[tutorial_id] = true
		tutorial_queue_area_ids.erase(tutorial_id)
	tutorial_active_kind = &""
	tutorial_active_id = &""


func advance_tutorial_for_new_business_day() -> Dictionary:
	_reconcile_owned_area_tutorials()
	if not tutorial_active_id.is_empty():
		return {"success": true, "active_kind": tutorial_active_kind, "active_id": tutorial_active_id}
	if not tutorial_queue_area_ids.is_empty():
		tutorial_active_kind = &"area"
		tutorial_active_id = tutorial_queue_area_ids.front()
	return {"success": true, "active_kind": tutorial_active_kind, "active_id": tutorial_active_id}


func _reconcile_owned_area_tutorials() -> void:
	# Older saves can own an area without retaining its one-time tutorial queue
	# entry. Recreate every unfinished owned area, never a completed one.
	for area_id in CATALOG.AREA_IDS:
		if not owns_area(area_id) or tutorial_completed_area_ids.has(area_id):
			continue
		if tutorial_active_kind == &"area" and tutorial_active_id == area_id:
			continue
		if not tutorial_queue_area_ids.has(area_id):
			tutorial_queue_area_ids.append(area_id)


func begin_next_business_day() -> Dictionary:
	if day_open:
		return {"success": false, "reason": &"business_day_open"}
	var rollback_snapshot := snapshot()
	var activated: Array[StringName] = []
	for growth_id in pending_growth_ids:
		var definition := CATALOG.growth_definition(growth_id)
		var activation_status := _evaluate_activation(growth_id)
		if definition.is_empty() or not bool(activation_status.get("can_activate", false)):
			load_snapshot(rollback_snapshot)
			return {"success": false, "reason": &"activation_rollback", "failed_growth_id": growth_id, "activated_growth_ids": []}
		_apply_growth(growth_id, definition)
		activated.append(growth_id)
	pending_growth_ids.clear()
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
		"pending_growth_ids": pending_growth_ids.duplicate(),
		"tutorial": tutorial_snapshot(),
	}


func load_snapshot(value: Dictionary) -> void:
	coins = maxi(int(value.get("coins", 0)), 0)
	reputation = maxi(int(value.get("reputation", 0)), 0)
	current_day = maxi(int(value.get("current_day", 1)), 1)
	day_open = bool(value.get("day_open", true))
	unlocked_area_ids = _load_id_set(value.get("unlocked_area_ids", [&"area.pancake"]))
	unlocked_area_ids[&"area.pancake"] = true
	device_tiers = Dictionary(value.get("device_tiers", {&"device.pancake_griddle": 0})).duplicate(true)
	# The storefront now has one permanent griddle. Normalize legacy tiered saves.
	device_tiers[&"device.pancake_griddle"] = 0
	unlocked_recipe_ids = _load_id_set(value.get("unlocked_recipe_ids", [&"recipe.pancake.base"]))
	unlocked_recipe_ids[&"recipe.pancake.base"] = true
	unlocked_product_ids = _load_id_set(value.get("unlocked_product_ids", [&"product.pancake.custom"]))
	unlocked_product_ids[&"product.pancake.custom"] = true
	unlocked_stock_ids = _load_id_set(value.get("unlocked_stock_ids", []))
	# The three historic sauce stocks now resolve to one player-facing secret
	# sauce. Preserve access for an existing save before retired IDs are pruned.
	if bool(unlocked_stock_ids.get(&"stock.pancake.sauce.red_chili", false)) or bool(unlocked_stock_ids.get(&"stock.pancake.sauce.tomato", false)):
		unlocked_stock_ids[&"stock.pancake.sauce.sweet_flour"] = true
	for starter_stock_id in [
		&"stock.pancake.batter",
		&"stock.pancake.sauce.sweet_flour",
	]:
		unlocked_stock_ids[starter_stock_id] = true
	unlocked_automation_ids = _load_id_set(value.get("unlocked_automation_ids", []))
	owned_assist_ids = _load_id_set(value.get("owned_assist_ids", []))
	owned_growth_ids = _load_id_set(value.get("owned_growth_ids", []))
	stock_capacity = clampi(int(value.get("stock_capacity", 6)), 6, 14)
	area_mastery = Dictionary(value.get("area_mastery", {})).duplicate(true)
	area_mastery_details = Dictionary(value.get("area_mastery_details", {})).duplicate(true)
	applied_mastery_settlement_ids = _load_id_set(value.get("applied_mastery_settlement_ids", []))
	pending_growth_ids = _load_id_array(value.get("pending_growth_ids", []))
	var tutorial: Dictionary = Dictionary(value.get("tutorial", {}))
	tutorial_completed_area_ids = _load_id_set(tutorial.get("completed_area_ids", []))
	tutorial_completed_device_ids = {}
	tutorial_queue_area_ids = _load_id_array(tutorial.get("queue_area_ids", [&"area.pancake"]))
	tutorial_queue_device_ids = []
	tutorial_active_kind = StringName(tutorial.get("active_kind", &"area"))
	tutorial_active_id = StringName(tutorial.get("active_id", &"area.pancake"))
	tutorial_failure_count_by_id = Dictionary(tutorial.get("failure_count_by_id", {})).duplicate(true)
	tutorial_action_ids_by_id = Dictionary(tutorial.get("action_ids_by_id", {})).duplicate(true)
	tutorial_order_validation_by_id = Dictionary(tutorial.get("order_validation_by_id", {})).duplicate(true)
	tutorial_final_outcome_by_id = Dictionary(tutorial.get("final_outcome_by_id", {})).duplicate(true)
	_normalize_three_area_state()


func _normalize_three_area_state() -> void:
	unlocked_area_ids = _active_area_set(unlocked_area_ids)
	device_tiers = _active_definition_dictionary(device_tiers, &"device")
	unlocked_recipe_ids = _active_definition_set(unlocked_recipe_ids, &"recipe")
	unlocked_product_ids = _active_definition_set(unlocked_product_ids, &"product")
	unlocked_stock_ids = _active_definition_set(unlocked_stock_ids, &"stock")
	var active_growth := {}
	for growth_id in owned_growth_ids:
		if bool(owned_growth_ids[growth_id]) and CATALOG.GROWTH_DISPLAY_ORDER.has(StringName(growth_id)):
			active_growth[StringName(growth_id)] = true
	owned_growth_ids = active_growth
	var active_assists := {}
	for growth_id in CATALOG.GROWTH_DEFINITIONS:
		var assist_id := StringName(Dictionary(CATALOG.GROWTH_DEFINITIONS[growth_id]).get("assist_id", &""))
		if not assist_id.is_empty() and bool(owned_assist_ids.get(assist_id, false)):
			active_assists[assist_id] = true
	owned_assist_ids = active_assists
	area_mastery = _active_area_dictionary(area_mastery)
	area_mastery_details = _active_area_dictionary(area_mastery_details)
	tutorial_completed_area_ids = _active_area_set(tutorial_completed_area_ids)
	tutorial_queue_area_ids = _active_area_array(tutorial_queue_area_ids)
	tutorial_completed_device_ids = {}
	tutorial_queue_device_ids = []
	if tutorial_active_kind != &"area" or not CATALOG.AREA_IDS.has(tutorial_active_id):
		tutorial_active_kind = &""
		tutorial_active_id = &""
	pending_growth_ids = _active_growth_array(pending_growth_ids)
	unlocked_area_ids[&"area.pancake"] = true
	device_tiers[&"device.pancake_griddle"] = 0
	for starter_recipe in [&"recipe.pancake.base"]:
		unlocked_recipe_ids[starter_recipe] = true
	unlocked_product_ids[&"product.pancake.custom"] = true
	for starter_stock in [&"stock.pancake.batter", &"stock.pancake.sauce.sweet_flour"]:
		unlocked_stock_ids[starter_stock] = true


func _active_area_set(source: Dictionary) -> Dictionary:
	var result := {}
	for raw_id in source:
		var id := StringName(raw_id)
		if bool(source[raw_id]) and CATALOG.AREA_IDS.has(id):
			result[id] = true
	return result


func _active_area_dictionary(source: Dictionary) -> Dictionary:
	var result := {}
	for raw_id in source:
		var id := StringName(raw_id)
		if CATALOG.AREA_IDS.has(id):
			result[id] = source[raw_id]
	return result


func _active_area_array(source: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in source:
		if CATALOG.AREA_IDS.has(id) and not result.has(id):
			result.append(id)
	return result


func _active_growth_array(source: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in source:
		if CATALOG.GROWTH_DISPLAY_ORDER.has(id) and not owns_growth(id) and not result.has(id):
			result.append(id)
	return result


func _active_definition_set(source: Dictionary, kind: StringName) -> Dictionary:
	var result := {}
	for raw_id in source:
		var id := StringName(raw_id)
		var definition := _definition_for_kind(kind, id)
		if bool(source[raw_id]) and CATALOG.AREA_IDS.has(StringName(definition.get("area_id", &""))):
			result[id] = true
	return result


func _active_definition_dictionary(source: Dictionary, kind: StringName) -> Dictionary:
	var result := {}
	for raw_id in source:
		var id := StringName(raw_id)
		var definition := _definition_for_kind(kind, id)
		if CATALOG.AREA_IDS.has(StringName(definition.get("area_id", &""))):
			result[id] = source[raw_id]
	return result


func _definition_for_kind(kind: StringName, id: StringName) -> Dictionary:
	match kind:
		&"device": return CATALOG.device_definition(id)
		&"recipe": return CATALOG.recipe_definition(id)
		&"product": return CATALOG.product_definition(id)
		&"stock": return CATALOG.stock_definition(id)
	return {}


func _device_is_active(device_id: StringName) -> bool:
	return CATALOG.AREA_IDS.has(StringName(CATALOG.device_definition(device_id).get("area_id", &"")))


func _active_device_set(source: Dictionary) -> Dictionary:
	var result := {}
	for raw_id in source:
		var id := StringName(raw_id)
		if bool(source[raw_id]) and _device_is_active(id):
			result[id] = true
	return result


func _active_device_array(source: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in source:
		if _device_is_active(id) and not result.has(id):
			result.append(id)
	return result


func _evaluate_purchase(growth_id: StringName) -> Dictionary:
	var definition := CATALOG.growth_definition(growth_id)
	if definition.is_empty():
		push_error("Growth configuration is missing: %s" % growth_id)
		return {"growth_id": growth_id, "can_purchase": false, "reason": &"unknown_growth", "missing_requirements": [{"reason": &"unknown_growth", "growth_id": growth_id}]}
	var required_area: StringName = definition.get("requires_area_id", &"")
	var min_day := int(definition.get("min_day", 1))
	var min_reputation := int(definition.get("min_reputation", 0))
	var price := int(definition.get("price", 0))
	var status := {
		"growth_id": growth_id,
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
	if pending_growth_ids.has(growth_id):
		status["pending_activation"] = true
		status["reason"] = &"pending_activation"
		return status
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
	var growth_kind := StringName(definition.get("kind", &""))
	var area_id: StringName = definition.get("area_id", &"")
	if not area_id.is_empty():
		unlocked_area_ids[area_id] = true
		if growth_kind == &"area_unlock" and not tutorial_completed_area_ids.has(area_id) and not tutorial_queue_area_ids.has(area_id):
			tutorial_queue_area_ids.append(area_id)
	var device_id: StringName = definition.get("device_id", &"")
	if not device_id.is_empty():
		device_tiers[device_id] = maxi(device_tier(device_id), int(definition.get("target_tier", 1)))
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

## Booking requires all prerequisites to be active already. Activation only
## rechecks the structural facts that were true at the time of booking.
func _evaluate_activation(growth_id: StringName) -> Dictionary:
	var definition := CATALOG.growth_definition(growth_id)
	if definition.is_empty() or owns_growth(growth_id):
		return {"can_activate": false}
	var required_area := StringName(definition.get("requires_area_id", &""))
	if not required_area.is_empty() and not owns_area(required_area):
		return {"can_activate": false}
	for raw_required_growth_id in Array(definition.get("requires_growth_ids", [])):
		if not owns_growth(StringName(raw_required_growth_id)):
			return {"can_activate": false}
	return {"can_activate": true}


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
