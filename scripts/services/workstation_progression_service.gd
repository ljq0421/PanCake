extends RefCounted

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const INGREDIENT_STOCK_MODEL := preload("res://scripts/gameplay/ingredient_stock_model.gd")

var coins := 0
var reputation := 0
var current_day := 1
var metrics := {}
var equipment_levels := {}
var owned_items := {}
var pending_purchase: StringName = &""
var refill_progress := {}
var inventory: RefCounted


func _init(snapshot: Dictionary = {}) -> void:
	inventory = INGREDIENT_STOCK_MODEL.new({}, CATALOG.stock_ids(), 6, false)
	owned_items[CATALOG.TOOL_SPREADER_BASIC] = true
	owned_items[CATALOG.TOOL_SAUCE_BRUSH_MANUAL] = true
	owned_items[CATALOG.INGREDIENT_BOX_BASIC] = true
	for stock_id in [CATALOG.STOCK_EGG, CATALOG.STOCK_BAOCUI, CATALOG.STOCK_SCALLION]:
		inventory.call("set_current", stock_id, 6)
	if not snapshot.is_empty():
		load_snapshot(snapshot)


func owns(item_id: StringName) -> bool:
	return bool(owned_items.get(item_id, false))


func owns_equipment(device_id: StringName) -> bool:
	return equipment_tier(device_id) >= CATALOG.TIER_BASIC


func equipment_tier(device_id: StringName) -> int:
	return int(equipment_levels.get(device_id, -1))


func set_metric(metric_id: StringName, value: int) -> void:
	metrics[metric_id] = maxi(value, 0)


func metric(metric_id: StringName) -> int:
	return int(metrics.get(metric_id, 0))


func purchase(item_id: StringName) -> Dictionary:
	var definition := CATALOG.purchase_definition(item_id)
	if definition.is_empty():
		return _failure(&"unknown_purchase")
	var kind: StringName = definition.get("kind", &"")
	if kind == &"equipment":
		var device_id: StringName = definition.get("device_id", &"")
		var target_tier := int(definition.get("target_tier", -1))
		var current_tier := equipment_tier(device_id)
		if current_tier >= target_tier:
			return _failure(&"already_owned")
		if target_tier != current_tier + 1:
			return _failure(&"missing_previous_tier", {"required_tier": target_tier - 1})
	elif owns(item_id):
		return _failure(&"already_owned")
	if not pending_purchase.is_empty():
		return _failure(&"pending_purchase_exists", {"pending_purchase": pending_purchase})
	var requirement_failure := _check_requirements(definition)
	if not requirement_failure.is_empty():
		return requirement_failure
	var price := int(definition.get("price", 0))
	if coins < price:
		return _failure(&"insufficient_coins", {"required_coins": price, "current_coins": coins})
	coins -= price
	pending_purchase = item_id
	return _success({"item_id": item_id, "charged_coins": price, "activates_on_day": current_day + 1})


func begin_next_business_day() -> Dictionary:
	var activated: StringName = pending_purchase
	if not activated.is_empty():
		_apply_purchase(activated)
		pending_purchase = &""
	current_day += 1
	return {"success": true, "activated_item": activated, "current_day": current_day}


