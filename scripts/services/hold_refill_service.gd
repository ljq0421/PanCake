extends RefCounted

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")

var progression: RefCounted


func _init(next_progression: RefCounted) -> void:
	progression = next_progression


func advance_hold(stock_id: StringName, delta: float) -> Dictionary:
	var definition := CATALOG.refill_definition(stock_id)
	if definition.is_empty():
		return _result(false, &"unknown_refill_entry", stock_id, 0, 0)
	var inventory: RefCounted = progression.get("inventory")
	if not bool(inventory.call("has_ingredient", stock_id)):
		return _result(false, &"unknown_refill_entry", stock_id, 0, 0)
	var unit_cost := int(definition.get("unit_cost", 0))
	var unit_seconds := maxf(float(definition.get("unit_seconds", 0.0)), 0.001)
	var current := int(inventory.call("current", stock_id))
	var capacity := int(inventory.call("capacity", stock_id))
	if current >= capacity:
		return _result(false, &"capacity_reached", stock_id, 0, 0)
	if int(progression.get("coins")) < unit_cost:
		return _result(false, &"insufficient_coins", stock_id, 0, 0)
	var progress := float(progression.call("refill_progress_for", stock_id)) + maxf(delta, 0.0)
	var completed_units := 0
	var charged_coins := 0
	var stop_reason: StringName = &""
	while progress + 0.0000001 >= unit_seconds:
		current = int(inventory.call("current", stock_id))
		capacity = int(inventory.call("capacity", stock_id))
		if current >= capacity:
			stop_reason = &"capacity_reached"
			progress = 0.0
			break
		if int(progression.get("coins")) < unit_cost:
			stop_reason = &"insufficient_coins"
			progress = 0.0
			break
		if not bool(inventory.call("add_one", stock_id)):
			stop_reason = &"capacity_reached"
			progress = 0.0
			break
		if not bool(progression.call("debit", unit_cost)):
			# Defensive rollback should never be needed after the funds check.
			inventory.call("set_current", stock_id, int(inventory.call("current", stock_id)) - 1)
			stop_reason = &"insufficient_coins"
			break
		progress = maxf(progress - unit_seconds, 0.0)
		completed_units += 1
		charged_coins += unit_cost
		if int(inventory.call("current", stock_id)) >= int(inventory.call("capacity", stock_id)):
			stop_reason = &"capacity_reached"
			progress = 0.0
			break
		if int(progression.get("coins")) < unit_cost:
			stop_reason = &"insufficient_coins"
			progress = 0.0
			break
	progression.call("set_refill_progress", stock_id, progress)
	return _result(true, stop_reason, stock_id, completed_units, charged_coins)


func release(stock_id: StringName) -> Dictionary:
	return status(stock_id)


func status(stock_id: StringName) -> Dictionary:
	var definition := CATALOG.refill_definition(stock_id)
	if definition.is_empty():
		return {"success": false, "reason": &"unknown_refill_entry"}
	var inventory: RefCounted = progression.get("inventory")
	var unit_seconds := maxf(float(definition.get("unit_seconds", 0.0)), 0.001)
	var progress := float(progression.call("refill_progress_for", stock_id))
	return {
		"success": true,
		"reason": &"",
		"stock_id": stock_id,
		"unit_cost": int(definition.get("unit_cost", 0)),
		"unit_seconds": unit_seconds,
		"current_stock": int(inventory.call("current", stock_id)),
		"capacity": int(inventory.call("capacity", stock_id)),
		"progress_seconds": progress,
		"progress_ratio": clampf(progress / unit_seconds, 0.0, 1.0),
	}


func _result(success: bool, reason: StringName, stock_id: StringName, completed_units: int, charged_coins: int) -> Dictionary:
	var result := status(stock_id)
	result["success"] = success
	result["reason"] = reason
	result["completed_units"] = completed_units
	result["charged_coins"] = charged_coins
	result["auto_stopped"] = not reason.is_empty()
	return result
