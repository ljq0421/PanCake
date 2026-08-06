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
var device_tiers: Dictionary = {&"device.pancake_griddle": 1}
var unlocked_recipe_ids: Dictionary = {&"recipe.pancake.base": true}
var unlocked_stock_ids: Dictionary = {
	&"stock.pancake.batter": true,
	&"stock.pancake.egg": true,
	&"stock.pancake.baocui": true,
	&"stock.pancake.scallion": true,
	&"stock.pancake.sauce.sweet_flour": true,
}
var unlocked_automation_ids: Dictionary = {}
var owned_growth_ids: Dictionary = {}
var area_mastery: Dictionary = {}
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


func owns_stock(stock_id: StringName) -> bool:
	return bool(unlocked_stock_ids.get(stock_id, false))


func owns_automation(automation_id: StringName) -> bool:
	return bool(unlocked_automation_ids.get(automation_id, false))


func device_tier(device_id: StringName) -> int:
	return int(device_tiers.get(device_id, 0))


func mastery_value(area_id: StringName) -> int:
	return int(area_mastery.get(area_id, 0))


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


func growth_recommendations(limit_per_slot: int = 3) -> Dictionary:
	var all_install: Array[Dictionary] = []
	var all_content: Array[Dictionary] = []
	var nearest_locked: Array[Dictionary] = []
	for growth_id in CATALOG.growth_ids():
		var status := _evaluate_purchase(growth_id)
		if bool(status.get("already_owned", false)):
			continue
		if status.get("purchase_slot") == INSTALL_SLOT:
			all_install.append(status)
		else:
			all_content.append(status)
		if nearest_locked.size() < limit_per_slot and not bool(status.get("can_purchase", false)):
			nearest_locked.append(status)
	all_install.sort_custom(_sort_recommendations)
	all_content.sort_custom(_sort_recommendations)
	return {"install": all_install.slice(0, limit_per_slot), "content": all_content.slice(0, limit_per_slot), "nearest_locked": nearest_locked}


func record_area_result(area_id: StringName, result: Dictionary) -> Dictionary:
	if not owns_area(area_id):
		return {"success": false, "reason": &"area_locked"}
	var grade := str(result.get("grade", ""))
	var gained := 1 if grade == "A" or grade == "B" else 0
	if gained > 0:
		area_mastery[area_id] = mastery_value(area_id) + gained
	return {"success": true, "area_id": area_id, "mastery_gained": gained, "mastery": mastery_value(area_id)}


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
	return {"success": true, "kind": kind, "tutorial_id": tutorial_id}


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
		"unlocked_stock_ids": _snapshot_id_set(unlocked_stock_ids),
		"unlocked_automation_ids": _snapshot_id_set(unlocked_automation_ids),
		"owned_growth_ids": _snapshot_id_set(owned_growth_ids),
		"area_mastery": area_mastery.duplicate(true),
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
	device_tiers = Dictionary(value.get("device_tiers", {&"device.pancake_griddle": 1})).duplicate(true)
	unlocked_recipe_ids = _load_id_set(value.get("unlocked_recipe_ids", [&"recipe.pancake.base"]))
	unlocked_stock_ids = _load_id_set(value.get("unlocked_stock_ids", []))
	unlocked_automation_ids = _load_id_set(value.get("unlocked_automation_ids", []))
	owned_growth_ids = _load_id_set(value.get("owned_growth_ids", []))
	area_mastery = Dictionary(value.get("area_mastery", {})).duplicate(true)
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
		return {"growth_id": growth_id, "can_purchase": false, "reason": &"unknown_growth"}
	var slot: StringName = definition.get("purchase_slot", &"")
	if owns_growth(growth_id):
		return {"growth_id": growth_id, "purchase_slot": slot, "already_owned": true, "can_purchase": false, "reason": &"already_owned"}
	var pending := _pending_for(slot)
	if not pending.is_empty():
		return {"growth_id": growth_id, "purchase_slot": slot, "can_purchase": false, "reason": &"purchase_slot_occupied", "pending_growth_id": pending}
	var required_area: StringName = definition.get("requires_area_id", &"")
	if not required_area.is_empty() and not owns_area(required_area):
		return {"growth_id": growth_id, "purchase_slot": slot, "can_purchase": false, "reason": &"area_locked", "required_area_id": required_area}
	for required_growth_variant in Array(definition.get("requires_growth_ids", [])):
		var required_growth_id := StringName(required_growth_variant)
		if not owns_growth(required_growth_id):
			return {"growth_id": growth_id, "purchase_slot": slot, "can_purchase": false, "reason": &"growth_requirement", "required_growth_id": required_growth_id}
	var min_day := int(definition.get("min_day", 1))
	if current_day < min_day:
		return {"growth_id": growth_id, "purchase_slot": slot, "can_purchase": false, "reason": &"day_requirement", "min_day": min_day}
	var price := int(definition.get("price", 0))
	if coins < price:
		return {"growth_id": growth_id, "purchase_slot": slot, "can_purchase": false, "reason": &"insufficient_coins", "price": price, "current_coins": coins}
	return {"growth_id": growth_id, "purchase_slot": slot, "price": price, "can_purchase": true, "already_owned": false}


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
	for stock_id in definition.get("unlock_stock_ids", []):
		unlocked_stock_ids[stock_id] = true
	var automation_id: StringName = definition.get("automation_id", &"")
	if not automation_id.is_empty():
		unlocked_automation_ids[automation_id] = true


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


static func _sort_recommendations(left: Dictionary, right: Dictionary) -> bool:
	var left_rank := 0 if bool(left.get("can_purchase", false)) else 1
	var right_rank := 0 if bool(right.get("can_purchase", false)) else 1
	if left_rank != right_rank:
		return left_rank < right_rank
	return int(left.get("price", 0)) < int(right.get("price", 0))