func debit(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	return true


func credit(amount: int) -> void:
	coins += maxi(amount, 0)


func ingredient_box_capacity() -> int:
	if owns(CATALOG.INGREDIENT_BOX_ADVANCED):
		return 14
	if owns(CATALOG.INGREDIENT_BOX_INTERMEDIATE):
		return 10
	return 6


func is_recipe_unlocked(recipe_id: StringName) -> bool:
	var definition := CATALOG.recipe_definition(recipe_id)
	if definition.is_empty():
		return false
	var unlock_item: StringName = definition.get("unlock_item", &"")
	return unlock_item.is_empty() or owns(unlock_item)


func refill_progress_for(stock_id: StringName) -> float:
	return maxf(float(refill_progress.get(stock_id, 0.0)), 0.0)


func set_refill_progress(stock_id: StringName, seconds: float) -> void:
	if not CATALOG.refill_definition(stock_id).is_empty():
		refill_progress[stock_id] = maxf(seconds, 0.0)


func snapshot() -> Dictionary:
	var equipment := {}
	for device_id in equipment_levels:
		equipment[str(device_id)] = int(equipment_levels[device_id])
	var items := PackedStringArray()
	for item_id in owned_items:
		if bool(owned_items[item_id]):
			items.append(str(item_id))
	var progress := {}
	for stock_id in refill_progress:
		progress[str(stock_id)] = float(refill_progress[stock_id])
	var metric_snapshot := {}
	for metric_id in metrics:
		metric_snapshot[str(metric_id)] = int(metrics[metric_id])
	return {
		"coins": coins,
		"reputation": reputation,
		"current_day": current_day,
		"metrics": metric_snapshot,
		"equipment_levels": equipment,
		"owned_items": items,
		"pending_purchase": str(pending_purchase),
		"ingredient_stock": inventory.call("snapshot"),
		"refill_progress": progress,
	}


func load_snapshot(snapshot: Dictionary) -> void:
	coins = maxi(int(snapshot.get("coins", 0)), 0)
	reputation = maxi(int(snapshot.get("reputation", 0)), 0)
	current_day = maxi(int(snapshot.get("current_day", 1)), 1)
	metrics.clear()
	for metric_id in Dictionary(snapshot.get("metrics", {})):
		metrics[StringName(metric_id)] = maxi(int(snapshot.metrics[metric_id]), 0)
	equipment_levels.clear()
	for device_id in Dictionary(snapshot.get("equipment_levels", {})):
		equipment_levels[StringName(device_id)] = clampi(int(snapshot.equipment_levels[device_id]), CATALOG.TIER_BASIC, CATALOG.TIER_ADVANCED)
	owned_items.clear()
	for item_id in Array(snapshot.get("owned_items", [])):
		owned_items[StringName(item_id)] = true
	# New-format snapshots are authoritative; only invariant starter ownership is enforced.
	owned_items[CATALOG.TOOL_SPREADER_BASIC] = true
	owned_items[CATALOG.TOOL_SAUCE_BRUSH_MANUAL] = true
	owned_items[CATALOG.INGREDIENT_BOX_BASIC] = true
	pending_purchase = StringName(snapshot.get("pending_purchase", ""))
	refill_progress.clear()
	for stock_id in Dictionary(snapshot.get("refill_progress", {})):
		set_refill_progress(StringName(stock_id), float(snapshot.refill_progress[stock_id]))
	inventory.call("set_capacity_for_all", ingredient_box_capacity())
	inventory.call("load_snapshot", Dictionary(snapshot.get("ingredient_stock", {})))


func _check_requirements(definition: Dictionary) -> Dictionary:
	var required_item: StringName = definition.get("requires_owned", &"")
	if not required_item.is_empty() and not owns(required_item):
		return _failure(&"missing_required_item", {"required_item": required_item})
	var required_equipment: StringName = definition.get("requires_equipment", &"")
	if not required_equipment.is_empty() and not owns_equipment(required_equipment):
		return _failure(&"equipment_not_owned", {"device_id": required_equipment})
	var minimum_day := int(definition.get("min_day", 1))
	if current_day < minimum_day:
		return _failure(&"day_requirement_not_met", {"required_day": minimum_day})
	var minimum_reputation := int(definition.get("min_reputation", 0))
	if reputation < minimum_reputation:
		return _failure(&"reputation_requirement_not_met", {"required_reputation": minimum_reputation})
	var metric_id: StringName = definition.get("metric", &"")
	var metric_value := int(definition.get("metric_value", 0))
	if not metric_id.is_empty() and metric(metric_id) < metric_value:
		return _failure(&"metric_requirement_not_met", {"metric": metric_id, "required_value": metric_value})
	return {}


func _apply_purchase(item_id: StringName) -> void:
	var definition := CATALOG.purchase_definition(item_id)
	var kind: StringName = definition.get("kind", &"")
	if kind == &"equipment":
		equipment_levels[definition.get("device_id", &"")] = int(definition.get("target_tier", CATALOG.TIER_BASIC))
		return
	owned_items[item_id] = true
	if kind == &"ingredient_box":
		inventory.call("set_capacity_for_all", int(CATALOG.item_effect(item_id).get("capacity", ingredient_box_capacity())))


func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": &""}
	result.merge(extra, true)
	return result


func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
